# Expand the chapter template: {{L key}} -> labelled ```zig listing,
# {{S name}} -> ```zig snippet, {{O tag}} -> headless output.
import sys, os, re, json
sys.path.insert(0, os.path.dirname(__file__))
from listings import STEPS, CH3, f3, span, fn
S = os.path.dirname(os.path.abspath(__file__))
outputs = json.load(open(S + '/outputs.json'))
errs = json.load(open(S + '/errs.json'))
steps = {s['key']: s for s in STEPS}

def art_walkway():
    t = f3('src/art.zig')
    a = t.index('/// Floors, ladders and poles'); b = t.index('pub const walkway_left')
    return t[a:b].rstrip('\n')

def training_excerpt():
    t = f3('src/training.zig')
    a = t.index('/// The castle, as declarations.')
    b = t.index('        .ladders = .{')
    return t[a:b].rstrip('\n') + '\n        // ... eighteen more rooms, and the final room ...'

SNIPS = {
    'walkway': art_walkway,
    'training_top': lambda: f3('src/training.zig')[:f3('src/training.zig').index('/// The castle, as declarations.')].rstrip('\n'),
    'training_plan': training_excerpt,
    'training_bytes': lambda: f3('src/training.zig')[f3('src/training.zig').index('/// The castle file\'s bytes'):].rstrip('\n'),
}

def sub(m):
    kind, name = m.group(1), m.group(2)
    if kind == 'L':
        st = steps[name]; st['used'] = True
        return st['label'] + '\n\n```zig\n' + st['text'].rstrip('\n') + '\n```'
    if kind == 'S':
        return '```zig snippet\n' + SNIPS[name]() + '\n```'
    if kind == 'X':
        return errs[name]
    if kind == 'O':
        return '```\n' + outputs[name].rstrip('\n') + '\n```'
    raise SystemExit(kind)

src = open(sys.argv[1]).read()
out = re.sub(r'\{\{([LSOX]) ([A-Za-z0-9_]+)\}\}', sub, src)
missing = [s['key'] for s in STEPS if s['label'] and not s.get('used')]
if missing: raise SystemExit('listings not used: %s' % missing)
# the listings must appear in step order
order = re.findall(r'\{\{L ([A-Za-z0-9_]+)\}\}', src)
want = [s['key'] for s in STEPS if s['label']]
assert order == want, (order, want)
open(sys.argv[2], 'w').write(out)
print('expanded', len(order), 'listings')
