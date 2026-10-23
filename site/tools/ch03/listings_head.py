# Every ```zig listing of Chapter 3, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch03) wherever the
# listing matches it, and written out here for intermediate states.
import re, os
CH3 = '/home/user/dr-creep-in-zig/site/code/ch03/'
CH2 = '/home/user/dr-creep-in-zig/site/code/ch02/'

def read(root, p): return open(root + p).read()
def f3(p): return read(CH3, p)

def doc_start(lines, i):
    while i > 0 and lines[i-1].startswith('///'): i -= 1
    return i

def fn(path, name, root=CH3):
    lines = read(root, path).split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^(pub )?fn %s\(' % re.escape(name), l):
            s = doc_start(lines, i); j = i
            while lines[j] != '}': j += 1
            return '\n'.join(lines[s:j+1]) + '\n'
    raise SystemExit('no fn %s in %s' % (name, path))

def span(path, first, last, root=CH3):
    """From the line starting with `first` to the line equal to `last` (or
    starting with it), inclusive. A leading doc comment comes along."""
    lines = read(root, path).split('\n')
    s = next(i for i, l in enumerate(lines) if l.startswith(first))
    s = doc_start(lines, s)
    e = next(i for i in range(s, len(lines)) if lines[i] == last or (last.endswith('…') and lines[i].startswith(last[:-1])))
    return '\n'.join(lines[s:e+1]) + '\n'

def upto(path, last, root=CH3):
    lines = read(root, path).split('\n')
    e = next(i for i, l in enumerate(lines) if l == last)
    return '\n'.join(lines[:e+1]) + '\n'

def tail(path, first, root=CH3):
    t = read(root, path)
    return t[t.index(first):]

STEPS = []
def step(key, label, op, text, arg=None, run=None, pad=''):
    STEPS.append(dict(key=key, label=label, op=op, text=text, arg=arg, run=run, pad=pad))

