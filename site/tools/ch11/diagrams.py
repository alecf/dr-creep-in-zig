# The disk diagram for Chapter 11, drawn from the master disk itself
# (rb-A.d64, saved by stage A of rebuild.py): every sector of the disk,
# where track 18's BAM and directory are, and the Training Castle's
# chain, read one sector at a time.
S = '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/ch11/'
O = '/home/claude/dr-creep-in-zig/site/page/diagrams/ch11-disk.html'
d = open(S + 'rb-A.d64', 'rb').read()
assert len(d) == 174848

def spt(t): return 21 if t <= 17 else 19 if t <= 24 else 18 if t <= 30 else 17
def off(t, s): return (sum(spt(i) for i in range(1, t)) + s) * 256

files = []  # (name, [(t, s)...])
dirs = []
t, s = 18, 1
while t:
    dirs.append((t, s))
    sec = d[off(t, s):off(t, s) + 256]
    for e in range(8):
        en = sec[e * 32:e * 32 + 32]
        if not en[2]: continue
        chain, ft, fs = [], en[3], en[4]
        while ft:
            chain.append((ft, fs))
            c = d[off(ft, fs):off(ft, fs) + 2]
            ft, fs = c[0], c[1]
        files.append((en[5:21].rstrip(b'\xa0').decode(), chain))
    t, s = sec[0], sec[1]
assert [f[0] for f in files] == ['ZTRAINING', 'ZENTRANCE HALL'], files
training, hall = files[0][1], files[1][1]
read = dirs[:1] + training  # what loading ZTRAINING touches, in order

C, G = 12, 2  # cell size, gap
L, T = 28, 16  # room for the sector numbers on the left, and above
W = L + 35 * (C + G)
H = T + 21 * (C + G) + 20
def xy(t, s): return L + (t - 1) * (C + G), T + s * (C + G)

kind = {}
kind[(18, 0)] = 'bam'
for ts in dirs: kind[ts] = 'dir'
for ts in training: kind[ts] = 'trn'
for ts in hall: kind[ts] = 'hal'

secs = 0.45 * (len(read) + 4)  # a step a sector, then a pause
out = []
out.append('<style>')
out.append('.ch11-dk { display: grid; gap: 10px; }')
out.append('.ch11-dk .scroll { overflow-x: auto; }')
out.append('.ch11-dk svg { width: 100%%; min-width: %dpx; max-width: %dpx; }' % (W, W * 1.6))
out.append('.ch11-dk rect.c { fill: var(--code-bg); stroke: var(--rule); stroke-width: .6; }')
out.append('.ch11-dk rect.bam, .ch11-dk rect.dir { fill: var(--ink); stroke: none; }')
out.append('.ch11-dk rect.hal { fill: var(--ink-soft); stroke: none; }')
out.append('.ch11-dk rect.trn { fill: var(--accent); stroke: none; opacity: .45; }')
out.append('.ch11-dk text { font-size: 9px; }')
out.append('.ch11-dk .head { fill: none; stroke: var(--ink); stroke-width: 1.6; animation: ch11-dk-head %.2fs step-end infinite; }' % secs)
out.append('.ch11-dk .key { display: flex; gap: 14px; flex-wrap: wrap; font-size: .72rem; color: var(--ink-soft); }')
out.append('.ch11-dk .key i { display: inline-block; width: .9em; height: .9em; border-radius: 2px; vertical-align: -1px; margin-right: 5px; }')
# The head's path: one keyframe a sector.
frames = []
n = len(read) + 4
for i, ts in enumerate(read):
    x, y = xy(*ts)
    frames.append('%.2f%% { transform: translate(%dpx, %dpx) }' % (100 * i / n, x - 1, y - 1))
out.append('@keyframes ch11-dk-head { %s }' % ' '.join(frames))
# Each of the file's sectors lights up as it's read, and stays lit to the end.
for i, ts in enumerate(training):
    k = i + 1
    out.append('.ch11-dk .r%d { animation: ch11-dk-r%d %.2fs step-end infinite; }' % (k, k, secs))
    out.append('@keyframes ch11-dk-r%d { 0%% { opacity: .45 } %.2f%% { opacity: 1 } 100%% { opacity: .45 } }' % (k, 100 * k / n))
out.append('</style>')
out.append('<div class="ch11-dk" data-animate>')
out.append('  <span class="dg-label">The game\'s own disk: 35 tracks across, a square for each sector</span>')
svg = ['<svg viewBox="0 0 %d %d" role="img" aria-label="Every sector of the disk, track by track. Track 18 holds the BAM and the directory; the Training Castle is a chain of %d sectors on track %s; the Entrance Hall %d more on track %s.">' % (W, H, len(training), ' and '.join(sorted({str(x[0]) for x in training})), len(hall), ' and '.join(sorted({str(x[0]) for x in hall})))]
for s_ in (0, 5, 10, 15, 20):
    x, y = xy(1, s_)
    svg.append('<text class="soft" x="%d" y="%d" text-anchor="end">%d</text>' % (L - 4, y + C - 2, s_))
for t_ in (1, 5, 10, 17, 25, 30, 35):
    x, y = xy(t_, 0)
    svg.append('<text class="soft" x="%.1f" y="%d" text-anchor="middle">%d</text>' % (x + C / 2, H - 4, t_))
x, y = xy(18, 0)
svg.append('<text class="soft" x="%.1f" y="%d" text-anchor="middle">18</text>' % (x + C / 2, T - 5))
r = {ts: i + 1 for i, ts in enumerate(training)}
for t_ in range(1, 36):
    for s_ in range(spt(t_)):
        x, y = xy(t_, s_)
        k = kind.get((t_, s_), '')
        cls = 'c ' + k + (' r%d' % r[(t_, s_)] if k == 'trn' else '')
        svg.append('<rect class="%s" x="%d" y="%d" width="%d" height="%d" rx="1.5"/>' % (cls.strip(), x, y, C, C))
svg.append('<rect class="head" x="0" y="0" width="%d" height="%d" rx="2"/>' % (C + 2, C + 2))
svg.append('</svg>')
out.append('  <div class="scroll">' + ''.join(svg) + '</div>')
out.append('  <div class="key"><span><i style="background: var(--ink)"></i>track 18: the BAM (sector 0) and the directory (sector 1)</span>'
           '<span><i style="background: var(--accent)"></i>ZTRAINING, %d sectors (pale until read)</span>'
           '<span><i style="background: var(--ink-soft)"></i>ZENTRANCE HALL, %d</span>'
           '<span><i style="background: var(--code-bg); box-shadow: inset 0 0 0 1px var(--rule)"></i>free</span></div>' % (len(training), len(hall)))
chain = ' &rarr; '.join('%d/%d' % ts for ts in read[:6])
out.append('  <small>Loading ZTRAINING: the directory at 18/1, then the chain, each sector naming the next: %s &rarr; &hellip; %d sectors, %d frames of the drive.</small>' % (chain, len(read), len(read)))
out.append('</div>')
open(O, 'w').write('\n'.join(out) + '\n')
print('ch11-disk:', len(training), 'training sectors,', len(hall), 'hall,', 'chain', read[:8], '...')
