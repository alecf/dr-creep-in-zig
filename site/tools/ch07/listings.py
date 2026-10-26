# Every ```zig listing of Chapter 7, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch07) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/claude/dr-creep-in-zig/site/code/ch07/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch06/'

def read(root, p): return open(root + p).read()
def f7(p): return read(NEW, p)
def f6(p): return read(OLD, p)

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

ART = f7('src/art.zig')
PICTURES = '// ---- pictures for the castle'
MAIN = f7('src/main.zig')
HELPERS = '/// The explorer\'s actor slot.'
TR = f7('src/training.zig')
TR6 = f6('src/training.zig')

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
# A: keys and locks
# ============================================================================
CASTLE = f7('src/castle.zig')
step('A1', '**`src/castle.zig`** (in the header, add below `lives`)', 'after_line',
     lines_of('src/castle.zig', 'pub const keys_count', 'pub const pocket'),
     arg='pub const lives = header + 0x07; // player 1, then player 2')
OLD_BLOCK = cut(f6('src/castle.zig'), '// The monsters, keys, locks and guns', '/// How a kind\'s records')
RAYGUN6 = 'pub const RayGun = extern struct { state: u8, x: u8, y: u8, length: u8, runtime: u8, control_x: u8, control_y: u8 };\n'
REST6 = '''// The guns and monsters later chapters bring to life, and the title
// screens' pattern. For now the loader only needs their sizes, and the
// authoring kit their fields.
pub const Mummy = extern struct { state: u8, ankh_x: u8, ankh_y: u8, tomb_x: u8, tomb_y: u8, runtime: [2]u8 };
pub const Pattern = extern struct { count: u8, shape: u8, x: u8, y: u8, step_x: u8, step_y: u8 };
''' + RAYGUN6 + '''pub const Frankenstein = extern struct { state: u8, x: u8, y: u8, runtime: [4]u8 };

'''
KEYLOCK = cut(CASTLE, '/// A key: its number', '/// A ray gun, on a track')
step('A2', '**`src/castle.zig`** (replace the monsters, keys, locks and guns, from their comment to `Frankenstein`)', 'replace_text',
     KEYLOCK + REST6, arg=OLD_BLOCK)
step('A3', '**`src/shapes.zig`** (in `Id`, add at the end, after `pad`)', 'after_line', ids('key', 'lock'), arg='    pad,')
step('A4', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '// ---- keys and locks', '// ---- ray guns'), arg=PICTURES)

KIND_O = '/// Every kind of object. Later chapters add more.\npub const Kind = enum(u8) { door, bell, machine, lever, button, trapdoor, plate, belt, control, booth, %s_ };\n'
TOP_O = lines_of('src/objects.zig', '//! The room\'s object table', '//! leave the table')
TOP_O_A = rep(TOP_O, ('''//! to 32 of them, 16 bytes each: doors and doorbells, the machines and
//! the switches that work them, keys and locks, and ray guns. A key can
//! leave the table while the room runs.''', '''//! to 32 of them, 16 bytes each: doors and doorbells, the machines and
//! the switches that work them, and keys and locks. A key can leave the
//! table while the room runs.'''))
step('A5', '**`src/objects.zig`** (replace the comment at the top)', 'replace_text', TOP_O_A,
     arg=lines_of('src/objects.zig', '//! The room\'s object table', '//! and the switches', root=OLD))
step('A6', '**`src/objects.zig`** (add below the `transmitter` import)', 'after_line',
     'const locks = @import("locks.zig");\n', arg='const transmitter = @import("transmitter.zig");')
step('A7', '**`src/objects.zig`** (replace `Kind`)', 'replace_text', KIND_O % 'key, lock, ', arg=KIND_O % '')
step('A8', '**`src/objects.zig`** (in `kinds`, add below the booth\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .key = ', '    .lock = '),
     arg='    .booth = .{ .execute = transmitter.flash, .in_front = transmitter.use },')
step('A9', '**`src/objects.zig`** (replace `step`)', 'replace_fn', fn('src/objects.zig', 'step'), arg='step')
step('A10', '**`src/objects.zig`** (add below `step`)', 'insert_after_fn', fn('src/objects.zig', 'remove'), arg='step')
step('A11', '**`src/room.zig`** (add below the `transmitter` import)', 'after_line',
     'const locks = @import("locks.zig");\n', arg='const transmitter = @import("transmitter.zig");')
step('A12', '**`src/room.zig`** (in `prepares`, replace the key and lock entries)', 'replace_text',
     '    .key = locks.prepareKey,\n    .lock = locks.prepareLock,\n', arg='    .key = later,\n    .lock = later,\n')
LOCKS = f7('src/locks.zig')
step('A13', '**`src/locks.zig`** (new file)', 'whole', LOCKS[:LOCKS.index('/// A key record:')].rstrip('\n') + '\n')
step('A14', '**`src/locks.zig`** (add at the end)', 'append', fn('src/locks.zig', 'prepareKey'))
step('A15', '**`src/locks.zig`** (add at the end)', 'append', fn('src/locks.zig', 'take'))
step('A16', '**`src/locks.zig`** (add at the end)', 'append', fn('src/locks.zig', 'carrying'))
step('A17', '**`src/locks.zig`** (add at the end)', 'append', fn('src/locks.zig', 'prepareLock') + '\n' + fn('src/locks.zig', 'unlock'))
AUTH = f7('src/author.zig')
step('A18', '**`src/author.zig`** (in `checkRoom`, add above the walkways\' loop)', 'before_text',
     cut(AUTH, '    for (room.key, 0..)', '    for (room.walkway, 0..)'), arg='    for (room.walkway, 0..) |r, i| {\n')
step('A19', '**`src/training.zig`** (add below the `art` import)', 'after_line',
     'const Color = @import("machine").Color;\n', arg='const art = @import("art.zig");')
step('A20', '**`src/training.zig`** (add above `says`)', 'before_text',
     cut(TR, '/// A key of colour', '/// A room\'s words:'), arg='/// A room\'s words:')
step('A21', '**`src/training.zig`** (replace the `keys` room)', 'replace_text',
     room_of(TR, 'keys', 'ray_guns'), arg=room_of(TR6, 'keys', 'ray_guns'))
step('A22', '**`src/main.zig`** (add above `explorer`, near the end of the file)', 'before_text', test('keys:'), arg=HELPERS)
step('A23', '**`src/main.zig`** (add above `inRoom`)', 'before_text', fn('src/main.zig', 'feet') + '\n',
     arg='/// Boot, press fire on the title', run='A')

# ============================================================================
# B: locked away
# ============================================================================
step('B1', '**`src/training.zig`** (replace the `locked_away` room)', 'replace_text',
     room_of(TR, 'locked_away', 'two_players'), arg=room_of(TR6, 'locked_away', 'two_players'))
step('B2', '**`src/main.zig`** (add below the `training` import)', 'after_line',
     'const locks = @import("locks.zig");\n', arg='const training = @import("training.zig");')
step('B3', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('locked away:'), arg=HELPERS, run='B')

# ============================================================================
# C: ray guns and their panels
# ============================================================================
step('C1', '**`src/castle.zig`** (replace the guns and monsters, from their comment to `Frankenstein`)', 'replace_text',
     cut(CASTLE, '/// A ray gun, on a track', '/// How a kind\'s records'), arg=REST6)
step('C2', '**`src/shapes.zig`** (in `Id`, add at the end, after `lock`)', 'after_line', ids('track', 'panel'), arg='    lock,')
step('C3', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '// ---- ray guns', '/// A laser:'), arg=PICTURES)
step('C4', '**`src/objects.zig`** (replace the comment at the top)', 'replace_text', TOP_O, arg=TOP_O_A)
step('C5', '**`src/objects.zig`** (add below the `locks` import)', 'after_line',
     'const guns = @import("guns.zig");\n', arg='const locks = @import("locks.zig");')
step('C6', '**`src/objects.zig`** (replace `Kind`)', 'replace_text', KIND_O % 'key, lock, gun, panel, ', arg=KIND_O % 'key, lock, ')
step('C7', '**`src/objects.zig`** (in `kinds`, add below the lock\'s entry)', 'after_line',
     lines_of('src/objects.zig', '    .gun = ', '    .panel = '),
     arg='    .lock = .{ .execute = null, .in_front = locks.unlock },')
step('C8', '**`src/room.zig`** (add below the `locks` import)', 'after_line',
     'const guns = @import("guns.zig");\n', arg='const locks = @import("locks.zig");')
step('C9', '**`src/room.zig`** (in `prepares`, replace the ray gun entry)', 'replace_text',
     '    .ray_gun = guns.prepare,\n', arg='    .ray_gun = later,\n')
step('C10', '**`src/room.zig`** (replace the comment above `later`)', 'replace_text',
     '/// The monsters come alive in the next chapter.\n', arg='/// Monsters, keys, locks and guns come alive in later chapters.\n')
GUNS = f7('src/guns.zig')
GUNS_HEAD = GUNS[:GUNS.index('/// Where gun `g` hangs')]
AIM = '''
/// The gun fires when the explorer's top is fewer than 5 rows from its
/// own. Its laser flies right or left: stick directions 2 and 6.
const aim = 5;
const right = 2;
const left = 6;
'''
step('C11', '**`src/guns.zig`** (new file)', 'whole', rep(GUNS_HEAD, (AIM, '')).rstrip('\n') + '\n')
step('C12', '**`src/guns.zig`** (add at the end)', 'append',
     fn('src/guns.zig', 'gunX') + '\n' + fn('src/guns.zig', 'picture') + '\n' + fn('src/guns.zig', 'lowest'))
step('C13', '**`src/guns.zig`** (add at the end)', 'append', fn('src/guns.zig', 'prepare') + '\n' + fn('src/guns.zig', 'lamps'))
RUN = fn('src/guns.zig', 'run')
RUN_C = rep(RUN,
    ('''/// A gun's `execute`, every fourth step. Unless the explorer at its panel
/// is steering it, it turns towards his row, and fires when he's within
/// 5 rows of it. Steered, it goes where the panel says, and fires when
/// the panel says.''', '''/// A gun's `execute`, every fourth step. Unless the explorer at its panel
/// is steering it, it turns towards his row. Steered, it goes where the
/// panel says.'''),
    ('    var near: u8 = 0xFF; // rows between his top and the gun\'s\n', ''),
    ('            near = if (him > g.gun_y) him - g.gun_y else g.gun_y - him;\n', ''),
    ('''    move(m, o, g);
    if (g.state.steered) {
        g.state.steered = false; // his panel says so again if he's still there
        if (!g.state.fire) return;
        g.state.fire = false;
    } else if (near >= aim) return;
    if (g.state.shot) return; // one laser at a time
    shoot(m, o, g);
''', '''    move(m, o, g);
    g.state.steered = false; // his panel says so again if he's still there
'''))
step('C14', '**`src/guns.zig`** (add at the end)', 'append', RUN_C)
step('C15', '**`src/guns.zig`** (add at the end)', 'append', fn('src/guns.zig', 'move'))
step('C16', '**`src/guns.zig`** (add at the end)', 'append', fn('src/guns.zig', 'steer'))
step('C17', '**`src/training.zig`** (replace the `ray_guns` room)', 'replace_text',
     room_of(TR, 'ray_guns', 'mummy'), arg=room_of(TR6, 'ray_guns', 'mummy'))
T_STEER = test('ray guns: steer')
SHOT = '''    hold(m, machine.joy.fire, 4); // and fire it, over his head
    hold(m, 0, 8); // the gun hears it on its next turn
    try std.testing.expectEqual(1, count(m, .laser));
    try std.testing.expect(gun.state.shot);
    hold(m, 0, 60);
    try std.testing.expectEqual(0, count(m, .laser));
    try std.testing.expect(!gun.state.shot);
'''
step('C18', '**`src/main.zig`** (add above `explorer`)', 'before_text', rep(T_STEER, (SHOT, '')), arg=HELPERS, run='C')

# ============================================================================
# D: lasers
# ============================================================================
step('D1', '**`src/actors.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/actors.zig', '//! The actor table', '//! forcefields and lasers'),
     arg=lines_of('src/actors.zig', '//! The actor table', '//! forcefields so far', root=OLD))
step('D2', '**`src/actors.zig`** (add below the `forcefields` import)', 'after_line',
     'const guns = @import("guns.zig");\n', arg='const forcefields = @import("forcefields.zig");')
step('D3', '**`src/actors.zig`** (replace `Kind`)', 'replace_text',
     lines_of('src/actors.zig', '/// Every kind of actor', 'pub const Kind'),
     arg=lines_of('src/actors.zig', '/// Every kind of actor', 'pub const Kind', root=OLD))
step('D4', '**`src/actors.zig`** (in `kinds`, add below the forcefield\'s entry)', 'after_line',
     lines_of('src/actors.zig', '    .laser = ', '    .laser = '),
     arg='    .forcefield = .{ .turn = forcefields.shimmer, .flickers = false, .group = 0b011 },')
step('D5', '**`src/actors.zig`** (replace the first line of `kinds` and the comment above it)', 'replace_text',
     lines_of('src/actors.zig', '/// One entry for every kind, found by number.', 'const kinds'),
     arg=lines_of('src/actors.zig', '/// One entry for every kind, found by number.', 'const kinds', root=OLD))
step('D6', '**`src/shapes.zig`** (in `Id`, add at the end, after `panel`)', 'after_line', '    laser,\n', arg='    panel,')
step('D7', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     cut(ART, '/// A laser:', PICTURES), arg=PICTURES)
step('D8', '**`src/guns.zig`** (add below `stick_still`)', 'after_line', AIM, arg='const stick_still = 0x80;')
step('D9', '**`src/guns.zig`** (replace `run`)', 'replace_fn', RUN, arg='run')
step('D10', '**`src/guns.zig`** (add below `move`)', 'insert_after_fn', fn('src/guns.zig', 'shoot'), arg='move')
step('D11', '**`src/guns.zig`** (add below `shoot`)', 'insert_after_fn',
     fn('src/guns.zig', 'fly') + '\n' + fn('src/guns.zig', 'gunOf'), arg='shoot')
step('D12', '**`src/guns.zig`** (add below `gunOf`)', 'insert_after_fn',
     fn('src/guns.zig', 'blocked') + '\n' + fn('src/guns.zig', 'strike'), arg='gunOf')
step('D13', '**`src/main.zig`** (add below the `locks` import)', 'after_line',
     'const guns = @import("guns.zig");\n', arg='const locks = @import("locks.zig");')
step('D14', '**`src/main.zig`** (add above the steering test)', 'before_text', test('ray guns: along'),
     arg='test "ray guns: steer')
step('D15', '**`src/main.zig`** (in the steering test, add below the `// up to the top of its track` line)', 'after_line',
     SHOT, arg='    while (gun.gun_y != gun.y) hold(m, machine.joy.up, 2); // up to the top of its track')
step('D16', '**`src/main.zig`** (add above `explorer`)', 'before_text', test('with all eight'), arg=HELPERS, run='D')

# ============================================================================
# E: under fire
# ============================================================================
step('E1', '**`src/training.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/training.zig', '//! The Training Castle', '//! kit.'),
     arg=lines_of('src/training.zig', '//! The Training Castle', '//! kit.', root=OLD))
step('E2', '**`src/training.zig`** (replace the `under_fire` room)', 'replace_text',
     room_of(TR, 'under_fire', 'mummy_storm'), arg=room_of(TR6, 'under_fire', 'mummy_storm'))
step('E3', '**`src/main.zig`** (add above the sprite-cap test)', 'before_text',
     test('under fire: the forcefield') + test('under fire: send'), arg='test "with all eight')
step('E4', '**`src/actors.zig`** (in `hitting`, replace the `overlap` line)', 'replace_text',
     '        if (!share(m, a.box, b.box)) continue;\n', arg='        if (!objects.overlap(m, a.box, b.box)) continue;\n')
step('E5', '**`src/actors.zig`** (add below `hitting`)', 'insert_after_fn', fn('src/actors.zig', 'share'), arg='hitting', run='F')
