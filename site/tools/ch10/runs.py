# The headless runs for each stage of the rebuild. "--wav creep.wav" writes
# the sound; rebuild.py keeps each stage's file beside its frames.
import os, importlib.util
_spec = importlib.util.spec_from_file_location('ch09runs', os.path.join(os.path.dirname(__file__), '..', 'ch09', 'runs.py'))
ch09 = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(ch09)
def shifted(args, by):
    """Chapter 9's run with every press `by` frames later, and as many more frames."""
    out, i = [], 0
    while i < len(args):
        a = args[i]
        if a == '--frames':
            out += [a, str(int(args[i + 1]) + by)]; i += 2
        elif a in ('--press', '--key'):
            t, rest = args[i + 1].split(':', 1); out += [a, '%d:%s' % (int(t) + by, rest)]; i += 2
        else:
            out.append(a); i += 1
    return out
WAV = ['--wav', 'creep.wav']
# A: the title, and the experiment's A4 under it.
NOTE = ['--frames', '150'] + WAV + ['--dump-every', '50']
# C: the title's waltz, round once and into its second time.
WALTZ = ['--frames', '1200'] + WAV + ['--dump-every', '100']
# D: the waltz, fire for a game, fire on the map: the map's chime.
CHIME = ['--frames', '400', '--press', '300:f:3', '--press', '330:f:3'] + WAV + ['--dump-every', '10']
# E, the Boss Battle: Chapter 9's game for two, after 280 frames of the
# waltz: Two's Company, the Way Out, two escapes, GAME OVER and the title.
BOSS = shifted(ch09.BOSS, 280) + WAV
RUNS = {
    'A': NOTE,
    'B': NOTE, # the tunes are in, but nothing plays them yet
    'C': WALTZ,
    'D': CHIME,
    'E': BOSS,
}
