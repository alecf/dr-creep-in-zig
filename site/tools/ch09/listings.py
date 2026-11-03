# Every ```zig listing of Chapter 9, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch09) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/claude/dr-creep-in-zig/site/code/ch09/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch08/'

def read(root, p): return open(root + p).read()
def f9(p): return read(NEW, p)
def f8(p): return read(OLD, p)

def doc_start(lines, i):
    while i > 0 and lines[i-1].startswith('///'): i -= 1
    return i

def fn_in(text, name):
    lines = text.split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^(pub )?fn %s\(' % re.escape(name), l):
            s = doc_start(lines, i); j = i
            while lines[j] != '}': j += 1
            return '\n'.join(lines[s:j+1]) + '\n'
    raise SystemExit('no fn %s' % name)

def fn(path, name, root=NEW):
    return fn_in(read(root, path), name)

def fns(path, *names):
    return '\n'.join(fn(path, n) for n in names)

def lines_of(path, first, last, root=NEW):
    ls = read(root, path).split('\n')
    s = next(i for i, l in enumerate(ls) if l.startswith(first))
    e = next(i for i in range(s, len(ls)) if ls[i].startswith(last))
    return '\n'.join(ls[s:e+1]) + '\n'

def cut(text, first, stop):
    s = text.index(first)
    return text[s:text.index(stop, s)]

def rep(text, *pairs):
    for a, b in pairs:
        assert text.count(a) == 1, (a, text.count(a))
        text = text.replace(a, b)
    return text

STEPS = []
def step(key, label, op, text, arg=None, run=None, pad='', file=None):
    d = dict(key=key, label=label, op=op, text=text, arg=arg, run=run, pad=pad)
    if file: d['file'] = file
    STEPS.append(d)

MAIN = f9('src/main.zig')
MAIN8 = f8('src/main.zig')
PL = f9('src/player.zig')
PL8 = f8('src/player.zig')
GAME = f9('src/game.zig')
MAP = f9('src/map.zig')
MAP8 = f8('src/map.zig')
CASTLE = f9('src/castle.zig')
CASTLE8 = f8('src/castle.zig')
ART = f9('src/art.zig')
PICTURES = '// ---- pictures for the castle'
HELPERS = '/// Player 1\'s actor slot.'
FEET = '/// Where his feet are, across the room.'
TR = f9('src/training.zig')
TR8 = f8('src/training.zig')

def test(title, text=MAIN):
    """The whole-game test whose name starts with `title`, and the blank line after it."""
    s = text.index('test "' + title)
    e = text.index('\n}\n', s) + 3
    return text[s:e] + '\n'

def ids(first, last):
    return lines_of('src/shapes.zig', '    ' + first + ',', '    ' + last + ',')

def room_of(text, name, nxt):
    return cut(text, '        .%s = .{' % name, '        .%s = .{' % nxt)

def frame_mode(text, name):
    """One prong of `frame`'s switch: `.name => { ... },`."""
    s = text.index('        .%s => {' % name)
    e = text.index('\n        },\n', s) + len('\n        },\n')
    return text[s:e]

# ============================================================================
# A: the header moves in, and a second explorer
# ============================================================================
step('A1', '**`src/map.zig`** (replace the castle region and its comment)', 'replace_text',
     cut(MAP, '/// The castle: its header', '/// Where each of the 200'),
     arg=cut(MAP8, '/// The castle: its header', '/// Where each of the 200'))
step('A2', '**`src/map.zig`** (in `regions`, add below `castle`)', 'after_line', '    staging,\n', arg='    castle,')
step('A3', '**`src/main.zig`** (in `boot`, replace the castle\'s `load`)', 'replace_text',
     '    m.load(map.stars.first, &title.star_map);\n    m.load(map.staging.first, training.bytes); // a new game copies it to map.castle\n',
     arg='    m.load(map.stars.first, &title.star_map);\n    m.load(map.castle.first, training.bytes);\n')
step('A4', '**`src/castle.zig`** (replace the header, from its comment to `magic_value`)', 'replace_text',
     cut(CASTLE, '// ---- the header', '// ---- the room directory'),
     arg=cut(CASTLE8, '// ---- the header', '// ---- the room directory'))
# A5-A7: a search-and-replace table in the prose (the walker test's `room`)
step('A5', None, 'replace_text',
     '    const bytes = [_]u8{\n', arg='    const room = [_]u8{\n', file='src/castle.zig')
step('A6', None, 'replace_text',
     '    m.load(at, &bytes);\n', arg='    m.load(at, &room);\n', file='src/castle.zig')
step('A7', None, 'replace_text',
     '    try std.testing.expectEqual(at + bytes.len, walk.at);\n',
     arg='    try std.testing.expectEqual(at + room.len, walk.at);\n', file='src/castle.zig')

# the players region replaces the player region
step('A8', None, 'delete_text', None, file='src/map.zig',
     arg=cut(MAP8, '/// What the game knows about player 1', '/// Which screen the game is on'))
step('A9', None, 'delete_text', None, file='src/map.zig', arg='    player,\n')
step('A10', '**`src/map.zig`** (add above the text region)', 'before_text',
     cut(MAP, '/// What the game knows about each explorer', '/// Text: a lookup table'), arg='/// Text: a lookup table')
step('A11', '**`src/map.zig`** (in `regions`, add below `dice`)', 'after_line', '    players,\n', arg='    dice,')

# player.zig, for two
step('A12', '**`src/player.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/player.zig', '//! The explorers', '//! its ladders'),
     arg=lines_of('src/player.zig', '//! Player 1: the explorer', '//! through its doors', root=OLD))
step('A13', '**`src/player.zig`** (add above `Status`)', 'before_text',
     cut(PL, '/// Player 1 or player 2, as a number', '/// What he\'s doing, as far as the room'),
     arg='/// What he\'s doing, as far as the room')
step('A14', '**`src/player.zig`** (replace `start`)', 'replace_fn', fn('src/player.zig', 'start'), arg='start')
step('A15', None, 'delete_fns', None, arg=['newGame'], file='src/player.zig')
step('A16', '**`src/player.zig`** (add below `start`)', 'insert_after_fn',
     fns('src/player.zig', 'records', 'record', 'number', 'here', 'arrive').rstrip('\n') + '\n', arg='start')
step('A17', '**`src/player.zig`** (replace `add`)', 'replace_fn', fn('src/player.zig', 'add'), arg='add')
step('A18', '**`src/player.zig`** (add below `add`)', 'insert_after_fn',
     fns('src/player.zig', 'coat', 'picture').rstrip('\n') + '\n', arg='add')
step('A19', '**`src/player.zig`** (replace `status` and `playing`)', 'replace_text',
     fns('src/player.zig', 'status', 'setStatus', 'playing', 'walking'),
     arg=fns('src/player.zig', 'status', 'playing').replace(fn('src/player.zig', 'status'), fn_in(PL8, 'status')).replace(
         fn('src/player.zig', 'playing'), fn_in(PL8, 'playing')))
step('A20', '**`src/player.zig`** (replace `turn` and `read`)', 'replace_text',
     fns('src/player.zig', 'turn', 'read'), arg=fn_in(PL8, 'turn') + '\n' + fn_in(PL8, 'read'))
step('A21', '**`src/player.zig`** (in `steer`, replace the `ways` line)', 'replace_text',
     lines_of('src/player.zig', '    const r = record(m, number(m, n));', '    r.mask = 0xFF;'),
     arg='    const ways = waysAt(m, fx, fy);\n')
step('A22', '**`src/player.zig`** (at the end of `steer`)', 'replace_text',
     '    if (next != now) picture(m, n, @enumFromInt(next));\n',
     arg='    if (next != now) actors.setFrame(m, n, @enumFromInt(next));\n')
WALKIN_A = rep(fn('src/player.zig', 'walkIn'),
               ('/// leads to. Through the way out, he\'s escaped the castle.\n', '/// leads to.\n'),
               ('    if (d.exit != 0) m.poke(castle.escaped + p, 1);\n', ''))
step('A23', '**`src/player.zig`** (replace `walkIn` and `walk`)', 'replace_text',
     WALKIN_A + '\n' + fn('src/player.zig', 'walk'), arg=fn_in(PL8, 'walkIn') + '\n' + fn_in(PL8, 'walk'))
HIT_A = '''/// His `hit`: his sprite touched actor `other`'s. A forcefield only stands
/// in his way (the grid sees to that), and the other explorer is a
/// friend; anything else is deadly.
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    switch (actors.slot(m, other).kind) {
        .forcefield, .player => return false,
        else => return die(m, n),
    }
}
'''
step('A24', '**`src/player.zig`** (replace `kill`, `die`, `hit` and `touch`)', 'replace_text',
     fns('src/player.zig', 'kill', 'die') + '\n' + HIT_A + '\n' + fn('src/player.zig', 'touch'),
     arg='\n'.join(fn_in(PL8, n) for n in ['kill', 'die', 'hit', 'touch']))
step('A25', '**`src/player.zig`** (replace `roomOver`, `nextRoom` and `pressedFire`)', 'replace_text',
     fn('src/player.zig', 'roomOver') + '\n' + fn('src/player.zig', 'pressedFire'),
     arg='\n'.join(fn_in(PL8, n) for n in ['roomOver', 'nextRoom', 'pressedFire']))

# the game
GAME_A_HEAD = '''//! A whole game, from the title screen's fire button to its end: who
//! plays which room next, and lives. It all lives in the castle header,
//! which a new game copies afresh.

const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const castle = @import("castle.zig");
const actors = @import("actors.zig");
const player = @import("player.zig");
'''
AFTER_A = '''/// The room's over: settle up with everyone who was in it. Dead, he loses
/// a life, and starts again at the castle's start, unless that was his
/// last: then he's out of the game. Then on to the next room: false if
/// nobody's left to play it.
pub fn after(m: *Machine) bool {
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        m.work(20); // the tests
        if (player.record(m, p).actor == actors.none) continue; // he wasn't here
        if (player.status(m, p) == .dead) {
            const lives = m.peek(castle.lives + p) -| 1;
            m.poke(castle.lives + p, lives);
            if (lives == 0) {
                m.poke(castle.in_game + p, 0);
            } else {
                m.poke(castle.room + p, m.peek(castle.start_room + p));
                m.poke(castle.door + p, m.peek(castle.start_door + p));
            }
        }
    }
    return next(m);
}
'''
step('A26', '**`src/game.zig`** (new file)', 'whole',
     GAME_A_HEAD + '\n' + fns('src/game.zig', 'chosen', 'start'))
step('A27', '**`src/game.zig`** (add at the end)', 'append', fn('src/game.zig', 'next') + '\n' + AFTER_A)
step('A28', '**`src/main.zig`** (add below the `dice` import)', 'after_line',
     'const game = @import("game.zig");\n', arg='const dice = @import("dice.zig");')
TITLE_FINAL = frame_mode(MAIN, 'title')
TITLE_A = rep(TITLE_FINAL, ('setMode(m, .draw_map);', 'setMode(m, .draw_room);'))
step('A29', '**`src/main.zig`** (in `frame`, replace the `.title` prong)', 'replace_text', TITLE_A,
     arg=frame_mode(MAIN8, 'title'))
step('A30', '**`src/main.zig`** (in the `.draw_room` prong, replace `player.add(m);`)', 'replace_text',
     '            player.arrive(m);\n', arg='            player.add(m);\n')
step('A31', '**`src/main.zig`** (in the `.room` prong, replace the `roomOver` line)', 'replace_text',
     '                if (player.roomOver(m)) setMode(m, if (game.after(m)) .draw_room else .draw_title);\n',
     arg='                if (player.roomOver(m)) setMode(m, if (player.nextRoom(m)) .draw_room else .draw_title);\n')
step('A32', '**`src/room.zig`** (in `flip`, replace the `player_door` line)', 'replace_text',
     lines_of('src/room.zig', '    for (0..2) |i| { // everyone', '    }'),
     arg='    m.poke(map.player_door, 0); // he comes in by its first door\n')

# everyone who asked about "the explorer"
step('A33', '**`src/doors.zig`** (the comment on `ring`)', 'replace_text',
     lines_of('src/doors.zig', '/// A bell\'s `in_front`', '/// door is shut'),
     arg=lines_of('src/doors.zig', '/// A bell\'s `in_front`', '/// door is shut', root=OLD))
PLAYING = '    if (!player.playing(m, who) or a.fire == 0) return;\n'
PLAYING8 = '    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;\n'
step('A34', '**`src/doors.zig`** (in `ring`, replace the `return` line)', 'replace_all', PLAYING, arg=[(PLAYING8, PLAYING)])
step('A35', '**`src/conveyors.zig`** (in `press`, the same line)', 'replace_all', PLAYING, arg=[(PLAYING8, PLAYING)])
step('A36', '**`src/forcefields.zig`** (in `press`, the same)', 'replace_all', PLAYING, arg=[(PLAYING8, PLAYING)])
step('A37', '**`src/locks.zig`** (in `take` and in `unlock`, both the same)', 'replace_all', PLAYING, arg=[(PLAYING8, PLAYING)])
SEES = '    if (!player.playing(m, who)) return;\n'
SEES8 = '    if (a.kind != .player or !player.playing(m)) return;\n'
step('A38', '**`src/lightning.zig`** (in `pull`, replace the `return` line)', 'replace_all', SEES, arg=[(SEES8, SEES)])
step('A39', '**`src/guns.zig`** (in `steer`, the same)', 'replace_all', SEES, arg=[(SEES8, SEES)])
step('A40', '**`src/mummy.zig`** (in `release`, the same)', 'replace_all', SEES, arg=[(SEES8, SEES)])
TX = '    if (o.flags.execute or !player.playing(m, who)) return;\n'
step('A41', '**`src/transmitter.zig`** (in `use`, nearly the same)', 'replace_all', TX,
     arg=[('    if (o.flags.execute or a.kind != .player or !player.playing(m)) return;\n', TX)])

# the chasers, for now player 1
GUNS_A = '''        if (player.walking(m, 0)) |a| {
            const him = a.box.y;
'''
step('A42', '**`src/guns.zig`** (in `run`, replace the first two lines of the `if`)', 'replace_text', GUNS_A,
     arg=lines_of('src/guns.zig', '        if (player.playing(m)) {', '            const him', root=OLD))
step('A43', '**`src/mummy.zig`** (in `walk`, replace the two lines that find him)', 'replace_text',
     '    const him = (player.walking(m, 0) orelse return).box.x;\n',
     arg=lines_of('src/mummy.zig', '    if (!player.playing(m)) return;', '    const him', root=OLD))
step('A44', '**`src/frankenstein.zig`** (in `wakes`, the same)', 'replace_text',
     '    const him = (player.walking(m, 0) orelse return false).box;\n',
     arg=lines_of('src/frankenstein.zig', '    if (!player.playing(m)) return false;', '    const him', root=OLD))
FR_CHOOSE8_ = lines_of('src/frankenstein.zig', '    if (player.playing(m)) {', '        const him', root=OLD)
FR_CHOOSE_A = '''    if (player.walking(m, 0)) |explorer| {
        const him = explorer.box;
'''
step('A45', '**`src/frankenstein.zig`** (in `choose`, the first two lines of the `if`)', 'replace_text', FR_CHOOSE_A,
     arg=FR_CHOOSE8_)
for k, f in [('A46', 'guns'), ('A47', 'mummy'), ('A48', 'frankenstein')]:
    step(k, None, 'delete_text', None, arg='const map = @import("map.zig");\n', file='src/%s.zig' % f)

# the title
TITLE = f9('src/title.zig')
step('A49', '**`src/title.zig`** (in `star_map`, add below the `PRESS FIRE` line)', 'after_line',
     '            (row == 15 and col >= 5 and col < 35) or // STICK 2 FOR TWO\n',
     arg='            (row == 13 and col >= 10 and col < 30) or // PRESS FIRE')
step('A50', '**`src/title.zig`** (in `draw`, add below `PRESS FIRE`)', 'after_line',
     '    text.say(m, 20, 120, .grey, "STICK 2 FOR TWO");\n', arg='    text.say(m, 40, 104, .white, "PRESS FIRE");')

# the tests
RENAMES = [('m.ram[map.player_status]', 'm.ram[castle.status]'),
           ('m.ram[map.player_door]', 'm.ram[castle.door]'),
           ('m.ram[map.player_lives]', 'm.ram[castle.lives]'),
           (', m.ram[map.room_number])', ', m.ram[castle.room])')]
# A51: a find-and-replace table in the prose (a missed one won't compile)
step('A51', None, 'replace_all', None, arg=RENAMES[:3], file='src/main.zig')
# A51r: told in prose with its reason: every room check reads the header now
step('A51r', None, 'replace_all', None, arg=RENAMES[3:], file='src/main.zig')
step('A52', '**`src/main.zig`** (replace `explorer`)', 'replace_fn', fn('src/main.zig', 'explorer'), arg='explorer')
INROOM_A = rep(fn_in(MAIN8, 'inRoom'), ('    m.ram[map.room_number] = n; // instead of the castle\'s start room\n',
                                        '    m.ram[castle.room] = n; // instead of the castle\'s start room\n    m.ram[map.room_number] = n;\n'))
step('A53', '**`src/main.zig`** (in `inRoom`, replace the `room_number` line)', 'replace_text',
     '    m.ram[castle.room] = n; // instead of the castle\'s start room\n    m.ram[map.room_number] = n;\n',
     arg='    m.ram[map.room_number] = n; // instead of the castle\'s start room\n', run='A')

# The reader's project right after these steps is kept, for errs.py.

# ============================================================================
# B: two explorers in one room
# ============================================================================
step('B1', '**`src/player.zig`** (add below `walking`)', 'insert_after_fn',
     fns('src/player.zig', 'nearest', 'holding').rstrip('\n') + '\n', arg='walking')
HIT_B = fn('src/player.zig', 'hit') + '\n' + fn('src/player.zig', 'jostle')
step('B2', '**`src/player.zig`** (replace `hit`, and add `jostle` below it)', 'replace_fn', HIT_B, arg='hit')
def old(path, first, last, *pairs):
    """Lines of a ch08 file, as they stand after the listings so far."""
    return rep(lines_of(path, first, last, root=OLD), *pairs)
step('B3', '**`src/forcefields.zig`** (replace the top of `press`)', 'replace_text',
     lines_of('src/forcefields.zig', '/// A button\'s `in_front`', '    if (!player.holding(m, who)) return;'),
     arg=old('src/forcefields.zig', '/// A button\'s `in_front`', PLAYING8.rstrip('\n'), (PLAYING8, PLAYING)))
step('B4', '**`src/castle.zig`** (in the conveyor\'s state bits)', 'replace_text',
     lines_of('src/castle.zig', 'pub const conveyor_pressed', 'pub const conveyor_held'),
     arg=lines_of('src/castle.zig', 'pub const conveyor_pressed', 'pub const conveyor_held', root=OLD))
step('B5', '**`src/conveyors.zig`** (replace `press`)', 'replace_fn', fn('src/conveyors.zig', 'press'), arg='press')
step('B6', '**`src/conveyors.zig`** (in `run`, replace its comment and the press test)', 'replace_text',
     lines_of('src/conveyors.zig', '/// last step, by either player)', '    if (pressed & ~held != 0) {'),
     arg=lines_of('src/conveyors.zig', '/// last step) works the belt', '    if (pressed and c.state', root=OLD))
step('B7', '**`src/conveyors.zig`** (further down `run`, replace the two lines that remember the press)', 'replace_text',
     lines_of('src/conveyors.zig', '    c.state = (c.state & ~castle.conveyor_players)', '    c.state = (c.state & ~castle.conveyor_players)'),
     arg=lines_of('src/conveyors.zig', '    c.state &= ~(castle.conveyor_pressed', '    if (pressed) c.state |= castle.conveyor_held;', root=OLD))
step('B8', '**`src/locks.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/locks.zig', '//! Keys and locks.', '//! has a pocket'),
     arg=lines_of('src/locks.zig', '//! Keys and locks.', '//! presses fire at it with', root=OLD))
step('B9', '**`src/locks.zig`** (replace `take` and `carrying`, with `pocket` between them)', 'replace_text',
     fns('src/locks.zig', 'take', 'pocket', 'carrying'),
     arg=rep(fn_in(f8('src/locks.zig'), 'take'), (PLAYING8, PLAYING)) + '\n' + fn_in(f8('src/locks.zig'), 'carrying'))
step('B10', '**`src/locks.zig`** (in `unlock`, its comment\'s first line)', 'replace_text',
     '/// A lock\'s `in_front`: an explorer presses fire at it. With its key in\n',
     arg='/// A lock\'s `in_front`: the explorer presses fire at it. With its key in\n')
step('B11', '**`src/locks.zig`** (and its key test)', 'replace_text',
     '    if (!carrying(m, player.number(m, who), l.number)) return;\n', arg='    if (!carrying(m, l.number)) return;\n')
step('B12', '**`src/main.zig`** (in the keys test, the `carrying` line)', 'replace_text',
     '    try std.testing.expect(locks.carrying(m, 0, @intFromEnum(Color.light_blue)));\n',
     arg='    try std.testing.expect(locks.carrying(m, @intFromEnum(Color.light_blue)));\n')
step('B13', '**`src/guns.zig`** (in `run`, the `if` that finds him)', 'replace_text',
     '        if (player.nearest(m, g.gun_y)) |a| {\n', arg='        if (player.walking(m, 0)) |a| {\n')
step('B14', '**`src/mummy.zig`** (in `walk`)', 'replace_text',
     '    const him = (player.walking(m, 0) orelse player.walking(m, 1) orelse return).box.x; // player 1 first\n',
     arg='    const him = (player.walking(m, 0) orelse return).box.x;\n')
step('B15', '**`src/frankenstein.zig`** (replace `wakes`)', 'replace_fn', fn('src/frankenstein.zig', 'wakes'), arg='wakes')
step('B16', '**`src/frankenstein.zig`** (in `choose`, replace the comment and the `if`)', 'replace_text',
     lines_of('src/frankenstein.zig', '    // How far the explorers are', '    }'),
     arg=old('src/frankenstein.zig', '    // How far the explorer is', '    }', (FR_CHOOSE8_, FR_CHOOSE_A)))
step('B17', '**`src/training.zig`** (replace room 18)', 'replace_text', room_of(TR, 'two_players', 'way_out'),
     arg=room_of(TR8, 'two_players', 'way_out'), run='B')

# ============================================================================
# C: the castle map, and the clock
# ============================================================================
step('C1', '**`src/clock.zig`** (new file)', 'whole', f9('src/clock.zig'))
BETWEEN_C = '''/// The castle map's working bytes, between rooms (chart.zig).
pub const between = Region{ .name = "between rooms", .first = 0x0200, .last = 0x0206 };

'''
BETWEEN_D = cut(MAP, '/// The screens between rooms', '/// Which screen the game is on')
step('C2', '**`src/map.zig`** (add where the player region was)', 'before_text', BETWEEN_C, arg='/// Which screen the game is on')
step('C3', '**`src/map.zig`** (in `regions`, add below `stack`)', 'after_line', '    between,\n', arg='    stack,')
step('C4', '**`src/castle.zig`** (in `Entry`, the `color` line)', 'replace_text',
     '    color: u8, // low four bits: the room\'s colour. Bit 6 set: the end. Bit 7: visited\n',
     arg='    color: u8, // low four bits: the room\'s colour. Bit 6 set: the end.\n')
step('C5', '**`src/castle.zig`** (add below `end_plain`)', 'after_text',
     '\n' + cut(CASTLE, '/// Bit 7 of a colour byte', '\n\n') + '\n',
     arg=lines_of('src/castle.zig', 'pub const end_plain', 'pub const end_plain'))
step('C6', '**`src/shapes.zig`** (in `Id`, add at the end, after `frank_slide`)', 'after_line',
     ids('map_floor', 'arrow_left'), arg='    frank_slide,')
ART_C_HEAD = '// ---- the castle map ---------------------------------------------------------\n'
ART_D_HEAD = '// ---- the castle map and the escape ------------------------------------------\n'
step('C7', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     ART_C_HEAD + cut(ART, ART_D_HEAD, '/// Out of the castle, and cheering')[len(ART_D_HEAD):], arg=PICTURES)
CHART_C = rep(f9('src/chart.zig'),
              ('const game = @import("game.zig");\n', ''),
              ('/// The map at work, in the bytes it shares with the other screens\n/// between rooms (game.zig).\n',
               '/// The map at work, in its bytes between rooms (map.zig).\n'),
              ('    return &game.between(m).chart;\n', '    return m.view(Chart, map.between.first);\n'))
step('C8', '**`src/chart.zig`** (new file)', 'whole', CHART_C)
step('C9', '**`src/main.zig`** (add below the `game` import)', 'after_line',
     'const chart = @import("chart.zig");\nconst clock = @import("clock.zig");\n', arg='const game = @import("game.zig");')
MODE8 = lines_of('src/main.zig', '/// What the game is doing.', 'const Mode', root=OLD)
MODE_C = rep(lines_of('src/main.zig', '/// What the game is doing.', 'const Mode'),
             (', draw_escape, escape, draw_over, over }', ' }'))
step('C10', '**`src/main.zig`** (replace `Mode`)', 'replace_text', MODE_C, arg=MODE8)
step('C11', '**`src/main.zig`** (in the `.title` prong, the `setMode` line)', 'replace_text',
     '                setMode(m, .draw_map);\n', arg='                setMode(m, .draw_room);\n')
step('C12', '**`src/main.zig`** (add above the `.draw_room` prong)', 'before_text',
     frame_mode(MAIN, 'draw_map') + frame_mode(MAIN, 'map'), arg='        .draw_room => {\n')
step('C13', '**`src/main.zig`** (in the `.room` prong, below `actors.show`)', 'after_text',
     '            m.bucket(0);\n            clock.tick(m);\n',
     arg='            m.bucket(bucket_sprites);\n            actors.show(m);\n')
step('C14', '**`src/main.zig`** (in the `.room` prong, the `roomOver` line)', 'replace_text',
     '                if (player.roomOver(m)) setMode(m, if (game.after(m)) .draw_map else .draw_title);\n',
     arg='                if (player.roomOver(m)) setMode(m, if (game.after(m)) .draw_room else .draw_title);\n')

# the tests
def renamed(text):
    """Old test text, after the A51 renames."""
    for a, b in RENAMES: text = text.replace(a, b)
    return text
step('C15', '**`src/main.zig`** (replace the first test, the title screen\'s)', 'replace_text',
     test('fire on the title screen starts'), arg=renamed(test('fire on the title screen opens', MAIN8)))
step('C16', '**`src/main.zig`** (in the N and P test, a comment)', 'replace_text',
     '    _ = m.runFrame(@This()); // draws the map, for room 0\n', arg='    _ = m.runFrame(@This()); // draws room 0\n')
step('C17', '**`src/main.zig`** (and the one after the N)', 'replace_text', '    _ = m.runFrame(@This()); // the key, on the map\n',
     arg='    _ = m.runFrame(@This()); // the key\n')
DOOR_TEST = test('through the door and out')
DOOR_TEST8 = rep(DOOR_TEST, ('    onward(m); // the map, and fire\n', ''), ('    onward(m);\n', ''))
step('C18', '**`src/main.zig`** (replace the through-the-door test)', 'replace_text',
     DOOR_TEST, arg=DOOR_TEST8)
X_TEST = test('X: a flicker')
X_TEST_C = rep(X_TEST, ('no lives left, GAME OVER', 'no lives left, the title'),
               ('''    try std.testing.expectEqual(@intFromEnum(Mode.over), m.ram[map.game_mode]);
    hold(m, 0, 210);
''', ''))
X_TEST8 = renamed(test('X: a flicker', MAIN8))
step('C19', '**`src/main.zig`** (replace the X test)', 'replace_text', X_TEST_C, arg=X_TEST8)
step('C20', '**`src/main.zig`** (replace `back`)', 'replace_fn', fn('src/main.zig', 'back'), arg='back')
INROOM_C = fn('src/main.zig', 'inRoom') + '\n' + fn('src/main.zig', 'onward')
step('C21', '**`src/main.zig`** (replace `inRoom`, and add `onward` below it)', 'replace_fn', INROOM_C, arg='inRoom', run='C')

# ============================================================================
# D: out of the castle, and GAME OVER
# ============================================================================
ROOM = f9('src/room.zig')
step('D1', '**`src/room.zig`** (in `draw`, replace the loop over the records, and add `build` below `draw`)', 'replace_text',
     '    while (walk.next(m)) |r| build(m, r);\n}\n\n' + fn('src/room.zig', 'build').rstrip('\n'),
     arg=cut(f8('src/room.zig'), '    while (walk.next(m)) |r| {\n', '\n\n/// '))
step('D2', '**`src/room.zig`** (make `prepare` public)', 'replace_text',
     'pub fn prepare(m: *Machine, n: u8) castle.Walker {\n', arg='fn prepare(m: *Machine, n: u8) castle.Walker {\n')
step('D3', '**`src/text.zig`** (add below `say`)', 'insert_after_fn', fn('src/text.zig', 'shout'), arg='say')
step('D4', '**`src/shapes.zig`** (in `Id`, add after `arrow_left`)', 'after_line',
     ids('explorer_cheer_0', 'explorer_cheer_1'), arg='    arrow_left,')
step('D5', '**`src/art.zig`** (the section\'s heading)', 'replace_text', ART_D_HEAD, arg=ART_C_HEAD)
step('D6', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// Out of the castle, and cheering', PICTURES), arg=PICTURES)
step('D7', '**`src/escape.zig`** (new file)', 'whole', f9('src/escape.zig'))

# the game grows
step('D8', '**`src/game.zig`** (replace the top, down to the imports)', 'replace_text',
     cut(GAME, '//! A whole game', '\n/// The screens between rooms'), arg=GAME_A_HEAD)
OVER_FINAL = cut(GAME, '/// GAME OVER stays up', 'const over_frames')
OVER_SHORT = rep(OVER_FINAL, ('    unused: [6]u8,\n', ''))
BETWEEN_BLOCK = cut(GAME, '/// The screens between rooms', '/// On the title screen')
step('D9', '**`src/game.zig`** (add above `chosen`)', 'before_text',
     rep(BETWEEN_BLOCK, (OVER_FINAL, OVER_SHORT)), arg='/// On the title screen')
step('D10', '**`src/game.zig`** (replace `after`)', 'replace_text',
     cut(GAME, '/// What comes after a room.', '/// The next player to show escaping'), arg=AFTER_A)
DRAWOVER = fn('src/game.zig', 'drawOver')
DRAWOVER_SHORT = rep(DRAWOVER, ('.{ .wait = over_frames, .unused = @splat(0) }', '.{ .wait = over_frames }'))
step('D11', '**`src/game.zig`** (add at the end)', 'append',
     fn('src/game.zig', 'escaper') + '\n' + DRAWOVER_SHORT + '\n' + fn('src/game.zig', 'over'))
CHART = f9('src/chart.zig')
step('D12', '**`src/chart.zig`** (add below the `clock` import)', 'after_line',
     'const game = @import("game.zig");\n', arg='const clock = @import("clock.zig");')
step('D13', '**`src/chart.zig`** (the comment on `Chart`)', 'replace_text',
     '/// The map at work, in the bytes it shares with the other screens\n/// between rooms (game.zig).\n',
     arg='/// The map at work, in its bytes between rooms (map.zig).\n')
step('D14', '**`src/chart.zig`** (in `chart`)', 'replace_text',
     '    return &game.between(m).chart;\n', arg='    return m.view(Chart, map.between.first);\n')
step('D15', '**`src/map.zig`** (the comment on `between`)', 'replace_text',
     BETWEEN_D[:BETWEEN_D.index('pub const between')], arg=BETWEEN_C[:BETWEEN_C.index('pub const between')])
WALKIN = fn('src/player.zig', 'walkIn')
step('D16', '**`src/player.zig`** (in `walkIn`, the end of its comment)', 'replace_text',
     '/// leads to. Through the way out, he\'s escaped the castle.\n', arg='/// leads to.\n')
step('D17', '**`src/player.zig`** (at the end of `walkIn`)', 'replace_text',
     lines_of('src/player.zig', '    m.poke(castle.door + p, d.to_door);', '    if (d.exit != 0)'),
     arg=lines_of('src/player.zig', '    m.poke(castle.door + p, d.to_door);', '    m.poke(castle.door + p, d.to_door);'))
step('D18', '**`src/main.zig`** (add below the `chart` import)', 'after_line',
     'const escape = @import("escape.zig");\n', arg='const chart = @import("chart.zig");')
step('D19', '**`src/main.zig`** (in `Mode`, the four new modes)', 'replace_text',
     lines_of('src/main.zig', 'const Mode', 'const Mode'), arg=MODE_C.split('\n')[-2] + '\n')
step('D20', '**`src/main.zig`** (in the `.room` prong, the `roomOver` line)', 'replace_text',
     lines_of('src/main.zig', '                if (player.roomOver(m)) setMode(m, switch', '                });'),
     arg='                if (player.roomOver(m)) setMode(m, if (game.after(m)) .draw_map else .draw_title);\n')
step('D21', '**`src/main.zig`** (add below the `.room` prong)', 'after_text',
     ''.join(frame_mode(MAIN, k) for k in ['draw_escape', 'escape', 'draw_over', 'over']),
     arg=frame_mode(MAIN, 'room'))
step('D22', '**`src/game.zig`** (the fix: replace `Over`)', 'replace_text', OVER_FINAL, arg=OVER_SHORT)
step('D23', '**`src/game.zig`** (and, in `drawOver`, its last line)', 'replace_text',
     '    between(m).over = .{ .wait = over_frames, .unused = @splat(0) };\n',
     arg='    between(m).over = .{ .wait = over_frames };\n')
step('D24', None, 'delete_text', None, file='src/training.zig',
     arg='            .{ .x = 48, .y = 16, .color = .yellow, .height = 2, .words = "YOU ESCAPED!" },\n')
step('D25', '**`src/main.zig`** (in the search test, the loop\'s first line)', 'replace_text',
     lines_of('src/main.zig', '    const names = std.enums.values(training.Room);', '    inline for (0..names.len + 1)') + '        m.ram[map.room_number] = n;\n',
     arg='    inline for (comptime std.enums.values(training.Room), 0..) |name, n| {\n' + '        m.ram[map.room_number] = n;\n')
step('D26', '**`src/main.zig`** (further down the loop, the `plan` line)', 'replace_text',
     '        const plan = if (n == names.len) training.plan.final.? else @field(training.plan.rooms, @tagName(names[n]));\n',
     arg='        const plan = @field(training.plan.rooms, @tagName(name));\n')
step('D27', '**`src/main.zig`** (replace the X test)', 'replace_text', X_TEST, arg=X_TEST_C, run='D')

# The reader's project right after these steps is kept, for errs.py.
SNAP = {'A4', 'D21'}

# ============================================================================
# E: the Boss Battle: the whole castle, through the stick, for one and two
# ============================================================================
def chunk(first, stop=None):
    """Main's text from the line starting `first` up to the one starting `stop` (or the end)."""
    s = MAIN.index('\n' + first) + 1
    e = MAIN.index('\n' + stop, s) + 1 if stop else len(MAIN)
    return MAIN[s:e]
step('E1', '**`src/main.zig`** (replace `hold`, and add `hold2` below it)', 'replace_fn',
     fn('src/main.zig', 'hold') + '\n' + fn('src/main.zig', 'hold2'), arg='hold')
step('E2', '**`src/main.zig`** (in `escapeRayGuns`, below the panel line)', 'after_text',
     '    hold(m, 0, 8); // a turn of the gun\'s, to see him there\n',
     arg='    while (feet(m) < 41) hold(m, machine.joy.right, 2); // the panel, at x 40\n')
step('E3', '**`src/main.zig`** (replace `trapFrank`)', 'replace_fn', fn('src/main.zig', 'trapFrank'), arg='trapFrank')
step('E4', '**`src/main.zig`** (add at the end)', 'append',
     chunk('test "the whole Training Castle, from', '/// Fire at a bell'))
step('E5', '**`src/main.zig`** (add at the end)', 'append', chunk('/// Fire at a bell', 'test "the whole Training Castle for two'))
step('E6', '**`src/main.zig`** (add at the end)', 'append', chunk('test "the whole Training Castle for two', 'test "a game for two'))
step('E7', '**`src/main.zig`** (add at the end)', 'append', chunk('test "a game for two', 'test "on a ladder'))
step('E8', '**`src/main.zig`** (add at the end)', 'append', chunk('test "on a ladder', 'test "player 2 out of lives'))
step('E9', '**`src/main.zig`** (add at the end)', 'append', chunk('test "player 2 out of lives'), run='E')
