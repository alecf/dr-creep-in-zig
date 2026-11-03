# Screenshots for Chapter 11, from the stage runs kept by rebuild.py (rb-*).
from PIL import Image
S = '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/ch11/'
O = '/home/claude/dr-creep-in-zig/site/chapters/images/'
for name, run, f in [('title', 'B', 59), ('menu', 'C', 130), ('signing', 'D', 1610),
                     ('times', 'D', 2049), ('save', 'E', 430)]:
    im = Image.open('%srb-%s/frame_%05d.ppm' % (S, run, f))
    assert im.size == (384, 272)
    im.resize((768, 544), Image.NEAREST).save(O + '11-%s.png' % name)
    print(name, run, f)
