//! The Comet 64 with no screen attached: boots the game, plays a scripted
//! joystick, and saves frames as PPM pictures (and, if asked, the sound as
//! a WAV file). Handy for checking a build without a browser, and for
//! testing.
//!
//!   zig build run -- --frames 300 --press 50:rf:20 --press 120:f@2 \
//!                    --key 200:R --dump frames --dump-every 50 --wav out.wav

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
    \\  --key FRAME:C           type character C at FRAME (FRAME:#13 types code 13)
    \\  --dump DIR              where pictures go (default "frames")
    \\  --dump-every K          save every Kth frame too (default: last only)
    \\  --wav FILE              save the sound to FILE (44,100 a second, mono)
    \\
;

const Press = struct { frame: u32, mask: u8, dur: u32, port: u8 };
const KeyPress = struct { frame: u32, key: u8 };

const Script = struct {
    frames: u32 = 250,
    dump_dir: []const u8 = "frames",
    dump_every: u32 = 0,
    wav: ?[]const u8 = null,
    presses: std.ArrayList(Press) = .empty,
    keys: std.ArrayList(KeyPress) = .empty,

    fn inputFor(s: *const Script, frame: u32) machine.Input {
        var in: machine.Input = .{};
        for (s.presses.items) |p| {
            if (frame < p.frame or frame - p.frame >= p.dur) continue;
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
    if (keys.len == 0) return error.BadPress;
    const dur = if (parts.next()) |d| try std.fmt.parseInt(u32, d, 10) else 10;
    if (parts.next() != null) return error.BadPress;
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
    const frame = try std.fmt.parseInt(u32, spec[0..colon], 10);
    const what = spec[colon + 1 ..];
    const key: u8 = if (what.len > 1 and what[0] == '#')
        try std.fmt.parseInt(u8, what[1..], 10)
    else if (what.len == 1)
        std.ascii.toUpper(what[0])
    else
        return error.BadKey;
    if (key == 0) return error.BadKey;
    return .{ .frame = frame, .key = key };
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
        } else if (std.mem.eql(u8, arg, "--wav")) {
            s.wav = it.next() orelse return error.MissingValue;
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

/// Samples a second in the WAV file; 882 a frame.
const wav_rate = 44100;
const per_frame = wav_rate / machine.frame_rate;

fn writeWav(io: std.Io, gpa: std.mem.Allocator, path: []const u8, samples: []const i16) !void {
    const data_len: u32 = @intCast(samples.len * 2);
    const buf = try gpa.alloc(u8, 44 + data_len);
    defer gpa.free(buf);
    @memcpy(buf[0..4], "RIFF");
    std.mem.writeInt(u32, buf[4..8], 36 + data_len, .little);
    @memcpy(buf[8..16], "WAVEfmt ");
    std.mem.writeInt(u32, buf[16..20], 16, .little); // the format chunk's size
    std.mem.writeInt(u16, buf[20..22], 1, .little); // plain samples
    std.mem.writeInt(u16, buf[22..24], 1, .little); // one channel
    std.mem.writeInt(u32, buf[24..28], wav_rate, .little);
    std.mem.writeInt(u32, buf[28..32], wav_rate * 2, .little); // bytes a second
    std.mem.writeInt(u16, buf[32..34], 2, .little); // bytes a sample
    std.mem.writeInt(u16, buf[34..36], 16, .little); // bits a sample
    @memcpy(buf[36..40], "data");
    std.mem.writeInt(u32, buf[40..44], data_len, .little);
    for (samples, 0..) |x, i| std.mem.writeInt(i16, buf[44 + i * 2 ..][0..2], x, .little);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = buf });
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
    var sound: std.ArrayList(i16) = .empty;
    defer sound.deinit(gpa);
    if (script.frames == 0) script.frames = 1;

    const m = try gpa.create(Machine);
    defer gpa.destroy(m);
    m.boot(game);

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, script.dump_dir);
    var dir = try cwd.openDir(io, script.dump_dir, .{});
    defer dir.close(io);

    // A long frame uses several frame slots; the frames it swallowed pass
    // without a call to `frame`, and show the same picture.
    var frame: u32 = 0;
    var last_saved: u32 = 0;
    while (frame < script.frames) {
        m.input = script.inputFor(frame);
        const slots = m.runFrame(game);
        const end = @min(script.frames, frame +| slots);
        if (script.wav != null) {
            // The chip keeps playing through every slot of a long frame.
            for (frame..end) |_| {
                var chunk: [per_frame]f32 = undefined;
                m.listen(&chunk, wav_rate);
                for (chunk) |x| try sound.append(gpa, @intFromFloat(std.math.clamp(x, -1, 1) * 32767));
            }
        }
        while (frame < end) : (frame += 1) {
            const last = frame == script.frames - 1;
            const due = script.dump_every != 0 and frame % script.dump_every == 0;
            if (last or due) {
                var name_buf: [32]u8 = undefined;
                const name = try std.fmt.bufPrint(&name_buf, "frame_{d:0>5}.ppm", .{frame});
                try writePpm(io, dir, name, &m.screen);
                last_saved = frame;
            }
        }
    }

    const s = &m.stats;
    const budget = machine.frame_budget;
    const avg: u64 = s.total_cycles / @max(1, s.calls);
    try out.print("ran {d} frames ({d} calls to frame)\n", .{ frame, s.calls });
    try out.print("cycles: max {d} ({d}%), avg {d} ({d}%) of {d}\n", .{
        s.max_cycles, @as(u64, s.max_cycles) * 100 / budget, avg, avg * 100 / budget, budget,
    });
    for (s.bucket_total, 0..) |total, i| {
        if (total == 0) continue;
        try out.print("  bucket {d}: max {d}, avg {d}\n", .{ i, s.bucket_max[i], total / @max(1, s.calls) });
    }
    try out.print("overruns: {d}, loading pauses: {d}\n", .{ s.overruns, s.loading });
    try out.print("last frame: {s}/frame_{d:0>5}.ppm\n", .{ script.dump_dir, last_saved });
    if (script.wav) |path| {
        var loudest: u16 = 0;
        for (sound.items) |x| loudest = @max(loudest, @abs(x));
        try writeWav(io, gpa, path, sound.items);
        try out.print("sound: {s}, {d}.{d:0>2} seconds, loudest {d}%\n", .{
            path, sound.items.len / wav_rate, sound.items.len % wav_rate * 100 / wav_rate, @as(u32, loudest) * 100 / 32767,
        });
    }
    try out.flush();
}
