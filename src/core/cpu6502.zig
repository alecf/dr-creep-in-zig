//! MOS 6510/6502 interpreter (documented opcodes).
//!
//! Generic over a Bus type providing `read8(addr: u16) u8` and
//! `write8(addr: u16, v: u8) void`. The Dr. Creep engine uses only
//! documented opcodes on every traced path (see tools/dis6502.py output),
//! so undocumented opcodes trap loudly instead of being emulated.
//!
//! Decimal mode is implemented: the game keeps scores/time in BCD.

const std = @import("std");

pub fn Cpu(comptime Bus: type) type {
    return struct {
        const Self = @This();

        a: u8 = 0,
        x: u8 = 0,
        y: u8 = 0,
        sp: u8 = 0xFD,
        pc: u16 = 0,
        // status flags
        c: bool = false,
        z: bool = false,
        i: bool = true,
        d: bool = false,
        v: bool = false,
        n: bool = false,

        bus: *Bus,
        cycles: u64 = 0,
        /// set when an unimplemented/illegal opcode is hit
        trap: ?u8 = null,
        trap_pc: u16 = 0,
        /// scratch effective address for store/rmw indexed modes
        ea_tmp: u16 = 0,

        pub fn init(bus: *Bus) Self {
            return .{ .bus = bus };
        }

        pub fn reset(self: *Self, entry: u16) void {
            self.pc = entry;
            self.sp = 0xFD;
            self.i = true;
            self.trap = null;
        }

        fn read16(self: *Self, addr: u16) u16 {
            const lo: u16 = self.bus.read8(addr);
            const hi: u16 = self.bus.read8(addr +% 1);
            return lo | (hi << 8);
        }

        /// 6502 bug: JMP ($xxFF) wraps within the page.
        fn read16PageWrap(self: *Self, addr: u16) u16 {
            const lo: u16 = self.bus.read8(addr);
            const hi_addr = (addr & 0xFF00) | ((addr +% 1) & 0x00FF);
            const hi: u16 = self.bus.read8(hi_addr);
            return lo | (hi << 8);
        }

        fn fetch8(self: *Self) u8 {
            const v = self.bus.read8(self.pc);
            self.pc +%= 1;
            return v;
        }

        fn fetch16(self: *Self) u16 {
            const lo: u16 = self.fetch8();
            const hi: u16 = self.fetch8();
            return lo | (hi << 8);
        }

        fn push8(self: *Self, v: u8) void {
            self.bus.write8(0x0100 | @as(u16, self.sp), v);
            self.sp -%= 1;
        }

        fn pop8(self: *Self) u8 {
            self.sp +%= 1;
            return self.bus.read8(0x0100 | @as(u16, self.sp));
        }

        pub fn statusByte(self: *Self, brk: bool) u8 {
            var p: u8 = 0x20; // bit 5 always set
            if (self.c) p |= 0x01;
            if (self.z) p |= 0x02;
            if (self.i) p |= 0x04;
            if (self.d) p |= 0x08;
            if (brk) p |= 0x10;
            if (self.v) p |= 0x40;
            if (self.n) p |= 0x80;
            return p;
        }

        fn setStatus(self: *Self, p: u8) void {
            self.c = p & 0x01 != 0;
            self.z = p & 0x02 != 0;
            self.i = p & 0x04 != 0;
            self.d = p & 0x08 != 0;
            self.v = p & 0x40 != 0;
            self.n = p & 0x80 != 0;
        }

        fn setZN(self: *Self, v: u8) u8 {
            self.z = v == 0;
            self.n = v & 0x80 != 0;
            return v;
        }

        /// Hardware IRQ (level-triggered; caller checks masking conditions).
        pub fn irq(self: *Self) void {
            if (self.i) return;
            self.push8(@intCast(self.pc >> 8));
            self.push8(@intCast(self.pc & 0xFF));
            self.push8(self.statusByte(false));
            self.i = true;
            self.pc = self.read16(0xFFFE);
            self.cycles += 7;
        }

        pub fn nmi(self: *Self) void {
            self.push8(@intCast(self.pc >> 8));
            self.push8(@intCast(self.pc & 0xFF));
            self.push8(self.statusByte(false));
            self.i = true;
            self.pc = self.read16(0xFFFA);
            self.cycles += 7;
        }

        // Addressing helpers return the effective address.
        fn addrZp(self: *Self) u16 {
            return self.fetch8();
        }
        fn addrZpX(self: *Self) u16 {
            return (self.fetch8() +% self.x);
        }
        fn addrZpY(self: *Self) u16 {
            return (self.fetch8() +% self.y);
        }
        fn addrAbs(self: *Self) u16 {
            return self.fetch16();
        }
        fn addrAbsX(self: *Self) u16 {
            const base = self.fetch16();
            const ea = base +% self.x;
            if ((base & 0xFF00) != (ea & 0xFF00)) self.cycles += 1;
            return ea;
        }
        fn addrAbsY(self: *Self) u16 {
            const base = self.fetch16();
            const ea = base +% self.y;
            if ((base & 0xFF00) != (ea & 0xFF00)) self.cycles += 1;
            return ea;
        }
        fn addrIzx(self: *Self) u16 {
            const zp = self.fetch8() +% self.x;
            return self.read16PageWrap(zp);
        }
        fn addrIzy(self: *Self) u16 {
            const zp = self.fetch8();
            const base = self.read16PageWrap(zp);
            const ea = base +% self.y;
            if ((base & 0xFF00) != (ea & 0xFF00)) self.cycles += 1;
            return ea;
        }

        fn branch(self: *Self, cond: bool) void {
            const off: i8 = @bitCast(self.fetch8());
            if (cond) {
                const old = self.pc;
                self.pc = self.pc +% @as(u16, @bitCast(@as(i16, off)));
                self.cycles += if ((old & 0xFF00) != (self.pc & 0xFF00)) @as(u64, 2) else 1;
            }
        }

        fn adc(self: *Self, operand: u8) void {
            if (self.d) {
                // BCD addition, NMOS behavior
                const carry_in: u16 = @intFromBool(self.c);
                var lo: u16 = @as(u16, self.a & 0x0F) + (operand & 0x0F) + carry_in;
                var hi: u16 = @as(u16, self.a >> 4) + (operand >> 4);
                if (lo > 9) {
                    lo += 6;
                    hi += 1;
                }
                // Z from binary result, N/V from intermediate high nybble
                const bin: u16 = @as(u16, self.a) + operand + carry_in;
                self.z = (bin & 0xFF) == 0;
                self.n = (hi & 0x08) != 0;
                self.v = ((hi << 4) ^ self.a) & 0x80 != 0 and ((self.a ^ operand) & 0x80) == 0;
                if (hi > 9) hi += 6;
                self.c = hi > 15;
                self.a = @intCast(((hi << 4) | (lo & 0x0F)) & 0xFF);
            } else {
                const sum: u16 = @as(u16, self.a) + operand + @intFromBool(self.c);
                self.c = sum > 0xFF;
                const result: u8 = @intCast(sum & 0xFF);
                self.v = (~(self.a ^ operand) & (self.a ^ result) & 0x80) != 0;
                self.a = self.setZN(result);
            }
        }

        fn sbc(self: *Self, operand: u8) void {
            if (self.d) {
                const borrow: i16 = if (self.c) 0 else 1;
                var lo: i16 = @as(i16, self.a & 0x0F) - @as(i16, operand & 0x0F) - borrow;
                var hi: i16 = @as(i16, self.a >> 4) - @as(i16, operand >> 4);
                if (lo < 0) {
                    lo -= 6;
                    hi -= 1;
                }
                if (hi < 0) hi -= 6;
                // flags from binary subtraction
                const bin: i16 = @as(i16, self.a) - @as(i16, operand) - borrow;
                self.c = bin >= 0;
                const bin8: u8 = @intCast(bin & 0xFF);
                self.v = ((self.a ^ operand) & (self.a ^ bin8) & 0x80) != 0;
                _ = self.setZN(bin8);
                self.a = @intCast(@as(u16, @bitCast(@as(i16, (hi << 4)) | (lo & 0x0F))) & 0xFF);
            } else {
                self.adcBinary(~operand);
            }
        }

        fn adcBinary(self: *Self, operand: u8) void {
            const sum: u16 = @as(u16, self.a) + operand + @intFromBool(self.c);
            self.c = sum > 0xFF;
            const result: u8 = @intCast(sum & 0xFF);
            self.v = (~(self.a ^ operand) & (self.a ^ result) & 0x80) != 0;
            self.a = self.setZN(result);
        }

        fn cmp(self: *Self, reg: u8, operand: u8) void {
            const diff = reg -% operand;
            self.c = reg >= operand;
            _ = self.setZN(diff);
        }

        fn aslV(self: *Self, v: u8) u8 {
            self.c = v & 0x80 != 0;
            return self.setZN(v << 1);
        }
        fn lsrV(self: *Self, v: u8) u8 {
            self.c = v & 0x01 != 0;
            return self.setZN(v >> 1);
        }
        fn rolV(self: *Self, v: u8) u8 {
            const cin: u8 = @intFromBool(self.c);
            self.c = v & 0x80 != 0;
            return self.setZN((v << 1) | cin);
        }
        fn rorV(self: *Self, v: u8) u8 {
            const cin: u8 = @intFromBool(self.c);
            self.c = v & 0x01 != 0;
            return self.setZN((v >> 1) | (cin << 7));
        }

        fn rmw(self: *Self, ea: u16, comptime op: fn (*Self, u8) u8) void {
            const v = self.bus.read8(ea);
            self.bus.write8(ea, op(self, v));
        }

        /// Execute one instruction. Returns false if the CPU trapped.
        pub fn step(self: *Self) bool {
            const op_pc = self.pc;
            const op = self.fetch8();
            switch (op) {
                // Loads / stores
                0xA9 => {
                    self.a = self.setZN(self.fetch8());
                    self.cycles += 2;
                },
                0xA5 => {
                    self.a = self.setZN(self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xB5 => {
                    self.a = self.setZN(self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0xAD => {
                    self.a = self.setZN(self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xBD => {
                    self.a = self.setZN(self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0xB9 => {
                    self.a = self.setZN(self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0xA1 => {
                    self.a = self.setZN(self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0xB1 => {
                    self.a = self.setZN(self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0xA2 => {
                    self.x = self.setZN(self.fetch8());
                    self.cycles += 2;
                },
                0xA6 => {
                    self.x = self.setZN(self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xB6 => {
                    self.x = self.setZN(self.bus.read8(self.addrZpY()));
                    self.cycles += 4;
                },
                0xAE => {
                    self.x = self.setZN(self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xBE => {
                    self.x = self.setZN(self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0xA0 => {
                    self.y = self.setZN(self.fetch8());
                    self.cycles += 2;
                },
                0xA4 => {
                    self.y = self.setZN(self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xB4 => {
                    self.y = self.setZN(self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0xAC => {
                    self.y = self.setZN(self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xBC => {
                    self.y = self.setZN(self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0x85 => {
                    self.bus.write8(self.addrZp(), self.a);
                    self.cycles += 3;
                },
                0x95 => {
                    self.bus.write8(self.addrZpX(), self.a);
                    self.cycles += 4;
                },
                0x8D => {
                    self.bus.write8(self.addrAbs(), self.a);
                    self.cycles += 4;
                },
                0x9D => {
                    _ = self.fetchAbsX();
                    self.bus.write8(self.ea_tmp, self.a);
                    self.cycles += 5;
                },
                0x99 => {
                    _ = self.fetchAbsY();
                    self.bus.write8(self.ea_tmp, self.a);
                    self.cycles += 5;
                },
                0x81 => {
                    self.bus.write8(self.addrIzx(), self.a);
                    self.cycles += 6;
                },
                0x91 => {
                    const zp = self.fetch8();
                    const ea = self.read16PageWrap(zp) +% self.y;
                    self.bus.write8(ea, self.a);
                    self.cycles += 6;
                },
                0x86 => {
                    self.bus.write8(self.addrZp(), self.x);
                    self.cycles += 3;
                },
                0x96 => {
                    self.bus.write8(self.addrZpY(), self.x);
                    self.cycles += 4;
                },
                0x8E => {
                    self.bus.write8(self.addrAbs(), self.x);
                    self.cycles += 4;
                },
                0x84 => {
                    self.bus.write8(self.addrZp(), self.y);
                    self.cycles += 3;
                },
                0x94 => {
                    self.bus.write8(self.addrZpX(), self.y);
                    self.cycles += 4;
                },
                0x8C => {
                    self.bus.write8(self.addrAbs(), self.y);
                    self.cycles += 4;
                },

                // Transfers
                0xAA => {
                    self.x = self.setZN(self.a);
                    self.cycles += 2;
                },
                0xA8 => {
                    self.y = self.setZN(self.a);
                    self.cycles += 2;
                },
                0x8A => {
                    self.a = self.setZN(self.x);
                    self.cycles += 2;
                },
                0x98 => {
                    self.a = self.setZN(self.y);
                    self.cycles += 2;
                },
                0xBA => {
                    self.x = self.setZN(self.sp);
                    self.cycles += 2;
                },
                0x9A => {
                    self.sp = self.x;
                    self.cycles += 2;
                },

                // Stack
                0x48 => {
                    self.push8(self.a);
                    self.cycles += 3;
                },
                0x68 => {
                    self.a = self.setZN(self.pop8());
                    self.cycles += 4;
                },
                0x08 => {
                    self.push8(self.statusByte(true));
                    self.cycles += 3;
                },
                0x28 => {
                    self.setStatus(self.pop8());
                    self.cycles += 4;
                },

                // Arithmetic
                0x69 => {
                    self.adc(self.fetch8());
                    self.cycles += 2;
                },
                0x65 => {
                    self.adc(self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0x75 => {
                    self.adc(self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0x6D => {
                    self.adc(self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0x7D => {
                    self.adc(self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0x79 => {
                    self.adc(self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0x61 => {
                    self.adc(self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0x71 => {
                    self.adc(self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0xE9 => {
                    self.sbc(self.fetch8());
                    self.cycles += 2;
                },
                0xE5 => {
                    self.sbc(self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xF5 => {
                    self.sbc(self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0xED => {
                    self.sbc(self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xFD => {
                    self.sbc(self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0xF9 => {
                    self.sbc(self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0xE1 => {
                    self.sbc(self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0xF1 => {
                    self.sbc(self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },

                // Logic
                0x29 => {
                    self.a = self.setZN(self.a & self.fetch8());
                    self.cycles += 2;
                },
                0x25 => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0x35 => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0x2D => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0x3D => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0x39 => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0x21 => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0x31 => {
                    self.a = self.setZN(self.a & self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0x09 => {
                    self.a = self.setZN(self.a | self.fetch8());
                    self.cycles += 2;
                },
                0x05 => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0x15 => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0x0D => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0x1D => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0x19 => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0x01 => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0x11 => {
                    self.a = self.setZN(self.a | self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0x49 => {
                    self.a = self.setZN(self.a ^ self.fetch8());
                    self.cycles += 2;
                },
                0x45 => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0x55 => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0x4D => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0x5D => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0x59 => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0x41 => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0x51 => {
                    self.a = self.setZN(self.a ^ self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0x24 => {
                    const v = self.bus.read8(self.addrZp());
                    self.z = (self.a & v) == 0;
                    self.n = v & 0x80 != 0;
                    self.v = v & 0x40 != 0;
                    self.cycles += 3;
                },
                0x2C => {
                    const v = self.bus.read8(self.addrAbs());
                    self.z = (self.a & v) == 0;
                    self.n = v & 0x80 != 0;
                    self.v = v & 0x40 != 0;
                    self.cycles += 4;
                },

                // Compares
                0xC9 => {
                    self.cmp(self.a, self.fetch8());
                    self.cycles += 2;
                },
                0xC5 => {
                    self.cmp(self.a, self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xD5 => {
                    self.cmp(self.a, self.bus.read8(self.addrZpX()));
                    self.cycles += 4;
                },
                0xCD => {
                    self.cmp(self.a, self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xDD => {
                    self.cmp(self.a, self.bus.read8(self.addrAbsX()));
                    self.cycles += 4;
                },
                0xD9 => {
                    self.cmp(self.a, self.bus.read8(self.addrAbsY()));
                    self.cycles += 4;
                },
                0xC1 => {
                    self.cmp(self.a, self.bus.read8(self.addrIzx()));
                    self.cycles += 6;
                },
                0xD1 => {
                    self.cmp(self.a, self.bus.read8(self.addrIzy()));
                    self.cycles += 5;
                },
                0xE0 => {
                    self.cmp(self.x, self.fetch8());
                    self.cycles += 2;
                },
                0xE4 => {
                    self.cmp(self.x, self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xEC => {
                    self.cmp(self.x, self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },
                0xC0 => {
                    self.cmp(self.y, self.fetch8());
                    self.cycles += 2;
                },
                0xC4 => {
                    self.cmp(self.y, self.bus.read8(self.addrZp()));
                    self.cycles += 3;
                },
                0xCC => {
                    self.cmp(self.y, self.bus.read8(self.addrAbs()));
                    self.cycles += 4;
                },

                // Inc/dec
                0xE6 => {
                    self.rmw(self.addrZp(), incV);
                    self.cycles += 5;
                },
                0xF6 => {
                    self.rmw(self.addrZpX(), incV);
                    self.cycles += 6;
                },
                0xEE => {
                    self.rmw(self.addrAbs(), incV);
                    self.cycles += 6;
                },
                0xFE => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, incV);
                    self.cycles += 7;
                },
                0xC6 => {
                    self.rmw(self.addrZp(), decV);
                    self.cycles += 5;
                },
                0xD6 => {
                    self.rmw(self.addrZpX(), decV);
                    self.cycles += 6;
                },
                0xCE => {
                    self.rmw(self.addrAbs(), decV);
                    self.cycles += 6;
                },
                0xDE => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, decV);
                    self.cycles += 7;
                },
                0xE8 => {
                    self.x = self.setZN(self.x +% 1);
                    self.cycles += 2;
                },
                0xC8 => {
                    self.y = self.setZN(self.y +% 1);
                    self.cycles += 2;
                },
                0xCA => {
                    self.x = self.setZN(self.x -% 1);
                    self.cycles += 2;
                },
                0x88 => {
                    self.y = self.setZN(self.y -% 1);
                    self.cycles += 2;
                },

                // Shifts
                0x0A => {
                    self.a = self.aslV(self.a);
                    self.cycles += 2;
                },
                0x06 => {
                    self.rmw(self.addrZp(), aslM);
                    self.cycles += 5;
                },
                0x16 => {
                    self.rmw(self.addrZpX(), aslM);
                    self.cycles += 6;
                },
                0x0E => {
                    self.rmw(self.addrAbs(), aslM);
                    self.cycles += 6;
                },
                0x1E => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, aslM);
                    self.cycles += 7;
                },
                0x4A => {
                    self.a = self.lsrV(self.a);
                    self.cycles += 2;
                },
                0x46 => {
                    self.rmw(self.addrZp(), lsrM);
                    self.cycles += 5;
                },
                0x56 => {
                    self.rmw(self.addrZpX(), lsrM);
                    self.cycles += 6;
                },
                0x4E => {
                    self.rmw(self.addrAbs(), lsrM);
                    self.cycles += 6;
                },
                0x5E => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, lsrM);
                    self.cycles += 7;
                },
                0x2A => {
                    self.a = self.rolV(self.a);
                    self.cycles += 2;
                },
                0x26 => {
                    self.rmw(self.addrZp(), rolM);
                    self.cycles += 5;
                },
                0x36 => {
                    self.rmw(self.addrZpX(), rolM);
                    self.cycles += 6;
                },
                0x2E => {
                    self.rmw(self.addrAbs(), rolM);
                    self.cycles += 6;
                },
                0x3E => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, rolM);
                    self.cycles += 7;
                },
                0x6A => {
                    self.a = self.rorV(self.a);
                    self.cycles += 2;
                },
                0x66 => {
                    self.rmw(self.addrZp(), rorM);
                    self.cycles += 5;
                },
                0x76 => {
                    self.rmw(self.addrZpX(), rorM);
                    self.cycles += 6;
                },
                0x6E => {
                    self.rmw(self.addrAbs(), rorM);
                    self.cycles += 6;
                },
                0x7E => {
                    _ = self.fetchAbsX();
                    self.rmw(self.ea_tmp, rorM);
                    self.cycles += 7;
                },

                // Jumps
                0x4C => {
                    self.pc = self.fetch16();
                    self.cycles += 3;
                },
                0x6C => {
                    self.pc = self.read16PageWrap(self.fetch16());
                    self.cycles += 5;
                },
                0x20 => {
                    const target = self.fetch16();
                    const ret = self.pc -% 1;
                    self.push8(@intCast(ret >> 8));
                    self.push8(@intCast(ret & 0xFF));
                    self.pc = target;
                    self.cycles += 6;
                },
                0x60 => {
                    const lo: u16 = self.pop8();
                    const hi: u16 = self.pop8();
                    self.pc = (lo | (hi << 8)) +% 1;
                    self.cycles += 6;
                },
                0x40 => {
                    self.setStatus(self.pop8());
                    const lo: u16 = self.pop8();
                    const hi: u16 = self.pop8();
                    self.pc = lo | (hi << 8);
                    self.cycles += 6;
                },
                0x00 => {
                    // BRK — the game shouldn't execute this; treat as trap
                    self.trap = op;
                    self.trap_pc = op_pc;
                    self.pc = op_pc;
                    return false;
                },

                // Branches
                0x10 => self.branchOp(!self.n),
                0x30 => self.branchOp(self.n),
                0x50 => self.branchOp(!self.v),
                0x70 => self.branchOp(self.v),
                0x90 => self.branchOp(!self.c),
                0xB0 => self.branchOp(self.c),
                0xD0 => self.branchOp(!self.z),
                0xF0 => self.branchOp(self.z),

                // Flags
                0x18 => {
                    self.c = false;
                    self.cycles += 2;
                },
                0x38 => {
                    self.c = true;
                    self.cycles += 2;
                },
                0x58 => {
                    self.i = false;
                    self.cycles += 2;
                },
                0x78 => {
                    self.i = true;
                    self.cycles += 2;
                },
                0xB8 => {
                    self.v = false;
                    self.cycles += 2;
                },
                0xD8 => {
                    self.d = false;
                    self.cycles += 2;
                },
                0xF8 => {
                    self.d = true;
                    self.cycles += 2;
                },
                0xEA => {
                    self.cycles += 2;
                },

                else => {
                    self.trap = op;
                    self.trap_pc = op_pc;
                    self.pc = op_pc;
                    return false;
                },
            }
            return true;
        }

        // store variants need EA without the page-cross cycle already applied;
        // simplest correct-enough approach: recompute and stash.
        fn fetchAbsX(self: *Self) void {
            self.ea_tmp = self.fetch16() +% self.x;
        }
        fn fetchAbsY(self: *Self) void {
            self.ea_tmp = self.fetch16() +% self.y;
        }

        fn branchOp(self: *Self, cond: bool) void {
            self.cycles += 2;
            self.branch(cond);
        }

        fn incV(self: *Self, v: u8) u8 {
            return self.setZN(v +% 1);
        }
        fn decV(self: *Self, v: u8) u8 {
            return self.setZN(v -% 1);
        }
        fn aslM(self: *Self, v: u8) u8 {
            return self.aslV(v);
        }
        fn lsrM(self: *Self, v: u8) u8 {
            return self.lsrV(v);
        }
        fn rolM(self: *Self, v: u8) u8 {
            return self.rolV(v);
        }
        fn rorM(self: *Self, v: u8) u8 {
            return self.rorV(v);
        }
    };
}
