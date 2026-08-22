const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Headless runner: boots the game core and dumps framebuffers to PPM.
    // No GPU/audio dependencies — used for verification and CI.
    const headless = b.addExecutable(.{
        .name = "creep-headless",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/headless.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(headless);

    const run_headless = b.addRunArtifact(headless);
    if (b.args) |args| run_headless.addArgs(args);
    b.step("headless", "Run the headless core").dependOn(&run_headless.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.step("test", "Run core tests").dependOn(&b.addRunArtifact(tests).step);
}
