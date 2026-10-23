# Rebuild ch03 from ch02 by applying every listing in order; build, test and
# run at each stage; compare the result with the checkpoint.
import sys, os, shutil, subprocess, re
sys.path.insert(0, os.path.dirname(__file__))
from listings import STEPS, CH2, CH3
S = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
work = S + '/rebuild'
shutil.rmtree(work, ignore_errors=True); os.makedirs(work)
shutil.copytree('/home/user/dr-creep-in-zig/site/code/machine', work + '/machine', ignore=shutil.ignore_patterns('.zig-cache', 'zig-out'))
P = work + '/my-creep/'
os.makedirs(P + 'src')
for f in ['build.zig', 'build.zig.zon']: shutil.copy(CH2 + f, P + f)
for f in os.listdir(CH2 + 'src'): shutil.copy(CH2 + 'src/' + f, P + 'src/' + f)

def rd(f): return open(P + f).read() if os.path.exists(P + f) else ''
def wr(f, t): open(P + f, 'w').write(t)
def fn_span(ls, name):
    for k, l in enumerate(ls):
        if re.match(r'^(pub )?fn %s\(' % name, l):
            s = k
            while s > 0 and ls[s-1].startswith('///'): s -= 1
            e = k
            while ls[e] != '}': e += 1
            return s, e
    raise Exception('no fn ' + name)
def apply(st):
    f, op, text, arg = st['file'], st['op'], (st['pad'] + st['text']) if st['text'] else None, st['arg']
    t = rd(f)
    if op == 'whole': t = text
    elif op == 'append': t = t.rstrip('\n') + '\n\n' + text
    elif op == 'copy': t = open(CH3 + arg).read()
    elif op == 'delete_fns':
        for name in arg:
            ls = t.split('\n'); s, e = fn_span(ls, name)
            while s > 0 and ls[s-1] == '': s -= 1
            t = '\n'.join(ls[:s] + ls[e+1:])
    elif op == 'replace_text':
        assert t.count(arg) == 1, (st['key'], arg[:80]); t = t.replace(arg, text)
    elif op in ('after_line', 'before_line'):
        ls = t.split('\n'); assert ls.count(arg) == 1, (st['key'], arg); k = ls.index(arg)
        head = '\n'.join(ls[:k+1 if op == 'after_line' else k]) + '\n'
        rest = '\n'.join(ls[k+1 if op == 'after_line' else k:])
        t = head + text + rest
    elif op == 'replace_fn':
        ls = t.split('\n'); s, e = fn_span(ls, arg)
        t = '\n'.join(ls[:s]) + '\n' + text + '\n'.join(ls[e+1:])
    elif op == 'insert_after_fn':
        ls = t.split('\n'); s, e = fn_span(ls, arg)
        t = '\n'.join(ls[:e+1]) + '\n\n' + text + '\n'.join(ls[e+1:])
    else: raise Exception(op)
    wr(f, t)

RUNS = {
    'A': ['--frames', '60', '--press', '20:f:5'],
    'B': ['--frames', '60', '--press', '20:f:5'],
    'C': ['--frames', '60', '--press', '20:f:5'],
    'D': ['--frames', '60', '--press', '20:f:5'],
    'E1': ['--frames', '60', '--press', '20:f:5'],
    'E': ['--frames', '60', '--press', '20:f:5'],
    'F': ['--frames', '300', '--press', '20:f:5', '--key', '60:N', '--key', '100:N', '--key', '140:P', '--key', '180:P', '--key', '220:P', '--dump-every', '20'],
    'G': ['--frames', '300', '--press', '20:f:5', '--key', '60:N', '--key', '100:N', '--key', '140:P', '--key', '180:P', '--key', '220:P', '--dump-every', '20'],
}
outputs = {}
for st in STEPS:
    if st['op'] == 'copy': st['file'] = st['arg']
    elif st['op'] == 'delete_fns': st['file'] = 'src/room.zig'
    else:
        m = re.match(r'\*\*`(src/[a-z_]+\.zig)`\*\*', st['label']); st['file'] = m.group(1)
    apply(st)
    if st['run']:
        tag = st['run']
        for cmd in (['zig', 'fmt', '--check', 'src'], ['zig', 'build'], ['zig', 'build', 'test']):
            r = subprocess.run(cmd, cwd=P, capture_output=True, text=True)
            if r.returncode: print(tag, ' '.join(cmd), 'FAILED\n', r.stdout[-2000:], r.stderr[-3000:]); sys.exit(1)
        d = S + '/rb-' + tag; shutil.rmtree(d, ignore_errors=True)
        r = subprocess.run(['zig', 'build', 'run', '--'] + RUNS[tag] + ['--dump', d], cwd=P, capture_output=True, text=True)
        if r.returncode: print(tag, 'run FAILED', r.stderr[-2000:]); sys.exit(1)
        outputs[tag] = r.stdout.replace(d, 'frames')
        print('== stage', tag, 'ok'); print(outputs[tag])
bad = False
for name in sorted(set(os.listdir(CH3 + 'src')) | set(os.listdir(P + 'src'))):
    a = open(CH3 + 'src/' + name).read() if os.path.exists(CH3 + 'src/' + name) else None
    b = open(P + 'src/' + name).read() if os.path.exists(P + 'src/' + name) else None
    if a != b: print('DIFF', name); bad = True
for f in ['build.zig', 'build.zig.zon']:
    if open(CH3 + f).read() != open(P + f).read(): print('DIFF', f); bad = True
print('REBUILD', 'MISMATCH' if bad else 'BYTE-IDENTICAL')
import json; json.dump(outputs, open(S + '/outputs.json', 'w'), indent=1)
