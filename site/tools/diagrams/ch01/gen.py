# Generates site/page/diagrams/ch01-*.html (static output, hand-tuned layout).
import re
D = "/home/user/dr-creep-in-zig/site/page/diagrams/"

# ---------- A: memory map strip ----------
def memmap():
    top, scale = 14, 150.0           # 1px = 150 bytes
    y = lambda a: top + a / scale
    bx, bw = 58, 22
    regions = [  # name, first, last, kind, anchor
        ("stack", 0x0100, 0x01FF, "res", "start"),
        ("the player", 0x0200, 0x0203, "ours", "start"),
        ("program image", 0x0800, 0x77FF, "res", "mid"),
        ("sprite frames", 0xC000, 0xC7FF, "hw", "mid"),
        ("screen plane", 0xCC00, 0xCFE7, "hw", "mid"),
        ("sprite pointers", 0xCFF8, 0xCFFF, "hw", "start"),
        ("VIDEO chip", 0xD000, 0xD02E, "hw", "start"),
        ("colour RAM", 0xD800, 0xDBE7, "hw", "mid"),
        ("joystick ports", 0xDC00, 0xDC02, "hw", "start"),
        ("bitmap", 0xE000, 0xFF3F, "hw", "mid"),
    ]
    bottom = y(0x10000)
    sp = 27
    anchors = [y(f) if k == "start" else (y(f) + y(l + 1)) / 2 for _, f, l, _, k in regions]
    ly = anchors[:]
    ly[0] = max(ly[0], top + 6)
    for i in range(1, len(ly)):
        ly[i] = max(ly[i], ly[i - 1] + sp)
    lim = bottom + 4
    for i in range(len(ly) - 1, -1, -1):
        ly[i] = min(ly[i], lim - (len(ly) - 1 - i) * sp)
        if i < len(ly) - 1:
            ly[i] = min(ly[i], ly[i + 1] - sp)
    fills = {"res": "ch01-mm-res", "hw": "ch01-mm-hw", "ours": "ch01-mm-ours"}
    s = []
    H = int(bottom + 22)
    s.append(f'<svg class="ch01-mm" viewBox="0 0 270 {H}" width="270" role="img" aria-labelledby="ch01-mm-t">')
    s.append('<title id="ch01-mm-t">The Comet 64\'s 65,536 bytes as one strip from $0000 at the top to $FFFF at the bottom, with the regions this chapter uses</title>')
    s.append(f'<rect class="ch01-mm-free" x="{bx}" y="{top}" width="{bw}" height="{bottom - top:.1f}"/>')
    for (name, f, l, kind, _), a, L in zip(regions, anchors, ly):
        y0, h = y(f), max((l + 1 - f) / scale, 3)
        s.append(f'<rect class="{fills[kind]}" x="{bx}" y="{y0:.1f}" width="{bw}" height="{h:.1f}"/>')
    for a in (0x0000, 0x4000, 0x8000, 0xC000, 0x10000):
        t = "$FFFF" if a == 0x10000 else f"${a:04X}"
        yy = y(a) if a < 0x10000 else bottom
        s.append(f'<line class="line" x1="{bx-5}" y1="{yy:.1f}" x2="{bx}" y2="{yy:.1f}"/>')
        s.append(f'<text class="soft" x="{bx-8}" y="{yy+3.5:.1f}" font-size="10" text-anchor="end">{t}</text>')
    for (name, f, l, kind, _), a, L in zip(regions, anchors, ly):
        lx = 116
        s.append(f'<path class="line" d="M{bx+bw} {a:.1f} H{bx+bw+8} L{lx-6} {L:.1f} H{lx-2}"/>')
        cls = ' class="ch01-mm-ourl"' if kind == "ours" else ""
        s.append(f'<text{cls} x="{lx}" y="{L-1:.1f}" font-size="11.5">{name}</text>')
        s.append(f'<text class="soft" x="{lx}" y="{L+11:.1f}" font-size="10">${f:04X} · {f:,}</text>')
    s.append("</svg>")
    legend = ('<div class="dg-row ch01-mm-key">'
              '<span><i class="ch01-mm-sw ch01-mm-hw"></i>hardware</span>'
              '<span><i class="ch01-mm-sw ch01-mm-res"></i>reserved</span>'
              '<span><i class="ch01-mm-sw ch01-mm-ours"></i>the game\'s</span>'
              '<span><i class="ch01-mm-sw ch01-mm-free"></i>free</span></div>')
    style = """<style>
.ch01-mm .ch01-mm-free, .ch01-mm-sw.ch01-mm-free { fill: var(--code-bg); background: var(--code-bg); stroke: var(--rule); }
.ch01-mm .ch01-mm-res, .ch01-mm-sw.ch01-mm-res { fill: var(--rule); background: var(--rule); }
.ch01-mm .ch01-mm-hw, .ch01-mm-sw.ch01-mm-hw { fill: var(--accent); background: var(--accent); }
.ch01-mm .ch01-mm-ours, .ch01-mm-sw.ch01-mm-ours { fill: var(--ink); background: var(--ink); }
.ch01-mm text.ch01-mm-ourl { font-weight: 700; }
.ch01-mm-key { gap: 6px 16px; color: var(--ink-soft); font-size: .75rem; }
.ch01-mm-key span { display: inline-flex; align-items: center; gap: 6px; }
.ch01-mm-sw { display: inline-block; width: 12px; height: 12px; border-radius: 2px; box-shadow: inset 0 0 0 1px var(--rule); }
</style>"""
    return style + "\n" + "\n".join(s) + "\n" + legend + "\n"

# ---------- B: a byte becomes the border ----------
def border():
    s = ['<svg class="ch01-bd" viewBox="0 0 340 300" width="340" role="img" aria-labelledby="ch01-bd-t">',
         '<title id="ch01-bd-t">The byte at $D020 holds 4 and the byte at $D021 holds 0; the VIDEO chip looks both up in the palette and draws a purple border around a black display</title>',
         '<defs><marker id="ch01-bd-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L8 4 L0 8 z" style="fill:var(--ink-soft)"/></marker></defs>']
    # byte boxes
    for x, addr, name, val in ((22, "$D020", "border", 4), (198, "$D021", "background", 0)):
        s.append(f'<text x="{x}" y="16" font-size="11">{name}</text>')
        s.append(f'<text class="soft" x="{x}" y="30" font-size="10">ram[{addr}]</text>')
        s.append(f'<rect class="ch01-bd-byte" x="{x}" y="36" width="56" height="30" rx="4"/>')
        s.append(f'<text x="{x+28}" y="56" font-size="14" text-anchor="middle" font-weight="700">{val}</text>')
    # palette
    px0, pw, py = 18, 19, 112
    s.append(f'<text class="soft" x="196" y="{py+46}" font-size="10">the palette, 0–15</text>')
    for i in range(16):
        x = px0 + i * pw
        sel = ' class="ch01-bd-sw ch01-bd-sel"' if i in (0, 4) else ' class="ch01-bd-sw"'
        s.append(f'<rect{sel} x="{x+1}" y="{py}" width="{pw-2}" height="18" rx="2" style="fill:var(--c{i})"/>')
        s.append(f'<text class="soft" x="{x+pw/2}" y="{py+31}" font-size="9" text-anchor="middle">{i}</text>')
    c4 = px0 + 4 * pw + pw / 2
    c0 = px0 + pw / 2
    s.append(f'<path class="line" d="M50 66 V86 H{c4} V{py-3}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<path class="line" d="M226 66 V92 H{c0+6} V{py-3}" marker-end="url(#ch01-bd-arrow)"/>')
    # mini screen
    sx, sy, sw, sh, b = 110, 168, 210, 118, 18
    s.append(f'<rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="3" style="fill:var(--c4)"/>')
    s.append(f'<rect x="{sx+b}" y="{sy+b}" width="{sw-2*b}" height="{sh-2*b}" style="fill:var(--c0)"/>')
    s.append(f'<path class="line" d="M{c4} {py+36} V{sy+b/2} H{sx-3}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<path class="line" d="M{c0} {py+36} V{sy+sh/2} H{sx+b+18}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<text x="{c4+6}" y="{sy-6}" font-size="10" class="soft">4 = purple</text>')
    s.append(f'<text x="{c0+6}" y="{sy+sh/2-6}" font-size="10" class="soft">0 = black</text>')
    s.append("</svg>")
    style = """<style>
.ch01-bd .ch01-bd-byte { fill: var(--code-bg); stroke: var(--rule); }
.ch01-bd .ch01-bd-sw { stroke: var(--rule); }
.ch01-bd .ch01-bd-sel { stroke: var(--accent); stroke-width: 2.5; }
</style>"""
    return style + "\n" + "\n".join(s) + "\n"

# ---------- C: the floor ----------
def floor():
    c, b = 7, 14           # cell px, border px
    sx, sy = 16, 8
    W, Hh = 40 * c, 25 * c
    dx, dy = sx + b, sy + b
    s = ['<svg class="ch01-fl" viewBox="0 0 340 470" width="340" role="img" aria-labelledby="ch01-fl-t">',
         '<title id="ch01-fl-t">The display as 40 by 25 cells with the bottom row, row 24, grey. Its first cell is eight bitmap bytes of $FF from $FE00 and one colour RAM byte of 12 at $DBC0</title>']
    s.append(f'<rect x="{sx}" y="{sy}" width="{W+2*b}" height="{Hh+2*b}" rx="3" style="fill:var(--c6)"/>')
    s.append(f'<rect x="{dx}" y="{dy}" width="{W}" height="{Hh}" style="fill:var(--c0)"/>')
    s.append(f'<rect x="{dx}" y="{dy+24*c}" width="{W}" height="{c}" style="fill:var(--c12)"/>')
    g = []
    for i in range(1, 40):
        g.append(f"M{dx+i*c} {dy}v{Hh}")
    for j in range(1, 25):
        g.append(f"M{dx} {dy+j*c}h{W}")
    s.append(f'<path class="ch01-fl-grid" d="{" ".join(g)}"/>')
    s.append(f'<rect class="ch01-fl-hi" x="{dx}" y="{dy+24*c}" width="{c}" height="{c}"/>')
    # labels for the grid
    ty = sy + Hh + 2 * b + 16
    s.append(f'<text class="soft" x="{dx+14}" y="{ty}" font-size="10">40 × 25 cells, each 8 × 8 pixels</text>')
    # zoom
    zy = ty + 26
    zx = 44
    ry = zy + 18
    s.append(f'<path class="line" d="M{dx+c/2} {dy+25*c} V{ry-5} H{zx+108} V{ry-1}"/>')
    s.append(f'<text x="{zx}" y="{zy+6}" font-size="11">row 24, cell 0</text>')
    ry = zy + 18
    for k in range(8):
        y0 = ry + k * 17
        s.append(f'<text class="soft" x="{zx}" y="{y0+11}" font-size="10">${0xFE00+k:04X}</text>')
        s.append(f'<rect class="ch01-fl-byte" x="{zx+44}" y="{y0}" width="28" height="14" rx="2"/>')
        s.append(f'<text x="{zx+58}" y="{y0+11}" font-size="10" text-anchor="middle">FF</text>')
        s.append(f'<rect x="{zx+80}" y="{y0}" width="56" height="14" style="fill:var(--c12)"/>')
    s.append(f'<rect class="ch01-fl-cellbox" x="{zx+80}" y="{ry}" width="56" height="{8*17-3}"/>')
    ny = ry + 8 * 17 + 10
    s.append(f'<text class="soft" x="{zx}" y="{ny}" font-size="10">next cell: $FE08…  last: $FF38–$FF3F</text>')
    # colour ram
    cx = 196
    s.append(f'<text x="{cx}" y="{zy+6}" font-size="11">its colour</text>')
    s.append(f'<text class="soft" x="{cx}" y="{ry+11}" font-size="10">$DBC0</text>')
    s.append(f'<rect class="ch01-fl-byte" x="{cx+44}" y="{ry}" width="28" height="14" rx="2"/>')
    s.append(f'<text x="{cx+58}" y="{ry+11}" font-size="10" text-anchor="middle">12</text>')
    s.append(f'<rect x="{cx+80}" y="{ry}" width="14" height="14" rx="2" style="fill:var(--c12)"/>')
    s.append(f'<text class="soft" x="{cx}" y="{ry+32}" font-size="10">12 = grey: the colour</text>')
    s.append(f'<text class="soft" x="{cx}" y="{ry+45}" font-size="10">for every $FF in</text>')
    s.append(f'<text class="soft" x="{cx}" y="{ry+58}" font-size="10">this cell</text>')
    # sums
    my = ny + 28
    for k, (lab, expr, note) in enumerate((("bitmap:", "$E000 + 24 × 320 = $FE00", "320 bytes, $FE00–$FF3F"),
                                          ("colour RAM:", "$D800 + 24 × 40 = $DBC0", "40 bytes, $DBC0–$DBE7"))):
        yy = my + k * 34
        s.append(f'<text x="{zx}" y="{yy}" font-size="10.5">{lab}</text>')
        s.append(f'<text x="{zx+78}" y="{yy}" font-size="10.5">{expr}</text>')
        s.append(f'<text class="soft" x="{zx+78}" y="{yy+14}" font-size="10">{note}</text>')
    s.append("</svg>")
    out = "\n".join(s)
    hgt = my + 58
    out = out.replace('viewBox="0 0 340 470"', f'viewBox="0 0 340 {hgt}"')
    style = """<style>
.ch01-fl .ch01-fl-grid { stroke: var(--c11); stroke-width: .5; fill: none; }
.ch01-fl .ch01-fl-hi { fill: none; stroke: var(--accent); stroke-width: 2; }
.ch01-fl .ch01-fl-byte { fill: var(--code-bg); stroke: var(--rule); }
.ch01-fl .ch01-fl-cellbox { fill: none; stroke: var(--accent); stroke-width: 1.5; }
.ch01-fl text { white-space: pre; }
</style>"""
    return style + "\n" + out + "\n"

# ---------- D: the sprite ----------
def sprite():
    src = open("/home/user/dr-creep-in-zig/site/code/ch01/src/player.zig").read()
    body = src[src.index("const picture"):]
    body = body[:body.index("};")]
    bytes_ = [int(b, 2) for b in re.findall(r"0b([01]{8})", body)]
    assert len(bytes_) == 63
    HI = 5
    rows = []
    for r in range(21):
        bits = " ".join(f"{bytes_[r*3+k]:08b}" for k in range(3))
        cls = ' class="ch01-sp-hl"' if r == HI else ""
        rows.append(f'<span{cls}><b>{r:>2}</b> {bits}</span>')
    pix = []
    for r in range(21):
        for k in range(3):
            for bit in range(7, -1, -1):
                on = bytes_[r*3+k] >> bit & 1
                pix.append('<i class="ch01-sp-1"></i>' if on else '<i></i>')
    exp = []
    for k in range(3):
        idx = HI * 3 + k
        v = bytes_[idx]
        cells = "".join(f'<span class="ch01-sp-b{v >> bit & 1}">{v >> bit & 1}</span>' for bit in range(7, -1, -1))
        exp.append(f'<div class="ch01-sp-byte"><div class="ch01-sp-bits">{cells}</div>'
                   f'<span class="dg-label">byte {idx}<br>${0xC000+idx:04X}</span></div>')
    style = """<style>
.ch01-sp-top { display: flex; flex-wrap: wrap; gap: 14px 28px; align-items: flex-start; }
.ch01-sp-src { display: flex; flex-direction: column; font-size: .72rem; line-height: 1.35; white-space: pre; }
.ch01-sp-src b { font-weight: 400; color: var(--ink-soft); }
.ch01-sp-src .ch01-sp-hl, .ch01-sp-grid .ch01-sp-row { box-shadow: 0 0 0 2px var(--accent); }
.ch01-sp-src .ch01-sp-hl { border-radius: 2px; }
.ch01-sp-pic { position: relative; padding: 0 10px; }
.ch01-sp-grid { --px: 9px; grid-template-columns: repeat(24, var(--px)); background: var(--c0); }
.ch01-sp-grid > .ch01-sp-1 { background: var(--c1); }
.ch01-sp-grid .ch01-sp-row { position: absolute; left: -10px; right: -10px; top: calc(var(--row) * var(--px)); height: var(--px); pointer-events: none; }
.ch01-sp-pic .dg-label { display: block; margin-top: 6px; }
.ch01-sp-exp { display: flex; flex-wrap: wrap; gap: 8px 6px; --bw: 11px; }
@media (min-width: 720px) { .ch01-sp-grid { --px: 13px; } .ch01-sp-exp { --bw: 20px; gap: 8px 12px; } .ch01-sp-bits span { height: 24px; line-height: 24px; font-size: .8rem; } }
.ch01-sp-byte { display: flex; flex-direction: column; gap: 4px; }
.ch01-sp-bits { display: inline-grid; grid-template-columns: repeat(8, var(--bw)); gap: 1px; }
.ch01-sp-bits span { box-shadow: inset 0 0 0 1px var(--rule); height: 18px; line-height: 18px; text-align: center; font-size: .7rem; }
.ch01-sp-b1 { background: var(--c1); color: var(--c0); }
.ch01-sp-b0 { background: var(--c0); color: var(--c12); }
</style>"""
    return (style + "\n"
            + '<div class="ch01-sp-top">\n'
            + '<div class="ch01-sp-src" aria-label="The 63 bytes of picture, three per row, in binary">' + "\n".join(rows) + '</div>\n'
            + f'<div class="ch01-sp-pic"><div class="dg-pixels ch01-sp-grid" style="position:relative" role="img" aria-label="The same bytes drawn as a 24 by 21 sprite: a 1 bit is a white pixel, a 0 lets the black background show">'
            + "".join(pix) + f'<span class="ch01-sp-row" style="--row:{HI}"></span></div>'
            + '<span class="dg-label">24 × 21 pixels</span></div>\n</div>\n'
            + f'<div class="dg-label">row {HI}: three bytes, one bit per pixel</div>\n'
            + '<div class="ch01-sp-exp">' + "".join(exp) + '</div>\n')

# ---------- E: the joystick byte ----------
def joystick():
    names = ["7", "6", "5", "fire", "right", "left", "down", "up"]
    states = [("nothing touched", 0xFF), ("holding left", 0xFB), ("up + fire", 0xEE)]
    h = ['<style>',
         '.ch01-js { display: grid; grid-template-columns: repeat(8, minmax(2.6em, 3.4em)) auto; gap: 3px; align-items: center; justify-content: start; }',
         '.ch01-js .dg-label { text-align: center; letter-spacing: .04em; }',
         '.ch01-js .ch01-js-state { grid-column: 1 / -1; margin-top: 8px; color: var(--ink-soft); font-size: .75rem; }',
         '.ch01-js .dg-bit { min-width: 0; }',
         '.ch01-js .ch01-js-fixed { opacity: .5; }',
         '.ch01-js .ch01-js-hex { padding-left: 10px; font-weight: 700; }',
         '</style>',
         '<div class="ch01-js" role="table" aria-label="Joystick 1, the byte at $DC01, bit by bit">',
         '<span role="row" style="display:contents">' + "".join(f'<span class="dg-label" role="columnheader">{n}</span>' for n in names) + '<span></span></span>']
    for label, v in states:
        h.append(f'<span class="ch01-js-state">{label}</span>')
        cells = []
        for bit in range(7, -1, -1):
            b = v >> bit & 1
            cls = "dg-bit"
            if bit >= 5:
                cls += " ch01-js-fixed"
            elif b == 0:
                cls += " dg-on"
            cells.append(f'<span class="{cls}">{b}</span>')
        h.append('<span role="row" style="display:contents">' + "".join(cells) + f'<span class="ch01-js-hex">${v:02X}</span></span>')
    h.append('</div>')
    return "\n".join(h) + "\n"

for name, fn in (("memory-map", memmap), ("border-byte", border), ("floor", floor), ("sprite", sprite), ("joystick", joystick)):
    open(D + f"ch01-{name}.html", "w").write(fn())
print("ok")
