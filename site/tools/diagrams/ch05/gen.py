# Generate the pixel-based Chapter 5 figures from the checkpoint's art.zig.
#
#   python3 site/tools/diagrams/ch05/gen.py            # both figures
#   python3 site/tools/diagrams/ch05/gen.py door       # just ch05-door.html
#   python3 site/tools/diagrams/ch05/gen.py touching   # just ch05-touching.html
import re, sys, pathlib
SITE = pathlib.Path(__file__).resolve().parents[3]
ART = (SITE / 'code/ch05/src/art.zig').read_text()
OUT = str(SITE / 'page/diagrams') + '/'
COL = dict(black=0, white=1, red=2, cyan=3, purple=4, green=5, blue=6, yellow=7, orange=8,
           brown=9, pink=10, dark_grey=11, grey=12, light_green=13, light_blue=14, light_grey=15)

def art(name):
    m = re.search(r'pub const %s = (?:room|frame)\((.*?), &\.\{\n(.*?)\n\}\);' % name, ART, re.S)
    rows = re.findall(r'"([.123]+)"', m.group(2))
    return rows

def mirror(rows): return [r[::-1] for r in rows]

# ---------------------------------------------------------------- the scene
# The Gatehouse around the bell, in castle coordinates: x in fat pixels, y in rows.
GATE = 2  # red: the Gatehouse's colour
GALLERY = 8  # orange: the Long Gallery's, beyond the door
def scene():
    """{(x, y): (code, colour)} for the bitmap."""
    px = {}
    def put(rows, x0, y0, colors):
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch != '.': px[(x0 + c, y0 + r)] = (int(ch), colors[int(ch) - 1])
    for k in range(40):  # the floor run at (16, 192); middle tiles only matter here
        put(art('walkway'), 16 + 4 * k, 192, (GATE, GATE, 15))
    put(art('door_frame'), 156, 160, (11, 12, 15))
    put(art('door_shut'), 160, 168, (9, 8, 7))
    put(art('bell'), 140, 168, (GALLERY, GALLERY, 15))
    return px

def sprite(rows, x0, y0):
    out = {}
    cols = {1: 10, 2: 1, 3: 8}  # pink skin, white coat, orange hat/belt/boots
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch != '.': out[(x0 + c, y0 + r)] = (int(ch), cols[int(ch)])
    return out

def runs(cells, x0, y0, w, h):
    """Merge horizontal runs of equal values: yields (x, y, length, value)."""
    for y in range(y0, y0 + h):
        x = x0
        while x < x0 + w:
            v = cells.get((x, y))
            if v is None: x += 1; continue
            s = x
            while x < x0 + w and cells.get((x, y)) == v: x += 1
            yield s, y, x - s, v

def touching():
    X0, Y0, W, H = 136, 164, 40, 30  # x 136..175, y 164..193
    SX, SY = 8, 4
    bm = scene()
    me = sprite(mirror(art('explorer_right_0')), 145, 171)  # explorer_left_0, his frame at the bell
    PX0, PY0, PW, PH, PSX, PSY = 138, 166, 20, 28, 16, 8  # the two pixel panels: closer in
    def PX(x): return (x - PX0) * PSX
    def PY(y): return (y - PY0) * PSY
    pw, ph = PW * PSX, PH * PSY
    def X(x): return (x - X0) * SX
    def Y(y): return (y - Y0) * SY
    w, h = W * SX, H * SY
    # 1. on screen, true colours
    a = [f'<svg viewBox="0 0 {pw} {ph}" width="{pw}" shape-rendering="crispEdges" role="img" aria-label="The Gatehouse around the bell, as the screen shows it">',
         f'<rect class="ch05-c0" width="{pw}" height="{ph}"/>']
    layer = {k: v[1] for k, v in bm.items()}
    layer.update({k: v[1] for k, v in me.items()})
    for x, y, n, c in runs(layer, PX0, PY0, PW, PH):
        a.append(f'<rect class="ch05-c{c}" x="{PX(x)}" y="{PY(y)}" width="{n*PSX}" height="{PSY}"/>')
    a.append('</svg>')
    # 2. what the chip compares
    hits = 0
    cls = {}
    for (x, y), (code, _) in bm.items():
        cls[(x, y)] = 'fg' if code >= 2 else 'bg'
    for k in me:
        if cls.get(k) == 'fg': cls[k] = 'hit'; hits += 1
    b = [f'<svg viewBox="0 0 {pw} {ph}" width="{pw}" shape-rendering="crispEdges" role="img" aria-label="The same pixels: foreground, sprite, and where they meet">']
    for x, y, n, c in runs(cls, PX0, PY0, PW, PH):
        b.append(f'<rect class="ch05-{c}" x="{PX(x)}" y="{PY(y)}" width="{n*PSX}" height="{PSY}"/>')
    for (x, y) in me:
        if PX0 <= x < PX0 + PW and PY0 <= y < PY0 + PH:
            if cls.get((x, y)) != 'hit': b.append(f'<rect class="ch05-spr" x="{PX(x)}" y="{PY(y)}" width="{PSX}" height="{PSY}"/>')
    b.append(f'<rect class="line" x=".5" y=".5" width="{pw-1}" height="{ph-1}"/>')
    b.append('</svg>')
    # 3. the boxes
    PAD = 30
    c = [f'<svg viewBox="0 0 {w} {h + PAD}" width="{w}" role="img" aria-label="The explorer\'s box overlaps the bell\'s box and stops short of the door\'s">']
    def box(bx, by, bw, bh, k):
        return f'<rect class="ch05-box ch05-{k}" x="{X(bx)}" y="{Y(by)}" width="{bw*SX}" height="{bh*SY}"/>'
    # overlap of his box and the bell's, edges inclusive
    ox0, ox1 = max(145, 140), min(145 + 8, 140 + 12)
    oy0, oy1 = max(171, 168), min(171 + 21, 168 + 19)
    c.append(f'<rect class="ch05-over" x="{X(ox0)}" y="{Y(oy0)}" width="{(ox1-ox0)*SX}" height="{(oy1-oy0)*SY}"/>')
    c.append(box(140, 168, 12, 19, 'bell'))
    c.append(box(160, 168, 12, 24, 'door'))
    c.append(box(145, 171, 8, 21, 'him'))
    c.append(f'<line class="line" x1="0" y1="{Y(192)}" x2="{w}" y2="{Y(192)}" stroke-dasharray="3 3"/>')
    c.append(f'<text x="{X(140)+3}" y="{Y(168)-4}" font-size="10">bell 140,168 12×19</text>')
    c.append(f'<text x="{X(160)+3}" y="{Y(168)-16}" font-size="10">door 160,168</text>')
    c.append(f'<text x="{X(160)+3}" y="{Y(168)-4}" font-size="10">12×24</text>')
    for i, t in enumerate(('him', '145,171', '8×21')):
        c.append(f'<text x="{X(145)+4}" y="{Y(171)+13+i*12}" font-size="10">{t}</text>')
    # the gap to the door
    gy = Y(178)
    c.append(f'<line class="line accent" x1="{X(153)}" y1="{gy}" x2="{X(160)}" y2="{gy}" marker-end="url(#ch05-ar)" marker-start="url(#ch05-ar)"/>')
    c.append(f'<text class="soft" x="{X(153)+1}" y="{gy-4}" font-size="9">gap</text>')
    # x ticks
    ty = h + PAD - 4
    for t in (140, 145, 152, 153, 160, 172):
        anchor = 'end' if t in (152,) else 'start' if t == 153 else 'middle'
        c.append(f'<line class="line" x1="{X(t)}" y1="{Y(192)}" x2="{X(t)}" y2="{ty-10}" stroke-dasharray="1 2"/>')
        c.append(f'<text class="soft" x="{X(t) + (-1 if anchor=="end" else 1 if anchor=="start" else 0)}" y="{ty}" font-size="10" text-anchor="{anchor}">{t}</text>')
    c.insert(1, '<defs><marker id="ch05-ar" viewBox="0 0 6 6" refX="3" refY="3" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0 L6 3 L0 6 z" class="ch05-arh"/></marker></defs>')
    c.append('</svg>')
    print('hits', hits, file=sys.stderr)
    return '\n'.join(a), '\n'.join(b), '\n'.join(c), hits

def door_anim():
    """The door opening, animated: the bell rings, then 24 engine steps wipe
    the panel a row a step from the bottom up, and the last draws it open in
    the colour of the room beyond. Returns {placeholder: html} for door.tmpl.html."""
    frame = art('door_frame'); shut = art('door_shut'); opn = art('door_open'); bell = art('bell')
    X0, Y0, W, H = 136, 160, 40, 39   # castle x 136..175, y 160..198: bell, door and floor
    SX, SY = 8, 4
    def X(x): return (x - X0) * SX
    def Y(y): return (y - Y0) * SY
    ROWS = len(shut)                  # 24: room.door_panel_height
    RING, STEP = 2.0, 0.34            # seconds: the ring, then one engine step (really 2 frames)
    TOTAL = RING + ROWS * STEP + 0.6
    def t_step(k): return RING + (k - 1) * STEP   # step k (1..24) wipes row 24 - k
    def P(t): return f'{t / TOTAL * 100:.3f}%'
    kf, rules = [], []
    def keyframes(name, frames, timing='step-end', sel=None):
        body = ' '.join(f'{P(t)} {{ {css} }}' for t, css in frames)
        kf.append(f'@keyframes {name} {{ {body} }}')
        rules.append(f'.ch05-dr .{sel or name} {{ animation: {name} {TOTAL:.2f}s {timing} forwards; }}')
    def visible(name, a, b=None):
        fr = [(0, 'opacity: 0'), (a, 'opacity: 1')] if a > 0 else [(0, 'opacity: 1')]
        if b is not None: fr.append((b, 'opacity: 0'))
        fr.append((TOTAL, f'opacity: {0 if b is not None else 1}'))
        keyframes(name, fr)

    def rects(rows, x0, y0, colors, cls=''):
        px = {}
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch != '.': px[(x0 + c, y0 + r)] = colors[int(ch) - 1]
        return ''.join(f'<rect class="ch05-dr-c{cc}{cls}" x="{X(x)}" y="{Y(y)}" width="{n*SX}" height="{SY}"/>'
                       for x, y, n, cc in runs(px, X0, Y0, W, H))
    w, h = W * SX, H * SY
    s = [f'<svg class="ch05-dr-scene" viewBox="0 0 {w} {h}" width="{w}" shape-rendering="crispEdges" role="img" '
         'aria-label="The Gatehouse door beside its bell. The bell swings; the door panel is wiped away a row at a time from the bottom, and the open doorway is drawn in the Long Gallery\'s orange.">',
         f'<rect class="ch05-dr-c0" width="{w}" height="{h}"/>']
    for k in range(10):
        s.append(rects(art('walkway'), 136 + 4 * k, 192, (GATE, GATE, 15)))
    s.append(rects(frame, 156, 160, (11, 12, 15)))
    # the bell on its bracket: row 0 stays put, the rest swings from the rope
    s.append(rects(bell[:1], 140, 168, (GALLERY, GALLERY, 15)))
    s.append(f'<g class="ch05-dr-bell" style="transform-origin: {X(146)}px {Y(169)}px">'
             + rects([('.' * 12)] + bell[1:], 140, 168, (GALLERY, GALLERY, 15)) + '</g>')
    s.append(f'<text class="ch05-dr-ding" x="{X(141)}" y="{Y(166)}" font-size="15" font-weight="700" text-anchor="middle">ding!</text>')
    # the shut panel, one group per row
    for r in range(ROWS):
        k = ROWS - r
        name = f'ch05-dr-r{r}'
        keyframes(name, [(0, 'opacity: 1'), (t_step(k), 'opacity: 0'), (TOTAL, 'opacity: 0')])
        s.append(f'<g class="{name}">' + rects([('.' * 12)] * r + [shut[r]], 160, 168, (9, 8, 7)) + '</g>')
    visible('ch05-dr-open', t_step(ROWS))
    s.append('<g class="ch05-dr-open">' + rects(opn, 160, 168, (GALLERY, GALLERY, 9)) + '</g>')
    # the row this step wipes
    fr = [(0, f'opacity: 0; transform: translateY({Y(168 + ROWS - 1)}px)')]
    for k in range(1, ROWS + 1):
        fr.append((t_step(k), f'opacity: 1; transform: translateY({Y(168 + ROWS - k)}px)'))
    fr.append((t_step(ROWS) + STEP, f'opacity: 0; transform: translateY({Y(168)}px)'))
    fr.append((TOTAL, f'opacity: 0; transform: translateY({Y(168)}px)'))
    keyframes('ch05-dr-mark', fr)
    s.append(f'<g class="ch05-dr-mark"><rect class="ch05-dr-halo" x="{X(160) - 3}" y="-1" width="{12 * SX + 6}" height="{SY + 2}"/>'
             f'<rect x="{X(160) - 3}" y="-1" width="{12 * SX + 6}" height="{SY + 2}"/></g>')
    s.append('</svg>')

    # the state, one card per moment
    states = [('the bell rings', '1', '0', '–', 'none', "ring() sets the door's execute flag and stops there. Nothing is drawn yet.")]
    for k in range(1, ROWS + 1):
        row = ROWS - k
        if k == 1:
            note = 'Open bit set in the castle, on this door and the far one. Then the first row: the bottom.'
        elif k < ROWS:
            note = 'Each step wipes one row back to the background, bottom up.'
        else:
            note = 'Row 0 wiped, execute cleared, and the door drawn open in the next room\'s colour: the Long Gallery\'s orange.'
        states.append((f'step {k} of {ROWS}', '1' if k < ROWS else '0', '1',
                       f'{row} → {row - 1}' if k < ROWS else '0', f'row {row}', note))
    cards = []
    for i, (title, ex, op, st, wiped, note) in enumerate(states):
        a = 0 if i == 0 else t_step(i)
        b = t_step(i + 1) if i < ROWS else None
        visible(f'ch05-dr-s{i}', a, b)
        on = lambda v: f' class="ch05-dr-on"' if v == '1' else ''
        cards.append(f'<div class="ch05-dr-s{i}"><b class="ch05-dr-t">{title}</b><dl>'
                     f'<dt>execute</dt><dd{on(ex)}>{ex}</dd><dt>open</dt><dd{on(op)}>{op}</dd>'
                     f'<dt>o.step</dt><dd>{st}</dd><dt>wiped</dt><dd>{wiped}</dd></dl><p>{note}</p></div>')
    # bell swing and ding
    swing = [(0, 10), (0.25, -9), (0.5, 8), (0.75, -6), (1.0, 6), (1.25, -4), (1.5, 2), (1.75, 0)]
    keyframes('ch05-dr-swing', [(t, f'transform: rotate({d}deg); animation-timing-function: ease-in-out') for t, d in swing] + [(TOTAL, 'transform: rotate(0deg)')], sel='ch05-dr-bell')
    visible('ch05-dr-ding', 0, RING)
    # progress: ring + 24 steps
    fr = [(0, f'width: {100 / (ROWS + 1):.3f}%')] + [(t_step(k), f'width: {(k + 1) * 100 / (ROWS + 1):.3f}%') for k in range(1, ROWS + 1)] + [(TOTAL, 'width: 100%')]
    keyframes('ch05-dr-fill', fr)
    ticks = ''.join(f'<i style="left:{k * 100 / (ROWS + 1):.3f}%"></i>' for k in range(1, ROWS + 1))
    labels = (f'<span style="left:0">ring</span>'
              f'<span style="left:{12 * 100 / (ROWS + 1):.3f}%">step 12</span>'
              f'<span style="right:0">step 24</span>')
    cols = sorted({0, 7, 8, 9, 11, 12, 15, GATE, GALLERY})
    palette = ' '.join(f'.ch05-dr .ch05-dr-c{c} {{ fill: var(--c{c}); }}' for c in cols)
    return {
        '@@STYLE@@': palette + '\n' + '\n'.join(kf) + '\n' + '\n'.join(rules),
        '@@SCENE@@': '\n'.join(s),
        '@@CARDS@@': '\n    '.join(cards),
        '@@TICKS@@': ticks, '@@LABELS@@': labels,
    }

if __name__ == '__main__':
    import pathlib
    HERE = pathlib.Path(__file__).resolve().parent
    want = set(sys.argv[1:]) or {'touching', 'door'}  # e.g. `gen.py door`
    if 'touching' in want:
        a, b, c, hits = touching()
        tmpl = (HERE / 'touching.tmpl.html').read_text()
        open(OUT + 'ch05-touching.html', 'w').write(tmpl.replace('@@SCREEN@@', a).replace('@@CHIP@@', b).replace('@@BOXES@@', c).replace('@@HITS@@', str(hits)))
    if 'door' in want:
        t2 = (HERE / 'door.tmpl.html').read_text()
        for k, v in door_anim().items(): t2 = t2.replace(k, v)
        open(OUT + 'ch05-door.html', 'w').write(t2)
