//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const room = @import("room.zig");
const player = @import("player.zig");

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    room.paint(m);
    player.start(m);
}

pub fn frame(m: *Machine) void {
    // Hardware first. The beam reaches the top of the display 3,213
    // cycles into the frame; registers written before then can't tear.
    player.show(m);

    // Then the game itself. What it decides shows up next frame.
    player.steer(m);
}

test "the stick steers the sprite and fire changes its colour" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    const x = m.ram[map.player_x];
    const color = m.ram[map.player_color];

    m.input = .{ .joy1 = machine.joy.left | machine.joy.fire };
    _ = m.runFrame(@This());
    try std.testing.expectEqual(x - 1, m.ram[map.player_x]);
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);

    // Still holding fire: same colour. The sprite registers caught up.
    _ = m.runFrame(@This());
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);
    try std.testing.expectEqual(x - 1, m.ram[hw.spriteX(0)]);
}
