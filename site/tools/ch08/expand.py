# Expand the chapter template: {{L key}} -> labelled ```zig listing,
# {{S name}} -> ```zig snippet, {{O tag}} -> headless output, {{X name}} -> quoted error.
import sys, os, re, json
sys.path.insert(0, os.path.dirname(__file__))
from listings import STEPS, f8
from runs import RUNS
S = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/ch08')
outputs = json.load(open(S + '/outputs.json'))
errs = json.load(open(S + '/errs.json'))
steps = {s['key']: s for s in STEPS}

SNIPS = {}

def sub(m):
    kind, name = m.group(1), m.group(2)
    if kind == 'L':
        st = steps[name]; st['used'] = True
        return st['label'] + '\n\n```zig\n' + st['text'].strip('\n') + '\n```'
    if kind == 'S':
        return '```zig snippet\n' + SNIPS[name]() + '\n```'
    if kind == 'X':
        return errs[name]
    if kind == 'A':
        return ' '.join(RUNS[name])
    if kind == 'O':
        return '```\n' + outputs[name].rstrip('\n') + '\n```'
    raise SystemExit(kind)

src = open(sys.argv[1]).read()
out = re.sub(r'\{\{([LSOXA]) ([A-Za-z0-9_]+)\}\}', sub, src)
missing = [s['key'] for s in STEPS if s['label'] and not s.get('used')]
if missing: raise SystemExit('listings not used: %s' % missing)
order = re.findall(r'\{\{L ([A-Za-z0-9_]+)\}\}', src)
want = [s['key'] for s in STEPS if s['label']]
assert order == want, (order, want)
open(sys.argv[2], 'w').write(out)
print('expanded', len(order), 'listings')
