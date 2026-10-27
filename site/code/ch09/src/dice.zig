//! The dice: numbers that look random, rolled the way the 1984 game rolls
//! them. Two bytes of memory hold the dice. Each roll stirs them with a
//! rotate and two XORs, and hands back one of them.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");

/// The two bytes the 1984 game starts its dice from.
const first_low: u8 = 0xC6;
const first_high: u8 = 0x57;

/// Once, at power-on: the same dice every time.
pub fn start(m: *Machine) void {
    m.poke(map.dice_low, first_low);
    m.poke(map.dice_high, first_high);
}

/// Roll: the next byte. Take the two bytes as one 16-bit number and
/// rotate it a bit to the right, so the high byte's bottom bit lands at
/// the top of the low byte. XOR that low byte into the high byte. Then
/// the new low byte is the old one, its bottom bit cleared, XOR the new
/// high byte.
pub fn roll(m: *Machine) u8 {
    const low = m.peek(map.dice_low);
    const high = m.peek(map.dice_high);
    const turned: u8 = @truncate(std.math.rotr(u16, @as(u16, high) << 8 | low, 1));
    const new_high = high ^ turned;
    const new_low = (low & 0xFE) ^ new_high;
    m.poke(map.dice_high, new_high);
    m.poke(map.dice_low, new_low);
    m.work(24); // two rotates, three XORs, an AND
    return new_low;
}

// ---- tests ----------------------------------------------------------------

test "the dice roll 1984's numbers, in 1984's order" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    for ([_]u8{ 0x72, 0xFF, 0x8C, 0xB8, 0xD0, 0xD0, 0xB8, 0x8C }) |want| {
        try std.testing.expectEqual(want, roll(m));
    }
}

test "after their first roll, the dice come round again every 32,767 rolls" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    _ = roll(m); // the starting pair never comes back, but this one does
    const low = m.ram[map.dice_low];
    const high = m.ram[map.dice_high];
    var rolls: usize = 0;
    var fours = [_]usize{0} ** 4; // how often each of the four low-bit pairs comes up
    while (true) {
        fours[roll(m) & 3] += 1;
        rolls += 1;
        if (m.ram[map.dice_low] == low and m.ram[map.dice_high] == high) break;
    }
    try std.testing.expectEqual(32_767, rolls);
    for (fours) |n| try std.testing.expect(n > 8_100 and n < 8_300); // a quarter each, near enough
}
