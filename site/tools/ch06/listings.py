# Every ```zig listing of Chapter 6, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch06) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/claude/dr-creep-in-zig/site/code/ch06/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch05/'

def read(root, p): return open(root + p).read()
def f6(p): return read(NEW, p)
def f5(p): return read(OLD, p)

def doc_start(lines, i):
    while i > 0 and lines[i-1].startswith('///'): i -= 1
    return i

def fn(path, name, root=NEW):
    lines = read(root, path).split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^(pub )?fn %s\(' % re.escape(name), l):
            s = doc_start(lines, i); j = i
            while lines[j] != '}': j += 1
            return '\n'.join(lines[s:j+1]) + '\n'
    raise SystemExit('no fn %s in %s' % (name, path))

def between(path, first, stop, root=NEW):
    """From the line starting with `first` (doc comment included) up to,
    not including, the line starting with `stop` (and its doc comment)."""
    lines = read(root, path).split('\n')
    s = next(i for i, l in enumerate(lines) if l.startswith(first))
    s = doc_start(lines, s)
    e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith(stop))
    e = doc_start(lines, e)
    return '\n'.join(lines[s:e]).rstrip('\n') + '\n'

def lines_of(path, first, last, root=NEW):
    ls = read(root, path).split('\n')
    s = next(i for i, l in enumerate(ls) if l.startswith(first))
    e = next(i for i in range(s, len(ls)) if ls[i].startswith(last))
    return '\n'.join(ls[s:e+1]) + '\n'

def tail(path, first, root=NEW):
    t = read(root, path)
    return t[t.index(first):]

def cut(text, first, stop):
    return text[text.index(first):text.index(stop)]

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

ART = f6('src/art.zig')
PICTURES = '// ---- pictures for the castle'
MAIN = f6('src/main.zig')
HELPERS = '/// The explorer\'s actor slot.'

def test(title):
    """The whole-game test whose name starts with `title`, and the blank line after it."""
    s = MAIN.index('test "' + title)
    e = MAIN.index('\n}\n', s) + 3
    return MAIN[s:e] + '\n'

# ============================================================================
# A: lightning machines and their switch
# ============================================================================
CASTLE = f6('src/castle.zig')
step('A1', "**`src/castle.zig`** (replace the machines-and-monsters records, from their comment to `Frankenstein`)", 'replace_text',
     cut(CASTLE, '/// A lightning machine, or a switch', '/// How a kind\'s records are strung together'),
     arg=cut(f5('src/castle.zig'), '// The machines and monsters later chapters', '/// How a kind\'s records are strung together'))

IDS = f6('src/shapes.zig')
def ids(first, last):
    return lines_of('src/shapes.zig', '    ' + first + ',', '    ' + last + ',')
step('A2', '**`src/shapes.zig`** (in `Id`, add at the end, after `explorer_back_1`)', 'after_line',
     ids('machine_pole', 'lever_down'), arg='    explorer_back_1,')
step('A3', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '// ---- machines', '/// A forcefield\'s button'), arg=PICTURES)

OBJ = f6('src/objects.zig')
step('A4', '**`src/objects.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/objects.zig', '//! The room\'s object table', '//! and the switches'),
     arg=lines_of('src/objects.zig', '//! The room\'s object table', '//! to 32 of them', root=OLD))
step('A5', '**`src/objects.zig`** (add below the `doors` import)', 'after_line',
     'const lightning = @import("lightning.zig");\n', arg='const doors = @import("doors.zig");')
step('A6', '**`src/objects.zig`** (in `Object`, replace the last four fields)', 'replace_text',
     lines_of('src/objects.zig', '    number: u8,', '    spare: [3]u8'),
     arg=lines_of('src/objects.zig', '    number: u8,', '    spare: [5]u8', root=OLD))
KIND_O = '/// Every kind of object. Later chapters add more.\npub const Kind = enum(u8) { door, bell, %s_ };\n'
step('A7', '**`src/objects.zig`** (replace `Kind`)', 'replace_text',
     KIND_O % 'machine, lever, ', arg=KIND_O % '')
step('A8', '**`src/objects.zig`** (in `kinds`, add below the bell\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .machine = ', '    .lever = '), arg='    .bell = .{ .execute = null, .in_front = doors.ring },')
FIND = fn('src/objects.zig', 'find') + '\n' + fn('src/objects.zig', 'clock') + '\n'
step('A9', '**`src/objects.zig`** (add above `clear`)', 'before_text', FIND, arg='/// No objects, before a room is prepared.')
step('A10', '**`src/objects.zig`** (in `add`, add below `o.record = record;`)', 'after_line',
     '    o.actor = actors.none;\n', arg='    o.record = record;')
DOORS_FIND = fn('src/doors.zig', 'find', root=OLD)
step('A11', None, 'delete_text', None, arg=DOORS_FIND + '\n', file='src/doors.zig')
step('A12', None, 'delete_text', None, arg='const map = @import("map.zig");\n', file='src/doors.zig')
step('A13', '**`src/doors.zig`** (in `ring`, replace the `find` line)', 'replace_text',
     '    const d = objects.slot(m, objects.find(m, .door, bell.number) orelse return);\n',
     arg='    const d = objects.slot(m, find(m, bell.number) orelse return);\n')

ACT = f6('src/actors.zig')
step('A14', '**`src/actors.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/actors.zig', '//! The actor table', '//! forcefields so far'),
     arg=lines_of('src/actors.zig', '//! The actor table', '//! far; lightning', root=OLD))
step('A15', '**`src/actors.zig`** (add below the `player` import)', 'after_line',
     'const lightning = @import("lightning.zig");\n', arg='const player = @import("player.zig");')
KIND_A = '/// Every kind of actor%s. Later chapters add more.\npub const Kind = enum(u8) { player, %s_ };\n'
step('A16', '**`src/actors.zig`** (replace `Kind`)', 'replace_text',
     KIND_A % (', numbered as in 1984', 'lightning, '), arg=KIND_A % ('', ''))
step('A17', '**`src/actors.zig`** (in `kinds`, add below the player\'s entry)', 'after_line',
     '    .lightning = .{ .turn = lightning.crackle, .flickers = false },\n',
     arg='    .player = .{ .turn = player.turn, .flickers = true },')
step('A18', '**`src/actors.zig`** (add below `kinds`, after a blank line)', 'after_line',
     '\n/// No actor: what an object holds when it isn\'t running one.\npub const none: u8 = 0xFF;\n', arg='});')

ROOM = f6('src/room.zig')
step('A19', '**`src/room.zig`** (add below the `objects` import)', 'after_line',
     'const lightning = @import("lightning.zig");\n', arg='const objects = @import("objects.zig");')
step('A20', '**`src/room.zig`** (in `prepares`, replace the lightning entry)', 'replace_text',
     '    .lightning = lightning.prepare,\n', arg='    .lightning = later,\n')
step('A21', '**`src/room.zig`** (make `place` public: add `pub` in front of `fn place`)', 'replace_text',
     'pub fn place(m: *Machine, id: shapes.Id, x: u8, y: u8) void {\n', arg='fn place(m: *Machine, id: shapes.Id, x: u8, y: u8) void {\n')
step('A22', '**`src/room.zig`** (add below `place`)', 'insert_after_fn',
     fn('src/room.zig', 'tint') + '\n' + fn('src/room.zig', 'boxOf') + '\n' + fn('src/room.zig', 'first'), arg='place')

LIGHT = f6('src/lightning.zig')
LIGHT_HEAD = LIGHT[:LIGHT.index('/// A lightning record:')]
step('A23', '**`src/lightning.zig`** (new file)', 'whole', LIGHT_HEAD.rstrip('\n') + '\n')
step('A24', '**`src/lightning.zig`** (add at the end)', 'append', fn('src/lightning.zig', 'prepare'))
step('A25', '**`src/lightning.zig`** (add at the end)', 'append', fn('src/lightning.zig', 'run'))
step('A26', '**`src/lightning.zig`** (add at the end)', 'append',
     fn('src/lightning.zig', 'crackle') + '\n' + LIGHT[LIGHT.index('comptime {'):])
# The lever: the switch's in_front, which needs the eraser.
SCREEN = f6('src/screen.zig')
step('A27', '**`src/screen.zig`** (add above `// ---- tests`)', 'before_text',
     fn('src/screen.zig', 'erase') + '\n', arg='// ---- tests')
step('A28', '**`src/room.zig`** (add below `place`)', 'insert_after_fn',
     fn('src/room.zig', 'unplace') + '\n' + fn('src/room.zig', 'swap'), arg='place')
step('A29', '**`src/lightning.zig`** (add below `prepare`)', 'insert_after_fn',
     fn('src/lightning.zig', 'pull') + '\n' + fn('src/lightning.zig', 'lever'), arg='prepare')

DRAW_OLD = '''            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            room.draw(m); // and its objects
            debug.overlay(m);
            m.bucket(bucket_sprites);
            actors.clear(m);
            player.add(m);
'''
DRAW_NEW = lines_of('src/main.zig', '        .draw_room => {', '            player.add(m);').split('\n', 1)[1]
step('A31', '**`src/main.zig`** (in the `.draw_room` branch, replace its first seven lines, from `m.poke(hw.control, 0);` through `player.add(m);`)', 'replace_text',
     DRAW_NEW, arg=DRAW_OLD)

TR = f6('src/training.zig')
step('A32', '**`src/training.zig`** (replace the comment at the top, and add a `castle` import below the `author` one)', 'replace_text',
     lines_of('src/training.zig', '//! The Training Castle', 'const castle = '),
     arg=lines_of('src/training.zig', '//! The Training Castle', 'const author = ', root=OLD))
def room_of(text, name, nxt):
    return cut(text, '        .%s = .{' % name, '        .%s = .{' % nxt)
TR5 = f5('src/training.zig')
step('A33', '**`src/training.zig`** (replace the `lightning` room)', 'replace_text',
     room_of(TR, 'lightning', 'forcefields'), arg=room_of(TR5, 'lightning', 'forcefields'))

T_LIGHT = test('lightning:')
T_LIGHT_A = rep(T_LIGHT,
    ('test "lightning: the bolts kill, and the switch upstairs stops both machines"', 'test "lightning: the switch upstairs stops both machines"'),
    ('''
    // Along the floor, into the first bolt.
    hold(m, machine.joy.right, 200);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);

    // Again, the other way: up the ladder (x 56) to the switch (x 32).
    inRoom(m, 4);
''', '''
    // Up the ladder (x 56) to the switch (x 32).
'''))
COUNT = fn('src/main.zig', 'count')
step('A34', '**`src/main.zig`** (add above `explorer`, near the end of the file)', 'before_text', T_LIGHT_A, arg=HELPERS)
step('A35', '**`src/main.zig`** (add above `hold`, the last function in the file)', 'before_text', COUNT + '\n',
     arg='/// Hold joystick 1\'s', run='A')

# ============================================================================
# B: touching lightning: sprite against sprite
# ============================================================================
BEH_FINAL = lines_of('src/actors.zig', '/// What each kind does', '};')
BEH_OLD = lines_of('src/actors.zig', '/// What each kind does', '};', root=OLD)
BEH_B = rep(BEH_FINAL,
    ('''/// flickers when it dies or vanishes on the spot. `hit` is what happens
/// when its sprite touches another actor's, and `touch` when it stands in
/// front of an object; either returns true if that starts it dying. Two
/// kinds whose `group` bits overlap pass through each other unseen.''',
     '''/// flickers when it dies or vanishes on the spot. `hit` is what happens
/// when its sprite touches another actor's; it returns true if that
/// starts it dying. Two kinds whose `group` bits overlap pass through
/// each other unseen.'''),
    ('    touch: ?*const fn (m: *Machine, n: u3, object: u8) bool = null,\n', ''))
step('B1', '**`src/actors.zig`** (replace `Behaviour` and the comment above it)', 'replace_text', BEH_B, arg=BEH_OLD)
P_FINAL = '    .player = .{ .turn = player.turn, .flickers = true, .hit = player.hit, .touch = player.touch, .group = 0 },\n'
P_B = '    .player = .{ .turn = player.turn, .flickers = true, .hit = player.hit, .group = 0 },\n'
L_FINAL = '    .lightning = .{ .turn = lightning.crackle, .flickers = false, .group = 0b100 },\n'
step('B2', '**`src/actors.zig`** (in `kinds`, replace both entries)', 'replace_text', P_B + L_FINAL,
     arg='    .player = .{ .turn = player.turn, .flickers = true },\n    .lightning = .{ .turn = lightning.crackle, .flickers = false },\n')
step('B3', '**`src/actors.zig`** (in `step`, add above `a.countdown -= 1;`)', 'before_text',
     '            if (a.state.hit_sprite) hitting(m, n, sprite_hits);\n', arg='            a.countdown -= 1;\n')
step('B4', '**`src/actors.zig`** (add below `step`)', 'insert_after_fn',
     fn('src/actors.zig', 'hitting') + '\n' + fn('src/actors.zig', 'hit'), arg='step')
KILL_OLD = fn('src/player.zig', 'kill', root=OLD)
HIT = fn('src/player.zig', 'hit')
HIT_B = '''/// His `hit`: his sprite touched actor `other`'s. So far that's a bolt
/// of lightning, and lightning is deadly.
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    _ = n;
    _ = other;
    return die(m);
}
'''
step('B5', '**`src/player.zig`** (replace `kill`, and add two functions below it)', 'replace_text',
     fn('src/player.zig', 'kill') + '\n' + fn('src/player.zig', 'die') + '\n' + HIT_B, arg=KILL_OLD)
step('B6', '**`src/main.zig`** (in the lightning test, replace its first line)', 'replace_text',
     'test "lightning: the bolts kill, and the switch upstairs stops both machines" {\n',
     arg='test "lightning: the switch upstairs stops both machines" {\n')
step('B6b', '**`src/main.zig`** (in the same test, replace the `// Up the ladder` comment)', 'replace_text',
     '''    // Along the floor, into the first bolt.
    hold(m, machine.joy.right, 200);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);

    // Again, the other way: up the ladder (x 56) to the switch (x 32).
    inRoom(m, 4);
''', arg='    // Up the ladder (x 56) to the switch (x 32).\n', run='B')

# ============================================================================
# C: forcefields
# ============================================================================
step('C1', '**`src/grid.zig`** (add above `piece`)', 'before_text', fn('src/grid.zig', 'wall') + '\n',
     arg='/// The ways out of piece `i`')
step('C2', '**`src/shapes.zig`** (in `Id`, add at the end, after `lever_down`)', 'after_line',
     ids('button_frame', 'field_off'), arg='    lever_down,')
step('C3', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// A forcefield\'s button', '/// A trapdoor, in the cell'), arg=PICTURES)
step('C4', '**`src/objects.zig`** (add below the `lightning` import)', 'after_line',
     'const forcefields = @import("forcefields.zig");\n', arg='const lightning = @import("lightning.zig");')
step('C5', '**`src/objects.zig`** (replace `Kind`)', 'replace_text',
     KIND_O % 'machine, lever, button, ', arg=KIND_O % 'machine, lever, ')
step('C6', '**`src/objects.zig`** (in `kinds`, add below the lever\'s entry)', 'after_line',
     '    .button = .{ .execute = forcefields.count, .in_front = forcefields.press },\n',
     arg='    .lever = .{ .execute = null, .in_front = lightning.pull },')
step('C7', '**`src/actors.zig`** (add below the `lightning` import)', 'after_line',
     'const forcefields = @import("forcefields.zig");\n', arg='const lightning = @import("lightning.zig");')
step('C8', '**`src/actors.zig`** (replace `Kind`)', 'replace_text',
     KIND_A % (', numbered as in 1984', 'lightning, forcefield, '), arg=KIND_A % (', numbered as in 1984', 'lightning, '))
step('C9', '**`src/actors.zig`** (in `kinds`, add below the lightning entry)', 'after_line',
     '    .forcefield = .{ .turn = forcefields.shimmer, .flickers = false, .group = 0b011 },\n', arg=L_FINAL.rstrip('\n'))
step('C9b', '**`src/player.zig`** (replace `hit`)', 'replace_fn', HIT, arg='hit')
step('C10', '**`src/room.zig`** (add below the `lightning` import)', 'after_line',
     'const forcefields = @import("forcefields.zig");\n', arg='const lightning = @import("lightning.zig");')
step('C11', '**`src/room.zig`** (in `prepares`, replace the forcefield entry)', 'replace_text',
     '    .forcefield = forcefields.prepare,\n', arg='    .forcefield = later,\n')
FF = f6('src/forcefields.zig')
step('C12', '**`src/forcefields.zig`** (new file)', 'whole', FF[:FF.index('/// A forcefield record:')].rstrip('\n') + '\n')
step('C13', '**`src/forcefields.zig`** (add at the end)', 'append', fn('src/forcefields.zig', 'prepare') + '\n' + fn('src/forcefields.zig', 'raise'))
step('C14', '**`src/forcefields.zig`** (add at the end)', 'append', fn('src/forcefields.zig', 'press') + '\n' + fn('src/forcefields.zig', 'count') + '\n' + fn('src/forcefields.zig', 'gauge'))
step('C15', '**`src/forcefields.zig`** (add at the end)', 'append', fn('src/forcefields.zig', 'shimmer'))
step('C16', '**`src/training.zig`** (replace the `forcefields` room)', 'replace_text',
     room_of(TR, 'forcefields', 'trapdoors'), arg=room_of(TR5, 'forcefields', 'trapdoors'))
T_SEARCH = test('searching the castle')
T_SEARCH_C = rep(T_SEARCH,
    ('''        // The search reads only the castle, so it walks through every
        // raised forcefield and open trapdoor: two cells each.''', '''        // The search reads only the castle, so it walks through every
        // raised forcefield: two cells each.'''),
    ('''        var walls = plan.forcefield.len;
        for (plan.trapdoor) |t| walls += t.state & castle.trapdoor_open;
''', '''        const walls = plan.forcefield.len;
'''))
step('C17', '**`src/main.zig`** (replace the searching test)', 'replace_text', T_SEARCH_C,
     arg=tail('src/main.zig', 'test "searching the castle', root=OLD)[:tail('src/main.zig', 'test "searching the castle', root=OLD).index('test "a walkway')])
step('C18', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('a forcefield'), arg=HELPERS, run='C')

# ============================================================================
# D: trapdoors
# ============================================================================
step('D1', '**`src/map.zig`** (replace the `player` region\'s comment and first line, and add two bytes below `player_door`)', 'replace_text',
     lines_of('src/map.zig', '/// What the game knows about player 1', 'pub const player_last_plate'),
     arg=lines_of('src/map.zig', '/// What the game knows about player 1', 'pub const player_door', root=OLD))
step('D2', '**`src/objects.zig`** (add above `find`)', 'before_text',
     '/// No object: what the explorer\'s switch bytes hold when he isn\'t on one.\npub const none: u8 = 0xFF;\n\n',
     arg='/// The object for the room\'s `kind` number')
step('D3', '**`src/objects.zig`** (add below the `forcefields` import)', 'after_line',
     'const trapdoors = @import("trapdoors.zig");\n', arg='const forcefields = @import("forcefields.zig");')
step('D4', '**`src/objects.zig`** (replace `Kind`)', 'replace_text',
     KIND_O % 'machine, lever, button, trapdoor, plate, ', arg=KIND_O % 'machine, lever, button, ')
step('D5', '**`src/objects.zig`** (in `kinds`, add below the button\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .trapdoor = ', '    .plate = '),
     arg='    .button = .{ .execute = forcefields.count, .in_front = forcefields.press },')
step('D6', '**`src/objects.zig`** (in `touching`, add above the `in_front` line)', 'before_text',
     '        if (actors.touch(m, who, n)) a.state.flash = true;\n',
     arg='        if (kinds[@intFromEnum(o.kind)].in_front) |in_front| in_front(m, n, who);\n')
step('D7', '**`src/actors.zig`** (replace `Behaviour` and the comment above it)', 'replace_text', BEH_FINAL, arg=BEH_B)
step('D8', '**`src/actors.zig`** (in `kinds`, replace the player\'s entry)', 'replace_text', P_FINAL, arg=P_B)
step('D9', '**`src/actors.zig`** (add below `hit`)', 'insert_after_fn', fn('src/actors.zig', 'touch'), arg='hit')
step('D10', '**`src/player.zig`** (add below the `actors` import)', 'after_line',
     'const objects = @import("objects.zig");\nconst trapdoors = @import("trapdoors.zig");\n', arg='const actors = @import("actors.zig");')
step('D11', '**`src/player.zig`** (replace the `feet_y` line)', 'replace_text',
     lines_of('src/player.zig', 'pub const feet_y', 'const underfoot'), arg='const feet_y = 21;\n')
step('D12', '**`src/player.zig`** (in `add`, add below the `engine_ending` line)', 'after_line',
     '    m.poke(map.player_plate, objects.none);\n    m.poke(map.player_last_plate, objects.none);\n',
     arg='    m.poke(map.engine_ending, 0);')
step('D13', '**`src/player.zig`** (in `turn`, add below `read(m, a);`)', 'after_line', '    tread(m);\n', arg='    read(m, a);')
step('D14', '**`src/player.zig`** (add below `read`)', 'insert_after_fn', fn('src/player.zig', 'tread'), arg='read')
step('D15', '**`src/player.zig`** (add below `hit`)', 'insert_after_fn', fn('src/player.zig', 'touch'), arg='hit')
step('D16', '**`src/shapes.zig`** (in `Id`, add at the end, after `field_off`)', 'after_line',
     ids('trapdoor_shut', 'plate'), arg='    field_off,')
step('D17', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// A trapdoor, in the cell', '/// A conveyor belt, on top'), arg=PICTURES)
step('D18', '**`src/room.zig`** (add below the `forcefields` import)', 'after_line',
     'const trapdoors = @import("trapdoors.zig");\n', arg='const forcefields = @import("forcefields.zig");')
step('D19', '**`src/room.zig`** (in `prepares`, replace the trapdoor entry)', 'replace_text',
     '    .trapdoor = trapdoors.prepare,\n', arg='    .trapdoor = later,\n')
TD = f6('src/trapdoors.zig')
step('D20', '**`src/trapdoors.zig`** (new file)', 'whole', TD[:TD.index('/// A trapdoor record:')].rstrip('\n') + '\n')
step('D21', '**`src/trapdoors.zig`** (add at the end)', 'append', fn('src/trapdoors.zig', 'prepare') + '\n' + fn('src/trapdoors.zig', 'wall'))
step('D22', '**`src/trapdoors.zig`** (add at the end)', 'append', fn('src/trapdoors.zig', 'flip') + '\n' + fn('src/trapdoors.zig', 'swing'))
step('D23', '**`src/training.zig`** (replace the `trapdoors` room)', 'replace_text',
     room_of(TR, 'trapdoors', 'conveyors'), arg=room_of(TR5, 'trapdoors', 'conveyors'))
step('D24', '**`src/main.zig`** (in the searching test, replace the comment and the two lines below it)', 'replace_text',
     lines_of('src/main.zig', '        // The search reads only the castle', '        for (plan.trapdoor)'),
     arg='''        // The search reads only the castle, so it walks through every
        // raised forcefield: two cells each.
        const plan = @field(training.plan.rooms, @tagName(name));
        const walls = plan.forcefield.len;
''')
step('D25', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('a trapdoor'), arg=HELPERS, run='D')

# ============================================================================
# E: conveyors
# ============================================================================
step('E1', '**`src/shapes.zig`** (in `Id`, add at the end, after `plate`)', 'after_line', ids('belt', 'control_knob'), arg='    plate,')
step('E2', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// A conveyor belt, on top', '/// The matter transmitter'), arg=PICTURES)
step('E3', '**`src/objects.zig`** (add below the `trapdoors` import)', 'after_line',
     'const conveyors = @import("conveyors.zig");\n', arg='const trapdoors = @import("trapdoors.zig");')
step('E4', '**`src/objects.zig`** (replace `Kind`)', 'replace_text',
     KIND_O % 'machine, lever, button, trapdoor, plate, belt, control, ', arg=KIND_O % 'machine, lever, button, trapdoor, plate, ')
step('E5', '**`src/objects.zig`** (in `kinds`, add below the plate\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .belt = ', '    .control = '),
     arg='    .plate = .{ .execute = null, .in_front = null }, // the explorer\'s touch does the work')
step('E6', '**`src/room.zig`** (add below the `trapdoors` import)', 'after_line',
     'const conveyors = @import("conveyors.zig");\n', arg='const trapdoors = @import("trapdoors.zig");')
step('E7', '**`src/room.zig`** (in `prepares`, replace the conveyor entry)', 'replace_text',
     '    .conveyor = conveyors.prepare,\n', arg='    .conveyor = later,\n')
CV = f6('src/conveyors.zig')
step('E8', '**`src/conveyors.zig`** (new file)', 'whole', CV[:CV.index('/// A conveyor record:')].rstrip('\n') + '\n')
step('E9', '**`src/conveyors.zig`** (add at the end)', 'append',
     fn('src/conveyors.zig', 'prepare') + '\n' + fn('src/conveyors.zig', 'arrows') + '\n' + fn('src/conveyors.zig', 'press'))
step('E10', '**`src/conveyors.zig`** (add at the end)', 'append', fn('src/conveyors.zig', 'run'))
step('E11', '**`src/conveyors.zig`** (add at the end)', 'append', fn('src/conveyors.zig', 'carry'))
step('E12', '**`src/training.zig`** (replace the `conveyors` room)', 'replace_text',
     room_of(TR, 'conveyors', 'transmitter'), arg=room_of(TR5, 'conveyors', 'transmitter'))
step('E13', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('a conveyor'), arg=HELPERS, run='E')

# ============================================================================
# F: the matter transmitter
# ============================================================================
step('F1', '**`src/shapes.zig`** (in `Id`, add at the end, after `control_knob`)', 'after_line', ids('booth', 'pad'), arg='    control_knob,')
step('F2', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// The matter transmitter', PICTURES), arg=PICTURES)
step('F3', '**`src/objects.zig`** (add below the `conveyors` import)', 'after_line',
     'const transmitter = @import("transmitter.zig");\n', arg='const conveyors = @import("conveyors.zig");')
step('F4', '**`src/objects.zig`** (replace `Kind`)', 'replace_text',
     lines_of('src/objects.zig', '/// Every kind of object.', 'pub const Kind'),
     arg=KIND_O % 'machine, lever, button, trapdoor, plate, belt, control, ')
step('F5', '**`src/objects.zig`** (in `kinds`, add below the control box\'s entry)', 'after_line',
     '    .booth = .{ .execute = transmitter.flash, .in_front = transmitter.use },\n',
     arg='    .control = .{ .execute = null, .in_front = conveyors.press },')
step('F6', '**`src/room.zig`** (add below the `conveyors` import)', 'after_line',
     'const transmitter = @import("transmitter.zig");\n', arg='const conveyors = @import("conveyors.zig");')
step('F7', '**`src/room.zig`** (in `prepares`, replace the teleport entry)', 'replace_text',
     '    .teleport = transmitter.prepare,\n', arg='    .teleport = later,\n')
step('F8', '**`src/room.zig`** (replace the comment above `later`)', 'replace_text',
     '/// Monsters, keys, locks and guns come alive in later chapters.\n', arg='/// Machines and monsters come alive in later chapters.\n')
TX = f6('src/transmitter.zig')
step('F9', '**`src/transmitter.zig`** (new file)', 'whole', TX[:TX.index('/// A teleport record:')].rstrip('\n') + '\n')
step('F10', '**`src/transmitter.zig`** (add at the end)', 'append', fn('src/transmitter.zig', 'prepare'))
step('F11', '**`src/transmitter.zig`** (add at the end)', 'append', fn('src/transmitter.zig', 'use') + '\n' + fn('src/transmitter.zig', 'flash'))
step('F12', '**`src/training.zig`** (replace the `transmitter` room)', 'replace_text',
     room_of(TR, 'transmitter', 'keys'), arg=room_of(TR5, 'transmitter', 'keys'))
step('F13', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('the transmitter'), arg=HELPERS)
step('F14', '**`src/screen.zig`** (add above the `plot` test)', 'before_text',
     cut(SCREEN, 'test "erase takes out', 'test "plot sets one fat pixel'), arg='test "plot sets one fat pixel', run='F')
