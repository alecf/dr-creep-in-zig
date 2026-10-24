"""Generate the Chapter 2 diagrams into site/page/diagrams/ch02-*.html.

    python3 site/tools/diagrams/ch02/gen.py                     # every figure
    python3 site/tools/diagrams/ch02/gen.py ch02-double-buffer  # just that one
"""
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[3] / "page" / "diagrams"

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
# Animated: two frames in slow motion, the same beam over two set-ups side by
# side. Frame N: sprite 0 shows block 0 and a busy frame unpacks the next
# stride (explorer_right_1) at lines 230-240 (630 cycles = 10 lines). With two
# blocks it goes into block 8 (0 ^ 8) and he's drawn whole; with one it goes
# into block 0 under the beam, overtakes it at row 16, and he tears at the
# knees. Frame N+1: line 0, show() flips the pointer, and he's drawn whole.
ART2 = (pathlib.Path(__file__).resolve().parents[3] / "code/ch02/src/art.zig").read_text()

def frame_art(name):
    import re
    m = re.search(r"pub const %s = frame\(\.white, &\.\{(.*?)\}\);" % name, ART2, re.S)
    return re.findall(r'"([.123]+)"', m.group(1))

R0 = frame_art("explorer_right_0")
R1 = frame_art("explorer_right_1")
R3 = frame_art("explorer_right_3")  # the stride before 0: what's stale in block 8
SPR = {"1": "c10", "2": "c1", "3": "c8"}  # 01 skin (pink), 10 own colour (white), 11 orange
TEAR = 16  # the row the unpack overtakes the beam (see Chapter 2's "Make it tear")
TORN = R0[:TEAR] + R1[TEAR:]

def sprite_svg(rows, w, cls=""):
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
    h = w * 21 / 16
    c = f' class="{cls}"' if cls else ""
    return (f'<svg{c} viewBox="0 0 16 21" width="{w}" height="{h:g}" shape-rendering="crispEdges" aria-hidden="true">'
            + "".join(rects) + "</svg>")

# ---- the clock: raster lines in frame N (0) and N+1 (1) -> seconds
LINES = 312
SPR_TOP = 51 + 171        # sprite row 0 on raster line 222 (display line 0 is raster 51)
UNP0, UNP1 = 230, 240     # the busy frame's unpack: 630 cycles = 10 lines
SEGS = [(0, 215, 1.3), (215, 250, 5.2), (250, LINES - 1, 0.9)]  # slow motion around him
HOLD = (1.2, 2.0)         # line 0 of each frame: show() runs
END_HOLD = 1.8

def frame_start(f):
    t = 0.0
    for g in range(f):
        t += HOLD[g] + sum(s[2] for s in SEGS)
    return t

def T(f, line):
    """Seconds into the loop when the beam reaches `line` of frame f."""
    t = frame_start(f) + HOLD[f]
    for a, b, d in SEGS:
        if line <= b:
            return t + d * (line - a) / (b - a)
        t += d
    return t

TOTAL = frame_start(2) + END_HOLD
def P(t):
    return f"{t / TOTAL * 100:.3f}%"
EPS = 0.004  # seconds: a jump between two keyframes

kf = []   # generated @keyframes
anim = []  # generated rules that use them
def keyframes(name, frames, timing="step-end"):
    """frames: [(t, css)]; holds each value until the next (step-end)."""
    body = " ".join(f"{P(t)} {{ {css} }}" for t, css in frames)
    kf.append(f"@keyframes {name} {{ {body} }}")
    anim.append(f".ch02-db .{name} {{ animation: {name} {TOTAL:.2f}s {timing} infinite; }}")

def shown_during(name, spans):
    """Visible only during [a, b) spans."""
    fr = [(0, "opacity: 0")]
    for a, b in spans:
        fr += [(a, "opacity: 1"), (b, "opacity: 0")]
    fr.append((TOTAL, "opacity: 0" if spans[-1][1] < TOTAL else "opacity: 1"))
    if spans[0][0] == 0:
        fr[0] = (0, "opacity: 1")
        fr.pop(1)
    keyframes(name, fr)

def reveal(name, a, b, hide_at=TOTAL):
    """A picture drawn top row first, a row at a time from a to b, kept until hide_at."""
    shut, full = "clip-path: inset(0 0 100% 0)", "clip-path: inset(0 0 0 0)"
    fr = [(0, shut + "; animation-timing-function: step-end"),
          (a, shut + "; animation-timing-function: steps(21, end)"),
          (b, full + "; animation-timing-function: step-end"),
          (hide_at, shut), (TOTAL, shut)]
    keyframes(name, fr)

def sweep(name, a, b):
    """A row marker moving from the top to the bottom of a block from a to b."""
    keyframes(name, [(0, "opacity: 0; top: 0%"), (a, "opacity: 1; top: 0%; animation-timing-function: linear"),
                     (b, "opacity: 1; top: 100%; animation-timing-function: step-end"), (b + EPS, "opacity: 0; top: 100%"),
                     (TOTAL, "opacity: 0; top: 100%")])

# the beam, and the line number it's on
pts = [(0, 0)]
for f in range(2):
    pts.append((T(f, 0), 0))
    for a, b, d in SEGS:
        pts.append((T(f, b), b))
    if f == 0:
        pts.append((T(f, LINES - 1) + EPS, 0))
pts.append((TOTAL, LINES - 1))
keyframes("ch02-db-beam", [(t, f"top: {l / LINES * 100:.3f}%; animation-timing-function: linear") for t, l in pts])
keyframes("ch02-db-ln", [(t, f"--ch02-db-line: {l}; animation-timing-function: linear") for t, l in pts])

F1 = T(1, 0) - HOLD[1]  # frame N+1 begins
DRAW = [(T(f, SPR_TOP), T(f, SPR_TOP + 21)) for f in range(2)]
UNPACK = (T(0, UNP0), T(0, UNP1))
shown_during("ch02-db-fN", [(0, F1)])
shown_during("ch02-db-fN1", [(F1, TOTAL)])
shown_during("ch02-db-flip", [(F1, T(1, 0))])
shown_during("ch02-db-band", [UNPACK])
# what the beam has drawn on screen: frame N's picture, then frame N+1's over it
reveal("ch02-db-drawN", *DRAW[0])
reveal("ch02-db-drawN1", *DRAW[1])
reveal("ch02-db-fill", *UNPACK)
sweep("ch02-db-readN", *DRAW[0])
sweep("ch02-db-readN1", *DRAW[1])
sweep("ch02-db-write", *UNPACK)
shown_during("ch02-db-tear", [(T(0, SPR_TOP + TEAR), T(1, SPR_TOP + TEAR))])

NOTE = [0]
def notes(cards):
    """[(until, text)]: one note at a time, each until the next begins."""
    out, start = [], 0
    for until, text in cards:
        NOTE[0] += 1
        shown_during(f"ch02-db-n{NOTE[0]}", [(start, until)])
        out.append(f'<p class="ch02-db-n{NOTE[0]}">{text}</p>')
        start = until
    return '<div class="ch02-db-notes">' + "".join(out) + "</div>"

STEPS = [T(0, SPR_TOP), UNPACK[0], UNPACK[1], F1, T(1, 0), T(1, SPR_TOP), DRAW[1][1], TOTAL]
notes_two = notes(list(zip(STEPS, [
    "show() has pointed sprite 0 at block 0. The beam sweeps down.",
    "The beam reaches him: it reads block 0, a row a line.",
    "Busy frame: the next stride is unpacked into block 8 (0 ^ 8). The beam never reads it.",
    "He's drawn whole from block 0. Block 8 waits, finished.",
    "Line 0: show() writes 8 to $CFF8. One byte, and the flip is done.",
    "The beam sweeps down to him.",
    "It reads block 8: the new stride, whole.",
    "Block 0 is the hidden one now (8 ^ 8): the next unpack goes there.",
])))
notes_one = notes(list(zip(STEPS, [
    "One block: sprite 0 shows block 0, so the unpack must go there too.",
    "The beam reaches him: it reads block 0, a row a line.",
    "The unpack rewrites block 0 under the beam, about two rows a line. At row 16 it overtakes.",
    "Above his knees, the old stride; below, the new. Torn.",
    "Line 0: $CFF8 ← 0 again. There's nowhere else to point.",
    "The beam sweeps down to him.",
    "Block 0 is finished now, so he's whole again, a frame late.",
    "Every busy frame that changes his stride tears him like this.",
])))

def stack(base, layers, w):
    """A picture with later pictures drawn over it, each layer `(rows, cls)`."""
    return (f'<span class="ch02-db-stack">{sprite_svg(base, w)}'
            + "".join(sprite_svg(r, w, c) for r, c in layers) + "</span>")

def block(n, base, layers, reads, writes, tags):
    marks = "".join(f'<i class="ch02-db-read {c}"><b>beam</b></i>' for c in reads)
    marks += "".join(f'<i class="ch02-db-wr {c}"><b>unpack</b></i>' for c in writes)
    tag = "".join(f'<span class="ch02-db-tag {c}{" ch02-db-on" if t == "shown" else ""}">{t}</span>' for t, c in tags)
    return (f'<div class="ch02-db-blk"><div class="ch02-db-bh"><span class="dg-label">block {n}</span><span class="ch02-db-tags">{tag}</span></div>'
            f'<div class="ch02-db-pic"><div class="ch02-db-in">{stack(base, layers, 48)}{marks}</div></div></div>')

def screen(ptrs, unp_into, small):
    ptr = "".join(f'<span class="{c}">$CFF8 ← {v}</span>' for v, c in ptrs)
    return f"""<div class="ch02-db-scr">
      <div class="ch02-db-disp"></div>
      <div class="ch02-db-floor"></div>
      <div class="ch02-db-ptr"><span class="ch02-db-pv">{ptr}</span></div>
      <i class="ch02-db-flash ch02-db-flip"></i>
      <div class="ch02-db-spr">{small}</div>
      <div class="ch02-db-unp ch02-db-band"></div>
      <div class="ch02-db-unl ch02-db-band">unpack<br>→ block {unp_into}</div>
      <i class="ch02-db-beam"></i>
    </div>"""

def result(base, layers, tear=False):
    t = '<i class="ch02-db-tearl ch02-db-tear"></i>' if tear else ""
    tag = '<span class="ch02-db-tags"><span class="ch02-db-tag ch02-db-bad ch02-db-tear">torn at the knees</span></span>' if tear else ""
    reads = '<i class="ch02-db-read ch02-db-readN"><b>beam</b></i><i class="ch02-db-read ch02-db-readN1"><b>beam</b></i>'
    return (f'<div class="ch02-db-blk"><div class="ch02-db-bh"><span class="dg-label">on screen</span>{tag}</div>'
            f'<div class="ch02-db-pic"><div class="ch02-db-in">{stack(base, layers, 48)}{t}{reads}</div></div></div>')

two = f"""<div class="ch02-db-case" aria-label="Two blocks: block 8 is unpacked while the beam reads block 0, then the pointer flips">
    <div class="dg-label">two blocks</div>
    <div class="ch02-db-body">
    {screen([(0, "ch02-db-fN"), (8, "ch02-db-fN1")], 8, stack(R0, [(R0, "ch02-db-drawN"), (R1, "ch02-db-drawN1")], 16))}
    <div class="ch02-db-col">
      {block(0, R0, [], ["ch02-db-readN"], [], [("shown", "ch02-db-fN"), ("hidden", "ch02-db-fN1")])}
      {block(8, R3, [(R1, "ch02-db-fill")], ["ch02-db-readN1"], ["ch02-db-write"], [("hidden", "ch02-db-fN"), ("shown", "ch02-db-fN1")])}
      {result(R0, [(R0, "ch02-db-drawN"), (R1, "ch02-db-drawN1")])}
    </div>
    </div>
    {notes_two}
  </div>"""
one = f"""<div class="ch02-db-case" aria-label="One block: the unpack rewrites block 0 while the beam reads it, and he tears at the knees">
    <div class="dg-label">one block</div>
    <div class="ch02-db-body">
    {screen([(0, "ch02-db-fN"), ("0", "ch02-db-fN1")], 0, stack(R0, [(TORN, "ch02-db-drawN"), (R1, "ch02-db-drawN1")], 16))}
    <div class="ch02-db-col">
      {block(0, R0, [(R1, "ch02-db-fill")], ["ch02-db-readN", "ch02-db-readN1"], ["ch02-db-write"], [("shown", "")])}
      {result(R0, [(TORN, "ch02-db-drawN"), (R1, "ch02-db-drawN1")], tear=True)}
    </div>
    </div>
    {notes_one}
  </div>"""

def pct(line):
    return f"{line / LINES * 100:.3f}%"

css = f"""@property --ch02-db-line {{ syntax: '<integer>'; inherits: false; initial-value: 0; }}
.ch02-db {{ display: grid; gap: 14px; }}
.ch02-db-clock {{ display: flex; flex-wrap: wrap; gap: 4px 14px; align-items: baseline; }}
.ch02-db-fr {{ display: inline-grid; }}
.ch02-db-fr > * {{ grid-area: 1 / 1; }}
.ch02-db-clock b {{ font-weight: 600; }}
.ch02-db-ln {{ counter-reset: ch02l var(--ch02-db-line); font-variant-numeric: tabular-nums; }}
.ch02-db-ln::after {{ content: counter(ch02l); }}
.ch02-db-cases {{ display: flex; flex-wrap: wrap; gap: 18px 26px; }}
.ch02-db-case {{ flex: 0 1 290px; min-width: 0; display: grid; gap: 8px; align-content: start; }}
.ch02-db-body {{ display: flex; gap: 12px; align-items: flex-start; }}
.ch02-db-scr {{ position: relative; flex: 0 0 104px; height: 312px; background: var(--code-bg); box-shadow: 0 0 0 1px var(--rule); border-radius: 4px; overflow: hidden; }}
.ch02-db-disp {{ position: absolute; left: 8px; right: 8px; top: {pct(51)}; height: {pct(200)}; background: var(--c0); }}
.ch02-db-floor {{ position: absolute; left: 8px; right: 8px; top: {pct(51 + 192)}; height: {pct(7)}; background: var(--c10); border-top: 1px solid var(--c15); }}
.ch02-db-ptr {{ position: absolute; left: 0; right: 0; top: 0; padding: 3px 6px; font-size: .7rem; z-index: 1; }}
.ch02-db-pv {{ display: inline-grid; }}
.ch02-db-pv > span {{ grid-area: 1 / 1; }}
.ch02-db-flash {{ position: absolute; left: 0; right: 0; top: 0; height: 1.5rem; background: color-mix(in srgb, var(--accent) 22%, transparent); box-shadow: inset 0 0 0 1.5px var(--accent); border-radius: 4px 4px 0 0; }}
.ch02-db-spr {{ position: absolute; left: 22px; top: {pct(SPR_TOP)}; line-height: 0; }}
.ch02-db-unp {{ position: absolute; left: 4px; right: 4px; top: {pct(UNP0)}; height: {pct(UNP1 - UNP0)}; background: color-mix(in srgb, var(--accent) 30%, transparent); box-shadow: 0 0 0 1px var(--accent); }}
.ch02-db-unl {{ position: absolute; right: 3px; top: {pct(UNP0 - 3)}; transform: translateY(-100%); text-align: right; font-size: .64rem; line-height: 1.2; color: var(--ink); background: var(--sheet); padding: 1px 3px; border-radius: 3px; box-shadow: 0 0 0 1px var(--accent); }}
.ch02-db-beam {{ position: absolute; left: 0; right: 0; top: 0; height: 2px; margin-top: -1px; background: var(--accent); box-shadow: 0 0 6px 1px var(--accent); }}
.ch02-db-col {{ flex: 1 1 auto; min-width: 0; display: grid; gap: 10px; align-content: start; }}
.ch02-db-blk {{ display: grid; gap: 3px; }}
.ch02-db-bh {{ display: flex; flex-wrap: wrap; gap: 0 8px; align-items: baseline; }}
.ch02-db-bh > .dg-label {{ white-space: nowrap; }}
.ch02-db-tags {{ display: inline-grid; }}
.ch02-db-tag {{ grid-area: 1 / 1; font-size: .66rem; color: var(--ink-soft); }}
.ch02-db-tag.ch02-db-on, .ch02-db-tag.ch02-db-bad {{ color: var(--accent); font-weight: 600; }}
.ch02-db-pic {{ position: relative; justify-self: start; margin-left: 36px; margin-right: 52px; padding: 3px; background: var(--c0); box-shadow: 0 0 0 1px var(--rule); line-height: 0; }}
.ch02-db-in {{ position: relative; }}
.ch02-db-stack {{ display: grid; }}
.ch02-db-stack > svg {{ grid-area: 1 / 1; }}
.ch02-db-read, .ch02-db-wr {{ position: absolute; top: 0; height: 0; font-style: normal; line-height: 1; }}
.ch02-db-in > .ch02-db-read {{ left: -39px; right: 0; border-top: 2px solid var(--accent); }}
.ch02-db-in > .ch02-db-wr {{ left: 0; right: -55px; border-top: 2px dashed var(--ink); }}
.ch02-db-read b, .ch02-db-wr b {{ position: absolute; top: -.62rem; font: 600 .6rem/1 var(--mono); padding: 1px 2px; background: var(--sheet); }}
.ch02-db-read b {{ left: 0; color: var(--accent); }}
.ch02-db-wr b {{ right: 0; color: var(--ink); }}
.ch02-db-tearl {{ position: absolute; left: -6px; right: -6px; top: {TEAR / 21 * 100:.3f}%; border-top: 1.5px dashed var(--accent); }}
.ch02-db-notes {{ display: grid; font-size: .74rem; line-height: 1.4; }}
.ch02-db-notes > p {{ grid-area: 1 / 1; margin: 0; }}
.ch02-db-key {{ display: grid; grid-template-columns: max-content 1fr; gap: 3px 10px; font-size: .74rem; }}
.ch02-db-key b {{ font-weight: 600; }}
"""

dbl = f"""<style>
{css}{chr(10).join(kf)}
{chr(10).join(anim)}
</style>
<div class="ch02-db" data-animate>
  <div class="ch02-db-clock"><span class="ch02-db-fr"><b class="ch02-db-fN">frame N</b><b class="ch02-db-fN1">frame N + 1</b></span><span>raster line <b class="ch02-db-ln"></b></span></div>
  <div class="ch02-db-cases">
  {two}
  {one}
  </div>
  <div class="ch02-db-key">
    <b>top to bottom</b><span>one frame's 312 raster lines; the black area is the display, lines 51–250</span>
    <b>$CFF8 ← n</b><span>show() points sprite 0 at block n, on line 0</span>
    <b>^ 8</b><span>the hidden block is the shown one ^ 8: 0 and 8 differ only in bit 3</span>
    <b>band</b><span>a busy frame's unpack: 630 cycles, lines 230–240, while the beam crosses him</span>
    <b>slow motion</b><span>a frame really lasts 1/50 s; the lines around him are slowed down most</span>
  </div>
</div>
"""

if __name__ == "__main__":
    import sys
    want = set(sys.argv[1:])  # e.g. ch02-double-buffer; nothing = every figure
    for name, html in [("ch02-fat-pixels", fat), ("ch02-cell-order", cells), ("ch02-row-table", table),
                       ("ch02-shape-entry", shape), ("ch02-double-buffer", dbl)]:
        if want and name not in want:
            continue
        (OUT / f"{name}.html").write_text(html)
        print("wrote", name)
