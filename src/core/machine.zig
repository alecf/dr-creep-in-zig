//! C64 machine model, tailored to what The Castles of Dr. Creep uses.
//!
//! The game banks out BASIC and KERNAL entirely ($01 = $05: I/O visible,
//! everything else RAM) and installs its own hardware IRQ/NMI vectors at
//! $FFFE/$FFFA. That means: no C64 ROM dumps are needed. The only ROM
//! service the game consumes is disk loading, which it performs with its
//! own drive code — intercepted here via the lift-table (see `Hook`).
//!
//! Timing model: coarse scanline stepping (NTSC: 65 cycles x 263 lines,
//! ~60 fps), sufficient for this game, which paces itself on the VIC
//! raster interrupt rather than cycle-exact tricks.

const std = @import("std");
const cpu6502 = @import("cpu6502.zig");

pub const CYCLES_PER_LINE = 65; // NTSC 6510
pub const LINES_PER_FRAME = 263;

pub const Machine = struct {
    ram: [0x10000]u8 = @splat(0),
    color_ram: [0x400]u8 = @splat(0),
    vic: [0x40]u8 = @splat(0),
    sid: [0x20]u8 = @splat(0),
    cia1_pra: u8 = 0xFF,
    cia1_prb: u8 = 0xFF,
    cia1_ddra: u8 = 0,
    cia1_ddrb: u8 = 0,
    cia1_icr_mask: u8 = 0,
    cia1_icr_flags: u8 = 0,
    cia2_pra: u8 = 0x03, // VIC bank bits (inverted): 0b11 = bank 0
    cpu_port: u8 = 0x37,
    cpu_ddr: u8 = 0x2F,

    raster_line: u16 = 0,
    frame: u64 = 0,

    /// joystick port 2 (the game's primary): active-low bits up/down/left/right/fire
    joy2: u8 = 0x1F,
    joy1: u8 = 0x1F,
    /// keyboard matrix rows (active-low), indexed by column select
    key_matrix: [8]u8 = @splat(0xFF),

    /// C64 character generator ROM (4KB). The VIC sees it at $1000-$1FFF in
    /// banks 0/2 regardless of CPU banking. Optional: zeroed if not provided
    /// (the game's own screens use custom charsets; only the boot menu uses
    /// the stock font).
    char_rom: [0x1000]u8 = @splat(0),

    cpu: Cpu = undefined,

    /// SID writes this frame, in order — captured for the audio layer.
    sid_log: std.ArrayList(SidWrite) = .empty,
    allocator: std.mem.Allocator,

    /// Lift table: native Zig implementations keyed by 6502 entry PC.
    /// When the CPU is about to execute one of these addresses, the hook
    /// runs instead and the CPU returns as if the routine executed (RTS).
    hooks: std.AutoHashMap(u16, Hook),

    pub const SidWrite = struct { frame: u64, line: u16, reg: u8, val: u8 };
    pub const Hook = struct {
        name: []const u8,
        /// return false to fall through to the original 6502 code
        func: *const fn (*Machine) bool,
    };
    pub const Cpu = cpu6502.Cpu(Machine);

    pub fn init(allocator: std.mem.Allocator) !*Machine {
        const m = try allocator.create(Machine);
        m.* = .{
            .allocator = allocator,
            .hooks = std.AutoHashMap(u16, Hook).init(allocator),
        };
        m.cpu = Cpu.init(m);
        return m;
    }

    pub fn deinit(self: *Machine) void {
        self.sid_log.deinit(self.allocator);
        self.hooks.deinit();
        self.allocator.destroy(self);
    }

    fn ioVisible(self: *const Machine) bool {
        // I/O appears at $D000-$DFFF when CHAREN=1 and at least one of
        // LORAM/HIRAM is set. The game runs with $01 = $05 (0b101).
        const port = self.cpu_port | ~self.cpu_ddr; // inputs read high
        return (port & 0x04 != 0) and (port & 0x03 != 0);
    }

    pub fn read8(self: *Machine, addr: u16) u8 {
        switch (addr) {
            0x0000 => return self.cpu_ddr,
            0x0001 => return (self.cpu_port & self.cpu_ddr) | (0x17 & ~self.cpu_ddr),
            else => {},
        }
        if (addr >= 0xD000 and addr <= 0xDFFF and self.ioVisible()) {
            return switch (addr & 0x0F00) {
                0x0000, 0x0100, 0x0200, 0x0300 => self.readVic(@intCast(addr & 0x3F)),
                0x0400, 0x0500, 0x0600, 0x0700 => self.sid[addr & 0x1F],
                0x0800, 0x0900, 0x0A00, 0x0B00 => self.color_ram[addr & 0x3FF] | 0xF0,
                0x0C00 => self.readCia1(@intCast(addr & 0x0F)),
                0x0D00 => self.readCia2(@intCast(addr & 0x0F)),
                else => 0xFF,
            };
        }
        return self.ram[addr];
    }

    pub fn write8(self: *Machine, addr: u16, v: u8) void {
        switch (addr) {
            0x0000 => {
                self.cpu_ddr = v;
                return;
            },
            0x0001 => {
                self.cpu_port = v;
                return;
            },
            else => {},
        }
        if (addr >= 0xD000 and addr <= 0xDFFF and self.ioVisible()) {
            switch (addr & 0x0F00) {
                0x0000, 0x0100, 0x0200, 0x0300 => self.writeVic(@intCast(addr & 0x3F), v),
                0x0400, 0x0500, 0x0600, 0x0700 => {
                    self.sid[addr & 0x1F] = v;
                    self.sid_log.append(self.allocator, .{
                        .frame = self.frame,
                        .line = self.raster_line,
                        .reg = @intCast(addr & 0x1F),
                        .val = v,
                    }) catch {};
                },
                0x0800, 0x0900, 0x0A00, 0x0B00 => self.color_ram[addr & 0x3FF] = v & 0x0F,
                0x0C00 => self.writeCia1(@intCast(addr & 0x0F), v),
                0x0D00 => self.writeCia2(@intCast(addr & 0x0F), v),
                else => {},
            }
            return;
        }
        self.ram[addr] = v;
    }

    fn readVic(self: *Machine, reg: u8) u8 {
        return switch (reg) {
            0x11 => (self.vic[0x11] & 0x7F) | @as(u8, if (self.raster_line >= 0x100) 0x80 else 0),
            0x12 => @intCast(self.raster_line & 0xFF),
            0x19 => self.vic[0x19] | 0x70,
            0x1E, 0x1F => blk: {
                // sprite collision registers clear on read
                const v = self.vic[reg];
                self.vic[reg] = 0;
                break :blk v;
            },
            else => self.vic[reg],
        };
    }

    fn writeVic(self: *Machine, reg: u8, v: u8) void {
        switch (reg) {
            0x19 => self.vic[0x19] &= ~v, // acknowledge IRQs by writing 1s
            else => self.vic[reg] = v,
        }
    }

    fn readCia1(self: *Machine, reg: u8) u8 {
        return switch (reg) {
            0x00 => self.cia1_pra & (self.joy2 | 0xE0),
            0x01 => blk: {
                // keyboard scan: selected columns are the zero bits of PRA
                var v: u8 = 0xFF;
                const sel = self.cia1_pra;
                for (0..8) |row| {
                    if (sel & (@as(u8, 1) << @intCast(row)) == 0) v &= self.key_matrix[row];
                }
                break :blk v & (self.joy1 | 0xE0);
            },
            0x02 => self.cia1_ddra,
            0x03 => self.cia1_ddrb,
            0x0D => blk: {
                const f = self.cia1_icr_flags;
                self.cia1_icr_flags = 0;
                break :blk f;
            },
            else => 0xFF,
        };
    }

    fn writeCia1(self: *Machine, reg: u8, v: u8) void {
        switch (reg) {
            0x00 => self.cia1_pra = v,
            0x01 => self.cia1_prb = v,
            0x02 => self.cia1_ddra = v,
            0x03 => self.cia1_ddrb = v,
            0x0D => {
                if (v & 0x80 != 0) {
                    self.cia1_icr_mask |= v & 0x7F;
                } else {
                    self.cia1_icr_mask &= ~(v & 0x7F);
                }
            },
            else => {},
        }
    }

    fn readCia2(self: *Machine, reg: u8) u8 {
        return switch (reg) {
            0x00 => self.cia2_pra,
            else => 0xFF,
        };
    }

    fn writeCia2(self: *Machine, reg: u8, v: u8) void {
        switch (reg) {
            0x00 => self.cia2_pra = v,
            else => {},
        }
    }

    /// Base of the 16KB region the VIC sees (CIA2 PRA bits 0-1, inverted).
    pub fn vicBank(self: *const Machine) u16 {
        return (@as(u16, 3 - (self.cia2_pra & 3))) * 0x4000;
    }

    /// A VIC-perspective memory fetch: like RAM, except the char ROM
    /// shadow at $1000-$1FFF / $9000-$9FFF in banks 0 and 2.
    pub fn vicRead(self: *const Machine, addr: u16) u8 {
        if ((addr & 0x7000) == 0x1000) return self.char_rom[addr & 0x0FFF];
        return self.ram[addr];
    }

    /// Load a .prg (2-byte load address header) into RAM. Returns load address.
    pub fn loadPrg(self: *Machine, data: []const u8) u16 {
        const load = @as(u16, data[0]) | (@as(u16, data[1]) << 8);
        @memcpy(self.ram[load .. load + data.len - 2], data[2..]);
        return load;
    }

    pub fn addHook(self: *Machine, pc: u16, hook: Hook) !void {
        try self.hooks.put(pc, hook);
    }

    /// Simulate an RTS — used by hooks that fully replace a routine.
    pub fn rts(self: *Machine) void {
        const c = &self.cpu;
        c.sp +%= 1;
        const lo: u16 = self.ram[0x0100 | @as(u16, c.sp)];
        c.sp +%= 1;
        const hi: u16 = self.ram[0x0100 | @as(u16, c.sp)];
        c.pc = (lo | (hi << 8)) +% 1;
    }

    pub const StepResult = enum { ok, trapped };

    fn stepCpu(self: *Machine) StepResult {
        if (self.hooks.get(self.cpu.pc)) |hook| {
            if (hook.func(self)) return .ok;
        }
        if (!self.cpu.step()) return .trapped;
        return .ok;
    }

    /// Run one video frame worth of emulation. Returns false on CPU trap.
    pub fn runFrame(self: *Machine) bool {
        var line: u16 = 0;
        while (line < LINES_PER_FRAME) : (line += 1) {
            self.raster_line = line;
            // raster compare IRQ
            const compare = @as(u16, self.vic[0x12]) | (@as(u16, self.vic[0x11] & 0x80) << 1);
            if (line == compare) {
                self.vic[0x19] |= 0x01;
            }
            if ((self.vic[0x19] & self.vic[0x1A] & 0x0F) != 0) {
                self.vic[0x19] |= 0x80;
                self.cpu.irq();
            }
            const target = self.cpu.cycles + CYCLES_PER_LINE;
            while (self.cpu.cycles < target) {
                if (self.stepCpu() == .trapped) return false;
            }
        }
        self.frame += 1;
        return true;
    }
};
