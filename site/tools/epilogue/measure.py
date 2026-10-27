#!/usr/bin/env python3
"""Measurements for the Epilogue's resource retrospective.

Copies the final checkpoint (site/code/ch11) to the scratch folder, adds a
probe program beside its sources (`src/probe.zig`, which imports the
game's own map, tables and `main.zig`), and runs it natively with
`zig run`. The probe prints JSON:

  regions  every region in map.zig's `regions`, in address order, plus
           how many bytes of each the game's built-in tables fill
  rooms    one tour of the Training Castle, room by room: N every
           ROOM_FRAMES frames, the explorer left standing in the
           doorway while the room's machines and monsters run; for each
           room, the worst in-play frame (display on, within budget) by
           bucket, and its average
  boss     Chapter 11's Boss Battle input script, frame by frame:
           in-play frames, loading pauses, the worst in-play frames

Writes the JSON to $WORK/measured.json (WORK defaults to the scratch
folder's epilogue/). diagrams.py draws the Epilogue's figures from it.
Author tooling only.
"""

import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.normpath(os.path.join(HERE, '..', '..'))
WORK = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/epilogue')
ROOM_FRAMES = 300

sys.path.insert(0, os.path.join(SITE, 'tools', 'ch11'))
import runs  # noqa: E402  (Chapter 11's stage scripts)

JOY = dict(u=1, d=2, l=4, r=8, f=16)


def script(args):
    """Chapter 11's headless arguments as (frames, presses, keys)."""
    frames, presses, keys, i = 250, [], [], 0
    while i < len(args):
        a = args[i]
        if a == '--frames':
            frames = int(args[i + 1]); i += 2; continue
        if a == '--press':
            spec, port = args[i + 1], 1
            if '@' in spec:
                spec, p = spec.split('@'); port = int(p)
            parts = spec.split(':')
            mask = sum(JOY[c] for c in parts[1])
            dur = int(parts[2]) if len(parts) > 2 else 10
            presses.append((int(parts[0]), mask, dur, port)); i += 2; continue
        if a == '--key':
            f, what = args[i + 1].split(':', 1)
            k = int(what[1:]) if what.startswith('#') and len(what) > 1 else ord(what.upper())
            keys.append((int(f), k)); i += 2; continue
        i += 1 if not a.startswith('--') or a in () else 2
    return frames, presses, keys


def zig_script(name, frames, presses, keys):
    p = ', '.join('.{ %d, %d, %d, %d }' % x for x in presses)
    k = ', '.join('.{ %d, %d }' % x for x in keys)
    return ('const %s = Script{ .frames = %d, .presses = &.{ %s }, .keys = &.{ %s } };\n'
            % (name, frames, p, k))


PROBE = r'''
const std = @import("std");
const machine = @import("machine");
const hw = machine.hw;
const map = @import("map.zig");
const game = @import("main.zig");
const shapes = @import("shapes.zig");
const tunes = @import("tunes.zig");
const training = @import("training.zig");
const title = @import("title.zig");

const Script = struct {
    frames: u32,
    presses: []const [4]u32,
    keys: []const [2]u32,
    fn input(s: Script, f: u32) machine.Input {
        var in: machine.Input = .{};
        for (s.presses) |p| {
            if (f < p[0] or f - p[0] >= p[2]) continue;
            if (p[3] == 2) in.joy2 |= @intCast(p[1]) else in.joy1 |= @intCast(p[1]);
        }
        for (s.keys) |k| if (k[0] == f) {
            in.key = @intCast(k[1]);
        };
        return in;
    }
};
SCRIPTS

fn fill(name: []const u8) ?usize {
    const eq = std.mem.eql;
    if (eq(u8, name, "castle") or eq(u8, name, "staging")) return training.bytes.len;
    if (eq(u8, name, "shape table")) return shapes.table.len;
    if (eq(u8, name, "music")) return tunes.music.len;
    if (eq(u8, name, "sound effects")) return tunes.effects.len;
    if (eq(u8, name, "star map")) return title.star_map.len;
    return null;
}

fn report(w: *std.Io.Writer, r: machine.Report) !void {
    try w.print("{{\"cycles\": {d}, \"buckets\": [", .{r.cycles});
    for (r.buckets[0..6], 0..) |b, i| try w.print("{s}{d}", .{ if (i == 0) "" else ", ", b });
    try w.print("], \"kind\": \"{t}\", \"slots\": {d}}}", .{ r.kind, r.slots });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var buf: [4096]u8 = undefined;
    var fw = std.Io.File.stdout().writer(io, &buf);
    const w = &fw.interface;

    try w.print("{{\"regions\": [", .{});
    for (map.regions, 0..) |r, i| {
        try w.print("{s}{{\"name\": \"{s}\", \"first\": {d}, \"last\": {d}", .{ if (i == 0) "" else ", ", r.name, r.first, r.last });
        if (fill(r.name)) |n| try w.print(", \"fill\": {d}", .{n});
        try w.print("}}", .{});
    }
    try w.print("],\n", .{});

    const m = try init.gpa.create(machine.Machine);
    defer init.gpa.destroy(m);

    // ---- the room tours: plain, then with Q (search) and C (scan) on ----
    inline for (.{ tour, tour_q, tour_c }, .{ "rooms", "rooms_q", "rooms_c" }) |t_, label| {
    const tour_ = t_;
    m.boot(game);
    try w.print("\"" ++ label ++ "\": [", .{});
    {
        var f: u32 = 0;
        var room: u8 = 0xFF;
        var worst: machine.Report = .{};
        var total: u64 = 0;
        var calls: u32 = 0;
        var started = false;
        var first = true;
        while (f < tour_.frames) {
            m.input = tour_.input(f);
            const slots = m.runFrame(game);
            const in_room = m.ram[map.game_mode] == @intFromEnum(game.Mode.room);
            if (in_room and m.last.kind == .ok) {
                const n = m.ram[map.room_number];
                if (n != room) {
                    if (started) {
                        try w.print("{s}{{\"room\": {d}, \"avg\": {d}, \"calls\": {d}, \"worst\": ", .{ if (first) "" else ", ", room, total / @max(1, calls), calls });
                        try report(w, worst);
                        try w.print("}}", .{});
                        first = false;
                    }
                    started = true;
                    room = n;
                    worst = .{};
                    total = 0;
                    calls = 0;
                }
                total += m.last.cycles;
                calls += 1;
                if (m.last.cycles > worst.cycles) worst = m.last;
            }
            f += slots;
        }
        if (started) {
            try w.print("{s}{{\"room\": {d}, \"avg\": {d}, \"calls\": {d}, \"worst\": ", .{ if (first) "" else ", ", room, total / @max(1, calls), calls });
            try report(w, worst);
            try w.print("}}", .{});
        }
    }
    try w.print("],\n", .{});
    }

    // ---- the Boss Battle, frame by frame ----
    m.boot(game);
    try w.print("\"boss\": {{\"frames\": [", .{});
    {
        var f: u32 = 0;
        var first = true;
        while (f < boss.frames) {
            m.input = boss.input(f);
            const slots = m.runFrame(game);
            try w.print("{s}[{d}, {d}, {d}", .{ if (first) "" else ",\n", f, m.ram[map.game_mode], m.last.cycles });
            for (m.last.buckets[0..6]) |b| try w.print(", {d}", .{b});
            try w.print(", \"{t}\"]", .{m.last.kind});
            first = false;
            f += slots;
        }
    }
    try w.print("], \"modes\": [", .{});
    inline for (@typeInfo(game.Mode).@"enum".fields, 0..) |fld, i| try w.print("{s}\"{s}\"", .{ if (i == 0) "" else ", ", fld.name });
    try w.print("]}}}}\n", .{});
    try w.flush();
}
'''


def tour(switch=None):
    """Power on, start a game for one, then N to the next room every
    ROOM_FRAMES frames. `switch` (Q or C) is pressed in the first room
    and stays on for the whole tour."""
    presses = [(60, 16, 3, 1), (75, 16, 3, 1)]
    # The game is in the Gatehouse from about frame 90; the first N comes
    # 300 frames on, so every room gets its 300 frames, the first too.
    keys = [(400 + ROOM_FRAMES * i, ord('N')) for i in range(20)]
    if switch:
        keys.append((150, ord(switch)))  # in the Gatehouse, after it's drawn
    return 400 + ROOM_FRAMES * 20 + 50, presses, keys


def main():
    proj = os.path.join(WORK, 'ch11')
    if os.path.exists(proj):
        shutil.rmtree(proj)
    shutil.copytree(os.path.join(SITE, 'code', 'ch11'), proj,
                    ignore=shutil.ignore_patterns('.zig-cache', 'zig-out', 'web', 'frames'))
    src = PROBE.replace('SCRIPTS', zig_script('tour', *tour()) + zig_script('tour_q', *tour('Q')) + zig_script('tour_c', *tour('C')) + zig_script('boss', *script(runs.BOSS)))
    with open(os.path.join(proj, 'src', 'probe.zig'), 'w') as f:
        f.write(src)
    # main.zig's Mode must be pub for the probe; it's a copy, so we may.
    mp = os.path.join(proj, 'src', 'main.zig')
    s = open(mp).read()
    if 'pub const Mode' not in s:
        s = s.replace('const Mode = enum', 'pub const Mode = enum', 1)
        open(mp, 'w').write(s)
    machine = os.path.join(SITE, 'code', 'machine', 'src', 'machine.zig')
    out = subprocess.run(['zig', 'run', '-OReleaseSafe', '--dep', 'machine', '-Mroot=' + os.path.join(proj, 'src', 'probe.zig'),
                          '-Mmachine=' + machine], cwd=proj, check=True, capture_output=True, text=True).stdout
    data = json.loads(out)
    with open(os.path.join(WORK, 'measured.json'), 'w') as f:
        json.dump(data, f)
    print('regions', len(data['regions']), 'rooms', len(data['rooms']), len(data['rooms_q']), len(data['rooms_c']), 'boss frames', len(data['boss']['frames']))


if __name__ == '__main__':
    main()
