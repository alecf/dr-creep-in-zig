# Every ```zig listing of Chapter 8, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch08) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/claude/dr-creep-in-zig/site/code/ch08/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch07/'

def read(root, p): return open(root + p).read()
def f8(p): return read(NEW, p)
def f7(p): return read(OLD, p)

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

def lines_of(path, first, last, root=NEW):
    ls = read(root, path).split('\n')
    s = next(i for i, l in enumerate(ls) if l.startswith(first))
    e = next(i for i in range(s, len(ls)) if ls[i].startswith(last))
    return '\n'.join(ls[s:e+1]) + '\n'

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

ART = f8('src/art.zig')
PICTURES = '// ---- pictures for the castle'
MAIN = f8('src/main.zig')
HELPERS = '/// The explorer\'s actor slot.'
FEET = '/// Where his feet are, across the room.'
TR = f8('src/training.zig')
TR7 = f7('src/training.zig')

def test(title):
    """The whole-game test whose name starts with `title`, and the blank line after it."""
    s = MAIN.index('test "' + title)
    e = MAIN.index('\n}\n', s) + 3
    return MAIN[s:e] + '\n'

def ids(first, last):
    return lines_of('src/shapes.zig', '    ' + first + ',', '    ' + last + ',')

def room_of(text, name, nxt):
    return cut(text, '        .%s = .{' % name, '        .%s = .{' % nxt)

# ============================================================================
# A: the dice
# ============================================================================
MAP = f8('src/map.zig')
step('A1', '**`src/map.zig`** (add above the text region)', 'before_text',
     cut(MAP, '/// The dice: two bytes', '/// Text: a lookup table'), arg='/// Text: a lookup table')
step('A2', '**`src/map.zig`** (in `regions`, add below `engine`)', 'after_line', '    dice,\n', arg='    engine,')
DICE = f8('src/dice.zig')
step('A3', '**`src/dice.zig`** (new file)', 'whole', DICE[:DICE.index('/// Roll: the next byte.')].rstrip('\n') + '\n')
step('A4', '**`src/dice.zig`** (add at the end)', 'append', fn('src/dice.zig', 'roll'))
step('A5', '**`src/dice.zig`** (add at the end)', 'append', DICE[DICE.index('// ---- tests'):])
step('A6', '**`src/main.zig`** (add below the `guns` import)', 'after_line',
     'const dice = @import("dice.zig");\n', arg='const guns = @import("guns.zig");')
step('A7', '**`src/main.zig`** (in `boot`, add below `player.start`)', 'after_line',
     '    dice.start(m);\n', arg='    player.start(m);')
step('A8', '**`src/lightning.zig`** (add below the `player` import)', 'after_line',
     'const dice = @import("dice.zig");\n', arg='const player = @import("player.zig");')
step('A9', '**`src/lightning.zig`** (replace `crackle`)', 'replace_fn', fn('src/lightning.zig', 'crackle'),
     arg='crackle', run='A')

# ============================================================================
# B: the mummy
# ============================================================================
CASTLE = f8('src/castle.zig')
OLD_BLOCK = cut(f7('src/castle.zig'), '// The monsters the next chapter', '/// How a kind\'s records')
REST_B = '''// Frankenstein's monster, later in this chapter, and the title screens'
// pattern. For now the loader only needs their sizes, and the authoring
// kit their fields.
pub const Pattern = extern struct { count: u8, shape: u8, x: u8, y: u8, step_x: u8, step_y: u8 };
pub const Frankenstein = extern struct { state: u8, x: u8, y: u8, runtime: [4]u8 };

'''
MUMMY_REC = cut(CASTLE, '/// A mummy, his tomb', '/// A Frankenstein\'s monster')
step('B1', '**`src/castle.zig`** (replace the monsters and the pattern, from their comment to `Frankenstein`)', 'replace_text',
     MUMMY_REC + REST_B, arg=OLD_BLOCK)
step('B2', '**`src/shapes.zig`** (in `Id`, add at the end, after `laser`)', 'after_line', ids('brick', 'mummy_left_2'), arg='    laser,')
step('B3', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '// ---- the mummy', '// ---- Frankenstein'), arg=PICTURES)
MAP7 = f7('src/map.zig')
step('B4', '**`src/map.zig`** (replace the star map and the shape table)', 'replace_text',
     lines_of('src/map.zig', 'pub const stars', 'pub const shape_table'),
     arg=lines_of('src/map.zig', 'pub const stars', 'pub const shape_table', root=OLD))

OBJ = f8('src/objects.zig')
KIND_O = '/// Every kind of object. Later chapters add more.\npub const Kind = enum(u8) { door, bell, machine, lever, button, trapdoor, plate, belt, control, booth, key, lock, gun, panel, %s_ };\n'
step('B5', '**`src/objects.zig`** (in `Object`, replace the `spare` bytes)', 'replace_text',
     lines_of('src/objects.zig', '    plate: u8,', '    spare: u8,'), arg='    spare: [3]u8, // for the monsters to come\n')
step('B6', '**`src/objects.zig`** (in `add`, replace the last two lines before `return n`)', 'replace_text',
     lines_of('src/objects.zig', '    o.actor = actors.none;', '    m.work(36);'),
     arg='    o.actor = actors.none;\n    m.work(30); // the stores\n')
step('B7', '**`src/objects.zig`** (add above `clock`)', 'before_text', fn('src/objects.zig', 'owner') + '\n',
     arg='/// The engine\'s clock')
GUNS = f8('src/guns.zig')
step('B8', '**`src/guns.zig`** (in `fly`, replace the `gunOf` line)', 'replace_text',
     '        if (objects.owner(m, .gun, n)) |o| {\n', arg='        if (gunOf(m, n)) |o| {\n')
step('B9', None, 'delete_fns', None, arg=['gunOf'], file='src/guns.zig')

TRAP = f8('src/trapdoors.zig')
step('B10', '**`src/trapdoors.zig`** (add below the `objects` import)', 'after_line',
     'const actors = @import("actors.zig");\nconst player = @import("player.zig");\n', arg='const objects = @import("objects.zig");')
step('B11', '**`src/trapdoors.zig`** (add below `open`)', 'after_line',
     '\n' + cut(TRAP, '/// Something is under an actor', '/// The switch\'s middle').rstrip('\n') + '\n',
     arg='const open = pictures.len - 1;')
step('B12', '**`src/trapdoors.zig`** (add at the end)', 'append',
     cut(TRAP, '/// What an actor can find', '/// What actor `n`') + fn('src/trapdoors.zig', 'under'))
step('B13', '**`src/trapdoors.zig`** (add at the end)', 'append', fn('src/trapdoors.zig', 'tread'))
PL7 = f7('src/player.zig')
step('B14', None, 'delete_text',
     None, file='src/player.zig', arg=cut(PL7, '/// Something under his feet', '/// Where he appears in a doorway'))
step('B15', '**`src/player.zig`** (in `turn`, replace the `tread` line)', 'replace_text',
     '    trapdoors.tread(m, m.view(u8, map.player_plate), m.view(u8, map.player_last_plate));\n', arg='    tread(m);\n')
step('B16', None, 'delete_fns', None, arg=['tread'], file='src/player.zig')
step('B17', '**`src/player.zig`** (replace `touch`)', 'replace_fn', fn('src/player.zig', 'touch'), arg='touch')

MUM = f8('src/mummy.zig')
step('B18', '**`src/mummy.zig`** (new file)', 'whole', MUM[:MUM.index('/// The ankh\'s colours')].rstrip('\n') + '\n')
step('B19', '**`src/mummy.zig`** (add at the end)', 'append', fn('src/mummy.zig', 'prepare') + '\n' + fn('src/mummy.zig', 'open'))
step('B20', '**`src/mummy.zig`** (add above `prepare`)', 'before_text',
     cut(MUM, '/// The ankh\'s colours', '/// Climbing out'), arg='/// A mummy record:')
step('B21', '**`src/mummy.zig`** (add at the end)', 'append', fn('src/mummy.zig', 'release') + '\n' + fn('src/mummy.zig', 'glow'))
step('B22', '**`src/mummy.zig`** (add above `prepare`)', 'before_text',
     cut(MUM, '/// Climbing out', '/// A mummy record:'), arg='/// A mummy record:')
step('B23', '**`src/mummy.zig`** (add at the end)', 'append', fn('src/mummy.zig', 'wake'))
step('B24', '**`src/mummy.zig`** (add at the end)', 'append', fn('src/mummy.zig', 'walk'))
step('B25', '**`src/mummy.zig`** (add at the end)', 'append', fn('src/mummy.zig', 'hit') + '\n' + fn('src/mummy.zig', 'touch'))

step('B26', '**`src/objects.zig`** (add below the `guns` import)', 'after_line',
     'const mummy = @import("mummy.zig");\n', arg='const guns = @import("guns.zig");', file='src/objects.zig')
step('B27', '**`src/objects.zig`** (replace `Kind`)', 'replace_text', KIND_O % 'ankh, ', arg=KIND_O % '')
step('B28', '**`src/objects.zig`** (in `kinds`, add below the panel\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .ankh = ', '    .ankh = '),
     arg='    .panel = .{ .execute = null, .in_front = guns.steer },')

ACT = f8('src/actors.zig')
ACT7 = f7('src/actors.zig')
step('B29', '**`src/actors.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/actors.zig', '//! The actor table', '//! forcefields, lasers'),
     arg=lines_of('src/actors.zig', '//! The actor table', '//! forcefields and lasers', root=OLD))
step('B30', '**`src/actors.zig`** (add below the `guns` import)', 'after_line',
     'const mummy = @import("mummy.zig");\n', arg='const guns = @import("guns.zig");')
KIND_A = '/// Every kind of actor, numbered as in 1984.\npub const Kind = enum(u8) { player, lightning, forcefield, mummy, laser, _ };\n'
step('B31', '**`src/actors.zig`** (replace `Kind`)', 'replace_text', KIND_A,
     arg=lines_of('src/actors.zig', '/// Every kind of actor', 'pub const Kind', root=OLD))
step('B32', '**`src/actors.zig`** (in `kinds`, add below the forcefield\'s entry)', 'after_line',
     lines_of('src/actors.zig', '    .mummy = ', '    .mummy = '),
     arg='    .forcefield = .{ .turn = forcefields.shimmer, .flickers = false, .group = 0b011 },')
step('B33', '**`src/actors.zig`** (replace the first line of `kinds` and the comment above it)', 'replace_text',
     lines_of('src/actors.zig', '/// One entry for every kind, found by number.', 'const kinds'),
     arg=lines_of('src/actors.zig', '/// One entry for every kind, found by number.', 'const kinds', root=OLD))

step('B34', '**`src/room.zig`** (add below the `guns` import)', 'after_line',
     'const mummy = @import("mummy.zig");\n', arg='const guns = @import("guns.zig");')
step('B35', '**`src/room.zig`** (in `prepares`, replace the mummy\'s entry)', 'replace_text',
     '    .mummy = mummy.prepare,\n', arg='    .mummy = later,\n')
AUTH = f8('src/author.zig')
step('B36', '**`src/author.zig`** (in `checkRoom`, add above the walkways\' loop)', 'before_text',
     cut(AUTH, '    for (room.mummy, 0..)', '    for (room.frankenstein, 0..)'), arg='    for (room.walkway, 0..) |r, i| {\n')
step('B37', '**`src/training.zig`** (replace the `mummy` room)', 'replace_text',
     room_of(TR, 'mummy', 'frankenstein'), arg=room_of(TR7, 'mummy', 'frankenstein'))
step('B38', '**`src/main.zig`** (add above `explorer`)', 'before_text',
     test('the mummy: past') + test('the mummy: caught'), arg=HELPERS)
step('B39', '**`src/main.zig`** (add above `feet`)', 'before_text',
     fn('src/main.zig', 'monster') + '\n' + fn('src/main.zig', 'distance') + '\n' + fn('src/main.zig', 'back') + '\n'
     + fn('src/main.zig', 'escapeMummy') + '\n', arg=FEET, run='B')

# ============================================================================
# C: mummy in a storm
# ============================================================================
step('C1', '**`src/training.zig`** (replace the `mummy_storm` room)', 'replace_text',
     room_of(TR, 'mummy_storm', 'locked_away'), arg=room_of(TR7, 'mummy_storm', 'locked_away'))
step('C2', '**`src/main.zig`** (add above `explorer`)', 'before_text',
     test('mummy in a storm: one') + test('mummy in a storm: caught'), arg=HELPERS)
step('C3', '**`src/main.zig`** (add above `feet`)', 'before_text', fn('src/main.zig', 'stormOut') + '\n',
     arg=FEET, run='C')

# ============================================================================
# D: Frankenstein's monster
# ============================================================================
step('D1', '**`src/castle.zig`** (replace Frankenstein and the pattern, from their comment to `Frankenstein`)', 'replace_text',
     cut(CASTLE, '/// A Frankenstein\'s monster', '/// How a kind\'s records'), arg=REST_B)
step('D2', '**`src/shapes.zig`** (in `Id`, add at the end, after `mummy_left_2`)', 'after_line',
     ids('alcove_right', 'frank_slide'), arg='    mummy_left_2,')
step('D3', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '// ---- Frankenstein', PICTURES), arg=PICTURES)
step('D4', '**`src/objects.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/objects.zig', '//! The room\'s object table', '//! runs.'),
     arg=lines_of('src/objects.zig', '//! The room\'s object table', '//! leave the table', root=OLD))
step('D5', '**`src/objects.zig`** (add below the `mummy` import)', 'after_line',
     'const frankenstein = @import("frankenstein.zig");\n', arg='const mummy = @import("mummy.zig");')
step('D6', '**`src/objects.zig`** (replace `Kind`)', 'replace_text', KIND_O % 'ankh, alcove, ', arg=KIND_O % 'ankh, ')
step('D7', '**`src/objects.zig`** (in `kinds`, add below the ankh\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .alcove = ', '    .alcove = '),
     arg='    .ankh = .{ .execute = mummy.glow, .in_front = mummy.release },')
FR = f8('src/frankenstein.zig')
step('D8', '**`src/frankenstein.zig`** (new file)', 'whole', FR[:FR.index('/// He wakes when')].rstrip('\n') + '\n')
step('D9', '**`src/frankenstein.zig`** (add at the end)', 'append', fn('src/frankenstein.zig', 'prepare'))
step('D10', '**`src/frankenstein.zig`** (add above `prepare`)', 'before_text',
     cut(FR, '/// He wakes when', '/// His pictures:'), arg='/// A Frankenstein record:')
step('D11', '**`src/frankenstein.zig`** (add at the end)', 'append',
     fn('src/frankenstein.zig', 'turn') + '\n' + fn('src/frankenstein.zig', 'wakes'))
step('D12', '**`src/frankenstein.zig`** (add at the end)', 'append',
     fn('src/frankenstein.zig', 'choose') + '\n' + fn('src/frankenstein.zig', 'bit'))
step('D13', '**`src/frankenstein.zig`** (add above `prepare`)', 'before_text',
     cut(FR, '/// His pictures:', '/// A Frankenstein record:'), arg='/// A Frankenstein record:')
step('D14', '**`src/frankenstein.zig`** (add at the end)', 'append', fn('src/frankenstein.zig', 'move'))
step('D15', '**`src/frankenstein.zig`** (add at the end)', 'append',
     fn('src/frankenstein.zig', 'hit') + '\n' + fn('src/frankenstein.zig', 'touch'))
step('D16', '**`src/actors.zig`** (add below the `mummy` import)', 'after_line',
     'const frankenstein = @import("frankenstein.zig");\n', arg='const mummy = @import("mummy.zig");')
step('D17', '**`src/actors.zig`** (replace `Kind`)', 'replace_text',
     lines_of('src/actors.zig', '/// Every kind of actor', 'pub const Kind'), arg=KIND_A)
step('D18', '**`src/actors.zig`** (in `kinds`, add below the laser\'s entry)', 'after_line',
     lines_of('src/actors.zig', '    .frankenstein = ', '    .frankenstein = '),
     arg=lines_of('src/actors.zig', '    .laser = ', '    .laser = ').rstrip('\n'))
step('D19', '**`src/room.zig`** (add below the `mummy` import)', 'after_line',
     'const frankenstein = @import("frankenstein.zig");\n', arg='const mummy = @import("mummy.zig");')
step('D20', '**`src/room.zig`** (in `prepares`, replace Frankenstein\'s entry)', 'replace_text',
     '    .frankenstein = frankenstein.prepare,\n', arg='    .frankenstein = later,\n')
step('D21', '**`src/room.zig`** (replace the comment above `later`)', 'replace_text',
     '/// The title screens\' pattern comes alive in Chapter 11.\n',
     arg='/// The monsters come alive in the next chapter, the title screens\' pattern later.\n')
step('D22', '**`src/author.zig`** (in `checkRoom`, add above the walkways\' loop)', 'before_text',
     cut(AUTH, '    for (room.frankenstein, 0..)', '    for (room.walkway, 0..)'), arg='    for (room.walkway, 0..) |r, i| {\n')
step('D23', '**`src/guns.zig`** (replace `strike`)', 'replace_fn', fn('src/guns.zig', 'strike'), arg='strike')
step('D24', '**`src/training.zig`** (replace the `frankenstein` room)', 'replace_text',
     room_of(TR, 'frankenstein', 'frank_trap'), arg=room_of(TR7, 'frankenstein', 'frank_trap'))
M7 = f7('src/main.zig')
step('D25', '**`src/main.zig`** (in the search test, replace everything from the comment above `const plan` to the end of the loop)', 'replace_text',
     cut(MAIN, '        // The search reads only the castle', '    }\n}\n\ntest "a walkway'),
     arg=cut(M7, '        // The search reads only the castle', '    }\n}\n\ntest "a walkway'))
step('D26', '**`src/main.zig`** (add above `explorer`)', 'before_text',
     test('Frankenstein: he sleeps') + test('Frankenstein: caught') + test('Frankenstein: asleep'), arg=HELPERS, run='D')

# ============================================================================
# E: a trap for Frank, and Frank's ride
# ============================================================================
step('E1', '**`src/training.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/training.zig', '//! The Training Castle', '//! kit.'),
     arg=lines_of('src/training.zig', '//! The Training Castle', '//! kit.', root=OLD))
step('E2', '**`src/training.zig`** (add below the `art` import)', 'after_line',
     'const shapes = @import("shapes.zig");\n', arg='const art = @import("art.zig");')
step('E3', '**`src/training.zig`** (replace the `frank_trap` room)', 'replace_text',
     room_of(TR, 'frank_trap', 'frank_ride'), arg=room_of(TR7, 'frank_trap', 'frank_ride'))
step('E4', '**`src/main.zig`** (add above `explorer`)', 'before_text',
     test('a trap for Frank: the switch') + test('a trap for Frank: without') + test('a trap for Frank: caught'), arg=HELPERS)
step('E5', '**`src/main.zig`** (add above `feet`)', 'before_text', fn('src/main.zig', 'trapFrank') + '\n', arg=FEET)
CONV = f8('src/conveyors.zig')
step('E6', '**`src/conveyors.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/conveyors.zig', '//! Conveyor belts', '//! control stops'),
     arg=lines_of('src/conveyors.zig', '//! Conveyor belts', '//! starts it again', root=OLD))
step('E7', '**`src/conveyors.zig`** (replace `carry`)', 'replace_fn', fn('src/conveyors.zig', 'carry'), arg='carry')
step('E8', '**`src/training.zig`** (replace the `frank_ride` room)', 'replace_text',
     room_of(TR, 'frank_ride', 'under_fire'), arg=room_of(TR7, 'frank_ride', 'under_fire'))
step('E9', '**`src/main.zig`** (add above `explorer`)', 'before_text',
     test('Frank\'s ride: the belt') + test('Frank\'s ride: caught'), arg=HELPERS)
step('E10', '**`src/main.zig`** (add above `feet`)', 'before_text', fn('src/main.zig', 'rideOut') + '\n',
     arg=FEET, run='EF')

# The reader's project right after these steps is kept, for errs.py.
SNAP = {'B3'}
