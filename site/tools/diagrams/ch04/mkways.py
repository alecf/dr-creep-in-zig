import sys; sys.path.insert(0,'.')
from grid import build
g=build()
C0,C1=19,27; R0,R1=15,24; S=34; L=30; T=18
W=L+(C1-C0+1)*S+2; H=T+(R1-R0+1)*S+2
o=[]
o.append(f'<svg class="ch04-wsvg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Cells of the Ladders room around the ladder, with each cell\'s ways byte">')
for c in range(C0,C1+1):
    x=L+(c-C0)*S+S/2
    o.append(f'<text x="{x}" y="{T-6}" text-anchor="middle" font-size="10" class="soft">{c}</text>')
for r in range(R0,R1+1):
    y=T+(r-R0)*S+S/2+4
    o.append(f'<text x="{L-6}" y="{y}" text-anchor="end" font-size="10" class="soft">{r}</text>')
o.append(f'<rect x="{L}" y="{T}" width="{(C1-C0+1)*S}" height="{(R1-R0+1)*S}" fill="var(--c0)"/>')
walk={(16,c) for c in range(20,40)}|{(24,c) for c in range(0,40)}
lad={(r,24) for r in range(16,25)}
for r in range(R0,R1+1):
    for c in range(C0,C1+1):
        x=L+(c-C0)*S; y=T+(r-R0)*S; v=g[r][c]
        if (r,c) in walk:
            o.append(f'<rect x="{x}" y="{y+1}" width="{S}" height="9" fill="var(--c4)"/>')
        if (r,c) in lad:
            o.append(f'<rect x="{x+9}" y="{y}" width="3" height="{S}" fill="var(--c12)"/><rect x="{x+S-12}" y="{y}" width="3" height="{S}" fill="var(--c12)"/>')
            for k in (6,23): o.append(f'<rect x="{x+9}" y="{y+k}" width="{S-18}" height="2" fill="var(--c12)"/>')
        # ways: yellow triangles at open edges
        cx,cy=x+S/2,y+S/2; a=5
        if v&1: o.append(f'<path d="M{cx-a} {y+a+2}L{cx} {y+2}L{cx+a} {y+a+2}Z" fill="var(--c7)"/>')
        if v&0x10: o.append(f'<path d="M{cx-a} {y+S-a-2}L{cx} {y+S-2}L{cx+a} {y+S-a-2}Z" fill="var(--c7)"/>')
        if v&4: o.append(f'<path d="M{x+S-a-2} {cy-a}L{x+S-2} {cy}L{x+S-a-2} {cy+a}Z" fill="var(--c7)"/>')
        if v&0x40: o.append(f'<path d="M{x+a+2} {cy-a}L{x+2} {cy}L{x+a+2} {cy+a}Z" fill="var(--c7)"/>')
        col='var(--c1)' if v else 'var(--c11)'
        o.append(f'<text x="{cx}" y="{cy+4}" text-anchor="middle" font-size="11" font-weight="700" style="fill:{col}">{v:02X}</text>')
# cell lines
for c in range(C0,C1+2):
    x=L+(c-C0)*S; o.append(f'<line x1="{x}" y1="{T}" x2="{x}" y2="{T+(R1-R0+1)*S}" stroke="var(--c11)" stroke-width="1"/>')
for r in range(R0,R1+2):
    y=T+(r-R0)*S; o.append(f'<line x1="{L}" y1="{y}" x2="{L+(C1-C0+1)*S}" y2="{y}" stroke="var(--c11)" stroke-width="1"/>')
o.append('</svg>')
svg='\n'.join(o)
def bits(v):
    return ''.join(f'<span class="dg-bit{" dg-on" if v>>b&1 else ""}">{v>>b&1}</span>' for b in range(7,-1,-1))
items=[(0x04,'(20, 16)','a walkway\'s first piece: right only'),
       (0x44,'(21, 16)','a walkway\'s middle: left and right'),
       (0x54,'(24, 16)','the ladder\'s top rung on the walkway: down, plus the walkway\'s left and right'),
       (0x11,'(24, 20)','a ladder\'s middle: up and down'),
       (0x45,'(24, 24)','the ladder\'s foot on the floor: up, left and right')]
leg='\n'.join(f'<div class="ch04-wi"><b>${v:02X}</b><span class="dg-bytes">{bits(v)}</span><span>{d} <span class="soft">{p}</span></span></div>' for v,p,d in items)
html=f'''<style>
.ch04-ways {{ display: flex; flex-wrap: wrap; gap: 14px 22px; align-items: flex-start; }}
.ch04-ways .ch04-wsvg {{ flex: none; max-width: 100%; }}
.ch04-ways .ch04-wleg {{ display: grid; gap: 8px; flex: 1 1 15em; min-width: 0; }}
.ch04-ways .ch04-wi {{ display: grid; grid-template-columns: 2.6em auto; gap: 2px 8px; align-items: center; }}
.ch04-ways .ch04-wi > span:last-child {{ grid-column: 1 / -1; font-size: .74rem; }}
.ch04-ways .ch04-wi .soft {{ color: var(--ink-soft); }}
.ch04-ways .dg-bit {{ min-width: 1.35em; padding: 2px 3px; }}
.ch04-ways .ch04-wkey {{ font-size: .72rem; color: var(--ink-soft); }}
</style>
<div class="ch04-ways">
{svg}
<div class="ch04-wleg">
<div class="ch04-wkey">bits 7 6 5 4 3 2 1 0 = up-left, left, down-left, down, down-right, right, up-right, up</div>
{leg}
</div>
</div>
'''
open('/home/user/dr-creep-in-zig/site/page/diagrams/ch04-ladders-ways.html','w').write(html)
