# Generate site/page/diagrams/ch01-beam.html: the beam sweeping the 312
# raster lines, twice: a frame that writes first, and one that writes late.
import re
SRC = '/home/user/dr-creep-in-zig/site/code/ch01/src/player.zig'
OUT = '/home/user/dr-creep-in-zig/site/page/diagrams/ch01-beam.html'
t = open(SRC).read()
body = t[t.index('const picture'):t.index('};', t.index('const picture'))]
bits = re.findall(r'0b([01]{8})', body)
rows = [''.join(bits[i*3:i*3+3]) for i in range(21)]

T = 2            # y of raster line 0
def y(line): return T + line
SX, SL = 168, 88  # explorer: sprite X 160 -> picture x 168; sprite Y 87 -> raster 88
WRITE = 95        # late write: m.work(6000) first puts the beam on line 95
LAP = 6           # seconds per lap (slow motion: really a fiftieth of a second)

def explorer(lo=0, hi=21):
    d = []
    for r in range(lo, hi):
        row = rows[r]; c = 0
        while c < 24:
            if row[c] == '1':
                s = c
                while c < 24 and row[c] == '1': c += 1
                d.append(f'M{SX+s} {y(SL+r)}h{c-s}v1h-{c-s}z')
            else: c += 1
    return ''.join(d)

ZX, ZY, Z = 244, 146, 4   # close-up: 4x, top-left at (244, line 146)
def zoomed(lo=0, hi=21):
    d = []
    for r in range(lo, hi):
        row = rows[r]; c = 0
        while c < 24:
            if row[c] == '1':
                s = c
                while c < 24 and row[c] == '1': c += 1
                d.append(f'M{ZX+s*Z} {y(ZY)+r*Z}h{(c-s)*Z}v{Z}h-{(c-s)*Z}z')
            else: c += 1
    return ''.join(d)

def closeup(paths):
    return (f'<rect style="fill:var(--c0);stroke:var(--c15)" x="{ZX-4}" y="{y(ZY)-4}" width="{24*Z+8}" height="{21*Z+8}"/>' + paths)

def picture(cls_explorer):
    return f'''<rect class="ch01-beam-off" x="0" y="{y(0)}" width="384" height="15"/>
<rect class="ch01-beam-off" x="0" y="{y(287)}" width="384" height="25"/>
<rect style="fill:var(--c6)" x="0" y="{y(15)}" width="384" height="272"/>
<rect style="fill:var(--c0)" x="32" y="{y(51)}" width="320" height="200"/>
<rect style="fill:var(--c12)" x="32" y="{y(243)}" width="320" height="8"/>
{cls_explorer}'''

def pill(x, line, text, cls=''):
    w = round(len(text) * 6.6 + 10)
    return (f'<g class="ch01-beam-pill {cls}"><rect x="{x}" y="{y(line) - 7}" width="{w}" height="14" rx="3"/>'
            f'<text x="{x + 5}" y="{y(line) + 4}" font-size="11">{text}</text></g>')

full = explorer()
top, bottom = explorer(0, WRITE - SL), explorer(WRITE - SL, 21)

svg = f'''<svg class="ch01-beam-tube" viewBox="0 -8 384 338" width="384" role="img" aria-labelledby="ch01-beam-t">
<title id="ch01-beam-t">The picture drawn by a beam sweeping 312 raster lines from top to bottom: off the tube, the top border, the display from line 51, the bottom border. In the first lap frame() writes the explorer's new colour at line 0 and he is drawn red all over; in the second it writes at line 95, while the beam is partway down him, so his top rows are drawn white and the rest red.</title>
<defs><clipPath id="ch01-beam-clip"><rect x="0" y="{y(0)}" width="384" height="312"/></clipPath>
<clipPath id="ch01-beam-zclip"><rect x="{ZX-4}" y="{y(ZY)-4}" width="{24*Z+8}" height="{21*Z+8}"/></clipPath></defs>
<g class="ch01-beam-lap1">{picture(f'<path style="fill:var(--c2)" d="{full}"/>')}</g>
<g class="ch01-beam-lap2">{picture(f'<path style="fill:var(--c1)" d="{top}"/><path style="fill:var(--c2)" d="{bottom}"/>')}</g>
<g class="ch01-beam-sweep" clip-path="url(#ch01-beam-clip)"><g class="ch01-beam-back">
{picture(f'<path style="fill:var(--c1)" d="{full}"/>')}
<rect class="ch01-beam-veil" x="0" y="{y(0)}" width="384" height="312"/>
</g></g>
<g class="ch01-beam-lap1">{closeup(f'<path style="fill:var(--c2)" d="{zoomed()}"/>')}</g>
<g class="ch01-beam-lap2">{closeup(f'<path style="fill:var(--c1)" d="{zoomed(0, WRITE - SL)}"/><path style="fill:var(--c2)" d="{zoomed(WRITE - SL, 21)}"/>')}</g>
<g class="ch01-beam-zsweep" clip-path="url(#ch01-beam-zclip)"><g class="ch01-beam-zback">
{closeup(f'<path style="fill:var(--c1)" d="{zoomed()}"/>')}
<rect class="ch01-beam-veil" x="{ZX-4}" y="{y(ZY)-4}" width="{24*Z+8}" height="{21*Z+8}"/>
</g></g>
<line style="stroke:var(--c15)" x1="{SX+24}" y1="{y(SL+10)}" x2="{ZX-4}" y2="{y(ZY)-4}" stroke-dasharray="2 2"/>
<text style="fill:var(--c15)" x="{ZX-4}" y="{y(ZY)-8}" font-size="11">close-up, 4×</text>
<g class="ch01-beam-lap1">
<rect class="ch01-beam-busy" x="372" y="{y(0)}" width="5" height="2"/>
<line class="ch01-beam-write" x1="0" y1="{y(1)}" x2="384" y2="{y(1)}"/>
{pill(126, 7, "frame() starts, show() writes: line 0")}
</g>
<g class="ch01-beam-lap2">
<rect class="ch01-beam-busy" x="372" y="{y(0)}" width="5" height="{WRITE + 1}"/>
<line class="ch01-beam-write" x1="32" y1="{y(WRITE)}" x2="352" y2="{y(WRITE)}"/>
<line class="ch01-beam-write" x1="{ZX-4}" y1="{y(ZY)+(WRITE-SL)*Z}" x2="{ZX+24*Z+4}" y2="{y(ZY)+(WRITE-SL)*Z}"/>
{pill(218, 7, "frame() starts: line 0")}
{pill(186, 33, "frame() busy: a big job")}
{pill(200, WRITE, "show() writes: line 95")}
</g>
<text class="soft" x="6" y="{y(11)}" font-size="11">off the tube</text>
<text style="fill:var(--c1)" x="6" y="{y(37)}" font-size="11">top border</text>
<text style="fill:var(--c1)" x="40" y="{y(66)}" font-size="11">display: line 51 is row 0</text>
<text style="fill:var(--c1)" x="6" y="{y(273)}" font-size="11">bottom border</text>
<text class="soft" x="6" y="{y(303)}" font-size="11">off the tube</text>
<g class="ch01-beam-sweep"><line class="ch01-beam-glow" x1="0" y1="{y(0)}" x2="384" y2="{y(0)}"/><line class="ch01-beam-ray" x1="0" y1="{y(0)}" x2="384" y2="{y(0)}"/>
<text style="fill:var(--c7)" x="380" y="{y(0) - 4}" font-size="11" text-anchor="end">the beam</text></g>
<text class="soft" x="0" y="{y(312) + 6}" font-size="10" dominant-baseline="hanging">312 lines, top to bottom, 50 times a second</text>
</svg>'''

css = f'''<style>
.ch01-beam {{ display: flex; flex-wrap: wrap; gap: 16px 24px; align-items: flex-start; }}
.ch01-beam .ch01-beam-tube {{ flex: 1 1 340px; width: 100%; max-width: min(480px, 100%); }}
.ch01-beam-off {{ fill: var(--code-bg); }}
.ch01-beam-veil {{ fill: var(--sheet); opacity: .5; }}
.ch01-beam-ray {{ stroke: var(--c7); stroke-width: 2; }}
.ch01-beam-glow {{ stroke: var(--c7); stroke-width: 7; opacity: .35; }}
.ch01-beam-write {{ stroke: var(--c13); stroke-width: 1.5; stroke-dasharray: 4 3; }}
.ch01-beam-busy {{ fill: var(--c13); }}
.ch01-beam-pill rect {{ fill: var(--sheet); stroke: var(--c13); stroke-width: 1; }}
.ch01-beam-pill text {{ fill: var(--ink); }}
.ch01-beam-sweep {{ animation: ch01-beam-down {LAP}s linear infinite; }}
.ch01-beam-back {{ animation: ch01-beam-up {LAP}s linear infinite; }}
@keyframes ch01-beam-down {{ from {{ transform: translateY(0); }} to {{ transform: translateY(312px); }} }}
@keyframes ch01-beam-zdown {{ 0%, {SL/312*100:.3f}% {{ transform: translateY(0); }} {(SL+21)/312*100:.3f}%, 100% {{ transform: translateY({21*Z+4}px); }} }}
@keyframes ch01-beam-zup {{ 0%, {SL/312*100:.3f}% {{ transform: translateY(0); }} {(SL+21)/312*100:.3f}%, 100% {{ transform: translateY(-{21*Z+4}px); }} }}
.ch01-beam-zsweep {{ animation: ch01-beam-zdown {LAP}s linear infinite; }}
.ch01-beam-zback {{ animation: ch01-beam-zup {LAP}s linear infinite; }}
@keyframes ch01-beam-up {{ from {{ transform: translateY(0); }} to {{ transform: translateY(-312px); }} }}
.ch01-beam-lap1 {{ animation: ch01-beam-one {2*LAP}s linear infinite; }}
.ch01-beam-lap2 {{ animation: ch01-beam-two {2*LAP}s linear infinite; }}
@keyframes ch01-beam-one {{ 0%, 49.9% {{ opacity: 1; }} 50%, 100% {{ opacity: 0; }} }}
@keyframes ch01-beam-two {{ 0%, 49.9% {{ opacity: 0; }} 50%, 100% {{ opacity: 1; }} }}
.ch01-beam-notes {{ flex: 1 1 220px; display: flex; flex-direction: column; gap: 10px; min-width: 0; }}
.ch01-beam-lap {{ padding: 8px 10px; border-radius: 6px; box-shadow: inset 0 0 0 1.5px var(--rule); }}
.ch01-beam-lap b {{ display: block; font: 400 .66rem/1.3 var(--display); letter-spacing: .1em; text-transform: uppercase; margin-bottom: 3px; }}
.ch01-beam-lap p {{ margin: 0; font: .78rem/1.45 var(--body); color: var(--ink-soft); }}
.ch01-beam-notes .ch01-beam-lap1, .ch01-beam-notes .ch01-beam-lap2 {{ animation-name: ch01-beam-card1; }}
.ch01-beam-notes .ch01-beam-lap2 {{ animation-name: ch01-beam-card2; }}
@keyframes ch01-beam-card1 {{ 0%, 49.9% {{ opacity: 1; box-shadow: inset 0 0 0 2px var(--c13); }} 50%, 100% {{ opacity: .45; box-shadow: inset 0 0 0 1.5px var(--rule); }} }}
@keyframes ch01-beam-card2 {{ 0%, 49.9% {{ opacity: .45; box-shadow: inset 0 0 0 1.5px var(--rule); }} 50%, 100% {{ opacity: 1; box-shadow: inset 0 0 0 2px var(--c13); }} }}
.ch01-beam-key {{ display: flex; flex-direction: column; gap: 4px; font: .74rem/1.4 var(--body); color: var(--ink-soft); }}
.ch01-beam-key span {{ display: flex; gap: 8px; align-items: center; }}
.ch01-beam-key i {{ flex: none; width: 18px; height: 10px; border-radius: 2px; box-shadow: inset 0 0 0 1px var(--rule); }}
</style>'''

notes = '''<div class="ch01-beam-notes" data-animate>
<div class="ch01-beam-lap ch01-beam-lap1"><b>Lap 1: write first</b><p>Fire was pressed, so this frame he turns from white to red. <code>frame()</code> starts with the beam at line 0, above the border, and <code>show()</code> writes the new colour straight away. The beam reaches him long after: he's red from hat to boots.</p></div>
<div class="ch01-beam-lap ch01-beam-lap2"><b>Lap 2: write late</b><p>The same frame, with a big job before <code>show()</code>. The colour changes at line 95, with the beam partway down him. The rows above it were already drawn white; the rest come out red. That's a tear.</p></div>
<div class="ch01-beam-key">
<span><i style="background:var(--c7)"></i>the beam, slowed right down</span>
<span><i style="background:var(--c13)"></i>frame() running, and where it writes</span>
<span><i style="background:color-mix(in srgb, var(--sheet) 50%, var(--c6))"></i>not drawn yet: still last frame's picture</span>
</div>
</div>'''

open(OUT, 'w').write(css + '\n<div class="ch01-beam">\n' + svg + '\n' + notes + '\n</div>\n')
print('wrote', OUT)
