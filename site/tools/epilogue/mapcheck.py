#!/usr/bin/env python3
"""Proves the Epilogue's way to see a whole castle on the map: take the
`visited` test out of `chart.draw`'s room loop, and the first map of a
game sketches every room.

Copies the final checkpoint (site/code/ch11) to $WORK/mapcheck/ twice:
`plain/` as it is, and `whole/` with that one line changed. Each gets a
review-only test appended to main.zig that powers on, starts a game for
one with fire, waits for the map, and counts the rooms whose top-left
map cell has floor pixels in the bitmap. Plain: 1 of 20. Whole: 20 of
20. Then `whole/` runs headless to the first map and saves it as
$WORK/mapcheck/whole-map.ppm for a look. Author tooling only.
"""

import os, shutil, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.normpath(os.path.join(HERE, '..', '..'))
WORK = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/epilogue')

LINE = '        if (m.peek(castle.entry(m, n)) & castle.visited != 0) sketch(m, n);\n'
WHOLE = '        sketch(m, n);\n'

TEST = r'''
test "MAPCHECK rooms sketched on the first map" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // power-on: the disk, the title
    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This()); // a game for one
    m.input = .{};
    _ = m.runFrame(@This()); // the map
    try std.testing.expectEqual(@intFromEnum(Mode.map), m.ram[map.game_mode]);
    var drawn: usize = 0;
    const rooms = castle.roomCount(m);
    var n: u8 = 0;
    while (n < rooms) : (n += 1) {
        const e = m.view(castle.Entry, castle.entry(m, n));
        const col: u16 = (e.map_x - castle.left_edge) / 4;
        const row: u16 = e.map_y / 8;
        const cell = machine.hw.bitmap + row * 320 + col * 8;
        var any: u8 = 0;
        for (0..8) |i| any |= m.ram[cell + i];
        if (any != 0) drawn += 1;
    }
    std.debug.print("MAPCHECK {d} of {d}\n", .{ drawn, rooms });
}
'''


def project(name, whole):
    proj = os.path.join(WORK, 'mapcheck', name)
    if os.path.exists(proj):
        shutil.rmtree(proj)
    shutil.copytree(os.path.join(SITE, 'code', 'ch11'), proj,
                    ignore=shutil.ignore_patterns('.zig-cache', 'zig-out', 'web', 'frames'))
    link = os.path.join(WORK, 'mapcheck', 'machine')
    if not os.path.exists(link):
        os.symlink(os.path.join(SITE, 'code', 'machine'), link)
    if whole:
        p = os.path.join(proj, 'src', 'chart.zig')
        s = open(p).read()
        assert s.count(LINE) == 1
        open(p, 'w').write(s.replace(LINE, WHOLE))
    with open(os.path.join(proj, 'src', 'main.zig'), 'a') as f:
        f.write(TEST)
    r = subprocess.run(['zig', 'build', 'test', '--summary', 'none'], cwd=proj, capture_output=True, text=True)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    line = next(l for l in out.splitlines() if 'MAPCHECK' in l and 'of' in l)
    return proj, line.strip()


def main():
    os.makedirs(os.path.join(WORK, 'mapcheck'), exist_ok=True)
    _, plain = project('plain', False)
    proj, whole = project('whole', True)
    print('plain:', plain)
    print('whole:', whole)
    assert plain == 'MAPCHECK 1 of 20', plain
    assert whole == 'MAPCHECK 20 of 20', whole
    subprocess.run(['zig', 'build'], cwd=proj, check=True)
    out = os.path.join(WORK, 'mapcheck', 'frames')
    subprocess.run([os.path.join(proj, 'zig-out', 'bin', 'creep'), '--frames', '120', '--press', '60:f:3',
                    '--dump', out], cwd=proj, check=True, capture_output=True)
    shutil.copy(os.path.join(out, 'frame_00119.ppm'), os.path.join(WORK, 'mapcheck', 'whole-map.ppm'))
    print('ok   the first map sketches every room; picture in', os.path.join(WORK, 'mapcheck', 'whole-map.ppm'))


if __name__ == '__main__':
    main()
