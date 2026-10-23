//! The Comet 64 with no screen attached: boots the game, plays a scripted
//! joystick, and saves frames as PPM pictures. Handy for checking a build
//! without a browser, and for testing.
//!
//!   zig build run -- --frames 300 --press 50:rf:20 --press 120:f@2 \
//!                    --key 200:R --dump frames --dump-every 50

const std = @import("std");
const machine = @import("machine");
const game = @import("game");

const Machine = machine.Machine;
const video = machine.video;

const usage =
    \\usage: run [options]
    \\  --frames N              frames to run (default 250, i.e. 5 seconds)
    \\  --press FRAME:KEYS[:DUR][@2]
    \\                          hold joystick KEYS (any of u d l r f) from FRAME
    \\                          for DUR frames (default 10); @2 = joystick 2
    \\  --key FRAME:C           type character C at FRAME
    \\  --dump DIR              where pictures go (default "frames")
    \\  --dump-every K          save every Kth frame too (default: last only)
    \\
;

const Press = struct { frame: u32, mask: u8, dur: u32, port: u8 };
const KeyPress = struct { frame: u32, key: u8 };

const Script = struct {
    frames: u32 = 250,
    dump_dir: []const u8 = "frames",
    dump_every: u32 = 0,
    presses: std.ArrayList(Press) = .empty,
    keys: std.ArrayList(KeyPress) = .empty,

    fn inputFor(s: *const Script, frame: u32) machine.Input {
        var in: machine.Input = .{};
        for (s.presses.items) |p| {
            if (frame < p.frame or frame >= p.frame + p.dur) continue;
            if (p.port == 2) in.joy2 |= p.mask else in.joy1 |= p.mask;
        }
        for (s.keys.items) |k| {
            if (k.frame == frame) in.key = k.key;
        }
        return in;
    }
};

fn parsePress(spec: []const u8) !Press {
    var rest = spec;
    var port: u8 = 1;
    if (std.mem.indexOfScalar(u8, rest, '@')) |at| {
        port = try std.fmt.parseInt(u8, rest[at + 1 ..], 10);
        if (port != 1 and port != 2) return error.BadPort;
        rest = rest[0..at];
    }
    var parts = std.mem.splitScalar(u8, rest, ':');
    const frame = try std.fmt.parseInt(u32, parts.next() orelse return error.BadPress, 10);
    const keys = parts.next() orelse return error.BadPress;
    const dur = if (parts.next()) |d| try std.fmt.parseInt(u32, d, 10) else 10;
    var mask: u8 = 0;
    for (keys) |ch| mask |= switch (ch) {
        'u' => machine.joy.up,
        'd' => machine.joy.down,
        'l' => machine.joy.left,
        'r' => machine.joy.right,
        'f' => machine.joy.fire,
        else => return error.BadPress,
    };
    return .{ .frame = frame, .mask = mask, .dur = dur, .port = port };
}

fn parseKey(spec: []const u8) !KeyPress {
    const colon = std.mem.indexOfScalar(u8, spec, ':') orelse return error.BadKey;
    if (spec.len != colon + 2) return error.BadKey;
    return .{
        .frame = try std.fmt.parseInt(u32, spec[0..colon], 10),
        .key = std.ascii.toUpper(spec[colon + 1]),
    };
}

fn parseArgs(gpa: std.mem.Allocator, args: std.process.Args) !Script {
    var s: Script = .{};
    var it = std.process.Args.Iterator.init(args);
    _ = it.next();
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--frames")) {
            s.frames = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, arg, "--press")) {
            try s.presses.append(gpa, try parsePress(it.next() orelse return error.MissingValue));
        } else if (std.mem.eql(u8, arg, "--key")) {
            try s.keys.append(gpa, try parseKey(it.next() orelse return error.MissingValue));
        } else if (std.mem.eql(u8, arg, "--dump")) {
            s.dump_dir = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, arg, "--dump-every")) {
            s.dump_every = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}", .{usage});
            std.process.exit(0);
        } else {
            return error.UnknownOption;
        }
    }
    return s;
}

fn writePpm(io: std.Io, dir: std.Io.Dir, name: []const u8, screen: *const video.Screen) !void {
    const header = std.fmt.comptimePrint("P6\n{d} {d}\n255\n", .{ video.width, video.height });
    var buf: [header.len + video.width * video.height * 3]u8 = undefined;
    @memcpy(buf[0..header.len], header);
    for (screen, 0..) |px, i| {
        const o = header.len + i * 3;
        buf[o + 0] = @truncate(px);
        buf[o + 1] = @truncate(px >> 8);
        buf[o + 2] = @truncate(px >> 16);
    }
    try dir.writeFile(io, .{ .sub_path = name, .data = &buf });
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var out_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &out_buf);
    const out = &stdout.interface;

    var script = parseArgs(gpa, init.minimal.args) catch |err| {
        std.debug.print("{t}\n\n{s}", .{ err, usage });
        std.process.exit(2);
    };
    defer script.presses.deinit(gpa);
    defer script.keys.deinit(gpa);
    if (script.frames == 0) script.frames = 1;

    const m = try gpa.create(Machine);
    defer gpa.destroy(m);
    m.boot(game);

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, script.dump_dir);
    var dir = try cwd.openDir(io, script.dump_dir, .{});
    defer dir.close(io);

    var frame: u32 = 0;
    while (frame < script.frames) : (frame += 1) {
        m.input = script.inputFor(frame);
        m.runFrame(game);
        const last = frame == script.frames - 1;
        const due = script.dump_every != 0 and frame % script.dump_every == 0;
        if (last or due) {
            var name_buf: [32]u8 = undefined;
            const name = try std.fmt.bufPrint(&name_buf, "frame_{d:0>5}.ppm", .{frame});
            try writePpm(io, dir, name, &m.screen);
        }
    }

    const budget = machine.frame_budget;
    const avg: u32 = @intCast(m.total_cycles / m.frames);
    try out.print("ran {d} frames\n", .{m.frames});
    try out.print("cycles: max {d} ({d}%), avg {d} ({d}%) of {d}\n", .{
        m.max_cycles, @as(u64, m.max_cycles) * 100 / budget, avg, @as(u64, avg) * 100 / budget, budget,
    });
    try out.print("overruns: {d}\n", .{m.overruns});
    try out.print("last frame: {s}/frame_{d:0>5}.ppm\n", .{ script.dump_dir, frame - 1 });
    try out.flush();
}
