const std = @import("std");
const machine = @import("machine");

pub fn build(b: *std.Build) void {
    machine.addGame(b, .{ .name = "creep", .root = b.path("src/main.zig") });
}
