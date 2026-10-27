#!/usr/bin/env python3
"""Proves the compile errors the Epilogue's "A new kind of thing" exercise
quotes, in the order it quotes them.

Copies the final checkpoint (site/code/ch11) to $WORK/kind/, then adds a
made-up castle kind, `spider`, one table at a time, building after each
step and checking the first error is the one the Epilogue names. The
last step builds clean, and `zig build test` fails on the one test that
knows 1984's tag codes. Author tooling only; the spider is not part of
any checkpoint.
"""

import os, shutil, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.normpath(os.path.join(HERE, '..', '..'))
WORK = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/epilogue')


def edit(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old)
    open(path, 'w').write(s.replace(old, new))


STEPS = [
    ('castle.Kind gets spider',
     lambda p: edit(p + '/src/castle.zig', '    text,\n    image,\n};', '    text,\n    image,\n    spider,\n};'),
     ['src/castle.zig', 'error: switch must handle all possibilities', "note: unhandled enumeration value: 'spider'"]),
    ('its record and framing',
     lambda p: (edit(p + '/src/castle.zig', '/// A ray gun, on a track',
                     '/// A spider on its thread.\npub const Spider = extern struct { x: u8, y: u8, thread: u8 };\n\n/// A ray gun, on a track'),
                edit(p + '/src/castle.zig', '        .image => .image,\n',
                     '        .image => .image,\n        .spider => .{ .marked = .{ .size = @sizeOf(Spider), .end = 0 } },\n')),
     ['src/author.zig', "error: no field named 'spider' in struct 'author.Room(training.Room)'"]),
    ('the kit\'s room list',
     lambda p: edit(p + '/src/author.zig', '        image: []const Image = &.{},\n',
                    '        image: []const Image = &.{},\n        spider: []const castle.Spider = &.{},\n'),
     ['src/room.zig', 'error: missing struct field: spider']),
    ('a prepare function',
     lambda p: edit(p + '/src/room.zig', '    .image = image,\n});',
                    '    .image = image,\n    .spider = spider,\n});\n\nfn spider(m: *Machine, r: castle.Record) void {\n    _ = m;\n    _ = r;\n}'),
     None),
    ('an actor kind',
     lambda p: edit(p + '/src/actors.zig', 'laser, frankenstein, _ };', 'laser, frankenstein, spider, _ };'),
     ['src/actors.zig', 'error: missing struct field: spider']),
    ('its behaviour',
     lambda p: edit(p + '/src/actors.zig',
                    '    .frankenstein = .{ .turn = frankenstein.turn, .flickers = true, .hit = frankenstein.hit, .touch = frankenstein.touch, .group = 0 },\n});',
                    '    .frankenstein = .{ .turn = frankenstein.turn, .flickers = true, .hit = frankenstein.hit, .touch = frankenstein.touch, .group = 0 },\n'
                    '    .spider = .{ .turn = dangle, .flickers = true, .group = 0b010 },\n});\n\nfn dangle(m: *Machine, n: u3) void {\n    _ = m;\n    _ = n;\n}'),
     None),
    ('an object kind',
     lambda p: edit(p + '/src/objects.zig', 'ankh, alcove, _ };', 'ankh, alcove, web, _ };'),
     ['src/objects.zig', 'error: missing struct field: web']),
    ('its handlers',
     lambda p: edit(p + '/src/objects.zig', "    .alcove = .{ .execute = null, .in_front = null }, // it's only there to be shot at\n});",
                    "    .alcove = .{ .execute = null, .in_front = null }, // it's only there to be shot at\n    .web = .{ .execute = null, .in_front = null },\n});"),
     None),
    ('a shape id',
     lambda p: edit(p + '/src/shapes.zig', '    explorer_cheer_1,\n', '    explorer_cheer_1,\n    spider,\n'),
     ['src/shapes.zig', "error: root source file struct 'art' has no member named 'spider'"]),
    ('(shape id taken back out)',
     lambda p: edit(p + '/src/shapes.zig', '    explorer_cheer_1,\n    spider,\n', '    explorer_cheer_1,\n'),
     None),
]


def main():
    root = os.path.join(WORK, 'kind')
    if os.path.exists(root):
        shutil.rmtree(root)
    os.makedirs(root)
    proj = os.path.join(root, 'ch11')
    shutil.copytree(os.path.join(SITE, 'code', 'ch11'), proj,
                    ignore=shutil.ignore_patterns('.zig-cache', 'zig-out', 'web', 'frames'))
    os.symlink(os.path.join(SITE, 'code', 'machine'), os.path.join(root, 'machine'))
    for name, apply, expect in STEPS:
        apply(proj)
        r = subprocess.run(['zig', 'build'], cwd=proj, capture_output=True, text=True)
        out = r.stdout + r.stderr
        if expect is None:
            assert r.returncode == 0, (name, out[:2000])
            print('ok   %-28s builds' % name)
            continue
        assert r.returncode != 0, name
        first = next(l for l in out.splitlines() if 'error:' in l)
        for e in expect:
            assert e in out, (name, e, out[:2000])
        assert expect[0] in first and expect[1] in first, (name, first)
        print('ok   %-28s %s' % (name, first.strip()))
    r = subprocess.run(['zig', 'build', 'test'], cwd=proj, capture_output=True, text=True)
    out = r.stdout + r.stderr
    assert r.returncode != 0
    want = "error: 'castle.test.tag codes turn into kinds and back' failed:"
    assert want in out and 'expected null, found .spider' in out, out[:3000]
    fails = [l for l in out.splitlines() if "' failed:" in l]
    assert len(fails) == 1, fails
    print('ok   zig build test              %s / expected null, found .spider' % want)


if __name__ == '__main__':
    main()
