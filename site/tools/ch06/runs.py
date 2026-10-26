# The headless runs for each stage of the rebuild; F is the Boss Battle.
def keys(n, first=45):
    """Fire on the title, then N n times: room n, standing at its door 0."""
    out = ['--press', '20:f:5']
    for i in range(n): out += ['--key', '%d:N' % (first + 15 * i)]
    return out
def at(t0, seg):
    out = []
    for p in seg.split():
        t, k, d = p.split(':'); out += ['--press', '%d:%s:%s' % (t0 + int(t), k, d)]
    return out
ROOM4 = "0:r:64 70:u:80 155:l:46 205:d:6 220:r:46 270:d:80 355:r:172 530:f:5 590:r:40 650:ur:10"
ROOM5 = "0:l:76 80:f:5 90:l:160 252:f:5 320:l:30 352:ur:10"
ROOM6 = "0:l:236 240:f:5 300:l:30 332:ur:10"
ROOM7 = "0:l:124 126:f:5 134:l:112 250:f:5 310:l:30 342:ur:10"
ROOM8 = "0:l:92 96:u:34 134:f:5 144:l:32 180:f:5 240:l:28 272:ur:10"
SWITCH = ['--frames', '800'] + keys(4) + at(110, ROOM4) + ['--dump-every', '10']
BOLT = ['--frames', '400'] + keys(4) + ['--press', '110:r:200', '--dump-every', '10']
FIELD = ['--frames', '700'] + keys(5) + at(125, ROOM5) + ['--dump-every', '10']
TRAP = ['--frames', '600'] + keys(6) + at(140, ROOM6) + ['--dump-every', '10']
BELT = ['--frames', '600'] + keys(7) + at(155, ROOM7) + ['--dump-every', '10']
BOSS = ['--frames', '2900'] + keys(4) + at(110, ROOM4) + at(920, ROOM5) + at(1420, ROOM6) + at(1900, ROOM7) + at(2390, ROOM8) + ['--dump-every', '10']
RUNS = {
    'A': SWITCH,
    'B': BOLT,
    'C': FIELD,
    'D': TRAP,
    'E': BELT,
    'F': BOSS,
}
