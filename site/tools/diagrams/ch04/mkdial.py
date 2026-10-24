from math import sin,cos,radians
CX,CY,R=170,152,80
def pt(v,r):
    a=radians(v/256*360); return CX+r*sin(a), CY-r*cos(a)
def arc(v0,v1,r,large,sweep=1):
    x0,y0=pt(v0,r); x1,y1=pt(v1,r)
    return f'M{x0:.1f} {y0:.1f}A{r} {r} 0 {large} {sweep} {x1:.1f} {y1:.1f}'
o=[f'<svg viewBox="0 0 340 290" width="340" height="290" role="img" aria-label="A byte as a dial: 0 to 127 on the right half, 128 to 255 on the left half, which an i8 reads as minus 128 to minus 1. Adding 255 to 10 goes almost all the way round and lands on 9.">']
o.append(f'<path d="{arc(0,128,R,0)}" stroke="var(--rule)" stroke-width="12" fill="none"/>')
o.append(f'<path d="{arc(128,256,R,0)}" stroke="var(--accent)" stroke-width="12" fill="none" opacity=".55"/>')
for v in range(0,256,16):
    x0,y0=pt(v,R-8); x1,y1=pt(v,R+8)
    o.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" class="line" stroke-width="1"/>')
for v,s in [(0,'0'),(64,'64'),(128,'128'),(192,'192')]:
    x,y=pt(v,R+20); o.append(f'<text x="{x:.1f}" y="{y+4:.1f}" text-anchor="middle" font-size="12" font-weight="700">{s}</text>')
for v,s in [(64,'64'),(128,'−128'),(192,'−64')]:
    x,y=pt(v,R-30); o.append(f'<text x="{x:.1f}" y="{y+4:.1f}" text-anchor="middle" font-size="11" class="soft">{s}</text>')
# the long lap: 10 +% 255
o.append('<defs><marker id="ch04-ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="var(--ink)"/></marker></defs>')
pts=[]
for k in range(0,255,2):
    v=10+k; r=R+14+k/254*24; x,y=pt(v,r); pts.append(f"{x:.1f} {y:.1f}")
o.append('<path d="M'+'L'.join(pts)+'" stroke="var(--ink)" stroke-width="1.6" fill="none" marker-end="url(#ch04-ah)"/>')
x,y=pt(10,R+14); o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="var(--ink)"/>')
# start / end marks
for v in (9,10):
    x0,y0=pt(v,R-6); x1,y1=pt(v,R+6)
    o.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="var(--ink)" stroke-width="2"/>')
# callouts
x,y=pt(255,R); o.append(f'<line x1="{x:.1f}" y1="{y:.1f}" x2="96" y2="30" class="line"/>')
o.append('<text x="92" y="22" text-anchor="end" font-size="11"><tspan font-weight="700">255</tspan> = −1</text>')
o.append('<text x="92" y="36" text-anchor="end" font-size="11" class="soft">254 = −2</text>')
x,y=pt(10,R); o.append(f'<line x1="{x:.1f}" y1="{y:.1f}" x2="246" y2="30" class="line"/>')
o.append('<text x="250" y="24" font-size="11"><tspan font-weight="700">10 +% 255</tspan></text>')
o.append('<text x="250" y="38" font-size="11" class="soft">a lap less one:</text>')
o.append('<text x="250" y="52" font-size="11" class="soft">lands on 9</text>')
o.append(f'<text x="{CX}" y="{CY-6}" text-anchor="middle" font-size="11" class="soft">outside: u8</text>')
o.append(f'<text x="{CX}" y="{CY+10}" text-anchor="middle" font-size="11" class="soft">inside: i8</text>')
o.append('<text x="8" y="284" font-size="11"><tspan style="fill:var(--accent)" font-weight="700">left half</tspan><tspan class="soft">: top bit set, negative in an i8</tspan></text>')
o.append('</svg>')
open('/home/user/dr-creep-in-zig/site/page/diagrams/ch04-minus-one.html','w').write('<div class="ch04-dial">\n'+'\n'.join(o)+'\n</div>\n')
