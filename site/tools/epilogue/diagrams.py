#!/usr/bin/env python3
"""The Epilogue's two figures, drawn from measure.py's measured.json:

  ep-memory.html  the final game's 64 KB, one square per 256-byte page,
                  from map.zig's `regions` (and how full each built-in
                  table and the castle buffers are)
  ep-frame.html   the busiest in-play frame of each Training Castle room,
                  by meter bucket, on one tour of the castle

Also prints the totals the prose quotes. Author tooling only.
"""

import html, json, os

WORK = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/epilogue')
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'page', 'diagrams'))
d = json.load(open(os.path.join(WORK, 'measured.json')))

# ---- memory -----------------------------------------------------------------

HARDWARE = {'sprite frames', 'screen plane', 'sprite pointers', 'VIDEO chip', 'SOUND chip', 'colour RAM',
            'input ports', 'disk drive', 'bitmap'}
CASTLE = {'castle', 'staging', 'best times', 'castle list'}
TABLES = {'music', 'star map', 'shape table', 'sound effects', 'row table'}
RESERVED = {'stack (reserved)', 'program image'}
EXPANSION = [(0xD02F, 0xD3FF), (0xD419, 0xD7FF), (0xDBE8, 0xDBFF), (0xDC03, 0xDCFF), (0xDD30, 0xDFFF)]

# Each class: (label, CSS colour). "Empty" is a region's room to spare.
CLASSES = {
    'state': ('the game\'s working memory', 'var(--c-green)'),
    'castle': ('the castle and its files', 'var(--c-cyan)'),
    'castle_empty': ('castle room to spare', 'color-mix(in srgb, var(--c-cyan) 30%, var(--sheet))'),
    'tables': ('built-in tables', 'var(--c-orange)'),
    'tables_empty': ('table room to spare', 'color-mix(in srgb, var(--c-orange) 30%, var(--sheet))'),
    'hardware': ('the hardware\'s', 'var(--accent)'),
    'reserved': ('stack, program, expansion', 'color-mix(in srgb, var(--ink-soft) 55%, var(--sheet))'),
    'free': ('nobody\'s', 'var(--code-bg)'),
}
ORDER = list(CLASSES)

byte_class = ['free'] * 0x10000
byte_owner = [None] * 0x10000
for r in d['regions']:
    name, first, last = r['name'], r['first'], r['last']
    cls = ('hardware' if name in HARDWARE else 'castle' if name in CASTLE else 'tables' if name in TABLES
           else 'reserved' if name in RESERVED else 'state')
    fill = r.get('fill')
    for a in range(first, last + 1):
        byte_owner[a] = name
        if fill is not None and a - first >= fill:
            byte_class[a] = cls + '_empty'
        else:
            byte_class[a] = cls
for lo, hi in EXPANSION:
    for a in range(lo, hi + 1):
        byte_class[a] = 'reserved'
        byte_owner[a] = 'reserved for expansion hardware'

totals = {c: byte_class.count(c) for c in ORDER}
assert sum(totals.values()) == 0x10000

out = ['<style>',
       '.ep-mm { display: grid; gap: 12px; }',
       '.ep-mm .grid { display: grid; grid-template-columns: 3.6em repeat(16, minmax(0, 1fr)); gap: 2px; max-width: 520px; font-size: .62rem; }',
       '.ep-mm .grid i { display: block; aspect-ratio: 1; border-radius: 2px; box-shadow: inset 0 0 0 1px var(--rule); }',
       '.ep-mm .grid b { font-weight: 400; color: var(--ink-soft); text-align: right; padding-right: 4px; align-self: center; }',
       '.ep-mm .grid u { text-decoration: none; color: var(--ink-soft); text-align: center; }',
       '.ep-mm .key { display: grid; grid-template-columns: auto 1fr auto auto; gap: 3px 10px; font-size: .74rem; align-items: center; max-width: 520px; }',
       '.ep-mm .key i { display: inline-block; width: 1em; height: 1em; border-radius: 2px; box-shadow: inset 0 0 0 1px var(--rule); }',
       '.ep-mm .key .n { text-align: right; font-variant-numeric: tabular-nums; }',
       '.ep-mm .key .p { text-align: right; color: var(--ink-soft); font-variant-numeric: tabular-nums; }',
       '.ep-mm .names { font-size: .7rem; color: var(--ink-soft); max-width: 62ch; }']
for c in ORDER:
    out.append('.ep-mm .%s { background: %s; }' % (c.replace('_', '-'), CLASSES[c][1]))
out.append('</style>')
out.append('<div class="ep-mm" role="img" aria-label="The final game\'s 65,536 bytes as 256 squares of 256 bytes each, coloured by who owns them">')
out.append('<div class="grid">')
out.append('<span></span>' + ''.join('<u>%X</u>' % c for c in range(16)))


def css(c):
    return CLASSES[c][1]


for row in range(16):
    out.append('<b>$%X000</b>' % row)
    for col in range(16):
        page = row * 16 + col
        a0 = page * 256
        counts = {}
        for a in range(a0, a0 + 256):
            counts[byte_class[a]] = counts.get(byte_class[a], 0) + 1
        owners = []
        for a in range(a0, a0 + 256):
            o = byte_owner[a] or 'free'
            if not owners or owners[-1] != o:
                owners.append(o)
        tip = '$%04X–$%04X: %s' % (a0, a0 + 255, ', '.join(dict.fromkeys(owners)))
        if len(counts) == 1:
            out.append('<i class="%s" title="%s"></i>' % (next(iter(counts)).replace('_', '-'), html.escape(tip)))
        else:
            # Bottom up, in the key's order: a page's share of each class.
            stops, at = [], 0.0
            for c in ORDER:
                if c in counts:
                    nxt = at + counts[c] / 256 * 100
                    stops.append('%s %.1f%% %.1f%%' % (css(c), at, nxt))
                    at = nxt
            out.append('<i style="background: linear-gradient(to top, %s)" title="%s"></i>' % (', '.join(stops), html.escape(tip)))
out.append('</div>')
out.append('<div class="key">')
for c in ORDER:
    out.append('<i class="%s"></i><span>%s</span><span class="n">%s</span><span class="p">%.1f%%</span>'
               % (c.replace('_', '-'), CLASSES[c][0], '{:,}'.format(totals[c]), totals[c] / 655.36))
out.append('</div>')
out.append('<p class="names">Rows are $1000 apart and columns $100. A square shared by two owners is split, bottom up, in the order of the key. Generated from <code>map.zig</code>.</p>')
out.append('</div>')
open(os.path.join(OUT, 'ep-memory.html'), 'w').write('\n'.join(out) + '\n')

# ---- the frame ---------------------------------------------------------------

ROOMS = ['The Gatehouse', 'The Long Gallery', 'Ladders', 'Sliding Poles', 'Lightning', 'Forcefields', 'Trapdoors',
         'Conveyors', 'The Transmitter', 'Keys and Locks', 'Ray Guns', 'The Mummy', 'Frankenstein',
         'A Trap for Frank', "Frank's Ride", 'Under Fire', 'Mummy in a Storm', 'Locked Away', "Two's Company",
         'The Way Out']
BUCKETS = [(0, 'glue and input', 'var(--rule)'), (2, 'sprites', 'var(--ink-soft)'), (3, 'actors', 'var(--accent)'),
           (4, 'objects', 'var(--c-orange)'), (5, 'sound', 'var(--c-green)')]
SCALE = 6000
rooms = [r for r in d['rooms'] if r['room'] < len(ROOMS)]
assert [r['room'] for r in rooms] == list(range(len(ROOMS))), [r['room'] for r in rooms]
out = ['<style>',
       '.ep-fr { display: grid; gap: 4px; font-size: .72rem; max-width: 640px; }',
       '.ep-fr .row { display: grid; grid-template-columns: 9.5em 1fr 3.6em; gap: 8px; align-items: center; }',
       '.ep-fr .name { text-align: right; color: var(--ink-soft); line-height: 1.15; }',
       '.ep-fr .bar { position: relative; display: flex; height: 12px; background: var(--code-bg); border-radius: 2px; box-shadow: inset 0 0 0 1px var(--rule); }',
       '.ep-fr .bar i { display: block; height: 100%; }',
       '.ep-fr .bar s { position: absolute; top: -2px; bottom: -2px; width: 2px; background: var(--c-red); text-decoration: none; }',
       '.ep-fr .n { font-variant-numeric: tabular-nums; text-align: right; }',
       '.ep-fr .axis { display: grid; grid-template-columns: 9.5em 1fr 3.6em; gap: 8px; color: var(--ink-soft); }',
       '.ep-fr .ticks { display: flex; justify-content: space-between; font-size: .64rem; }',
       '.ep-fr .key { display: flex; flex-wrap: wrap; gap: 4px 14px; margin-top: 8px; color: var(--ink-soft); }',
       '.ep-fr .key i { display: inline-block; width: .9em; height: .9em; border-radius: 2px; vertical-align: -1px; margin-right: 5px; }',
       '.ep-fr .key s { display: inline-block; width: 2px; height: 1em; background: var(--c-red); vertical-align: -2px; margin-right: 5px; }',
       '</style>',
       '<div class="ep-fr" role="img" aria-label="For each of the Training Castle\'s twenty rooms, its busiest frame in play, split by meter bucket, on a scale to 6,000 cycles">']
for r in rooms:
    w = r['worst']
    segs = ''.join('<i style="width: %.2f%%; background: %s" title="%s %s"></i>'
                   % (w['buckets'][b] / SCALE * 100, col, label, '{:,}'.format(w['buckets'][b]))
                   for b, label, col in BUCKETS if w['buckets'][b])
    avg = '<s style="left: %.2f%%" title="average %s"></s>' % (r['avg'] / SCALE * 100, '{:,}'.format(r['avg']))
    out.append('<div class="row"><span class="name">%s</span><span class="bar">%s%s</span><span class="n">%s</span></div>'
               % (html.escape(ROOMS[r['room']]), segs, avg, '{:,}'.format(w['cycles'])))
out.append('<div class="axis"><span></span><span class="ticks">%s</span><span></span></div>'
           % ''.join('<span>%s</span>' % '{:,}'.format(t) for t in range(0, SCALE + 1, 2000)))
out.append('<div class="key">%s<span><s></s>average frame</span><span>the whole budget, 19,656, is 3.3 times this scale</span></div>'
           % ''.join('<span><i style="background: %s"></i>%s</span>' % (col, label) for _, label, col in BUCKETS))
out.append('</div>')
open(os.path.join(OUT, 'ep-frame.html'), 'w').write('\n'.join(out) + '\n')

# ---- numbers for the prose ------------------------------------------------------
print('memory:', {c: totals[c] for c in ORDER})
free_runs, a = [], 0
while a < 0x10000:
    if byte_class[a] == 'free':
        b = a
        while b + 1 < 0x10000 and byte_class[b + 1] == 'free':
            b += 1
        free_runs.append((a, b, b - a + 1))
        a = b + 1
    else:
        a += 1
print('free runs:', ['$%04X-$%04X %d' % r for r in free_runs])
for r in d['regions']:
    if 'fill' in r:
        size = r['last'] - r['first'] + 1
        print('fill: %s %d of %d (%d spare)' % (r['name'], r['fill'], size, size - r['fill']))
worst = max(rooms, key=lambda r: r['worst']['cycles'])
print('busiest room frame:', ROOMS[worst['room']], worst['worst'])
print('room averages:', min(r['avg'] for r in rooms), '-', max(r['avg'] for r in rooms))
for key in ('rooms_q', 'rooms_c'):
    rs = [r for r in d[key] if r['room'] < len(ROOMS)]
    print(key, 'avg of avgs', sum(r['avg'] for r in rs) // len(rs), 'vs', sum(r['avg'] for r in rooms) // len(rooms),
          'max', max(r['worst']['cycles'] for r in rs))
fr, modes = d['boss']['frames'], d['boss']['modes']
ok = [f for f in fr if f[-1] == 'ok']
load = [f for f in fr if f[-1] == 'loading']
room_frames = [f for f in ok if modes[f[1]] == 'room']
top = max(room_frames, key=lambda f: f[2])
print('boss: calls', len(fr), 'ok', len(ok), 'loading', len(load), 'overrun', sum(f[-1] == 'overrun' for f in fr))
print('boss: loading slots', sum(-(-f[2] // 19656) for f in load), 'of', 3800)
print('boss: busiest room frame', top, 'avg room frame', sum(f[2] for f in room_frames) // len(room_frames))
print('boss: busiest in-play frame', max(ok, key=lambda f: f[2]), modes[max(ok, key=lambda f: f[2])[1]])
print('boss: biggest loading frames', [(f[0], modes[f[1]], f[2]) for f in sorted(load, key=lambda f: -f[2])[:3]])
