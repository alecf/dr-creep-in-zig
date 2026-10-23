import sys; sys.path.insert(0,'.')
from grid import build
g=build()
HR,HC=16,24
walk={(16,c) for c in range(20,40)}|{(24,c) for c in range(0,40)}
lad={(r,24) for r in range(16,25)}
cells=[]
for r in range(25):
    for c in range(40):
        if (r,c)==(HR,HC): cls='h'
        elif (r,c) in lad: cls='l'
        elif (r,c) in walk: cls='w'
        else: cls=''
        cells.append(f'<i class="{cls}"></i>' if cls else '<i></i>')
grid2d=''.join(cells)
segs=''.join(f'<i{" class=h" if r==HR else ""}></i>' for r in range(25))
row=''.join(f'<i{" class=h" if c==HC else ""}></i>' for c in range(40))
html=f'''<style>
.ch04-flat {{ display: grid; gap: 16px; }}
.ch04-flat .ch04-2d {{ display: grid; grid-template-columns: auto auto; gap: 4px 6px; justify-content: start; }}
.ch04-flat .ch04-room {{ display: grid; grid-template-columns: repeat(40, 7px); grid-auto-rows: 7px; gap: 0; background: var(--c0); box-shadow: 0 0 0 1px var(--rule); }}
.ch04-flat .ch04-room i {{ display: block; box-shadow: inset 0 0 0 .5px var(--c11); }}
.ch04-flat .ch04-room i.w {{ background: var(--c4); }}
.ch04-flat .ch04-room i.l {{ background: var(--c12); }}
.ch04-flat .ch04-room i.h {{ background: var(--c7); box-shadow: 0 0 0 2px var(--accent); position: relative; z-index: 1; }}
.ch04-flat .ch04-cols {{ grid-column: 2; position: relative; height: 1.2em; font-size: .7rem; color: var(--ink-soft); }}
.ch04-flat .ch04-cols span {{ position: absolute; transform: translateX(-50%); white-space: nowrap; }}
.ch04-flat .ch04-rows {{ position: relative; width: 3.2em; font-size: .7rem; color: var(--ink-soft); }}
.ch04-flat .ch04-rows span {{ position: absolute; right: 0; transform: translateY(-50%); white-space: nowrap; }}
.ch04-flat .ch04-hl {{ color: var(--accent); font-weight: 700; }}
.ch04-flat .ch04-strip {{ display: grid; grid-template-columns: repeat(25, 1fr); height: 18px; gap: 1px; max-width: 34em; }}
.ch04-flat .ch04-strip i {{ display: block; background: var(--code-bg); box-shadow: inset 0 0 0 1px var(--rule); }}
.ch04-flat .ch04-strip i.h {{ background: var(--accent); box-shadow: none; }}
.ch04-flat .ch04-row16 {{ display: grid; grid-template-columns: repeat(40, 1fr); height: 18px; gap: 1px; max-width: 34em; }}
.ch04-flat .ch04-row16 i {{ display: block; background: var(--code-bg); box-shadow: inset 0 0 0 1px var(--rule); }}
.ch04-flat .ch04-row16 i.h {{ background: var(--accent); box-shadow: none; }}
.ch04-flat .ch04-ticks {{ position: relative; height: 1.3em; font-size: .7rem; color: var(--ink-soft); max-width: 34em; }}
.ch04-flat .ch04-ticks span {{ position: absolute; transform: translateX(-50%); white-space: nowrap; }}
.ch04-flat .ch04-sum {{ font-size: .8rem; }}
</style>
<div class="ch04-flat">
  <div>
    <div class="dg-label">The grid as the room sees it: 40 × 25 cells</div>
    <div class="ch04-2d">
      <span></span>
      <div class="ch04-cols"><span style="left:3.5px">0</span><span style="left:171.5px" class="ch04-hl">col 24</span><span style="left:276.5px">39</span></div>
      <div class="ch04-rows"><span style="top:3.5px">0</span><span style="top:115.5px" class="ch04-hl">row 16</span><span style="top:171.5px">24</span></div>
      <div class="ch04-room">{grid2d}</div>
    </div>
  </div>
  <div>
    <div class="dg-label">The same grid in memory: 1,000 bytes, a row after a row</div>
    <div class="ch04-strip">{segs}</div>
    <div class="ch04-ticks"><span style="left:0;transform:none">row 0</span><span style="left:66%" class="ch04-hl">row 16: bytes 640–679</span><span style="left:100%;transform:translateX(-100%)">row 24</span></div>
    <div class="ch04-row16">{row}</div>
    <div class="ch04-ticks"><span style="left:0;transform:none">640</span><span style="left:61.25%" class="ch04-hl">664</span><span style="left:100%;transform:translateX(-100%)">679</span></div>
  </div>
  <div class="ch04-sum">16 × 40 + 24 = <b class="ch04-hl">664</b> bytes in: <b>$C800</b> + 664 = <b class="ch04-hl">$CA98</b></div>
</div>
'''
open('/home/user/dr-creep-in-zig/site/page/diagrams/ch04-flat-grid.html','w').write(html)
