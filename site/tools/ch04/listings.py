# Every ```zig listing of Chapter 4, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch04) wherever the
# listing matches it, and written out here for intermediate states.
import re, os
NEW = '/home/user/dr-creep-in-zig/site/code/ch04/'
OLD = '/home/user/dr-creep-in-zig/site/code/ch03/'

def read(root, p): return open(root + p).read()
def f4(p): return read(NEW, p)
def f3(p): return read(OLD, p)

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
    """The lines from the one starting with `first` to the one starting with `last`, inclusive."""
    ls = read(root, path).split('\n')
    s = next(i for i, l in enumerate(ls) if l.startswith(first))
    e = next(i for i in range(s, len(ls)) if ls[i].startswith(last))
    return '\n'.join(ls[s:e+1]) + '\n'

def tail(path, first, root=NEW):
    t = read(root, path)
    return t[t.index(first):]

STEPS = []
def step(key, label, op, text, arg=None, run=None, pad=''):
    STEPS.append(dict(key=key, label=label, op=op, text=text, arg=arg, run=run, pad=pad))

# ---- A: past the wall: castle coordinates, the ninth bit, a doorway ---------
step('A2', '**`src/sprites.zig`** (add an import below `hw`)', 'after_line', 'const video = machine.video;\n', arg='const hw = machine.hw;')
step('A3', '**`src/sprites.zig`** (add at the end of the file)', 'append', fn('src/sprites.zig', 'place'))
step('A1', '**`src/map.zig`** (replace the `player_x` and `player_y` lines)', 'replace_text',
     lines_of('src/map.zig', 'pub const player_x', 'pub const player_y'),
     arg=lines_of('src/map.zig', 'pub const player_x', 'pub const player_y', root=OLD))
step('A4', '**`src/room.zig`** (replace `prepare`)', 'replace_fn',
     fn('src/room.zig', 'prepare') + '\n' + fn('src/room.zig', 'objects') + '\n' + fn('src/room.zig', 'firstDoor'), arg='prepare')
step('A5', '**`src/player.zig`** (add an import below `map`, and delete the `video` import above it)', 'replace_text',
     'const map = @import("map.zig");\nconst castle = @import("castle.zig");\n',
     arg='const video = machine.video;\nconst map = @import("map.zig");\n')
LIMITS_OLD = between('src/player.zig', '/// How far the sprite may go', '/// The first frame of each walk', root=OLD)
LIMITS_A = '''/// How far he may go, in castle X: from the left edge of the screen to
/// the right edge, less his own 8 fat pixels.
const min_x = castle.left_edge;
const max_x = castle.left_edge + 160 - 8;

''' + between('src/player.zig', '/// His feet', '/// The first frame of each walk')
step('A6', '**`src/player.zig`** (replace `min_x`, `max_x` and `floor_y`, and the comment above them)', 'replace_text', LIMITS_A, arg=LIMITS_OLD)
ENTER_A = fn('src/player.zig', 'enter').replace('    m.poke(map.player_way, still);\n', '')
step('A7', '**`src/player.zig`** (replace `enter`)', 'replace_fn', ENTER_A, arg='enter')
step('A8', '**`src/player.zig`** (replace `show`)', 'replace_fn', fn('src/player.zig', 'show'), arg='show')
step('A9', '**`src/player.zig`** (in `steer`, add at the top)', 'after_line',
     '    if (m.peek(map.game_tick) & 1 != 0) return; // the castle\'s pace: 25 steps a second\n', arg='pub fn steer(m: *Machine) void {')
WALK_OLD = '''    // Bits 2 and 3 of x count 0, 1, 2, 3 as he walks, a new frame every
    // four pixels. Standing still, he stands on frame 0.
    const step = if (walking) (x >> 2) & 0b11 else 0;
'''
WALK_A = '''    // Bits 1 and 2 of x count 0, 1, 2, 3 as he walks, a new frame every
    // two fat pixels. Standing still, he stands on frame 0.
    const step = if (walking) (x >> 1) & 0b11 else 0;
'''
step('A10', '**`src/player.zig`** (in `steer`, replace the walk-frame comment and the line below it)', 'replace_text', WALK_A, arg=WALK_OLD)
step('A11', '**`src/main.zig`** (replace the first test)', 'replace_text',
     between('src/main.zig', 'test "fire on the title screen opens the room, and the explorer walks in"', '// hall.zig is no longer loaded'),
     arg=between('src/main.zig', 'test "fire on the title screen opens the room, and the explorer walks"', '// hall.zig is no longer loaded', root=OLD))
step('A12', '**`src/main.zig`** (add at the end of the file)', 'append', fn('src/main.zig', 'hold'), run='A')

# ---- B: the navigation grid, built while the room is drawn ------------------
step('B1', '**`src/map.zig`** (add below the row table)', 'after_line',
     between('src/map.zig', '/// The navigation grid', '// ---- memory the hardware gives us').rstrip('\n') + '\n',
     arg='pub const row_table = Region{ .name = "row table", .first = 0xBB00, .last = 0xBB00 + 200 * 2 - 1 };', pad='\n')
step('B2', '**`src/map.zig`** (in `regions`, add after `sprite_frames,`)', 'after_line', '    grid,\n', arg='    sprite_frames,')
step('B3', '**`src/grid.zig`** (new file)', 'whole', between('src/grid.zig', '//! The navigation grid', '/// The ways out of piece'))
step('B4', '**`src/grid.zig`** (add at the end of the file)', 'append', between('src/grid.zig', '/// The ways out of piece', '/// The same answer as `at`'))
step('B5', '**`src/room.zig`** (add an import below `castle`)', 'after_line', 'const grid = @import("grid.zig");\n', arg='const castle = @import("castle.zig");')
DRAW_TOP_OLD = '''/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
'''
DRAW_TOP = lines_of('src/room.zig', '/// Draw the whole room', '    grid.clear(m);')
step('B6', '**`src/room.zig`** (replace the comment above `draw` and its first line)', 'replace_text', DRAW_TOP, arg=DRAW_TOP_OLD)
step('B7', "**`src/room.zig`** (in `draw`, add after the `switch` statement's closing brace, inside the loop)", 'after_text',
     '        grid.add(m, r); // walkways, ladders and poles: places to walk\n',
     arg='            else => {}, // machines and monsters come alive in later chapters\n        }\n', run='B0')
POLE_RULE_OLD = lines_of('src/author.zig', '    for ([_][]const Run{ room.ladder, room.pole }', '    }', root=OLD)
step('B8', '**`src/author.zig`** (in `checkRoom`, replace the loop over ladders and poles)', 'replace_text',
     lines_of('src/author.zig', '    // A ladder\'s bottom rung stands', '    }'), arg=None)
STEPS[-1]['arg'] = None
step('B9', '**`src/training.zig`** (in the `poles` room, replace the pole)', 'replace_text',
     '            .pole = &.{.{ .length = 8, .x = 72, .y = 128 }},\n', arg='            .pole = &.{.{ .length = 9, .x = 72, .y = 128 }},\n')
step('B10', '**`src/hall.zig`** (replace the pole\'s bytes)', 'replace_text',
     '    0x09, 0x08, 15, 64, 72, 0, // one sliding pole\n', arg='    0x09, 0x08, 16, 64, 72, 0, // one sliding pole\n')
step('B11', '**`src/hall.zig`** (in `plan`, replace the pole)', 'replace_text',
     '        .pole = &.{.{ .length = 15, .x = 64, .y = 72 }},\n', arg='        .pole = &.{.{ .length = 16, .x = 64, .y = 72 }},\n')
step('B12', '**`src/map.zig`** (add below the `room` region)', 'after_line',
     between('src/map.zig', '/// Two switches for looking inside', '/// Text: a lookup table').rstrip('\n') + '\n',
     arg='pub const room_number = room.first + 0; // its place in the castle\'s room directory', pad='\n')
step('B13', '**`src/map.zig`** (in `regions`, add after `room,`)', 'after_line', '    debug,\n', arg='    room,')
step('B14', '**`src/debug.zig`** (new file)', 'whole', f4('src/debug.zig'))
step('B15', '**`src/main.zig`** (add below the `player` import)', 'after_line', 'const debug = @import("debug.zig");\n', arg='const player = @import("player.zig");')
step('B16', "**`src/main.zig`** (in the `.draw_room` branch, add after `room.draw(m);`)", 'after_line', '            debug.overlay(m);\n', arg='            room.draw(m);')
step('B17', '**`src/main.zig`** (in the `.room` branch, replace the `room.flip` line)', 'replace_text',
     '            if (debug.keys(m) or room.flip(m)) setMode(m, .draw_room);\n', arg='            if (room.flip(m)) setMode(m, .draw_room);\n', run='B')

# ---- C: steering by the grid ------------------------------------------------
step('C1', "**`src/map.zig`** (replace the `player` region's comment and first line)", 'replace_text',
     lines_of('src/map.zig', '/// Everything the game knows about the player', 'pub const player = Region'),
     arg=lines_of('src/map.zig', '/// Everything the game knows about the player', 'pub const player = Region', root=OLD))
step('C2', '**`src/map.zig`** (add below `player_frame`)', 'after_line', lines_of('src/map.zig', 'pub const player_way', 'pub const player_way'),
     arg='pub const player_frame = player.first + 5; // shape ID of the picture in that block')
step('C3', '**`src/map.zig`** (replace the `game` region\'s first line)', 'replace_text',
     lines_of('src/map.zig', 'pub const game = Region', 'pub const game = Region'), arg=lines_of('src/map.zig', 'pub const game = Region', 'pub const game = Region', root=OLD))
step('C4', '**`src/map.zig`** (replace the `room` region\'s first line)', 'replace_text',
     lines_of('src/map.zig', 'pub const room = Region', 'pub const room = Region'), arg=lines_of('src/map.zig', 'pub const room = Region', 'pub const room = Region', root=OLD))
step('C5', '**`src/player.zig`** (add an import below `castle`)', 'after_line', 'const grid = @import("grid.zig");\n', arg='const castle = @import("castle.zig");')
LIMITS_C_DEL = LIMITS_A.split('/// His feet')[0]
step('C6', None, 'delete_text', None, arg=LIMITS_C_DEL)
STEPS[-1]['file'] = 'src/player.zig'
COMPTIME_OLD = '''comptime {
    if (left_0 != right_0 + 4 or @intFromEnum(shapes.Id.explorer_left_3) != left_0 + 3)
        @compileError("the explorer's eight frames must be in a row in shapes.Id");
}
'''
step('C7', '**`src/player.zig`** (add below the `comptime` block)', 'after_text',
     between('src/player.zig', '/// Directions run clockwise', '/// Once, at power-on.').rstrip('\n') + '\n', arg=COMPTIME_OLD, pad='\n')
step('C8', '**`src/player.zig`** (in `enter`, add below the `player_y` line)', 'after_line', '    m.poke(map.player_way, still);\n', arg='    m.poke(map.player_y, y);')
STEER = fn('src/player.zig', 'steer')
PIC_FINAL = STEER[STEER.index('    // His picture.'):]
PIC_C = '''    // His picture: Chapter 2's walk, a frame every 2 fat pixels. Climbing,
    // sliding or still, he stands for now.
    const now = m.peek(map.player_frame);
    const first: u8 = if (way == 6 or (way != 2 and now >= left_0)) left_0 else right_0;
    const next = if (way == 2 or way == 6) first + ((x >> 1) & 0b11) else first;
    if (next != now) setFrame(m, @enumFromInt(next));
}
'''
STEER_C = STEER.replace(PIC_FINAL, PIC_C)
step('C8b', '**`src/player.zig`** (replace the comment at the top)', 'replace_text',
     "//! Player 1: a multicolour sprite who walks the castle's floors, climbs its\n//! ladders and slides down its poles, steered by joystick 1.\n",
     arg='//! Player 1: a multicolour sprite who walks the floor with joystick 1.\n')
step('C9', '**`src/player.zig`** (replace `steer`)', 'replace_fn', STEER_C, arg='steer')
WAYS_C = '''/// The ways out of the cell under castle point (x, y): one byte from the
/// grid.
fn waysAt(m: *Machine, x: u8, y: u8) u8 {
    return grid.at(m, x, y);
}
'''
step('C10', '**`src/player.zig`** (add below `steer`)', 'insert_after_fn', fn('src/player.zig', 'bit') + '\n' + WAYS_C, arg='steer', run='C')

# ---- D: climbing and sliding pictures ---------------------------------------
step('D1', '**`src/shapes.zig`** (in `Id`, add at the end, after `image`)', 'after_text',
     lines_of('src/shapes.zig', '    explorer_climb_0,', '    explorer_slide,'),
     arg='    image, // points into the castle, at whichever image is being drawn\n')
step('D2', None, 'copy', None, arg='src/art.zig')
FIRSTS_OLD = '''const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);
''' + COMPTIME_OLD
FIRSTS = lines_of('src/player.zig', 'const right_0 =', '}')
step('D3', '**`src/player.zig`** (replace `right_0`, `left_0` and the `comptime` block)', 'replace_text', FIRSTS, arg=FIRSTS_OLD)
step('D4', "**`src/player.zig`** (in `steer`, replace everything from `// His picture` to the end)", 'replace_text', PIC_FINAL, arg=PIC_C, run='D')

# ---- E: the slow way, for the meter -----------------------------------------
step('E1', '**`src/grid.zig`** (add at the end of the file)', 'append', tail('src/grid.zig', '/// The same answer as `at`'))
step('E2', '**`src/player.zig`** (replace `waysAt`)', 'replace_fn', fn('src/player.zig', 'waysAt'), arg='waysAt', run='E')

# ---- F: tests ---------------------------------------------------------------
step('F1', '**`src/sprites.zig`** (add at the end of the file)', 'append', tail('src/sprites.zig', '// ---- tests'))
step('F2', '**`src/main.zig`** (add an import below `castle`)', 'after_line', 'const grid = @import("grid.zig");\n', arg='const castle = @import("castle.zig");')
F4 = tail('src/main.zig', 'test "the Ladders room\'s grid')
F4 = F4[:F4.index('/// Hold joystick 1')]
step('F4', '**`src/main.zig`** (add above `hold`, at the end of the file)', 'before_text', F4, arg=fn('src/main.zig', 'hold'), run='F')

# B8's old text (set after the call so the label line stays short)
for s in STEPS:
    if s['key'] == 'B8': s['arg'] = POLE_RULE_OLD
