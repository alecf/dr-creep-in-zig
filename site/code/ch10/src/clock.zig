//! Each explorer's time in the castle: a clock that runs while he's in a
//! room, kept in binary-coded decimal, a decimal digit to each half of a
//! byte, so that printing it needs no dividing.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const castle = @import("castle.zig");
const text = @import("text.zig");
const actors = @import("actors.zig");
const player = @import("player.zig");

/// One explorer's time: frames (0 to 49, in plain binary), then seconds,
/// minutes and hours, each two decimal digits in one byte.
pub const Time = extern struct { frames: u8, seconds: u8, minutes: u8, hours: u8 };
pub const frames_per_second = 50;

/// Player `p`'s time, in the castle header.
pub fn of(m: *Machine, p: player.Number) *align(1) Time {
    return m.view(Time, castle.time + @as(u16, p) * @sizeOf(Time));
}

/// Every frame of a room: a frame more for each explorer in it who's
/// playing or in a doorway.
pub fn tick(m: *Machine) void {
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        m.work(20); // the tests
        if (player.record(m, p).actor == actors.none) continue;
        switch (player.status(m, p)) {
            .playing, .doorway => advance(m, of(m, p)),
            else => {},
        }
    }
}

/// One frame later: 50 frames make a second, 60 seconds a minute, 60
/// minutes an hour, and after 99 hours it starts again.
fn advance(m: *Machine, t: *align(1) Time) void {
    m.work(12); // the add and the test
    t.frames += 1;
    if (t.frames < frames_per_second) return;
    t.frames = 0;
    if (!up(m, &t.seconds, 0x60)) return;
    if (!up(m, &t.minutes, 0x60)) return;
    _ = up(m, &t.hours, 0xA0);
}

/// Add one to the two decimal digits in `digits`. Past a 9 in the low
/// half, add 6 more: the 6 codes from $A to $F get skipped, and the carry
/// goes into the high half. At `limit` it goes back to 00, and returns
/// true: carry one into the next byte.
pub fn up(m: *Machine, digits: *align(1) u8, limit: u8) bool {
    m.work(14); // the add, the mask, the tests
    var n = digits.* + 1;
    if (n & 0x0F == 0x0A) n += 0x06;
    if (n == limit) {
        digits.* = 0;
        return true;
    }
    digits.* = n;
    return false;
}

/// Print player `p`'s time as HH:MM:SS at fat pixel (x, y). Each digit is
/// half a byte, so it's a shift or a mask away from its letter.
pub fn print(m: *Machine, x: u8, y: u8, color: Color, p: player.Number) void {
    const t = of(m, p);
    var at = map.text_buffer;
    for ([3]u8{ t.hours, t.minutes, t.seconds }) |digits| {
        m.poke(at, '0' + (digits >> 4));
        m.poke(at + 1, '0' + (digits & 0x0F));
        m.poke(at + 2, ':');
        at += 3;
        m.work(16); // the shift, the mask, the adds
    }
    m.poke(at - 2, m.peek(at - 2) | 0x80); // the last digit ends the string
    _ = text.draw(m, x, y, color, text.plain, map.text_buffer);
}

// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "a decimal digit to each half: 09 + 1 is 10, and 59 + 1 carries" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    var d: u8 = 0x09;
    try std.testing.expect(!up(m, &d, 0x60));
    try std.testing.expectEqual(0x10, d);
    d = 0x59;
    try std.testing.expect(up(m, &d, 0x60));
    try std.testing.expectEqual(0x00, d);
    d = 0x99;
    try std.testing.expect(up(m, &d, 0xA0)); // 99 hours, and round again
}

test "an hour, a minute and a second, and it prints as it reads" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    const t = of(m, 1);
    for (0..(3600 + 60 + 1) * frames_per_second) |_| advance(m, t);
    try std.testing.expectEqual(Time{ .frames = 0, .seconds = 0x01, .minutes = 0x01, .hours = 0x01 }, t.*);
    t.minutes = 0x42;
    @import("screen.zig").start(m);
    text.start(m);
    print(m, 0, 0, .white, 1);
    try std.testing.expectEqualSlices(u8, "01:42:0", m.ram[map.text_buffer..][0..7]);
    try std.testing.expectEqual('1' | 0x80, m.ram[map.text_buffer + 7]);
}
