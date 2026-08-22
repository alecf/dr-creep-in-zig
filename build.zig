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

    // Native windowed app (sokol: Metal on macOS). The same shell is the
    // basis for the wasm build (sokol WebGL2 via emscripten) later.
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    const app = b.addExecutable(.{
        .name = "creep",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            },
        }),
    });
    b.installArtifact(app);
    const run_app = b.addRunArtifact(app);
    b.step("run", "Run the windowed game").dependOn(&run_app.step);

    // WebAssembly build: wasm32-freestanding, driven by web/creep.js.
    const wasm = b.addExecutable(.{
        .name = "creep",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = .ReleaseSmall,
        }),
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    const wasm_install = b.addInstallFile(wasm.getEmittedBin(), "../web/creep.wasm");
    b.step("wasm", "Build web/creep.wasm").dependOn(&wasm_install.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.step("test", "Run core tests").dependOn(&b.addRunArtifact(tests).step);
}
