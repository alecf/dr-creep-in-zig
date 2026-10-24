const std = @import("std");
const machine = @import("machine");

pub fn build(b: *std.Build) void {
    machine.addGame(b, .{ .name = "starter", .root = b.path("src/main.zig") });
}
