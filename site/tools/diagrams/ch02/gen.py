"""Generate the Chapter 2 diagrams into site/page/diagrams/ch02-*.html."""
import pathlib

OUT = pathlib.Path("/home/user/dr-creep-in-zig/site/page/diagrams")

# ---------------------------------------------------------------- 1. fat pixels
# Byte $6C = 01 10 11 00 in a cell painted with the walkway's stone colours:
# screen plane $9A (brown high, pink low), colour RAM $0F (light grey),
# background $D021 = 0 (black).
fat = """<style>
.ch02-fp { display: grid; gap: 14px; }
.ch02-fp-byte b { font-weight: 600; }
.ch02-fp-byte { display: grid; grid-template-columns: repeat(4, minmax(0, 66px)); column-gap: 6px; row-gap: 4px; justify-items: center; align-items: center; }
.ch02-fp-pair { display: inline-grid; grid-auto-flow: column; gap: 2px; }
.ch02-fp-strip { grid-column: 1 / -1; display: grid; grid-template-columns: repeat(4, minmax(0, 66px)); column-gap: 6px; width: 100%; }
.ch02-fp-strip > i { display: block; height: 33px; box-shadow: 0 0 0 1px var(--rule); }
.ch02-fp-src { display: grid; grid-template-columns: max-content max-content minmax(0, 1fr); gap: 8px 12px; align-items: center; }
.ch02-fp-src b { font-weight: 600; }
.ch02-fp-nib { justify-self: start; display: inline-grid; grid-auto-flow: column; gap: 2px; }
.ch02-fp-nib > span { min-width: 2.2em; padding: 4px 6px; text-align: center; border-radius: 4px; font-weight: 600; box-shadow: inset 0 0 0 1px var(--rule); }
.ch02-fp-addr { color: var(--ink-soft); }
</style>
<div class="ch02-fp">
  <div class="dg-label">one bitmap byte: $6C</div>
  <div class="ch02-fp-byte">
    <span class="ch02-fp-pair"><span class="dg-bit">0</span><span class="dg-bit">1</span></span>
    <span class="ch02-fp-pair"><span class="dg-bit">1</span><span class="dg-bit">0</span></span>
    <span class="ch02-fp-pair"><span class="dg-bit">1</span><span class="dg-bit">1</span></span>
    <span class="ch02-fp-pair"><span class="dg-bit">0</span><span class="dg-bit">0</span></span>
    <span class="dg-label">bits 7–6</span><span class="dg-label">bits 5–4</span><span class="dg-label">bits 3–2</span><span class="dg-label">bits 1–0</span>
    <div class="ch02-fp-strip" aria-label="four fat pixels: brown, pink, light grey, black">
      <i style="background:var(--c9)"></i><i style="background:var(--c10)"></i><i style="background:var(--c15)"></i><i style="background:var(--c0)"></i>
    </div>
    <span>pixel 0</span><span>pixel 1</span><span>pixel 2</span><span>pixel 3</span>
    <b>code 01</b><b>code 10</b><b>code 11</b><b>code 00</b>
  </div>
  <div class="dg-label">where each code finds its colour</div>
  <div class="ch02-fp-src">
    <b>code 00</b>
    <span class="ch02-fp-nib"><span style="background:var(--c0);color:var(--c1)">0</span></span>
    <span>background <span class="ch02-fp-addr">$D021</span>: black, for the whole screen</span>
    <b>code 01</b>
    <span class="ch02-fp-nib"><span style="background:var(--c9);color:var(--c1)">9</span><span class="dg-byte">A</span></span>
    <span>screen plane <span class="ch02-fp-addr">$CC00 + cell</span>, high half: brown</span>
    <b>code 10</b>
    <span class="ch02-fp-nib"><span class="dg-byte">9</span><span style="background:var(--c10);color:var(--c1)">A</span></span>
    <span>the same byte, low half: pink</span>
    <b>code 11</b>
    <span class="ch02-fp-nib"><span class="dg-byte">0</span><span style="background:var(--c15);color:var(--c0)">F</span></span>
    <span>colour RAM <span class="ch02-fp-addr">$D800 + cell</span>: light grey</span>
  </div>
</div>
"""

# ---------------------------------------------------------------- 2. cell order
def cell_col(c, r, hi):
    rows = []
    for l in range(8):
        a = 0xE000 + (r * 40 + c) * 8 + l
        cls = "ch02-co-b"
        if (r * 8 + l) == 3:
            cls += " ch02-co-row"
        if a == hi:
            cls += " ch02-co-hi"
        rows.append(f'<span class="{cls}">{a:04X}</span>')
    return "".join(rows)

cols = [0, 1, 2, None, 39]
head = "".join(
    f'<span class="dg-label">{"cell " + str(c) if c is not None else ""}</span>' for c in cols
)
body = []
for r in range(2):
    body.append(f'<span class="dg-label ch02-co-rl">cell row {r}</span>')
    for c in cols:
        if c is None:
            body.append('<span class="ch02-co-gap">…</span>')
        else:
            body.append(f'<span class="ch02-co-cell">{cell_col(c, r, 0xE00B)}</span>')
cells = f"""<style>
.ch02-co {{ display: grid; grid-template-columns: max-content repeat(3, max-content) 1.4em max-content; gap: 6px 6px; align-items: start; }}
.ch02-co-cell {{ display: grid; gap: 1px; padding: 3px; border-radius: 5px; box-shadow: 0 0 0 1px var(--rule); }}
.ch02-co-b {{ padding: 0 4px; border-radius: 3px; font-size: .72rem; line-height: 1.45; text-align: center; background: var(--code-bg); }}
.ch02-co-row {{ box-shadow: inset 0 0 0 1.5px var(--accent); }}
.ch02-co-hi {{ background: var(--accent); color: var(--sheet); font-weight: 600; }}
.ch02-co-gap {{ align-self: center; text-align: center; color: var(--ink-soft); }}
.ch02-co-rl {{ writing-mode: vertical-rl; transform: rotate(180deg); align-self: center; }}
.ch02-co-steps {{ display: grid; grid-template-columns: max-content 1fr; gap: 2px 10px; }}
.ch02-co-steps b {{ font-weight: 600; color: var(--accent); }}
</style>
<div class="ch02-co" aria-label="bitmap addresses, cell by cell">
  <span></span>{head}
  {"".join(body)}
</div>
<div class="ch02-co-steps">
  <b>+1</b><span>the next line down, inside a cell</span>
  <b>+8</b><span>the same line, one cell to the right (the outlined row: display row 3)</span>
  <b>+320</b><span>the same line, one row of cells down (40 cells × 8 bytes)</span>
</div>
"""

# ---------------------------------------------------------------- 3. row table
def rt_row(y):
    a = 0xE000 + (y // 8) * 320 + y % 8
    at = 0xBB00 + y * 2
    return (y, at, a)

rows_html = []
prev = None
for y in [0, 1, 2, None, 7, 8, 9, None, 199]:
    if y is None:
        rows_html.append('<span class="ch02-rt-dots">⋮</span><span></span><span class="ch02-rt-dots">⋮</span><span></span><span class="ch02-rt-dots">⋮</span><span></span>')
        prev = None
        continue
    yy, at, a = rt_row(y)
    step = ""
    if prev is not None:
        d = a - prev
        step = f'<span class="ch02-rt-step{" ch02-rt-big" if d != 1 else ""}">+{d}</span>'
    else:
        step = "<span></span>"
    rows_html.append(
        f'<span>{yy}</span><span class="ch02-rt-at">${at:04X}</span>'
        f'<span class="dg-bytes"><span class="dg-byte">{a & 0xFF:02X}</span><span class="dg-byte">{a >> 8:02X}</span></span>'
        f'<span class="dg-arrow">→</span><span class="dg-byte ch02-rt-addr">${a:04X}</span>{step}'
    )
    prev = a
table = f"""<style>
.ch02-rt {{ display: grid; grid-template-columns: repeat(6, max-content); gap: 4px 10px; align-items: center; }}
.ch02-rt-at {{ color: var(--ink-soft); }}
.ch02-rt-dots {{ color: var(--ink-soft); text-align: center; line-height: 1; }}
.ch02-rt-addr {{ min-width: 4.4em; }}
.ch02-rt-step {{ color: var(--ink-soft); }}
.ch02-rt-big {{ color: var(--accent); font-weight: 600; }}
</style>
<div class="ch02-rt" aria-label="the row table">
  <span class="dg-label">y</span><span class="dg-label">entry</span><span class="dg-label">holds</span><span></span><span class="dg-label">row starts at</span><span></span>
  {"".join(rows_html)}
</div>
"""

# ---------------------------------------------------------------- 4. shape entry
CODE_COL = {".": "c0", "1": "c9", "2": "c10", "3": "c15"}
walk = ["3333", "2221", "2221", "1111", "2122", "2122", "1111"]

def packrow(s):
    b = 0
    for ch in s:
        b = b << 2 | ".123".index(ch)
    return b

def swatches(s):
    return "".join(f'<i style="background:var(--{CODE_COL[ch]})"></i>' for ch in s)

px_rows = "".join(
    f'<span class="dg-byte">{packrow(s):02X}</span><span class="ch02-se-codes">{" ".join(format(".123".index(ch), "02b") for ch in s)}</span>'
    f'<span class="ch02-se-px">{swatches(s)}</span>'
    for s in walk
)
dir_rows = [
    (0, "glyph", 0xBB00, 0x0310, False),
    (1, "walkway", 0x6802, 0x6828, True),
    (2, "walkway_left", 0x6804, 0x6834, False),
]
dir_html = "".join(
    f'<span>{i}</span><span class="ch02-se-soft">${0x6800 + i * 2:04X}</span>'
    f'<span class="dg-bytes"><span class="dg-byte{" dg-on" if on else ""}">{p & 0xFF:02X}</span><span class="dg-byte{" dg-on" if on else ""}">{p >> 8:02X}</span></span>'
    f'<span class="ch02-se-soft">→ ${p:04X} {name}</span>'
    for i, name, _, p, on in dir_rows
)
shape = f"""<style>
.ch02-se {{ display: flex; flex-wrap: wrap; gap: 18px 28px; align-items: flex-start; }}
.ch02-se-box {{ display: grid; gap: 8px; }}
.ch02-se-dir {{ display: grid; grid-template-columns: repeat(4, max-content); gap: 4px 10px; align-items: center; }}
.ch02-se-soft {{ color: var(--ink-soft); }}
.ch02-se-hdr {{ display: grid; grid-template-columns: repeat(3, max-content); gap: 2px 6px; justify-items: center; }}
.ch02-se-rows {{ display: grid; grid-template-columns: max-content max-content max-content; gap: 3px 10px; align-items: center; }}
.ch02-se-codes {{ font-size: .72rem; color: var(--ink-soft); }}
.ch02-se-px {{ display: inline-grid; grid-template-columns: repeat(4, 20px); box-shadow: 0 0 0 1px var(--rule); }}
.ch02-se-px > i {{ display: block; height: 10px; }}
.ch02-se-big {{ display: inline-grid; grid-template-columns: repeat(4, 28px); box-shadow: 0 0 0 1px var(--rule); justify-self: start; }}
.ch02-se-big > i {{ display: block; height: 14px; }}
.ch02-se-col {{ display: grid; grid-template-columns: max-content minmax(0, 1fr); gap: 4px 10px; align-items: center; }}
</style>
<div class="ch02-se">
  <div class="ch02-se-box" style="gap:24px">
  <div class="ch02-se-box">
    <div class="dg-label">directory at $6800: shape id × 2</div>
    <div class="ch02-se-dir">{dir_html}<span class="ch02-se-soft">⋮</span><span></span><span></span><span></span></div>
  </div>
  <div class="ch02-se-box">
    <div class="dg-label">drawn: one cell of the floor</div>
    <div class="ch02-se-big" aria-label="the walkway piece: a light grey top edge over pink bricks with brown mortar">{"".join(swatches(r) for r in walk)}{'<i style="background:var(--c0)"></i>' * 4}</div>
    <span class="ch02-se-soft">the cell's 8th line stays code 00</span>
  </div>
  </div>
  <div class="ch02-se-box">
    <div class="dg-label">shape 1, the walkway, at $6828</div>
    <div class="ch02-se-hdr">
      <span class="dg-byte">01</span><span class="dg-byte">07</span><span class="dg-byte">00</span>
      <span class="dg-label">width</span><span class="dg-label">height</span><span class="dg-label">flags</span>
    </div>
    <div class="dg-label">pixels: width × height bytes, top row first</div>
    <div class="ch02-se-rows">{px_rows}</div>
    <div class="dg-label">colours: one byte per cell, each</div>
    <div class="ch02-se-col">
      <span class="dg-byte">9A</span><span>screen plane: 01 brown, 10 pink</span>
      <span class="dg-byte">0F</span><span>colour RAM: 11 light grey</span>
    </div>
  </div>
</div>
"""

# ---------------------------------------------------------------- 5. double buffer
R0 = ["........", "...33...", "..3333..", ".333333.", "..1111..", "..11.1..", "..11111.", "...111..",
      "...22...", "..2222..", ".222222.", ".222222.", ".1.22.1.", "..3333..", "..2222..", "..2..2..",
      "..2..2..", "..2..2..", "..2..2..", "..3..3..", "..33.33."]
R1 = ["........", "...33...", "..3333..", ".333333.", "..1111..", "..11.1..", "..11111.", "...111..",
      "...22...", "..2222..", ".222222.", "..22222.", "..1221..", "..3333..", "..2222..", "..2..2..",
      ".2...2..", ".2....2.", ".2....2.", ".3....3.", ".33...33"]
SPR = {"1": "c10", "2": "c1", "3": "c8"}  # 01 skin (pink), 10 own colour (white), 11 orange

def sprite_svg(rows, w, cls="", split=None):
    rects = []
    for y, row in enumerate(rows):
        x = 0
        while x < 8:
            ch = row[x]
            if ch == ".":
                x += 1
                continue
            n = 1
            while x + n < 8 and row[x + n] == ch:
                n += 1
            rects.append(f'<rect x="{x * 2}" y="{y}" width="{n * 2}" height="1" style="fill:var(--{SPR[ch]})"/>')
            x += n
    line = ""
    if split is not None:
        line = f'<line x1="-1" x2="17" y1="{split}" y2="{split}" style="stroke:var(--accent);stroke-width:.35;stroke-dasharray:1 .6"/>'
    h = w * 21 / 16
    return (f'<svg class="{cls}" viewBox="0 0 16 21" width="{w}" height="{h:g}" shape-rendering="crispEdges" aria-hidden="true">'
            + "".join(rects) + line + "</svg>")

TORN = R0[:16] + R1[16:]
LINES = 312
def pct(line):
    return f"{line / LINES * 100:.3f}%"

def panel(title, ptr, unpack_at, unpack_into, shown_rows, note, verdict, torn=False):
    bar = "" if unpack_at is None else (
        f'<div class="ch02-db-unp" style="top:{pct(unpack_at)};height:{pct(10)}"></div>'
        f'<div class="ch02-db-unl" style="top:{pct(unpack_at - 3)}">unpack<br>→ block {unpack_into}</div>')  # 630 cycles = 10 lines
    return f"""
  <div class="ch02-db-p">
    <div class="dg-label">{title}</div>
    <div class="ch02-db-scr">
      <div class="ch02-db-disp"></div>
      <div class="ch02-db-floor"></div>
      <div class="ch02-db-ptr">$CFF8 ← {ptr}</div>
      <div class="ch02-db-spr">{sprite_svg(shown_rows, 16)}</div>
      {bar}
    </div>
    <div class="ch02-db-out">{sprite_svg(shown_rows, 32, split=16 if torn else None)}<span>{note}<br><b>{verdict}</b></span></div>
  </div>"""

dbl = f"""<style>
.ch02-db {{ display: flex; flex-wrap: wrap; gap: 16px; }}
.ch02-db-p {{ flex: 1 1 92px; max-width: 200px; display: grid; gap: 8px; align-content: start; }}
.ch02-db-scr {{ position: relative; height: 312px; background: var(--code-bg); box-shadow: 0 0 0 1px var(--rule); border-radius: 4px; }}
.ch02-db-disp {{ position: absolute; left: 10px; right: 10px; top: {pct(51)}; height: {pct(200)}; background: var(--c0); }}
.ch02-db-floor {{ position: absolute; left: 10px; right: 10px; top: {pct(51 + 192)}; height: {pct(7)}; background: var(--c10); border-top: 1px solid var(--c15); }}
.ch02-db-ptr {{ position: absolute; left: 0; right: 0; top: 0; padding: 3px 8px; border-top: 2px solid var(--accent); font-size: .72rem; }}
.ch02-db-spr {{ position: absolute; left: calc(50% - 8px); top: {pct(51 + 171)}; line-height: 0; }}
.ch02-db-spr svg {{ display: block; }}
.ch02-db-unp {{ position: absolute; left: 4px; right: 4px; background: color-mix(in srgb, var(--accent) 18%, transparent); box-shadow: 0 0 0 1px var(--accent); }}
.ch02-db-unl {{ position: absolute; right: 4px; transform: translateY(-100%); text-align: right; font-size: .68rem; line-height: 1.25; color: var(--ink); background: var(--sheet); padding: 1px 4px; border-radius: 3px; }}
.ch02-db-out {{ display: flex; flex-wrap: wrap; gap: 6px 10px; align-items: center; font-size: .72rem; line-height: 1.35; }}
.ch02-db-out svg {{ flex: none; background: var(--c0); padding: 3px; box-sizing: content-box; }}
.ch02-db-out b {{ color: var(--accent); font-weight: 600; }}
.ch02-db-key {{ display: grid; grid-template-columns: max-content 1fr; gap: 3px 10px; }}
.ch02-db-key b {{ font-weight: 600; }}
</style>
<div class="ch02-db">{panel("frame N", 0, 230, 8, R0, "beam reads block 0", "whole (block 8 is hidden)")}{panel("frame N + 1", 8, None, None, R1, "beam reads block 8", "whole, and new")}{panel("one block", 0, 230, 0, TORN, "beam and unpack share block 0", "torn at the knees", torn=True)}
</div>
<div class="ch02-db-key">
  <b>top to bottom</b><span>one frame's 312 raster lines; the black area is the display</span>
  <b>$CFF8 ← n</b><span>show() points sprite 0 at block n, on line 0</span>
  <b>band</b><span>a busy frame's unpack: 630 cycles, lines 230–240, while the beam crosses him</span>
</div>
"""

for name, html in [("ch02-fat-pixels", fat), ("ch02-cell-order", cells), ("ch02-row-table", table),
                   ("ch02-shape-entry", shape), ("ch02-double-buffer", dbl)]:
    (OUT / f"{name}.html").write_text(html)
    print("wrote", name)
