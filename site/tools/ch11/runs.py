# The headless runs for each stage of the rebuild. "--wav creep.wav" and
# "--save-disk creep.d64" name files that rebuild.py keeps beside each
# stage's frames.
import os, importlib.util
_spec = importlib.util.spec_from_file_location('ch10runs', os.path.join(os.path.dirname(__file__), '..', 'ch10', 'runs.py'))
ch10 = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(ch10)
shifted = ch10.shifted

def keys(t, text):
    """Type `text` from frame t, a key every 4 frames (\\r is Return, \\x1b Esc, \\x08 Backspace)."""
    out = []
    for i, c in enumerate(text):
        k = '#%d' % ord(c) if not ('A' <= c <= 'Z' or '0' <= c <= '9') else c
        out += ['--key', '%d:%s' % (t + 4 * i, k)]
    return out

def downs(t, n):
    """Push stick 1 down n times from frame t, one every 10 frames."""
    return [a for i in range(n) for a in ('--press', '%d:d:1' % (t + 10 * i))]

# A: power on. The disk's directory, the first castle, and the title with
# its name. The disk is saved at the end: our own master disk, as a file.
POWER = ['--frames', '60', '--dump-every', '10', '--save-disk', 'creep.d64']
# B: Esc for the menu, down to the Entrance Hall, fire: the title names it,
# and fire plays it.
MENU = (['--frames', '320'] + keys(60, '\x1b') + downs(80, 5)
        + ['--press', '140:f:1', '--press', '200:f:3', '--press', '240:f:3', '--dump-every', '10'])
# C: fire, then N on the map 19 times to the Way Out; ring, out, escape;
# initials ACE and Return; GAME OVER, the title, and the menu's BEST TIMES.
WAYOUT = (['--frames', '2050', '--press', '60:f:3', '--press', '75:f:3']
          + [a for i in range(19) for a in ('--key', '%d:N' % (100 + 15 * i))]
          + ['--press', '400:f:3', '--press', '430:l:240', '--press', '670:f:4', '--press', '680:l:60', '--press', '742:ur:4']
          + keys(1600, 'ACE\r') + keys(1900, '\x1b') + downs(1920, 1) + ['--press', '1940:f:1']
          + ['--dump-every', '10'])
# D: through the Gatehouse to the map; Esc, the name MY GAME and Return:
# saved. Three lives given up (X) to GAME OVER and the title; then Esc,
# fire on RESUME GAME, the name again: the map, and on into the Long
# Gallery, where the game was.
SAVE = (['--frames', '1700', '--press', '60:f:3', '--press', '75:f:3', '--press', '100:l:34', '--press', '134:f:4',
         '--press', '138:r:60', '--press', '198:ur:4'] + keys(380, '\x1b') + keys(400, 'MY GAME\r')
        + ['--press', '480:f:3', '--key', '580:X', '--press', '730:f:3', '--key', '830:X', '--press', '980:f:3', '--key', '1080:X']
        + keys(1480, '\x1b') + ['--press', '1500:f:1'] + keys(1520, 'MY GAME\r') + ['--press', '1600:f:3']
        + ['--dump-every', '10'])
# E, the Boss Battle: Chapter 10's game for two (24 frames later: the
# disk at power-on), each explorer signing his best time.
# Then GAME OVER, the title, and the menu's BEST TIMES.
def boss():
    out = shifted([a for a in ch10.BOSS if a not in ('--wav', 'creep.wav')], 24)
    i = out.index('--frames'); out[i + 1] = '3800'
    return out + keys(2740, 'ACE\r') + keys(3330, 'DUO\r') + keys(3640, '\x1b') + downs(3660, 1) + ['--press', '3680:f:1']
BOSS = boss()
RUNS = {
    'A': POWER,
    'B': MENU,
    'C': WAYOUT,
    'D': SAVE,
    'E': BOSS,
}
