//! Build support for the Comet 64.
//!
//! On its own, `zig build test` here tests the machine. A game project
//! depends on this package and calls `addGame` from its build.zig, which
//! gives it four commands:
//!
//!   zig build            build the headless runner (zig-out/bin/NAME)
//!   zig build run -- ... run the game headless (see src/headless.zig)
//!   zig build test       the game's tests, plus a 100-frame boot test
//!   zig build wasm       write web/game.wasm, web/shell.js, web/index.html

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("machine", .{
        .root_source_file = b.path("src/machine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{ .root_module = mod });
    b.step("test", "Test the machine").dependOn(&b.addRunArtifact(tests).step);
}

pub const GameOptions = struct {
    /// Name of the headless executable.
    name: []const u8,
    /// The game's root source file: it must define `pub fn boot` and
    /// `pub fn frame`.
    root: std.Build.LazyPath,
};

pub fn addGame(b: *std.Build, options: GameOptions) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep = b.dependency("machine", .{});

    // ---- native: headless runner and tests ----
    const native = gameModules(b, dep, options.root, target, optimize);

    const exe = b.addExecutable(.{
        .name = options.name,
        .root_module = b.createModule(.{
            .root_source_file = dep.path("src/headless.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &native.imports,
        }),
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run the game headless (zig build run -- --help)").dependOn(&run.step);

    const test_step = b.step("test", "Run the game's tests and a boot test");
    const own_tests = b.addTest(.{ .root_module = native.game });
    test_step.dependOn(&b.addRunArtifact(own_tests).step);
    const boot_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = dep.path("src/game_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &native.imports,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(boot_test).step);

    // ---- browser: web/game.wasm plus the shell ----
    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const web = gameModules(b, dep, options.root, wasm_target, .ReleaseSafe);
    const wasm = b.addExecutable(.{
        .name = "game",
        .root_module = b.createModule(.{
            .root_source_file = dep.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSafe,
            .imports = &web.imports,
        }),
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    const update = b.addUpdateSourceFiles();
    update.addCopyFileToSource(wasm.getEmittedBin(), "web/game.wasm");
    update.addCopyFileToSource(dep.path("web/shell.js"), "web/shell.js");
    update.addCopyFileToSource(dep.path("web/index.html"), "web/index.html");
    b.step("wasm", "Build web/game.wasm (serve the web/ folder to play)").dependOn(&update.step);
}

const GameModules = struct {
    game: *std.Build.Module,
    imports: [2]std.Build.Module.Import,
};

fn gameModules(
    b: *std.Build,
    dep: *std.Build.Dependency,
    root: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) GameModules {
    const machine = b.createModule(.{
        .root_source_file = dep.path("src/machine.zig"),
        .target = target,
        .optimize = optimize,
    });
    const game = b.createModule(.{
        .root_source_file = root,
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "machine", .module = machine }},
    });
    return .{
        .game = game,
        .imports = .{
            .{ .name = "machine", .module = machine },
            .{ .name = "game", .module = game },
        },
    };
}
