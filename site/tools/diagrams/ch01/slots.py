# Generate site/page/diagrams/ch01-sprite-slots.html: the VIDEO chip's eight
# sprite slots, their registers, and slot 0's pointer into sprite memory.
OUT = '/home/user/dr-creep-in-zig/site/page/diagrams/ch01-sprite-slots.html'
H0 = 34          # top of row 0
RH = 24          # row height
cols = [('slot', 78), ('X', 54), ('Y', 54), ('colour', 60), ('on: $D015', 74), ('pointer', 62)]
TW = sum(w for _, w in cols)
GX, BW = 452, 46  # sprite memory grid: x, block width (4 columns x 8 rows)
o = []
o.append(f'<rect class="ch01-ss-frame" x="0" y="{H0}" width="{TW}" height="{8*RH}" rx="4"/>')
x = 0
for name, w in cols:
    o.append(f'<text class="soft" x="{x + 6}" y="{H0 - 8}" font-size="11">{name}</text>')
    x += w
for n in range(8):
    top = H0 + n * RH
    if n == 0:
        o.append(f'<rect class="ch01-ss-on" x="0" y="{top}" width="{TW}" height="{RH}" rx="4"/>')
    elif n:
        o.append(f'<line class="ch01-ss-rule" x1="0" y1="{top}" x2="{TW}" y2="{top}"/>')
    cells = [f'{n} · player' if n == 0 else f'{n}', f'${0xD000 + 2*n:04X}', f'${0xD001 + 2*n:04X}',
             f'${0xD027 + n:04X}', f'bit {n}', f'${0xCFF8 + n:04X}']
    x = 0
    cls = ' class="ch01-ss-ontx"' if n == 0 else ''
    for (name, w), c in zip(cols, cells):
        o.append(f'<text{cls} x="{x + 6}" y="{top + 16}" font-size="11.5">{c}</text>')
        x += w
# sprite memory
o.append(f'<text class="soft" x="{GX}" y="{H0 - 8}" font-size="11">sprite memory $C000–$C7FF</text>')
for b in range(32):
    r, c = divmod(b, 4)
    bx, by = GX + c * BW, H0 + r * RH
    cls = 'ch01-ss-on' if b == 0 else 'ch01-ss-blk'
    o.append(f'<rect class="{cls}" x="{bx + 1}" y="{by + 1}" width="{BW - 2}" height="{RH - 2}" rx="2"/>')
    tcls = 'ch01-ss-ontx' if b == 0 else 'soft'
    o.append(f'<text class="{tcls}" x="{bx + BW/2}" y="{by + 16}" font-size="11" text-anchor="middle">{b}</text>')
# pointer arrows: slot 0 -> block 0, and the one-byte change -> block 8
py = H0 + RH / 2
o.append(f'<path class="ch01-ss-arr" d="M{TW - 4} {py} H{GX - 4}" marker-end="url(#ch01-ss-ah)"/>')
o.append(f'<text x="{(TW + GX) / 2}" y="{py - 6}" font-size="10.5" text-anchor="middle">holds 0</text>')
b8y = H0 + 2 * RH + RH / 2
o.append(f'<path class="ch01-ss-arr ch01-ss-maybe" d="M{TW - 4} {py + 6} C {TW + 40} {py + 6}, {GX - 50} {b8y}, {GX - 4} {b8y}" marker-end="url(#ch01-ss-ah)"/>')
o.append(f'<text class="soft" x="{TW + 14}" y="{b8y + 22}" font-size="10.5">poke 8</text>')
o.append(f'<text class="soft" x="{TW + 14}" y="{b8y + 35}" font-size="10.5">there:</text>')
o.append(f'<text class="soft" x="{TW + 14}" y="{b8y + 48}" font-size="10.5">block 8</text>')
end = H0 + 8 * RH
o.append(f'<text class="soft" x="0" y="{end + 20}" font-size="10.5">One block: 64 bytes, a 24 × 21 picture (63 bytes) and a spare.</text>')
o.append(f'<text class="soft" x="{GX}" y="{end + 20}" font-size="10.5">block N: $C000 + N × 64</text>')

W = GX + 4 * BW
svg = f'''<svg viewBox="0 0 {W} {end + 28}" width="{W}" role="img" aria-labelledby="ch01-ss-t">
<title id="ch01-ss-t">The VIDEO chip's eight sprite slots, 0 to 7, each with an X register, a Y register, a colour register, one bit of the enable byte at $D015, and a sprite pointer from $CFF8 to $CFFF. Slot 0 is the player's; its pointer holds 0, so it shows block 0 of the 32 blocks in sprite memory at $C000. Changing that byte to 8 would make it show block 8.</title>
<defs><marker id="ch01-ss-ah" viewBox="0 0 6 6" refX="5" refY="3" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0 L6 3 L0 6 z" class="ch01-ss-ahd"/></marker></defs>
{chr(10).join(o)}
</svg>'''
css = '''<style>
.ch01-ss svg { max-width: none; }
.ch01-ss .ch01-ss-frame { fill: var(--code-bg); stroke: var(--rule); }
.ch01-ss .ch01-ss-rule { stroke: var(--rule); }
.ch01-ss .ch01-ss-on { fill: var(--accent); }
.ch01-ss text.ch01-ss-ontx { fill: var(--sheet); }
.ch01-ss .ch01-ss-blk { fill: var(--code-bg); stroke: var(--rule); }
.ch01-ss .ch01-ss-arr { stroke: var(--accent); stroke-width: 1.5; fill: none; }
.ch01-ss .ch01-ss-maybe { stroke-dasharray: 4 3; opacity: .7; }
.ch01-ss .ch01-ss-ahd { fill: var(--accent); }
</style>'''
open(OUT, 'w').write(css + '\n<div class="ch01-ss">\n' + svg + '\n</div>\n')
print('wrote', OUT, W)
