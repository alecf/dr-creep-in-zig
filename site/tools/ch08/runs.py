# The headless runs for each stage of the rebuild; F is the Boss Battle.
# Each room's presses are counted from the frame he arrives: by N (20
# frames after the last N) or through a door.
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
# Room 4 (Chapter 6's): up to the switch, the bolts off, and out.
ROOM4 = "0:r:64 70:u:80 155:l:46 205:d:6 220:r:46 270:d:80 355:r:172 530:f:5 590:r:40 650:ur:10"
# Room 11: read the sign, walk past the ankh, lead him left, then run
# right to the pole, down, the bell and the door.
ROOM11 = "100:r:62 282:l:74 424:r:220 644:d:70 714:r:24 738:f:4 742:r:60 802:ur:4"
# Room 16: to the switch, wait for the mummy under it, throw it up, down
# the ladder, left past the dead machine to the bell.
ROOM16 = "100:l:78 178:u:4 222:l:48 270:d:70 340:l:92 432:f:4 436:l:60 496:ur:4"
ROOM16_DOOR = "100:l:78 182:u:4 226:l:48 274:d:70 344:l:92 436:f:4 440:l:60 500:ur:4"
# Room 12: to the pole, down in front of him, and run for the bell.
ROOM12 = "100:r:128 228:d:70 298:r:104 402:f:4 406:r:60 466:ur:4"
ROOM12_DOOR = "110:r:162 272:d:70 342:r:104 446:f:4 450:r:60 510:ur:4"
# Room 13: down the pole, onto the switch, wait for him to come down the
# ladder into the hole, off and on the switch, up his ladder, the door.
ROOM13 = "100:r:112 212:d:70 282:r:32 432:l:8 440:r:8 458:r:56 514:u:70 584:r:32 616:f:4 620:r:60 680:ur:4"
ROOM13_DOOR = "111:r:146 257:d:70 327:r:32 547:l:8 555:r:8 573:r:56 629:u:70 699:r:32 731:f:4 735:r:60 795:ur:4"
# Room 14: down the pole, to the control, wait while he rides the belt,
# press twice (stop, then run left), and leave him walking on the spot.
ROOM14 = "111:r:194 305:d:70 375:r:28 497:f:4 505:f:4 1009:r:44 1053:f:4 1057:r:60 1117:ur:4"
DICE = ['--frames', '800'] + keys(4) + at(start(4), ROOM4) + ['--dump-every', '10']
MUMMY = ['--frames', '1030'] + keys(11) + at(start(11), ROOM11) + ['--dump-every', '10']
STORM = ['--frames', '800'] + keys(16) + at(start(16), ROOM16) + ['--dump-every', '10']
FRANK = ['--frames', '710'] + keys(12) + at(start(12), ROOM12) + ['--dump-every', '10']
TRAPS = ['--frames', '2060'] + keys(13) + at(start(13), ROOM13) + at(929, ROOM14) + ['--dump-every', '10']
BOSS = (['--frames', '4060'] + keys(11) + at(start(11), ROOM11) + at(1021, ROOM12_DOOR) + at(1535, ROOM13_DOOR)
        + at(2334, ROOM14) + ['--key', '3515:N'] + at(3548, ROOM16_DOOR) + ['--dump-every', '10'])
RUNS = {
    'A': DICE,
    'B': MUMMY,
    'C': STORM,
    'D': FRANK,
    'E': TRAPS,
    'F': BOSS,
}
