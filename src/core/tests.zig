//! Core unit tests: CPU semantics against hand-checked cases.
//! (Differential tests against VICE traces come later — see design doc M6.)

const std = @import("std");
const cpu6502 = @import("cpu6502.zig");

const FlatBus = struct {
    mem: [0x10000]u8 = @splat(0),
    pub fn read8(self: *FlatBus, addr: u16) u8 {
        return self.mem[addr];
    }
    pub fn write8(self: *FlatBus, addr: u16, v: u8) void {
        self.mem[addr] = v;
    }
};

const Cpu = cpu6502.Cpu(FlatBus);

fn run(bus: *FlatBus, code: []const u8, steps: usize) Cpu {
    @memcpy(bus.mem[0x1000 .. 0x1000 + code.len], code);
    var cpu = Cpu.init(bus);
    cpu.reset(0x1000);
    var i: usize = 0;
    while (i < steps) : (i += 1) {
        if (!cpu.step()) break;
    }
    return cpu;
}

test "lda/sta round trip with flags" {
    var bus = FlatBus{};
    // lda #$80; sta $2000; lda #$00
    const cpu = run(&bus, &.{ 0xA9, 0x80, 0x8D, 0x00, 0x20, 0xA9, 0x00 }, 3);
    try std.testing.expectEqual(@as(u8, 0x80), bus.mem[0x2000]);
    try std.testing.expect(cpu.z);
    try std.testing.expect(!cpu.n);
}

test "adc binary overflow and carry" {
    var bus = FlatBus{};
    // lda #$7f; adc #$01 -> $80, V set, C clear
    const cpu = run(&bus, &.{ 0xA9, 0x7F, 0x69, 0x01 }, 2);
    try std.testing.expectEqual(@as(u8, 0x80), cpu.a);
    try std.testing.expect(cpu.v);
    try std.testing.expect(!cpu.c);
    try std.testing.expect(cpu.n);
}

test "adc decimal mode" {
    var bus = FlatBus{};
    // sed; clc; lda #$19; adc #$01 -> $20 BCD
    const cpu = run(&bus, &.{ 0xF8, 0x18, 0xA9, 0x19, 0x69, 0x01 }, 4);
    try std.testing.expectEqual(@as(u8, 0x20), cpu.a);
    try std.testing.expect(!cpu.c);
}

test "sbc decimal mode" {
    var bus = FlatBus{};
    // sed; sec; lda #$20; sbc #$01 -> $19 BCD
    const cpu = run(&bus, &.{ 0xF8, 0x38, 0xA9, 0x20, 0xE9, 0x01 }, 4);
    try std.testing.expectEqual(@as(u8, 0x19), cpu.a);
    try std.testing.expect(cpu.c);
}

test "jsr/rts nesting" {
    var bus = FlatBus{};
    // $1000: jsr $1005; brk-pad; $1005: lda #$42; rts
    const code = [_]u8{ 0x20, 0x05, 0x10, 0xEA, 0xEA, 0xA9, 0x42, 0x60 };
    const cpu = run(&bus, &code, 3); // jsr, lda, rts
    try std.testing.expectEqual(@as(u8, 0x42), cpu.a);
    try std.testing.expectEqual(@as(u16, 0x1003), cpu.pc);
}

test "indexed indirect addressing" {
    var bus = FlatBus{};
    bus.mem[0x00A0] = 0x00;
    bus.mem[0x00A1] = 0x30;
    bus.mem[0x3005] = 0x77;
    // ldy #$05; lda ($a0),y
    const cpu = run(&bus, &.{ 0xA0, 0x05, 0xB1, 0xA0 }, 2);
    try std.testing.expectEqual(@as(u8, 0x77), cpu.a);
}

test "cmp sets carry when >=" {
    var bus = FlatBus{};
    const cpu = run(&bus, &.{ 0xA9, 0x40, 0xC9, 0x40 }, 2);
    try std.testing.expect(cpu.c);
    try std.testing.expect(cpu.z);
}

test "branch back and page-wrap timing does not corrupt pc" {
    var bus = FlatBus{};
    // ldx #$03; loop: dex; bne loop; nop
    const cpu = run(&bus, &.{ 0xA2, 0x03, 0xCA, 0xD0, 0xFD, 0xEA }, 8);
    try std.testing.expectEqual(@as(u8, 0), cpu.x);
    try std.testing.expectEqual(@as(u16, 0x1006), cpu.pc);
}

test "asl memory through rmw" {
    var bus = FlatBus{};
    bus.mem[0x0080] = 0x81;
    // asl $80 -> $02, carry set
    const cpu = run(&bus, &.{ 0x06, 0x80 }, 1);
    try std.testing.expectEqual(@as(u8, 0x02), bus.mem[0x0080]);
    try std.testing.expect(cpu.c);
}

test "php/plp round trips flags" {
    var bus = FlatBus{};
    // sec; sed; php; cld; clc; plp
    const cpu = run(&bus, &.{ 0x38, 0xF8, 0x08, 0xD8, 0x18, 0x28 }, 6);
    try std.testing.expect(cpu.c);
    try std.testing.expect(cpu.d);
}

test "machine banking: io visible at 05, ram at 04" {
    const Machine = @import("machine.zig").Machine;
    const m = try Machine.init(std.testing.allocator);
    defer m.deinit();
    m.cpu_ddr = 0x2F;
    m.cpu_port = 0x05;
    m.write8(0xD020, 0x07);
    try std.testing.expectEqual(@as(u8, 0x07), m.vic[0x20]);
    m.write8(0xD400 + 0x18, 0x0F);
    try std.testing.expectEqual(@as(u8, 0x0F), m.sid[0x18]);
    // bank I/O out: writes hit RAM underneath
    m.cpu_port = 0x04;
    m.write8(0xD020, 0x99);
    try std.testing.expectEqual(@as(u8, 0x99), m.ram[0xD020]);
    try std.testing.expectEqual(@as(u8, 0x07), m.vic[0x20]);
}
