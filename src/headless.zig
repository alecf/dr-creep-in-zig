//! Headless runner: boots The Castles of Dr. Creep in the emulation core,
//! runs N frames, and dumps the rendered framebuffer as PPM images.
//! This is the verification harness for M3 — no window, no GPU, no audio.
//!
//! Usage: creep-headless [--frames N] [--dump-every K] [--out DIR]

const std = @import("std");
const Machine = @import("core/machine.zig").Machine;
const vic = @import("core/vic.zig");
const kernal = @import("core/kernal.zig");

fn writePpm(
    io: std.Io,
    allocator: std.mem.Allocator,
    dir: std.Io.Dir,
    name: []const u8,
    fb: *const [vic.WIDTH * vic.HEIGHT]u32,
) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.print(allocator, "P6\n{d} {d}\n255\n", .{ vic.WIDTH, vic.HEIGHT });
    for (fb) |px| {
        try out.appendSlice(allocator, &.{
            @intCast(px & 0xFF),
            @intCast((px >> 8) & 0xFF),
            @intCast((px >> 16) & 0xFF),
        });
    }
    try dir.writeFile(io, .{ .sub_path = name, .data = out.items });
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var frames: u32 = 300;
    var dump_every: u32 = 60;
    var out_dir_path: []const u8 = "frames";
    var fire_at: u32 = 0; // frame at which to hold the joystick fire button
    // scripted presses: --press FRAME:udlrf (held 15 frames)
    const Press = struct { frame: u32, mask: u8, dur: u32 = 15 };
    var presses: [16]Press = undefined;
    var press_count: usize = 0;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--frames")) {
            frames = try std.fmt.parseInt(u32, args.next() orelse "300", 10);
        } else if (std.mem.eql(u8, arg, "--dump-every")) {
            dump_every = try std.fmt.parseInt(u32, args.next() orelse "60", 10);
        } else if (std.mem.eql(u8, arg, "--out")) {
            out_dir_path = args.next() orelse "frames";
        } else if (std.mem.eql(u8, arg, "--fire")) {
            fire_at = try std.fmt.parseInt(u32, args.next() orelse "0", 10);
        } else if (std.mem.eql(u8, arg, "--press")) {
            const spec = args.next() orelse continue;
            const colon = std.mem.indexOfScalar(u8, spec, ':') orelse continue;
            var mask: u8 = 0;
            for (spec[colon + 1 ..]) |ch| {
                mask |= switch (ch) {
                    'u' => @as(u8, 0x01),
                    'd' => 0x02,
                    'l' => 0x04,
                    'r' => 0x08,
                    'f' => 0x10,
                    else => 0,
                };
            }
            if (press_count < presses.len) {
                // optional duration: FRAME:keys:DUR
                var dur: u32 = 15;
                const rest = spec[colon + 1 ..];
                if (std.mem.indexOfScalar(u8, rest, ':')) |c2| {
                    dur = std.fmt.parseInt(u32, rest[c2 + 1 ..], 10) catch 15;
                }
                presses[press_count] = .{
                    .frame = try std.fmt.parseInt(u32, spec[0..colon], 10),
                    .mask = mask,
                    .dur = dur,
                };
                press_count += 1;
            }
        }
    }

    const m = try Machine.init(allocator);
    defer m.deinit();

    const cwd = std.Io.Dir.cwd();

    // In-memory disk: every extracted file, keyed by its C64 name
    // ("ztutorial", "music0", ...). Filenames on disk are <name>.prg.
    var fs = kernal.Fs.init(allocator);
    defer fs.deinit();
    {
        var dir = try cwd.openDir(io, "extracted", .{});
        defer dir.close(io);
        // manifest.txt preserves the original disk-directory order, which the
        // game's castle menu depends on
        const manifest = try dir.readFileAlloc(io, "manifest.txt", allocator, .limited(16 * 1024));
        defer allocator.free(manifest);
        var lines = std.mem.tokenizeScalar(u8, manifest, '\n');
        while (lines.next()) |stem| {
            var path_buf: [128]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buf, "{s}.prg", .{stem});
            const data = dir.readFileAlloc(io, path, allocator, .limited(64 * 1024)) catch continue;
            const name = try allocator.dupe(u8, stem);
            try fs.addFile(name, data);
        }
    }
    try kernal.install(m, &fs);

    // Character ROM for the boot menu font (VICE's GPL-distributed dump if
    // available; the game's own screens bring their own charsets).
    const chargen_paths = [_][]const u8{
        "roms/chargen.bin",
        "/opt/homebrew/share/vice/C64/chargen-901225-01.bin",
    };
    for (chargen_paths) |path| {
        const rom = cwd.readFileAlloc(io, path, allocator, .limited(8192)) catch continue;
        defer allocator.free(rom);
        if (rom.len >= 0x1000) {
            @memcpy(&m.char_rom, rom[0..0x1000]);
            break;
        }
    }

    // Boot state as creepload leaves it: object.prg in memory, jmp $0800.
    const object = fs.files.get("object") orelse return error.MissingObjectPrg;
    const entry = m.loadPrg(object);
    m.cpu.reset(entry);

    cwd.createDir(io, out_dir_path, .default_dir) catch {};
    var out_dir = try cwd.openDir(io, out_dir_path, .{});
    defer out_dir.close(io);

    const fb = try allocator.create([vic.WIDTH * vic.HEIGHT]u32);
    defer allocator.destroy(fb);

    var frame: u32 = 0;
    while (frame < frames) : (frame += 1) {
        // scripted input (the menu reads joystick 1, on CIA1 port B)
        var joy: u8 = 0x1F;
        if (fire_at != 0 and frame >= fire_at and frame < fire_at + 15) joy &= ~@as(u8, 0x10);
        for (presses[0..press_count]) |p| {
            if (frame >= p.frame and frame < p.frame + p.dur) joy &= ~p.mask;
        }
        m.joy1 = joy;
        if (!m.runFrame()) {
            std.debug.print(
                "CPU trap at frame {d}: opcode ${x:0>2} at ${x:0>4}\n",
                .{ frame, m.cpu.trap.?, m.cpu.trap_pc },
            );
            const pc = m.cpu.trap_pc;
            std.debug.print("context: ", .{});
            var a: u16 = pc -% 8;
            while (a != pc +% 8) : (a +%= 1) {
                std.debug.print("{s}{x:0>2}", .{ if (a == pc) ">" else " ", m.ram[a] });
            }
            std.debug.print("\nA={x:0>2} X={x:0>2} Y={x:0>2} SP={x:0>2}\n", .{ m.cpu.a, m.cpu.x, m.cpu.y, m.cpu.sp });
            break;
        }
        if (frame % dump_every == 0 or frame == frames - 1) {
            vic.renderFrame(m, fb);
            var name_buf: [64]u8 = undefined;
            const name = try std.fmt.bufPrint(&name_buf, "frame_{d:0>5}.ppm", .{frame});
            try writePpm(io, allocator, out_dir, name, fb);
        }
    }

    std.debug.print(
        "ran {d} frames, {d} cycles, pc=${x:0>4}, {d} SID writes\n",
        .{ frame, m.cpu.cycles, m.cpu.pc, m.sid_log.items.len },
    );
    std.debug.print(
        "vic: d011={x:0>2} d016={x:0>2} d018={x:0>2} d015={x:0>2} dd00={x:0>2} bank=${x:0>4} cpu_port={x:0>2}\n",
        .{ m.vic[0x11], m.vic[0x16], m.vic[0x18], m.vic[0x15], m.cia2_pra, m.vicBank(), m.cpu_port },
    );
}
