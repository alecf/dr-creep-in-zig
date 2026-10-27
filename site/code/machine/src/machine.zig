//! The Comet 64.
//!
//! This file is the whole computer as far as a game is concerned: 64 KB of
//! RAM, the work meter that keeps a frame honest, the raster beam that the
//! meter drives, the frame driver that reads the joysticks and runs the
//! game's frame interrupt, the SOUND chip's speaker, and the disk drive.
//!
//! A game never touches anything here except through `Machine`'s methods
//! and `m.ram`. Everything the game remembers lives in that one array.

const std = @import("std");
const builtin = @import("builtin");

pub const video = @import("video.zig");
pub const sound = @import("sound.zig");
pub const font = @import("font.zig");
pub const drive = @import("drive.zig");
const layout = @import("layout.zig");

comptime {
    // Two-byte values are stored low byte first, and `view` hands out
    // pointers straight into RAM, so the host must agree.
    if (builtin.cpu.arch.endian() != .little)
        @compileError("the Comet 64 needs a little-endian host");
}

/// The beam sweeps 312 raster lines a frame, 63 cycles per line.
pub const raster_lines: u32 = 312;
pub const cycles_per_line: u32 = 63;

/// Cycles available in one frame: 312 raster lines of 63 cycles each.
pub const frame_budget: u32 = raster_lines * cycles_per_line;

/// Frames per second. The frame interrupt fires this often.
pub const frame_rate = 50;

/// Fixed hardware addresses. These never move; a game's own memory map
/// is built around them.
pub const hw = struct {
    pub const stack: u16 = 0x0100; // reserved, 256 bytes
    pub const program: u16 = 0x0800; // program image, up to 0x77FF
    pub const program_end: u16 = 0x7800;

    pub const sprite_data: u16 = 0xC000; // 32 blocks of 64 bytes
    pub const screen: u16 = 0xCC00; // 1000 bytes, one per cell
    pub const sprite_pointers: u16 = 0xCFF8; // 8 block numbers
    pub const color_ram: u16 = 0xD800; // 1000 bytes, low nibble used
    pub const bitmap: u16 = 0xE000; // 8000 bytes

    // VIDEO chip
    pub const video_chip: u16 = 0xD000;
    pub fn spriteX(n: u3) u16 {
        return 0xD000 + @as(u16, n) * 2;
    }
    pub fn spriteY(n: u3) u16 {
        return 0xD001 + @as(u16, n) * 2;
    }
    pub fn spriteColor(n: u3) u16 {
        return 0xD027 + @as(u16, n);
    }
    pub const sprite_x_msb: u16 = 0xD010;
    pub const control: u16 = 0xD011; // bit 4 display on; bit 7 raster line bit 8
    pub const raster: u16 = 0xD012; // raster line, low 8 bits (read only)
    pub const sprite_enable: u16 = 0xD015;
    pub const sprite_double_height: u16 = 0xD017;
    pub const sprite_behind: u16 = 0xD01B;
    pub const sprite_multicolor: u16 = 0xD01C;
    pub const sprite_double_width: u16 = 0xD01D;
    pub const sprite_sprite_hits: u16 = 0xD01E;
    pub const sprite_bitmap_hits: u16 = 0xD01F;
    pub const border: u16 = 0xD020;
    pub const background: u16 = 0xD021;
    pub const sprite_mc0: u16 = 0xD025;
    pub const sprite_mc1: u16 = 0xD026;

    // SOUND chip: $D400-$D418, seven registers for each of three voices,
    // then the filter (not fitted) and the volume. It plays what they say
    // from the end of each frame to the end of the next.
    pub const sound_chip: u16 = 0xD400;
    pub fn voice(v: u2) u16 {
        return 0xD400 + @as(u16, v) * 7;
    }
    pub const sound_volume: u16 = 0xD418; // low 4 bits

    // Input ports
    pub const joy2: u16 = 0xDC00;
    pub const joy1: u16 = 0xDC01;
    pub const key: u16 = 0xDC02;

    // The disk drive: write a command, and it's done before the next
    // instruction (see `drive.Command`).
    pub const drive_command: u16 = 0xDD00; // a drive.Command
    pub const drive_status: u16 = 0xDD01; // a drive.Status, after the command
    pub const drive_address: u16 = 0xDD02; // 2 bytes: where in RAM
    pub const drive_length: u16 = 0xDD04; // 2 bytes: how much (a load sets it to what came)
    pub const drive_name_length: u16 = 0xDD06;
    pub const drive_name: u16 = 0xDD10; // up to 32 bytes
    pub const drive_name_max = 32;
};

/// Each sector the drive reads or writes takes a frame's worth of cycles.
pub const sector_cycles = frame_budget;

/// What's in the drive: a disk image (outside the 64 KB) and whether
/// there is one.
pub const Drive = struct {
    image: drive.Image = @splat(0),
    present: bool = false,
};

/// `$D011` bit 4: the display is on.
pub const display_on: u8 = 0x10;

/// Joystick bits as the ports report them (a 0 bit means "pressed").
pub const joy = struct {
    pub const up: u8 = 0x01;
    pub const down: u8 = 0x02;
    pub const left: u8 = 0x04;
    pub const right: u8 = 0x08;
    pub const fire: u8 = 0x10;
};

/// The 16 colours, by palette index.
pub const Color = enum(u4) {
    black,
    white,
    red,
    cyan,
    purple,
    green,
    blue,
    yellow,
    orange,
    brown,
    pink,
    dark_grey,
    grey,
    light_green,
    light_blue,
    light_grey,
};

/// What the outside world is doing to the machine this frame. The shell
/// (browser or headless) fills this in before each `runFrame`.
pub const Input = struct {
    /// Held joystick directions, using the `joy` bits (1 = held here; the
    /// port inverts them).
    joy1: u8 = 0,
    joy2: u8 = 0,
    /// A key pressed since the last frame, as uppercase ASCII (0 = none).
    key: u8 = 0,
};

/// How a frame went, as far as the budget is concerned.
pub const FrameKind = enum {
    /// Fitted in the budget.
    ok,
    /// Over budget with the display on: the player saw it.
    overrun,
    /// Over budget with the display blanked: a loading pause.
    loading,
};

/// The meter's record of one finished frame.
pub const Report = struct {
    cycles: u32 = 0,
    /// Cycles by bucket (see `Machine.bucket`).
    buckets: [8]u32 = @splat(0),
    kind: FrameKind = .ok,
    /// Frame slots used: 1, or more when the frame ran long.
    slots: u32 = 1,
};

/// Running totals since power-on, for the headless summary and the
/// browser. These are the machine's, not the game's.
pub const Stats = struct {
    frames: u32 = 0, // frame slots elapsed
    calls: u32 = 0, // times `frame` was called
    overruns: u32 = 0,
    loading: u32 = 0,
    max_cycles: u32 = 0,
    total_cycles: u64 = 0,
    bucket_max: [8]u32 = @splat(0),
    bucket_total: [8]u64 = @splat(0),
};

/// Where the beam is in the current frame.
const Beam = struct {
    active: bool = false, // only while `frame` runs
    drawn: u32 = 0, // raster lines finished since the frame began
    next_line_at: u32 = std.math.maxInt(u32), // cycle count that finishes the next line
    display_seen: bool = false, // a display line was drawn with the display on
};

pub const Machine = struct {
    /// All of memory. The game's code, data, the screen, the hardware
    /// registers: it is all in here.
    ram: [0x10000]u8 = @splat(0),

    /// The picture on the tube (RGBA), drawn line by line by the beam.
    screen: video.Screen = @splat(0),

    /// Set by the shell before each frame.
    input: Input = .{},

    /// Cycles spent so far this frame.
    cycles: u32 = 0,
    bucket_now: u3 = 0,
    bucket_cycles: [8]u32 = @splat(0),

    /// The previous frame, as the meter saw it.
    last: Report = .{},
    stats: Stats = .{},

    beam: Beam = .{},

    /// The SOUND chip's oscillators and envelopes, and its registers as
    /// the last frame left them: what it plays while this frame runs.
    chip: sound.Chip = .{},
    sound_regs: [sound.register_count]u8 = @splat(0),

    /// The disk drive and the disk in it. A power-on doesn't touch it.
    drive: Drive = .{},

    // ---- memory ---------------------------------------------------------

    /// Read one byte. 4 cycles.
    pub fn peek(m: *Machine, addr: u16) u8 {
        m.charge(4);
        return m.ram[addr];
    }

    /// Write one byte. 4 cycles. A write to `hw.drive_command` runs the
    /// command, and costs its sectors too.
    pub fn poke(m: *Machine, addr: u16, value: u8) void {
        m.charge(4);
        m.ram[addr] = value;
        if (addr == hw.drive_command) m.driveCommand(value);
    }

    /// Read a two-byte value stored low byte first. 8 cycles.
    pub fn peek16(m: *Machine, addr: u16) u16 {
        m.charge(8);
        return @as(u16, m.ram[addr]) | @as(u16, m.ram[addr +% 1]) << 8;
    }

    /// Write a two-byte value, low byte first. 8 cycles.
    pub fn poke16(m: *Machine, addr: u16, value: u16) void {
        m.charge(8);
        m.ram[addr] = @truncate(value);
        m.ram[addr +% 1] = @truncate(value >> 8);
    }

    /// Copy `n` bytes from `src` to `dst`. Overlapping ranges are fine.
    /// 8 cycles per byte.
    pub fn copy(m: *Machine, dst: u16, src: u16, n: u16) void {
        // The bytes land first and the time is charged after, so the beam
        // sees a copy as one quick burst. Close enough for a game.
        if (@as(u32, dst) + n <= m.ram.len and @as(u32, src) + n <= m.ram.len) {
            @memmove(m.ram[dst..][0..n], m.ram[src..][0..n]);
        } else if (dst -% src < n) {
            // Runs off the top of memory and wraps; copy backwards so an
            // overlapping source isn't overwritten before it's read.
            var i: u16 = n;
            while (i > 0) {
                i -= 1;
                m.ram[dst +% i] = m.ram[src +% i];
            }
        } else {
            for (0..n) |i| {
                const k: u16 = @intCast(i);
                m.ram[dst +% k] = m.ram[src +% k];
            }
        }
        m.charge(@as(u32, n) * 8);
    }

    /// Set `n` bytes starting at `dst` to `value`. 8 cycles per byte.
    pub fn fill(m: *Machine, dst: u16, n: u16, value: u8) void {
        if (@as(u32, dst) + n <= m.ram.len) {
            @memset(m.ram[dst..][0..n], value);
        } else {
            for (0..n) |i| m.ram[dst +% @as(u16, @intCast(i))] = value;
        }
        m.charge(@as(u32, n) * 8);
    }

    /// Copy bytes from the program image (a `const` table in your code)
    /// into RAM at `dst`. 8 cycles per byte, like `copy`.
    pub fn load(m: *Machine, dst: u16, bytes: []const u8) void {
        if (bytes.len > m.ram.len) @panic("load is bigger than memory");
        for (bytes, 0..) |b, i| m.ram[dst +% @as(u16, @truncate(i))] = b;
        m.charge(@intCast(@min(bytes.len * 8, std.math.maxInt(u32))));
    }

    /// Multiply two bytes. The CPU has no multiply instruction, so this is
    /// a software routine: 120 cycles. Lookup tables are usually cheaper.
    pub fn mul8(m: *Machine, a: u8, b: u8) u16 {
        m.charge(120);
        return @as(u16, a) * b;
    }

    /// Charge `n` cycles for work done outside peek/poke (loop overhead,
    /// arithmetic, decisions).
    pub fn work(m: *Machine, n: u32) void {
        m.charge(n);
    }

    /// Cycles the previous frame used. Compare against `frame_budget`.
    pub fn meter(m: *const Machine) u32 {
        return m.last.cycles;
    }

    /// Send the cycles spent from now on to meter bucket `id` (0-7), so
    /// the meter can say where a frame's time went. Every frame starts in
    /// bucket 0. Free.
    pub fn bucket(m: *Machine, id: u3) void {
        m.bucket_now = id;
    }

    /// The raster line the beam is on (0-311). Free.
    pub fn rasterLine(m: *const Machine) u16 {
        return @intCast((m.cycles / cycles_per_line) % raster_lines);
    }

    /// A typed window onto RAM: `m.view(Header, 0x7800)` lets you read and
    /// write the bytes at 0x7800 as a `Header`. Free on its own; charge
    /// `m.work()` for what you do with it.
    ///
    /// `T` must have exactly the same bytes in Zig as in memory: whole-byte
    /// integers (not usize), padding-free `extern struct`s, `packed
    /// struct(u8)`-style flags, non-exhaustive enums, and arrays of those.
    /// Anything else is a compile error that says why.
    pub fn view(m: *Machine, comptime T: type, addr: u16) *align(1) T {
        comptime layout.check(T);
        if (@as(usize, addr) + @sizeOf(T) > m.ram.len)
            @panic("view runs past the end of memory");
        return @ptrCast(&m.ram[addr]);
    }

    /// The 8 bytes of a glyph in the character ROM (top row first, bit 7
    /// is the leftmost pixel). The ROM is not in the 64 KB map; reading it
    /// this way is free.
    pub fn charRom(m: *const Machine, code: u8) *const [8]u8 {
        _ = m;
        return &font.rom[code];
    }

    // ---- the disk drive ---------------------------------------------------

    /// Put a disk image in the drive (a 35- or 40-track image file, with
    /// or without its error bytes). The game sees it at its next command.
    pub fn insert(m: *Machine, bytes: []const u8) error{NotADiskImage}!void {
        if (std.mem.indexOfScalar(usize, &drive.image_sizes, bytes.len) == null) return error.NotADiskImage;
        @memcpy(&m.drive.image, bytes[0..drive.image_size]);
        m.drive.present = true;
    }

    /// Take the disk out.
    pub fn eject(m: *Machine) void {
        m.drive.present = false;
    }

    /// The disk in the drive, as it is now (saves included), or null.
    pub fn diskImage(m: *const Machine) ?*const drive.Image {
        return if (m.drive.present) &m.drive.image else null;
    }

    fn driveCommand(m: *Machine, command: u8) void {
        const r = &m.ram;
        const address = @as(u16, r[hw.drive_address]) | @as(u16, r[hw.drive_address + 1]) << 8;
        var length: u32 = @as(u16, r[hw.drive_length]) | @as(u16, r[hw.drive_length + 1]) << 8;
        length = @min(length, 0x10000 - @as(u32, address)); // the top of memory
        const name = r[hw.drive_name..][0..@min(r[hw.drive_name_length], hw.drive_name_max)];
        var name_copy: [hw.drive_name_max]u8 = undefined;
        @memcpy(name_copy[0..name.len], name);
        var touched: u32 = 0;
        const status: drive.Status = if (!m.drive.present) .no_disk else switch (command) {
            @intFromEnum(drive.Command.load) => blk: {
                const out = r[address..][0..length];
                const total = drive.load(&m.drive.image, name_copy[0..name.len], out, &touched) catch |e| break :blk statusOf(e);
                const got: u16 = @intCast(@min(total, length));
                r[hw.drive_length] = @truncate(got);
                r[hw.drive_length + 1] = @truncate(got >> 8);
                break :blk if (total > length) .too_long else .ok;
            },
            @intFromEnum(drive.Command.save) => blk: {
                const data = r[address..][0..length];
                drive.save(&m.drive.image, name_copy[0..name.len], address, data, &touched) catch |e| break :blk statusOf(e);
                break :blk .ok;
            },
            else => .bad_name,
        };
        r[hw.drive_status] = @intFromEnum(status);
        r[hw.drive_command] = 0; // done
        m.charge(sector_cycles * @max(1, touched)); // even a miss spins the disk once
    }

    fn statusOf(e: drive.Error) drive.Status {
        return switch (e) {
            error.NotFound => .not_found,
            error.Exists => .exists,
            error.DiskFull => .full,
            error.TooLong => .too_long,
            error.BadName => .bad_name,
            error.BadDisk => .bad_disk,
        };
    }

    // ---- the meter and the beam -----------------------------------------

    inline fn charge(m: *Machine, n: u32) void {
        m.cycles +|= n;
        m.bucket_cycles[m.bucket_now] +|= n;
        if (m.cycles >= m.beam.next_line_at) m.beamCatchUp();
    }

    /// Draw every picture line the beam has finished since we last looked,
    /// from RAM as it is now.
    fn beamCatchUp(m: *Machine) void {
        if (!m.beam.active) return;
        const now = m.cycles / cycles_per_line; // the line in progress
        var line = m.beam.drawn;
        // Long jobs lap the screen; only the latest lap is still visible.
        if (now - line > raster_lines) line = now - raster_lines;
        while (line < now) : (line += 1) m.drawRaster(line % raster_lines, true);
        m.beam.drawn = now;
        m.beam.next_line_at = std.math.mul(u32, now + 1, cycles_per_line) catch std.math.maxInt(u32);
        m.latchRaster(now % raster_lines);
    }

    fn drawRaster(m: *Machine, raster: u32, during_frame: bool) void {
        const first = video.picture_first_raster;
        if (raster < first or raster >= first + video.height) return;
        const y = raster - first;
        if (during_frame and m.ram[hw.control] & display_on != 0 and
            y >= video.display_y and y < video.display_y + video.display_height)
            m.beam.display_seen = true;
        video.drawLine(m, y);
    }

    fn latchRaster(m: *Machine, line: u32) void {
        m.ram[hw.raster] = @truncate(line);
        m.ram[hw.control] = (m.ram[hw.control] & 0x7F) | @as(u8, @intCast(line >> 8)) << 7;
    }

    // ---- the frame driver -----------------------------------------------

    /// Power on: clear memory, switch the display on, set the input ports
    /// to "nothing pressed", put the game's own disk in the drive (if it
    /// has `pub const disk`; else the drive is empty), then let the game
    /// set itself up. Boot time is not metered and the beam isn't
    /// running. A shell can `insert` another disk after.
    pub fn boot(m: *Machine, comptime Game: type) void {
        comptime checkGame(Game);
        m.reset();
        m.eject();
        if (@hasDecl(Game, "disk")) m.insert(&Game.disk) catch unreachable;
        m.ram[hw.control] = display_on;
        m.writeInput();
        Game.boot(m);
        m.cycles = 0;
        m.bucket_cycles = @splat(0);
    }

    /// One frame. Latch the input ports, start the beam at the top, and run
    /// the game's frame interrupt; the beam draws as the game spends
    /// cycles. When `frame` returns, the beam finishes the picture.
    ///
    /// Returns how many frame slots that took: 1 normally, more when the
    /// frame went over budget. The shell lets that many frames of time
    /// pass before calling again.
    pub fn runFrame(m: *Machine, comptime Game: type) u32 {
        comptime checkGame(Game);
        m.writeInput();
        m.cycles = 0;
        m.bucket_now = 0;
        m.bucket_cycles = @splat(0);
        m.beam = .{ .active = true, .next_line_at = cycles_per_line };
        m.latchRaster(0);
        // The SOUND chip takes the last frame's registers, and plays them
        // while this one runs.
        m.sound_regs = m.ram[sound.base..][0..sound.register_count].*;

        Game.frame(m);

        m.finishPicture();
        const slots = @max(1, std.math.divCeil(u32, m.cycles, frame_budget) catch unreachable);
        const kind: FrameKind = if (m.cycles <= frame_budget)
            .ok
        else if (m.beam.display_seen)
            .overrun
        else
            .loading;
        m.last = .{ .cycles = m.cycles, .buckets = m.bucket_cycles, .kind = kind, .slots = slots };

        const s = &m.stats;
        s.frames +|= slots;
        s.calls +|= 1;
        s.total_cycles += m.cycles;
        s.max_cycles = @max(s.max_cycles, m.cycles);
        switch (kind) {
            .ok => {},
            .overrun => s.overruns += 1,
            .loading => s.loading += 1,
        }
        for (m.bucket_cycles, 0..) |c, i| {
            s.bucket_total[i] += c;
            s.bucket_max[i] = @max(s.bucket_max[i], c);
        }
        return slots;
    }

    /// The rest of this lap of the beam is drawn from RAM as `frame` left it.
    fn finishPicture(m: *Machine) void {
        m.beamCatchUp();
        const lap_end = (m.beam.drawn / raster_lines + 1) * raster_lines;
        var line = m.beam.drawn;
        while (line < lap_end) : (line += 1) m.drawRaster(line % raster_lines, false);
        m.beam.active = false;
        m.beam.next_line_at = std.math.maxInt(u32);
    }

    /// The sound of a frame slot of the frame that just ran: `out` gets a
    /// frame's worth of samples (`rate / 50`) at `rate` a second. The chip
    /// plays the registers as the frame *before* left them, all through
    /// this one, however many slots it took. The shell calls this once for
    /// each slot `runFrame` reports, and sends the samples to a speaker.
    pub fn listen(m: *Machine, out: []f32, rate: u32) void {
        m.chip.render(&m.sound_regs, out, rate);
    }

    /// Back to the power-on state. (Field by field rather than `m.* = .{}`
    /// so no half-megabyte temporary lands on a small wasm stack.)
    fn reset(m: *Machine) void {
        @memset(&m.ram, 0);
        @memset(&m.screen, 0xFF000000);
        m.input = .{};
        m.cycles = 0;
        m.bucket_now = 0;
        m.bucket_cycles = @splat(0);
        m.last = .{};
        m.stats = .{};
        m.beam = .{};
        m.chip = .{};
        m.sound_regs = @splat(0);
    }

    fn writeInput(m: *Machine) void {
        m.ram[hw.joy1] = portByte(m.input.joy1);
        m.ram[hw.joy2] = portByte(m.input.joy2);
        if (m.input.key != 0) {
            m.ram[hw.key] = m.input.key;
            m.input.key = 0;
        }
    }
};

/// Joystick port encoding: five active-low switches, top three bits
/// always read 1.
pub fn portByte(held: u8) u8 {
    return 0xE0 | (~held & 0x1F);
}

fn checkGame(comptime Game: type) void {
    if (!@hasDecl(Game, "boot") or @TypeOf(Game.boot) != fn (*Machine) void)
        @compileError("a game needs `pub fn boot(m: *Machine) void`");
    if (!@hasDecl(Game, "frame") or @TypeOf(Game.frame) != fn (*Machine) void)
        @compileError("a game needs `pub fn frame(m: *Machine) void`");
    if (@hasDecl(Game, "disk") and @TypeOf(Game.disk) != drive.Image)
        @compileError("a game's `disk` must be a `machine.drive.Image`");
}

// ---- tests ---------------------------------------------------------------

const testing = std.testing;

fn newMachine() !*Machine {
    const m = try testing.allocator.create(Machine);
    m.* = .{};
    return m;
}

test {
    _ = video;
    _ = sound;
    _ = font;
    _ = layout;
    _ = drive;
}

test "costs" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.poke(0x0200, 7);
    try testing.expectEqual(4, m.cycles);
    _ = m.peek(0x0200);
    try testing.expectEqual(8, m.cycles);
    m.poke16(0x0300, 0x1234);
    _ = m.peek16(0x0300);
    try testing.expectEqual(24, m.cycles);
    m.copy(0x0400, 0x0300, 10);
    try testing.expectEqual(104, m.cycles);
    m.fill(0x0500, 5, 0xAA);
    try testing.expectEqual(144, m.cycles);
    try testing.expectEqual(@as(u16, 600), m.mul8(20, 30));
    try testing.expectEqual(264, m.cycles);
    m.work(6);
    try testing.expectEqual(270, m.cycles);
    m.load(0x0600, &.{ 1, 2, 3 });
    try testing.expectEqual(294, m.cycles);
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, m.ram[0x0600..0x0603]);
    _ = m.view([4]u8, 0x0500);
    _ = m.charRom('A');
    m.bucket(3);
    _ = m.rasterLine();
    try testing.expectEqual(294, m.cycles);
}

test "peek16 and poke16 are little-endian" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.poke16(0x7800, 0xBEEF);
    try testing.expectEqual(0xEF, m.ram[0x7800]);
    try testing.expectEqual(0xBE, m.ram[0x7801]);
    m.ram[0x7802] = 0x34;
    m.ram[0x7803] = 0x12;
    try testing.expectEqual(0x1234, m.peek16(0x7802));
}

test "copy handles overlap and fill sets bytes" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    for (0..8) |i| m.ram[0x1000 + i] = @intCast(i + 1);
    m.copy(0x1002, 0x1000, 6); // overlapping, forwards
    try testing.expectEqualSlices(u8, &.{ 1, 2, 1, 2, 3, 4, 5, 6 }, m.ram[0x1000..0x1008]);
    m.fill(0xFFFE, 4, 9); // wraps to 0x0000
    try testing.expectEqual(9, m.ram[0xFFFF]);
    try testing.expectEqual(9, m.ram[0x0001]);
    try testing.expectEqual(0, m.ram[0x0002]);
}

test "view gives a typed window onto RAM" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    const Flags = packed struct(u8) { open: bool, locked: bool, color: u4, _pad: u2 = 0 };
    const Rec = extern struct { kind: u8, x: u8, y: u8, flags: Flags };
    const r = m.view(Rec, 0x7900);
    r.x = 40;
    r.flags = .{ .open = true, .locked = false, .color = 5 };
    try testing.expectEqual(40, m.ram[0x7901]);
    try testing.expectEqual(0b0001_0101, m.ram[0x7903]);

    const recs = m.view([3]Rec, 0x7A00);
    recs[2].y = 7;
    try testing.expectEqual(7, m.ram[0x7A00 + 2 * 4 + 2]);

    const w = m.view(u16, 0x7905);
    w.* = 0x0102;
    try testing.expectEqual(0x02, m.ram[0x7905]);
}

test "input ports are active-low with the top bits set" {
    const Game = struct {
        pub fn boot(_: *Machine) void {}
        pub fn frame(_: *Machine) void {}
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Game);
    try testing.expectEqual(0xFF, m.ram[hw.joy1]);
    try testing.expectEqual(0xFF, m.ram[hw.joy2]);
    try testing.expectEqual(0x00, m.ram[hw.key]);

    m.input = .{ .joy1 = joy.up | joy.fire, .joy2 = joy.right, .key = 'R' };
    _ = m.runFrame(Game);
    try testing.expectEqual(0xEE, m.ram[hw.joy1]);
    try testing.expectEqual(0xF7, m.ram[hw.joy2]);
    try testing.expectEqual('R', m.ram[hw.key]);

    // The key stays until the game acknowledges it, and is delivered once.
    _ = m.runFrame(Game);
    try testing.expectEqual('R', m.ram[hw.key]);
    m.ram[hw.key] = 0;
    _ = m.runFrame(Game);
    try testing.expectEqual(0, m.ram[hw.key]);
}

/// A game whose frame does whatever `$0200` asks, so one machine can run
/// several experiments.
const Lab = struct {
    const mode = 0x0200;
    pub fn boot(_: *Machine) void {}
    pub fn frame(m: *Machine) void {
        switch (m.ram[mode]) {
            // Spend 1000 cycles.
            0 => m.work(1000),
            // Spend one cycle over budget.
            1 => m.work(frame_budget + 1),
            // Blank, spend 2.5 frames, display back on: a loading pause.
            2 => {
                m.poke(hw.control, 0);
                m.work(frame_budget * 5 / 2);
                m.poke(hw.control, display_on);
            },
            // Move sprite 0 right by 100 once the beam is past display row 20.
            3 => {
                m.work((video.display_first_raster + 21) * cycles_per_line);
                m.poke(hw.spriteX(0), video.sprite_origin_x + 100);
            },
            // Split the frame's work between buckets.
            4 => {
                m.work(10);
                m.bucket(2);
                m.work(300);
                m.bucket(5);
                m.work(7);
            },
            else => {},
        }
    }
};

test "the meter counts one frame at a time and flags overruns" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Lab);
    try testing.expectEqual(1, m.runFrame(Lab));
    try testing.expectEqual(1000, m.meter());
    m.ram[Lab.mode] = 1;
    try testing.expectEqual(2, m.runFrame(Lab)); // ran into a second slot
    try testing.expectEqual(frame_budget + 1, m.meter());
    try testing.expectEqual(FrameKind.overrun, m.last.kind);
    try testing.expectEqual(1, m.stats.overruns);
    try testing.expectEqual(3, m.stats.frames);
    try testing.expectEqual(2, m.stats.calls);
}

test "a blanked display turns a long frame into a loading pause" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Lab);
    m.ram[Lab.mode] = 2;
    try testing.expectEqual(3, m.runFrame(Lab));
    try testing.expectEqual(FrameKind.loading, m.last.kind);
    try testing.expectEqual(0, m.stats.overruns);
    try testing.expectEqual(1, m.stats.loading);
    try testing.expectEqual(3, m.stats.frames);
}

test "the display-enable bit blanks the display window to border colour" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Lab);
    m.ram[Lab.mode] = 0xFF;
    try testing.expectEqual(display_on, m.ram[hw.control] & display_on); // on at power-up
    m.ram[hw.border] = 6;
    m.ram[hw.background] = 2;
    m.ram[hw.sprite_enable] = 1;
    @memset(m.ram[hw.sprite_data..][0..63], 0xFF);
    m.ram[hw.spriteX(0)] = video.sprite_origin_x;
    m.ram[hw.spriteY(0)] = video.sprite_origin_y;
    @memset(m.ram[hw.bitmap..][0..8], 0xFF); // foreground under the sprite
    const corner = video.display_y * video.width + video.display_x;

    _ = m.runFrame(Lab);
    try testing.expectEqual(video.palette[0], m.screen[corner]); // sprite colour 0
    try testing.expectEqual(1, m.ram[hw.sprite_bitmap_hits]);

    m.ram[hw.sprite_bitmap_hits] = 0;
    m.ram[hw.control] = 0;
    _ = m.runFrame(Lab);
    try testing.expectEqual(video.palette[6], m.screen[corner]);
    try testing.expectEqual(video.palette[6], m.screen[corner + 200 * video.width]);
    try testing.expectEqual(0, m.ram[hw.sprite_bitmap_hits]);
}

test "changing a sprite while the beam draws it tears" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Lab);
    m.ram[Lab.mode] = 3;
    @memset(m.ram[hw.sprite_data..][0..63], 0xFF);
    m.ram[hw.spriteX(0)] = video.sprite_origin_x;
    m.ram[hw.spriteY(0)] = video.sprite_origin_y;
    m.ram[hw.spriteColor(0)] = 1;
    m.ram[hw.sprite_double_height] = 1; // 42 lines tall
    m.ram[hw.sprite_enable] = 1;
    _ = m.runFrame(Lab);

    const white = video.palette[1];
    const at = struct {
        fn px(mm: *const Machine, x: usize, y: usize) u32 {
            return mm.screen[(video.display_y + y) * video.width + video.display_x + x];
        }
    }.px;
    // Rows 0-20 were drawn before the move, rows 21-41 after.
    try testing.expectEqual(white, at(m, 0, 20));
    try testing.expect(at(m, 100, 20) != white);
    try testing.expect(at(m, 0, 21) != white);
    try testing.expectEqual(white, at(m, 100, 21));
    try testing.expectEqual(white, at(m, 100, 41));
}

test "the raster register follows the beam" {
    const Game = struct {
        pub fn boot(_: *Machine) void {}
        pub fn frame(m: *Machine) void {
            m.work(300 * cycles_per_line);
            m.ram[0x0300] = m.peek(hw.raster);
            m.ram[0x0301] = m.ram[hw.control] >> 7;
            m.ram[0x0302] = @intCast(m.rasterLine() - 256);
        }
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);
    m.boot(Game);
    _ = m.runFrame(Game);
    try testing.expectEqual(300 - 256, m.ram[0x0300]);
    try testing.expectEqual(1, m.ram[0x0301]);
    try testing.expectEqual(300 - 256, m.ram[0x0302]);
}

test "buckets split a frame's cycles" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Lab);
    m.ram[Lab.mode] = 4;
    _ = m.runFrame(Lab);
    try testing.expectEqual(317, m.meter());
    try testing.expectEqual([8]u32{ 10, 0, 300, 0, 0, 7, 0, 0 }, m.last.buckets);
    _ = m.runFrame(Lab); // each frame starts back in bucket 0
    try testing.expectEqual(10, m.last.buckets[0]);
}

test "the SOUND chip plays what the last frame left, all through this one" {
    const Game = struct {
        pub fn boot(_: *Machine) void {}
        pub fn frame(m: *Machine) void {
            // Frame 0: a note, gate on. Frame 1: a long job, then silence.
            if (m.ram[0x0200] == 0) {
                m.poke(hw.sound_volume, 15);
                m.poke16(hw.voice(0) + sound.freq_lo, 7382);
                m.poke(hw.voice(0) + sound.sustain_release, 0xF0);
                m.poke(hw.voice(0) + sound.control, sound.sawtooth | sound.gate);
            } else {
                m.work(frame_budget * 2);
                m.poke(hw.voice(0) + sound.control, 0);
            }
            m.ram[0x0200] += 1;
        }
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);
    m.boot(Game);
    var out: [882]f32 = undefined;
    try testing.expectEqual(1, m.runFrame(Game));
    m.listen(&out, 44100); // frame 0 played the power-on silence
    for (out) |s| try testing.expectEqual(0, s);
    const slots = m.runFrame(Game);
    try testing.expectEqual(3, slots);
    for (0..slots) |_| {
        m.listen(&out, 44100); // the note, for every slot of the long frame
        var loudest: f32 = 0;
        for (out) |s| loudest = @max(loudest, @abs(s));
        try testing.expect(loudest > 0.1);
    }
    _ = m.runFrame(Game);
    m.listen(&out, 44100); // and then the silence it left, once the note
    m.listen(&out, 44100); // has faded (a few milliseconds) and the output
    m.listen(&out, 44100); // stage has settled
    var loudest: f32 = 0;
    for (out) |s| loudest = @max(loudest, @abs(s));
    try testing.expect(loudest < 0.001);
}

test "the disk drive: a game's own disk, a load, a save, and the time they take" {
    const Game = struct {
        pub const disk = blk: {
            @setEvalBranchQuota(100_000);
            var d: drive.Image = undefined;
            drive.format(&d, "LAB DISK", .{ 'L', '1' });
            var n: u32 = 0;
            drive.save(&d, "HELLO", 0x1000, "HELLO, DISK", &n) catch unreachable;
            break :blk d;
        };
        pub fn boot(_: *Machine) void {}
        pub fn frame(m: *Machine) void {
            m.poke(hw.control, 0); // a loading pause, not an overrun
            const name = if (m.ram[0x0200] == 0) "HELLO" else "@0:SAVED";
            @memcpy(m.ram[hw.drive_name..][0..name.len], name);
            m.ram[hw.drive_name_length] = @intCast(name.len);
            m.ram[hw.drive_address] = 0x00;
            m.ram[hw.drive_address + 1] = 0x30;
            m.ram[hw.drive_length] = 100;
            m.ram[hw.drive_length + 1] = 0;
            m.poke(hw.drive_command, @intFromEnum(if (m.ram[0x0200] == 0) drive.Command.load else drive.Command.save));
        }
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);
    m.boot(Game);
    try testing.expect(m.diskImage() != null);
    _ = m.runFrame(Game);
    try testing.expectEqual(@intFromEnum(drive.Status.ok), m.ram[hw.drive_status]);
    try testing.expectEqualSlices(u8, "HELLO, DISK", m.ram[0x3000..][0..11]);
    try testing.expectEqual(11, m.ram[hw.drive_length]);
    try testing.expectEqual(FrameKind.loading, m.last.kind);
    try testing.expectEqual(2 * sector_cycles + 2 * 4, m.last.cycles); // a directory sector, a file sector, two pokes
    m.ram[0x0200] = 1;
    _ = m.runFrame(Game); // 11 bytes saved
    try testing.expectEqual(@intFromEnum(drive.Status.ok), m.ram[hw.drive_status]);
    var out: [11]u8 = undefined;
    var n: u32 = 0;
    _ = try drive.load(m.diskImage().?, "SAVED", &out, &n);
    try testing.expectEqualSlices(u8, "HELLO, DISK", &out);

    m.eject();
    _ = m.runFrame(Game);
    try testing.expectEqual(@intFromEnum(drive.Status.no_disk), m.ram[hw.drive_status]);
    try testing.expectError(error.NotADiskImage, m.insert("too short"));
    m.boot(Game); // power on again: the game's disk is back in
    try testing.expect(m.diskImage() != null);
}
