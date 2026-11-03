# The headless runs for each stage of the rebuild. "@2" on a press is
# stick 2: player 2.
def both(t, k, d):
    """Both sticks the same way at once."""
    return ['--press', '%d:%s:%d' % (t, k, d), '--press', '%d:%s:%d@2' % (t, k, d)]
# A: fire on stick 2 starts a game for two in the Gatehouse; player 1
# walks off left, player 2 follows a little way behind.
TWO = (['--frames', '300', '--press', '20:f:5@2', '--press', '60:l:80', '--press', '100:l:40@2']
       + ['--dump-every', '10'])
def keys(n, first=45):
    """Fire on stick 2 at the title, then N n times: room n, for two."""
    out = ['--press', '20:f:5@2']
    for i in range(n): out += ['--key', '%d:N' % (first + 15 * i)]
    return out
def at(t0, seg):
    out = []
    for p in seg.split():
        t, k, d = p.split(':'); d, two = (d[:-2], '@2') if d.endswith('@2') else (d, '')
        out += ['--press', '%d:%s:%s%s' % (t0 + int(t), k, d, two)]
    return out
# B: Two's Company (room 18). Both to the ladder; player 1 climbs to the
# button and holds fire; player 2 runs through the field, rings the bell
# and goes out.
ROOM18 = ("0:l:52 0:l:52@2 52:u:60 115:r:46 161:f:400 170:l:182@2 352:f:4@2 356:l:60@2 416:ur:4@2")
COMPANY = ['--frames', '900'] + keys(18) + at(330, ROOM18) + ['--dump-every', '10']
# C: a game for two, both on the stick together: fire on the map, through
# the Gatehouse (player 1 rings), the map, the Long Gallery, the map.
MAPS = (['--frames', '820', '--press', '20:f:5@2'] + both(30, 'f', 3)
        + at(44, "0:l:34 0:l:34@2 34:f:4 38:r:60 38:r:60@2 98:ur:4 98:ur:4@2")
        + both(300, 'f', 3)
        + at(320, "0:r:212 0:r:212@2 214:f:4 218:r:60 218:r:60@2 278:ur:4 278:ur:4@2")
        + ['--dump-every', '10'])
# D: a game for two, N on the map to the Way Out (room 19); both ring,
# both go out by the green door. Player 1 escapes, then player 2, then
# GAME OVER for both, and the title.
OUT = (['--frames', '2400', '--press', '20:f:5@2'] + both(40, 'f', 3)
       + [a for i in range(19) for a in ('--key', '%d:N' % (60 + 15 * i))]
       + at(360, "0:l:240 0:l:240@2 240:f:4 240:f:4@2 250:l:60 250:l:60@2 312:ur:4 312:ur:4@2")
       + ['--dump-every', '10'])
# E, the Boss Battle: a game for two from the title to GAME OVER. N on
# the map to Two's Company; through it together (B's moves), then player
# 1 alone, down and out while the field's still down; the map, the Way
# Out together, two escapes, GAME OVER and the title.
BOSS = (['--frames', '3500', '--press', '20:f:5@2'] + both(40, 'f', 3)
        + [a for i in range(18) for a in ('--key', '%d:N' % (60 + 15 * i))]
        + at(345, ROOM18) + at(0, "910:l:46 956:d:100 1056:l:250 1310:ur:4") + both(1430, 'f', 3)
        + at(1462, "0:l:240 0:l:240@2 240:f:4 240:f:4@2 250:l:60 250:l:60@2 312:ur:4 312:ur:4@2")
        + ['--dump-every', '10'])
RUNS = {
    'A': TWO,
    'B': COMPANY,
    'C': MAPS,
    'D': OUT,
    'E': BOSS,
}
