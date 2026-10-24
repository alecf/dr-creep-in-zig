//! Added to every game's `zig build test`: power the machine on with the
//! game and run a few seconds of frames, so a game that panics, or that
//! forgets `boot` or `frame`, fails the test step.

const std = @import("std");
const machine = @import("machine");
const game = @import("game");

test "the game boots and runs 100 frames" {
    const m = try std.testing.allocator.create(machine.Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(game);
    for (0..100) |i| {
        m.input = .{ .joy1 = if (i % 20 < 10) machine.joy.fire else 0 };
        _ = m.runFrame(game);
    }
    try std.testing.expect(m.stats.frames >= 100);
}
