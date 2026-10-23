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
    # Each byte box sits straight above its palette entry, and the two paths
    # down to the screen nest (0's L wraps outside 4's), so nothing crosses.
    px0, pw, py = 20, 18, 112
    cx = lambda i: px0 + i * pw + pw / 2
    c0, c4 = cx(0), cx(4)
    sx, sy, sw, sh, b = 178, 166, 150, 104, 16
    ya, yb = sy + 30, sy + 70           # where the 4 and 0 paths turn right
    H = sy + sh + 8
    s = [f'<svg class="ch01-bd" viewBox="0 0 340 {H}" width="340" role="img" aria-labelledby="ch01-bd-t">',
         '<title id="ch01-bd-t">The byte at $D021 holds 0 and the byte at $D020 holds 4; the VIDEO chip looks both up in the palette and draws a black display inside a purple border</title>',
         '<defs><marker id="ch01-bd-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L8 4 L0 8 z" style="fill:var(--ink-soft)"/></marker></defs>']
    for c, addr, name, val in ((c0, "$D021", "background", 0), (c4, "$D020", "border", 4)):
        s.append(f'<text x="{c}" y="16" font-size="11" text-anchor="middle">{name}</text>')
        s.append(f'<text class="soft" x="{c}" y="30" font-size="10" text-anchor="middle">ram[{addr}]</text>')
        s.append(f'<rect class="ch01-bd-byte" x="{c-24}" y="36" width="48" height="30" rx="4"/>')
        s.append(f'<text x="{c}" y="56" font-size="14" text-anchor="middle" font-weight="700">{val}</text>')
        s.append(f'<path class="line" d="M{c} 66 V{py-3}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<text class="soft" x="{px0 + 16 * pw}" y="{py-8}" font-size="10" text-anchor="end">the palette, 0–15</text>')
    for i in range(16):
        x = px0 + i * pw
        sel = ' class="ch01-bd-sw ch01-bd-sel"' if i in (0, 4) else ' class="ch01-bd-sw"'
        s.append(f'<rect{sel} x="{x+1}" y="{py}" width="{pw-2}" height="18" rx="2" style="fill:var(--c{i})"/>')
        s.append(f'<text class="soft" x="{x+pw/2}" y="{py+31}" font-size="9" text-anchor="middle">{i}</text>')
    # the screen: a purple border around a black display
    s.append(f'<rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="3" style="fill:var(--c4)"/>')
    s.append(f'<rect x="{sx+b}" y="{sy+b}" width="{sw-2*b}" height="{sh-2*b}" style="fill:var(--c0)"/>')
    s.append(f'<path class="line" d="M{c4} {py+36} V{ya} H{sx-3}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<path class="line" d="M{c0} {py+36} V{yb} H{sx+b+22}" marker-end="url(#ch01-bd-arrow)"/>')
    s.append(f'<text x="{c4+8}" y="{ya-6}" font-size="10" class="soft">4 = purple</text>')
    s.append(f'<text x="{c0+8}" y="{yb-6}" font-size="10" class="soft">0 = black</text>')
    s.append("</svg>")
    style = """<style>
.ch01-bd .ch01-bd-byte { fill: var(--code-bg); stroke: var(--rule); }
.ch01-bd .ch01-bd-sw { stroke: var(--rule); }
.ch01-bd .ch01-bd-sel { stroke: var(--accent); stroke-width: 2.5; }
</style>"""
    return style + "\n" + "\n".join(s) + "\n"

# ---------- C: the floor ----------
def floor():
    c, b = 7, 14           # one cell drawn 7 px square; border 14 px
    sx, sy = 16, 22
    W, Hh = 40 * c, 25 * c
    dx, dy = sx + b, sy + b
    fy = dy + 24 * c       # top of the floor row
    s = ['<svg class="ch01-fl" viewBox="0 0 340 520" width="340" role="img" aria-labelledby="ch01-fl-t">',
         '<title id="ch01-fl-t">The display is a grid of 40 by 25 cells, each 8 by 8 pixels. The floor is the bottom row of cells, row 24, in grey. Up close, its first cell is a square made of eight bitmap bytes of $FF, one byte per pixel row, from $FE00 to $FE07, and one colour RAM byte of 12, grey, at $DBC0</title>']
    s.append(f'<text class="soft" x="{dx + W/2}" y="{sy-7}" font-size="10" text-anchor="middle">40 cells across</text>')
    s.append(f'<rect x="{sx}" y="{sy}" width="{W+2*b}" height="{Hh+2*b}" rx="3" style="fill:var(--c6)"/>')
    s.append(f'<rect x="{dx}" y="{dy}" width="{W}" height="{Hh}" style="fill:var(--c0)"/>')
    s.append(f'<rect x="{dx}" y="{fy}" width="{W}" height="{c}" style="fill:var(--c12)"/>')
    g = [f"M{dx+i*c} {dy}v{Hh}" for i in range(1, 40)] + [f"M{dx} {dy+j*c}h{W}" for j in range(1, 25)]
    s.append(f'<path class="ch01-fl-grid" d="{" ".join(g)}"/>')
    s.append(f'<text class="ch01-fl-on" x="{dx + W/2}" y="{dy + 12*c}" font-size="10" text-anchor="middle">25 rows of cells</text>')
    s.append(f'<text class="ch01-fl-on" x="{dx + W/2}" y="{dy + 12*c + 13}" font-size="10" text-anchor="middle">each cell 8 × 8 pixels</text>')
    s.append(f'<text class="ch01-fl-on" x="{dx + W/2}" y="{fy - 5}" font-size="10" text-anchor="middle">row 24: the floor ↓</text>')
    s.append(f'<rect class="ch01-fl-hi" x="{dx}" y="{fy}" width="{c}" height="{c}"/>')
    # zoom: one cell as an 8 x 8 square, each pixel row one byte
    z = 15                                   # one pixel, zoomed
    qx, qy = 118, dy + Hh + b + 34           # the square's top-left
    Z = 8 * z
    s.append(f'<path class="ch01-fl-zoom" d="M{dx} {fy+c} L{qx} {qy} M{dx+c} {fy+c} L{qx+Z} {qy}"/>')
    s.append(f'<rect x="{qx}" y="{qy}" width="{Z}" height="{Z}" style="fill:var(--c12)"/>')
    gz = [f"M{qx} {qy+k*z}h{Z}" for k in range(1, 8)]
    s.append(f'<path class="ch01-fl-rows" d="{" ".join(gz)}"/>')
    gp = [f"M{qx+k*2*z} {qy}v{Z}" for k in range(1, 4)]
    s.append(f'<path class="ch01-fl-pairs" d="{" ".join(gp)}"/>')
    s.append(f'<rect class="ch01-fl-cellbox" x="{qx}" y="{qy}" width="{Z}" height="{Z}"/>')
    s.append(f'<text class="soft" x="{qx + Z/2}" y="{qy+Z+14}" font-size="10" text-anchor="middle">8 × 8 pixels</text>')
    for k in range(8):
        y0 = qy + k * z
        s.append(f'<text class="soft" x="{qx-46}" y="{y0+11}" font-size="10" text-anchor="end">${0xFE00+k:04X}</text>')
        s.append(f'<rect class="ch01-fl-byte" x="{qx-40}" y="{y0+1}" width="26" height="{z-2}" rx="2"/>')
        s.append(f'<text x="{qx-27}" y="{y0+11}" font-size="10" text-anchor="middle">FF</text>')
        s.append(f'<path class="line" d="M{qx-12} {y0+z/2} H{qx-3}"/>')
    s.append(f'<text class="soft" x="{qx-12}" y="{qy+Z+14}" font-size="10" text-anchor="end">1 byte = 1 row</text>')
    # its colour byte
    kx = qx + Z + 14
    # title sits right of the square, clear of the dashed zoom lines
    s.append(f'<text x="{kx}" y="{qy-22}" font-size="10.5">row 24, cell 0,</text>')
    s.append(f'<text x="{kx}" y="{qy-9}" font-size="10.5">up close</text>')
    s.append(f'<text x="{kx}" y="{qy+11}" font-size="10.5">colour RAM</text>')
    s.append(f'<text class="soft" x="{kx}" y="{qy+28}" font-size="10">$DBC0</text>')
    s.append(f'<rect class="ch01-fl-byte" x="{kx+40}" y="{qy+17}" width="26" height="15" rx="2"/>')
    s.append(f'<text x="{kx+53}" y="{qy+28}" font-size="10" text-anchor="middle">12</text>')
    for k, t in enumerate(("1 byte for the", "whole cell:", "12 = grey")):
        s.append(f'<text class="soft" x="{kx}" y="{qy+50+k*13}" font-size="10">{t}</text>')
    s.append(f'<path class="line" d="M{kx-3} {qy+24} H{qx+Z-6}"/>')
    hgt = qy + Z + 24
    out = "\n".join(s).replace('viewBox="0 0 340 520"', f'viewBox="0 0 340 {hgt}"') + "\n</svg>"
    writes = ('<div class="ch01-fl-writes">'
              '<div><span class="dg-label">write 1 · bitmap</span>'
              '<span>40 cells × 8 bytes = <b>320 bytes of $FF</b></span>'
              '<span class="ch01-fl-soft">$E000 + 24 × 320 = $FE00, up to $FF3F</span></div>'
              '<div><span class="dg-label">write 2 · colour RAM</span>'
              '<span>40 cells × 1 byte = <b>40 bytes of 12</b></span>'
              '<span class="ch01-fl-soft">$D800 + 24 × 40 = $DBC0, up to $DBE7</span></div>'
              '</div>')
    style = """<style>
.ch01-fl .ch01-fl-grid { stroke: var(--c11); stroke-width: .5; fill: none; }
.ch01-fl .ch01-fl-hi { fill: none; stroke: var(--accent); stroke-width: 2; }
.ch01-fl .ch01-fl-zoom { stroke: var(--accent); stroke-width: 1; stroke-dasharray: 3 3; fill: none; }
.ch01-fl .ch01-fl-byte { fill: var(--code-bg); stroke: var(--rule); }
.ch01-fl .ch01-fl-rows { stroke: var(--c11); stroke-width: 1.5; fill: none; }
.ch01-fl .ch01-fl-pairs { stroke: var(--c11); stroke-width: .6; stroke-dasharray: 2 3; fill: none; }
.ch01-fl .ch01-fl-cellbox { fill: none; stroke: var(--accent); stroke-width: 2; }
.ch01-fl text.ch01-fl-on { fill: var(--c15); }
.ch01-fl-writes { display: flex; flex-wrap: wrap; gap: 10px 28px; }
.ch01-fl-writes > div { display: flex; flex-direction: column; gap: 2px; }
.ch01-fl-writes b { font-weight: 700; }
.ch01-fl-writes .ch01-fl-soft { color: var(--ink-soft); font-size: .72rem; }
</style>"""
    return style + "\n" + out + "\n" + writes + "\n"

# ---------- F: a byte's eight bits ----------
def byte():
    h = ['<style>',
         '.ch01-by { align-self: flex-start; display: inline-grid; grid-template-columns: auto repeat(8, minmax(2.2em, 3em)); gap: 4px 3px; align-items: center; }',
         '.ch01-by .dg-label { text-align: center; }',
         '.ch01-by .ch01-by-head { text-align: right; padding-right: 8px; }',
         '.ch01-by .dg-bit { min-width: 0; font-weight: 700; }',
         '.ch01-by .ch01-by-w { text-align: center; font-variant-numeric: tabular-nums; }',
         '.ch01-by-sum { color: var(--ink-soft); }',
         '</style>',
         '<div class="ch01-by" role="table" aria-label="A byte with all eight bits on, and what each bit is worth">',
         '<span role="row" style="display:contents"><span class="dg-label ch01-by-head" role="rowheader">bit</span>'
         + "".join(f'<span class="dg-label" role="columnheader">{n}</span>' for n in range(7, -1, -1)) + '</span>',
         '<span role="row" style="display:contents"><span class="dg-label ch01-by-head" role="rowheader">value</span>'
         + '<span class="dg-bit dg-on" role="cell">1</span>' * 8 + '</span>',
         '<span role="row" style="display:contents"><span class="dg-label ch01-by-head" role="rowheader">worth</span>'
         + "".join(f'<span class="ch01-by-w" role="cell">{1 << n}</span>' for n in range(7, -1, -1)) + '</span>',
         '</div>',
         '<div class="ch01-by-sum">128 + 64 + 32 + 16 + 8 + 4 + 2 + 1 = <b>255</b>, the biggest u8</div>']
    return "\n".join(h) + "\n"

# ---------- G: the player's four bytes ----------
def player_bytes():
    fields = (("$0200", "player_x"), ("$0201", "player_y"), ("$0202", "player_color"), ("$0203", "player_last_stick"))
    h = ['<style>',
         '.ch01-pb { display: flex; flex-wrap: wrap; gap: 8px 3px; }',
         '.ch01-pb > div { display: flex; flex-direction: column; gap: 4px; }',
         '.ch01-pb .ch01-pb-a { padding-left: 2px; color: var(--ink-soft); font-size: .72rem; }',
         '.ch01-pb .dg-byte { text-align: left; padding: 6px 10px; }',
         '</style>',
         '<div class="ch01-pb" aria-label="The player\'s four bytes, $0200 to $0203">']
    for a, n in fields:
        h.append(f'<div><span class="ch01-pb-a">{a}</span><span class="dg-byte">{n}</span></div>')
    h.append('</div>')
    return "\n".join(h) + "\n"

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

for name, fn in (("memory-map", memmap), ("border-byte", border), ("floor", floor), ("sprite", sprite), ("joystick", joystick),
                 ("byte", byte), ("player-bytes", player_bytes)):
    open(D + f"ch01-{name}.html", "w").write(fn())
print("ok")
