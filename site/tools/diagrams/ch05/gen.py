# Generate the pixel-based Chapter 5 figures from the checkpoint's art.zig.
import re, sys
ART = open('/home/user/dr-creep-in-zig/site/code/ch05/src/art.zig').read()
OUT = '/home/user/dr-creep-in-zig/site/page/diagrams/'
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

def door_frames():
    """The door, five moments of its opening, each 20 x 32 fat pixels."""
    frame = art('door_frame'); shut = art('door_shut'); opn = art('door_open')
    SX, SY = 6, 3
    W, H = 20, 32
    arch = {}
    for r, row in enumerate(frame):
        for c, ch in enumerate(row):
            if ch != '.': arch[(c, r)] = (11, 12, 15)[int(ch) - 1]
    archg = ''.join(f'<rect style="fill:var(--c{cc})" x="{x*SX}" y="{y*SY}" width="{n*SX}" height="{SY}"/>' for x, y, n, cc in runs(arch, 0, 0, W, H))
    def draw(wiped_from, opened, first):
        px = {}
        p = opn if opened else shut
        cols = (GALLERY, GALLERY, 9) if opened else (9, 8, 7)
        for r, row in enumerate(p):
            for c, ch in enumerate(row):
                if ch != '.' and (opened or r < wiped_from): px[(4 + c, 8 + r)] = cols[int(ch) - 1]
        s = [f'<svg viewBox="0 0 {W*SX} {H*SY}" width="{W*SX}" shape-rendering="crispEdges" aria-hidden="true">', f'<rect class="ch05-c0" width="{W*SX}" height="{H*SY}"/>']
        s.append(f'<g id="ch05-arch">{archg}</g>' if first else '<use href="#ch05-arch"/>')
        for x, y, n, cc in runs(px, 0, 0, W, H):
            s.append(f'<rect class="ch05-c{cc}" x="{x*SX}" y="{y*SY}" width="{n*SX}" height="{SY}"/>')
        s.append('</svg>')
        return ''.join(s)
    return [draw(24, False, True), draw(23, False, False), draw(12, False, False), draw(1, False, False), draw(0, True, False)]

if __name__ == '__main__':
    a, b, c, hits = touching()
    tmpl = open(sys.argv[1]).read()
    open(OUT + 'ch05-touching.html', 'w').write(tmpl.replace('@@SCREEN@@', a).replace('@@CHIP@@', b).replace('@@BOXES@@', c).replace('@@HITS@@', str(hits)))
    d = door_frames()
    t2 = open(sys.argv[2]).read()
    for i, s in enumerate(d): t2 = t2.replace('@@D%d@@' % i, s)
    open(OUT + 'ch05-door.html', 'w').write(t2)
