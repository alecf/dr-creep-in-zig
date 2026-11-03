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
def start(n):
    """The frame room n's run starts on: 20 frames after the last N."""
    return 45 + 15 * (n - 1) + 20
# Room 9: the lock (nothing), up the ladder to the key, back down to the
# lock, through the door.
ROOM9 = "0:l:230 230:f:5 255:r:126 381:u:70 451:r:130 581:f:5 596:l:114 710:d:70 780:l:126 906:f:5 911:l:60 971:ur:10"
# Room 10: to the panel behind the gun, the gun up, a shot high over the
# room, then along the floor past the gun, the bell, the door.
ROOM10 = "0:r:32 72:u:596 668:f:5 733:r:204 937:f:5 942:r:60 1002:ur:10"
# Room 15: lasers die on the field; up to the panel, the gun up, down, the
# button, and a run past the gun to the bell.
ROOM15 = "0:l:140 200:r:36 236:u:70 306:r:16 322:u:514 836:l:12 848:d:70 918:r:56 974:f:5 979:l:182 1161:f:5 1166:l:60 1226:ur:10"
# Room 17: into the booth and up, the key, down the pole, the lock.
ROOM17 = "0:l:64 64:f:5 79:r:90 169:f:5 184:l:138 322:d:70 392:l:102 494:f:5 499:l:60 559:ur:10"
KEYS = ['--frames', '1350'] + keys(9) + at(start(9), ROOM9) + ['--dump-every', '10']
LOCKED = ['--frames', '900'] + keys(17) + at(start(17), ROOM17) + ['--dump-every', '10']
TRACK = ['--frames', '1400'] + keys(10) + at(start(10), ROOM10) + ['--dump-every', '10']
# Straight along the floor, past the gun's muzzle.
SHOT = ['--frames', '600'] + keys(10) + ['--press', '%d:r:300' % start(10), '--dump-every', '2']
FIRE = ['--frames', '1650'] + keys(15) + at(start(15), ROOM15) + ['--dump-every', '10']
BOSS = (['--frames', '4745'] + keys(9) + at(185, ROOM9) + at(1326, ROOM10)
        + ['--key', '2498:N', '--key', '2513:N', '--key', '2528:N', '--key', '2543:N'] + at(2578, ROOM15)
        + ['--key', '3978:N'] + at(4013, ROOM17) + ['--dump-every', '10'])
RUNS = {
    'A': KEYS,
    'B': LOCKED,
    'C': TRACK,
    'D': SHOT,
    'E': FIRE,
    'F': BOSS,
}
