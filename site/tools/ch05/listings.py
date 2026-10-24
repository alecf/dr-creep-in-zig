# Every ```zig listing of Chapter 5, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch05) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/user/dr-creep-in-zig/site/code/ch05/'
OLD = '/home/user/dr-creep-in-zig/site/code/ch04/'

def read(root, p): return open(root + p).read()
def f5(p): return read(NEW, p)
def f4(p): return read(OLD, p)

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

# ============================================================================
# A: the actor table, and the explorer as actor 0
# ============================================================================
step('A1', "**`src/map.zig`** (replace the `player` region, its comment and its seven bytes)", 'replace_text',
     between('src/map.zig', '/// What the game knows about player 1', '/// Which screen the game is on'),
     arg=between('src/map.zig', '/// Everything the game knows about the player', '/// Which screen the game is on', root=OLD))
step('A2', '**`src/map.zig`** (add below the row table)', 'after_line',
     between('src/map.zig', '/// The actor table', '/// The room\'s object table'),
     arg='pub const row_table = Region{ .name = "row table", .first = 0xBB00, .last = 0xBB00 + 200 * 2 - 1 };', pad='\n')
step('A3', '**`src/map.zig`** (in `regions`, add after `row_table,`)', 'after_line', '    actors,\n', arg='    row_table,')

ACT = f5('src/actors.zig')
ACT_HEAD = ACT[:ACT.index('/// Hand every actor to the VIDEO chip')]
ACT_A_HEAD = rep(ACT_HEAD,
    ('const Color = machine.Color;\n', ''),
    ('const objects = @import("objects.zig");\n', ''),
    ('''/// What each kind does: the function that takes its turn, and whether it
/// flickers when it dies or vanishes on the spot.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
    flickers: bool,
};''', '''/// What each kind does: the function that takes its turn.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
};'''),
    ('    .player = .{ .turn = player.turn, .flickers = true },', '    .player = .{ .turn = player.turn },'),
    ('''/// Empty every slot, and forget any collisions, before a room starts.''', '''/// Empty every slot, before a room starts.'''),
    ('''        m.work(10); // the store and the loop
    }
    m.poke(hw.sprite_sprite_hits, 0);
    m.poke(hw.sprite_bitmap_hits, 0);
}''', '''        m.work(10); // the store and the loop
    }
}'''))
SHOW = fn('src/actors.zig', 'show')
SHOW_A = rep(SHOW,
    ('        if (a.state.unused or a.state.destroy) continue; // gone, or going\n', '        if (a.state.unused) continue;\n'),
    ('        if (!a.state.dying) multicolor |= bit; // dying, it flickers in one colour\n', '        multicolor |= bit;\n'))
STEP = fn('src/actors.zig', 'step')
STEP_A = '''/// One engine step for every actor, in slot order: each one whose
/// countdown runs out takes its turn.
pub fn step(m: *Machine) void {
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused) continue;
        const n: u3 = @intCast(i);
        if (a.state.destroy) {
            kinds[@intFromEnum(a.kind)].turn(m, n); // its last turn
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            kinds[@intFromEnum(a.kind)].turn(m, n);
        }
        if (a.state.free) a.state = .{ .unused = true };
        a.countdown = a.pace;
        m.work(30); // the flags
    }
}
'''
SETFRAME = fn('src/actors.zig', 'setFrame')
ACT_A = ACT_A_HEAD + SHOW_A + '\n' + STEP_A + '\n' + SETFRAME
def cut(t, *marks):
    idx = [0] + [t.index(mk) for mk in marks] + [len(t)]
    return [t[a:b].rstrip('\n') + '\n' for a, b in zip(idx, idx[1:])]
A4 = cut(ACT_A, '/// Every kind of actor.', 'pub const slots = 8;', '/// Hand every actor to the VIDEO chip')
step('A4', '**`src/actors.zig`** (new file)', 'whole', A4[0])
step('A4b', '**`src/actors.zig`** (add at the end of the file)', 'append', A4[1])
step('A4c', '**`src/actors.zig`** (add at the end of the file)', 'append', A4[2])
step('A4d', '**`src/actors.zig`** (add at the end of the file)', 'append', A4[3])

PL = f5('src/player.zig'); PL4 = f4('src/player.zig')
step('A5', '**`src/player.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/player.zig', '//! Player 1', '//! through its doors'),
     arg=lines_of('src/player.zig', '//! Player 1', '//! ladders and slides', root=OLD))
step('A6', '**`src/player.zig`** (replace the `sprites` import)', 'replace_text',
     'const actors = @import("actors.zig");\n', arg='const sprites = @import("sprites.zig");\n')
step('A7', None, 'delete_text', None, arg='''/// Which of the VIDEO chip's eight sprite slots (0-7) is the player's.
/// He shows block 0 or block 8, whichever one isn't being rewritten.
const player_sprite = 0;

''', file='src/player.zig')
step('A8', '**`src/player.zig`** (replace `start`)', 'replace_fn', fn('src/player.zig', 'start'), arg='start')
ADD = fn('src/player.zig', 'add')
ADD_A = '''/// Into the room: an actor slot, and his place in its first doorway,
/// facing into the room. A room with no doors (the final room) puts him in
/// the middle of the floor.
pub fn add(m: *Machine) void {
    const n = actors.add(m, .player) orelse return; // he's the first in, so never
    m.poke(map.player_actor, n);
    const a = actors.slot(m, n);
    a.box.x = castle.left_edge + 80;
    a.box.y = room.floor_top - feet_y;
    a.way = still;
    if (room.firstDoor(m)) |at| {
        const d = m.view(castle.Door, at);
        a.box.x = d.x + door_x;
        a.box.y = d.y + door_y;
    }
    m.work(40); // the sums and the stores
    actors.setFrame(m, n, if (a.box.x < castle.left_edge + 80) .explorer_right_0 else .explorer_left_0);
}
'''
step('A9', '**`src/player.zig`** (replace `enter`)', 'replace_fn', ADD_A, arg='enter')
TURN = fn('src/player.zig', 'turn')
TURN_A = '''/// His turn, actor `n`'s: on every engine step.
pub fn turn(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    a.state.created = false;
    read(m, a);
    steer(m, n);
}
'''
step('A10', '**`src/player.zig`** (replace `show`)', 'replace_fn', TURN_A + '\n' + fn('src/player.zig', 'read'), arg='show')
step('A11', '**`src/player.zig`** (replace `steer`)', 'replace_fn', fn('src/player.zig', 'steer'), arg='steer')
step('A12', None, 'delete_fns', None, arg=['setFrame'], file='src/player.zig')
step('A13', '**`src/player.zig`** (replace `pressedFire`)', 'replace_fn',
     fn('src/player.zig', 'pressedFire') + '\n' + fn('src/player.zig', 'pressed'), arg='pressedFire')
step('A14', '**`src/main.zig`** (add below the `player` import)', 'after_line', 'const actors = @import("actors.zig");\n', arg='const player = @import("player.zig");')
step('A15', '**`src/main.zig`** (add below `bucket_sprites`)', 'after_line', 'const bucket_actors = 3;\n', arg='const bucket_sprites = 2;')
step('A16', "**`src/main.zig`** (in the `.draw_room` branch, replace `player.enter(m);`)", 'replace_text',
     '            actors.clear(m);\n            player.add(m);\n', arg='            player.enter(m);\n')
ROOM_A = '''            m.bucket(bucket_sprites);
            actors.show(m);

            // Then the castle itself, one engine step every other frame:
            // 25 a second. What it decides shows up next frame.
            if (m.peek(map.game_tick) & 1 == 0) {
                m.bucket(bucket_actors);
                actors.step(m);
            }
'''
step('A17', "**`src/main.zig`** (in the `.room` branch, replace everything from `m.bucket(bucket_sprites);` to `player.steer(m);`)", 'replace_text', ROOM_A,
     arg='''            m.bucket(bucket_sprites);
            player.show(m);

            // Then the game itself. What it decides shows up next frame.
            player.steer(m);
''')
step('A18', None, 'replace_all', None, arg=[
    ('m.ram[map.player_x]', 'explorer(m).box.x'), ('m.ram[map.player_y]', 'explorer(m).box.y'),
    ('m.ram[map.player_frame]', 'explorer(m).frame'), ('m.ram[map.player_block]', 'explorer(m).block')], file='src/main.zig')
step('A19', '**`src/main.zig`** (add above `inRoom`)', 'before_text', fn('src/main.zig', 'explorer') + '\n',
     arg=fn('src/main.zig', 'inRoom', root=OLD))
step('A20', '**`src/actors.zig`** (add at the end of the file)', 'append', tail('src/actors.zig', '// ---- tests'))
step('A21', '**`src/player.zig`** (add at the end of the file)', 'append', tail('src/player.zig', '// ---- tests'), run='A')

# ============================================================================
# B: a table of functions for preparing a room
# ============================================================================
RM = f5('src/room.zig'); RM4 = f4('src/room.zig')
step('B1', '**`src/room.zig`** (add above the `machine` import)', 'before_line', 'const std = @import("std");\n', arg='const machine = @import("machine");')
DRAW = between('src/room.zig', '/// What preparing a room does', '/// Get room `n` ready to draw')
DRAW_B = rep(DRAW, ('    objects.clear(m);\n', ''),
    ('''/// Prepare the whole room: draw it, build its navigation grid and fill its
/// object table, every record handed to its kind's function. Far too big
/// for one frame: call it with the display blanked.''', '''/// Draw the whole room, and build its navigation grid on the way, every
/// record handed to its kind's function. Far too big for one frame: call
/// it with the display blanked.'''))
step('B2', '**`src/room.zig`** (replace `draw`)', 'replace_fn', DRAW_B, arg='draw')
DOORAT = fn('src/room.zig', 'doorAt')
DOORAT_B = rep(DOORAT, ('    const at = stream(m, n);', '    const at = objects(m, n);'))
step('B3', '**`src/room.zig`** (replace `firstDoor`)', 'replace_fn', DOORAT_B, arg='firstDoor')
step('B4', '**`src/room.zig`** (replace the comment above `walkway` and its first two lines)', 'replace_text',
     lines_of('src/room.zig', '/// A walkway: `length` pieces', '    const w = m.view'),
     arg=lines_of('src/room.zig', '/// A walkway: `length` pieces', '    const w = m.view', root=OLD))
step('B5', '**`src/room.zig`** (add above `column`)', 'before_text',
     between('src/room.zig', '/// A sliding pole, and a ladder', '/// A ladder or a pole: `length`') + '\n',
     arg='/// A ladder or a pole: `length` pieces stacked 8 rows apart, top first.\n')
step('B6', '**`src/room.zig`** (in `door`, replace the first two lines)', 'replace_text',
     'fn door(m: *Machine, r: castle.Record) void {\n    const d = m.view(castle.Door, r.at);\n',
     arg='fn door(m: *Machine, at: u16) void {\n    const d = m.view(castle.Door, at);\n')
BELL_B = '''/// A doorbell, in the colour of the room its door leads to.
fn bell(m: *Machine, r: castle.Record) void {
    const b = m.view(castle.Bell, r.at);
    const at = doorAt(m, m.peek(map.room_number), b.door) orelse return;
    const d = m.view(castle.Door, at);
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    place(m, .bell, b.x, b.y);
}
'''
step('B7', '**`src/room.zig`** (replace `bell`)', 'replace_fn', BELL_B, arg='bell')
step('B8', '**`src/room.zig`** (in `line`, replace the first line)', 'replace_text',
     'fn line(m: *Machine, r: castle.Record) void {\n    const at = r.at;\n', arg='fn line(m: *Machine, at: u16) void {\n')
step('B9', '**`src/room.zig`** (in `image`, replace the first line)', 'replace_text',
     'fn image(m: *Machine, r: castle.Record) void {\n    const at = r.at;\n', arg='fn image(m: *Machine, at: u16) void {\n')
step('B10', '**`src/player.zig`** (in `add`, replace the `firstDoor` line)', 'replace_text',
     '    if (room.doorAt(m, m.peek(map.room_number), 0)) |at| {\n', arg='    if (room.firstDoor(m)) |at| {\n')
step('B11', '**`src/room.zig`** (add at the end of the file)', 'append', tail('src/room.zig', '// ---- tests'), run='B')

# ============================================================================
# C: the object table, collisions, and the doorbell
# ============================================================================
step('C1', '**`src/map.zig`** (add below the `actors` region)', 'after_line',
     between('src/map.zig', '/// The room\'s object table', '/// The navigation grid'),
     arg='pub const actors = Region{ .name = "actors", .first = 0xBD00, .last = 0xBD00 + 8 * 16 - 1 };', pad='\n')
step('C2', '**`src/map.zig`** (in `regions`, add after `actors,`)', 'after_line', '    objects,\n', arg='    actors,')
step('C3', '**`src/map.zig`** (add below the `debug` region)', 'after_line',
     between('src/map.zig', '/// The room at work', '/// Text: a lookup table').rstrip('\n') + '\n',
     arg='pub const debug_search = debug.first + 1; // Q: search the castle instead of reading the grid', pad='\n')
step('C4', '**`src/map.zig`** (in `regions`, add after `debug,`)', 'after_line', '    engine,\n', arg='    debug,')
OBJ = f5('src/objects.zig')
OBJ_BODY = OBJ[:OBJ.index('// ---- tests')].rstrip('\n') + '\n'
OBJ_C = rep(OBJ_BODY, ('    .door = .{ .execute = doors.open, .in_front = doors.enter },', '    .door = .{ .execute = doors.open, .in_front = null },'))
C5 = cut(OBJ_C, '/// What each kind does', 'pub const slots = 32;', '/// One engine step for the objects')
step('C5', '**`src/objects.zig`** (new file)', 'whole', C5[0])
step('C5b', '**`src/objects.zig`** (add at the end of the file)', 'append', C5[1])
step('C5c', '**`src/objects.zig`** (add at the end of the file)', 'append', C5[2])
step('C5d', '**`src/objects.zig`** (add at the end of the file)', 'append', C5[3])
ACT_CLEAR_A = rep(fn('src/actors.zig', 'clear'),
    ('/// Empty every slot, and forget any collisions, before a room starts.', '/// Empty every slot, before a room starts.'),
    ('    m.poke(hw.sprite_sprite_hits, 0);\n    m.poke(hw.sprite_bitmap_hits, 0);\n', ''))
step('C17', '**`src/actors.zig`** (add below the `sprites` import)', 'after_line', 'const objects = @import("objects.zig");\n', arg='const sprites = @import("sprites.zig");')
step('C18', '**`src/actors.zig`** (in `clear`, add at the end, and replace the comment above it)', 'replace_text',
     fn('src/actors.zig', 'clear'), arg=ACT_CLEAR_A)
STEP_C = rep(STEP,
    ('            if (a.state.hit_bitmap or m.peek(map.debug_scan) != 0) objects.touching(m, n);\n', '            if (a.state.hit_bitmap) objects.touching(m, n);\n'),
    ('''        } else if (a.state.flash or a.state.dying) {
            flicker(m, n);
        } else {''', '''        } else {'''),
    ('            if (!a.state.flash) kinds[@intFromEnum(a.kind)].turn(m, n);\n', '            kinds[@intFromEnum(a.kind)].turn(m, n);\n'))
step('C19', '**`src/actors.zig`** (replace `step`)', 'replace_fn', STEP_C, arg='step')
DR = f5('src/doors.zig')
DR_C = DR[:DR.index('/// A door\'s `in_front`')].rstrip('\n') + '\n'
DR_C = rep(DR_C,
    ('''/// The stick's direction for walking into a door: up and to the right,
/// the way the walk goes.
const into_door = 1;

''', ''),
    ('    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;', '    if (a.kind != .player or a.fire == 0) return;'),
    ('//! Doors and doorbells at work: a bell rung, a door swinging open, and the\n//! explorer walking through.', '//! Doors and doorbells at work: a bell rung, a door swinging open.'))
step('C6', '**`src/doors.zig`** (new file)', 'whole', DR_C)
step('C7', '**`src/player.zig`** (replace the `feet_x` line)', 'replace_text', 'pub const feet_x = 3;\n', arg='const feet_x = 3;\n')
step('C8a', '**`src/room.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/room.zig', '//! The room on screen', '//! stream, draw'), arg=lines_of('src/room.zig', '//! The room on screen', '//! stream and draw', root=OLD))
step('C8', '**`src/room.zig`** (add below the `text` import)', 'after_line',
     'const actors = @import("actors.zig");\nconst objects = @import("objects.zig");\n', arg='const text = @import("text.zig");')
step('C9', '**`src/room.zig`** (replace the comment above `objects` and its first line)', 'replace_text',
     lines_of('src/room.zig', '/// Where room `n`\'s object stream starts', 'pub fn stream('),
     arg=lines_of('src/room.zig', '/// Where room `n`\'s objects start', 'pub fn objects(', root=OLD))
step('C10', '**`src/room.zig`** (in `prepare`, replace the last line)', 'replace_text',
     '    return .{ .at = stream(m, n) };\n', arg='    return .{ .at = objects(m, n) };\n')
step('C11', '**`src/room.zig`** (in `doorAt`, replace the first line)', 'replace_text',
     '    const at = stream(m, n);\n', arg='    const at = objects(m, n);\n')
step('C12', '**`src/player.zig`** (in `waysAt`, replace `room.objects`)', 'replace_text',
     '        return grid.search(m, room.stream(m, m.peek(map.room_number)), x, y);\n',
     arg='        return grid.search(m, room.objects(m, m.peek(map.room_number)), x, y);\n')
step('C13', '**`src/main.zig`** (in the test that searches the castle, replace the `objects` line and the lines down to the one that uses it)', 'replace_text',
     lines_of('src/main.zig', '        const stream = room.stream', '                try std.testing.expectEqual(grid.at(m, x, y), grid.search'),
     arg=lines_of('src/main.zig', '        const objects = room.objects', '                try std.testing.expectEqual(grid.at(m, x, y), grid.search', root=OLD))
step('C14', '**`src/room.zig`** (replace the comment above `draw` and its first three lines)', 'replace_text',
     lines_of('src/room.zig', '/// Prepare the whole room', '    objects.clear(m);'),
     arg=lines_of('src/room.zig', '/// Prepare the whole room', '    grid.clear(m);').replace(
        '''/// Prepare the whole room: draw it, build its navigation grid and fill its
/// object table, every record handed to its kind's function. Far too big
/// for one frame: call it with the display blanked.''', '''/// Draw the whole room, and build its navigation grid on the way, every
/// record handed to its kind's function. Far too big for one frame: call
/// it with the display blanked.'''))
DOOR_OLD = between('src/room.zig', '/// Where the door itself sits', '/// A doorbell, in the colour', root=OLD)
DOOR_OLD = rep(DOOR_OLD, ('fn door(m: *Machine, at: u16) void {\n    const d = m.view(castle.Door, at);\n', 'fn door(m: *Machine, r: castle.Record) void {\n    const d = m.view(castle.Door, r.at);\n'))
step('C15', '**`src/room.zig`** (replace `door_panel_dx`, `door_panel_dy` and `door`, and the comments above them)', 'replace_text',
     between('src/room.zig', '/// Where the door itself sits', '/// A doorbell, in the colour'), arg=DOOR_OLD)
step('C16', '**`src/room.zig`** (replace `bell`)', 'replace_fn', fn('src/room.zig', 'bell'), arg='bell')
step('C20', '**`src/main.zig`** (add below the `actors` import)', 'after_line', 'const objects = @import("objects.zig");\n', arg='const actors = @import("actors.zig");')
step('C21', '**`src/main.zig`** (add below `bucket_actors`)', 'after_line', 'const bucket_objects = 4;\n', arg='const bucket_actors = 3;')
step('C22', "**`src/main.zig`** (in the `.draw_room` branch, replace `room.draw(m);`)", 'replace_text',
     '            room.draw(m); // and its objects\n', arg='            room.draw(m);\n')
step('C23', "**`src/main.zig`** (in the `.room` branch, add below `actors.step(m);`)", 'after_line',
     '                m.bucket(bucket_objects);\n                objects.step(m);\n', arg='                actors.step(m);')
step('C24', '**`src/objects.zig`** (add at the end of the file)', 'append', tail('src/objects.zig', '// ---- tests'), run='C')

# ============================================================================
# D: through the door, into the next room
# ============================================================================
step('D1', '**`src/player.zig`** (add above `feet_x`)', 'before_text',
     between('src/player.zig', '/// What he\'s doing, as far as the room', '/// His feet') + '\n',
     arg='/// His feet: the point the grid is read at')
step('D2', '**`src/player.zig`** (add below `door_y`, after a blank line)', 'after_line',
     '\n/// How many engine steps the room runs on after he\'s gone or dead.\nconst ending_steps = 30;\n', arg='const door_y = 11;')
step('D2b', '**`src/shapes.zig`** (in `Id`, add at the end, after `explorer_slide`)', 'after_line',
     '    explorer_back_0,\n    explorer_back_1,\n', arg='    explorer_slide,')
ART = f5('src/art.zig')
step('D2c', '**`src/art.zig`** (add above `// ---- pictures for the castle`)', 'before_text',
     ART[ART.index('/// Walking into a doorway, seen from behind'):ART.index('// ---- pictures for the castle')],
     arg='// ---- pictures for the castle')
step('D3', '**`src/player.zig`** (add below `step_y`, after a blank line)', 'after_line',
     '\n' + between('src/player.zig', '/// Walking through a doorway', '/// Once, at power-on.').rstrip('\n') + '\n',
     arg='const step_y = [8]u8{ 0xFE, 0xFE, 0, 2, 2, 2, 0, 0xFE };')
NEWGAME_D = rep(fn('src/player.zig', 'newGame'),
    ('/// A new game: the castle\'s start room and start door, and its lives.', '/// A new game: the castle\'s start room and start door.'),
    ('    m.poke(map.player_lives, m.peek(castle.lives));\n', ''))
step('D4', '**`src/player.zig`** (add below `start`)', 'insert_after_fn', NEWGAME_D, arg='start')
step('D5', '**`src/player.zig`** (replace `add`)', 'replace_fn', ADD, arg='add')
step('D6', '**`src/player.zig`** (add below `add`)', 'insert_after_fn', fn('src/player.zig', 'status') + '\n' + fn('src/player.zig', 'playing'), arg='add')
step('D7', '**`src/player.zig`** (replace `turn`)', 'replace_fn', TURN, arg='turn')
ROOMOVER = fn('src/player.zig', 'roomOver')
step('D8', '**`src/player.zig`** (add below `waysAt`)', 'insert_after_fn',
     fn('src/player.zig', 'walkIn') + '\n' + fn('src/player.zig', 'walk') + '\n' + ROOMOVER, arg='waysAt')
step('D9', '**`src/doors.zig`** (add below `bell_reach`, after a blank line)', 'after_line',
     '''
/// The stick's direction for walking into a door: up and to the right,
/// the way the walk goes.
const into_door = 1;
''', arg='const bell_reach = 12;')
step('D10', '**`src/doors.zig`** (in `ring`, replace the first test)', 'replace_text',
     '    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;\n', arg='    if (a.kind != .player or a.fire == 0) return;\n')
step('D11', '**`src/doors.zig`** (replace the comment at the top)', 'replace_text',
     '//! Doors and doorbells at work: a bell rung, a door swinging open, and the\n//! explorer walking through.\n',
     arg='//! Doors and doorbells at work: a bell rung, a door swinging open.\n')
step('D11b', '**`src/doors.zig`** (add at the end of the file)', 'append', fn('src/doors.zig', 'enter'))
step('D12', "**`src/objects.zig`** (in `kinds`, replace the door's entry)", 'replace_text',
     '    .door = .{ .execute = doors.open, .in_front = doors.enter },\n', arg='    .door = .{ .execute = doors.open, .in_front = null },\n')
step('D13', None, 'delete_fns', None, arg=['start'], file='src/room.zig')
step('D14', '**`src/room.zig`** (in `flip`, add below the `room_number` line)', 'after_line',
     '    m.poke(map.player_door, 0); // he comes in by its first door\n', arg='    m.poke(map.room_number, next);')
step('D15', '**`src/main.zig`** (in the `.title` branch, replace `room.start(m);`)', 'replace_text',
     '                player.newGame(m);\n', arg='                room.start(m);\n')
step('D16', "**`src/main.zig`** (in the `.room` branch, add below `objects.step(m);`)", 'after_line',
     '                m.bucket(0);\n                if (player.roomOver(m)) setMode(m, .draw_room);\n', arg='                objects.step(m);')
step('D17', '**`src/training.zig`** (in the `gatehouse` room, replace the last line of its text)', 'replace_text',
     '                "PUSH UP AND RIGHT.",\n', arg='                "PUSH UP.",\n')
TESTS = tail('src/main.zig', 'test "a doorbell opens its door')
TESTS_D = TESTS[:TESTS.index('test "X: a flicker')]
step('D18', '**`src/main.zig`** (add above `explorer`, near the end of the file)', 'before_text', TESTS_D,
     arg=fn('src/main.zig', 'explorer'), run='D')

# ============================================================================
# E: dying, and lives
# ============================================================================
step('E1', '**`src/actors.zig`** (add below the `Machine` import)', 'after_line', 'const Color = machine.Color;\n', arg='const Machine = machine.Machine;')
step('E2', '**`src/actors.zig`** (replace `Behaviour` and `kinds`, and the comment above `Behaviour`)', 'replace_text',
     between('src/actors.zig', '/// What each kind does', 'pub const slots'),
     arg=rep(between('src/actors.zig', '/// What each kind does', 'pub const slots'),
        ('''/// What each kind does: the function that takes its turn, and whether it
/// flickers when it dies or vanishes on the spot.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
    flickers: bool,
};''', '''/// What each kind does: the function that takes its turn.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
};'''), ('    .player = .{ .turn = player.turn, .flickers = true },', '    .player = .{ .turn = player.turn },')))
STEP_E_OLD = '''        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            if (a.state.hit_bitmap) objects.touching(m, n);
            kinds[@intFromEnum(a.kind)].turn(m, n);
        }
'''
STEP_E = '''        } else if (a.state.flash or a.state.dying) {
            flicker(m, n);
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            if (a.state.hit_bitmap) objects.touching(m, n);
            if (!a.state.flash) kinds[@intFromEnum(a.kind)].turn(m, n);
        }
'''
step('E3', "**`src/actors.zig`** (in `step`, replace the `else` branch)", 'replace_text', STEP_E, arg=STEP_E_OLD)
step('E4', '**`src/actors.zig`** (add below `step`)', 'insert_after_fn', fn('src/actors.zig', 'flicker'), arg='step')
step('E5', '**`src/actors.zig`** (in `show`, replace the `unused` test, and the `multicolor` line four lines down)', 'replace_text',
     lines_of('src/actors.zig', '        if (a.state.unused or a.state.destroy)', '        if (!a.state.dying) multicolor'),
     arg='        if (a.state.unused) continue;\n        const n: u3 = @intCast(i);\n        const bit = @as(u8, 1) << n;\n        on |= bit;\n        multicolor |= bit;\n')
step('E6', '**`src/player.zig`** (in `newGame`, add at the end, and replace the comment above it)', 'replace_text',
     fn('src/player.zig', 'newGame'), arg=NEWGAME_D)
step('E7', '**`src/player.zig`** (add below `walk`)', 'insert_after_fn', fn('src/player.zig', 'kill'), arg='walk')
step('E8', '**`src/player.zig`** (add below `roomOver`)', 'insert_after_fn', fn('src/player.zig', 'nextRoom'), arg='roomOver')
step('E9', '**`src/main.zig`** (in the `.room` branch, replace the `roomOver` line)', 'replace_text',
     '                if (player.roomOver(m)) setMode(m, if (player.nextRoom(m)) .draw_room else .draw_title);\n',
     arg='                if (player.roomOver(m)) setMode(m, .draw_room);\n')
DBG = f5('src/debug.zig')
KEYS = fn('src/debug.zig', 'keys')
KEYS_E = rep(KEYS,
    ('''/// G, Q or C on the keyboard flips its switch, and X kills the explorer.
/// True if the room needs drawing again (the grid view does; the others
/// don't).''', '''/// G or Q on the keyboard flips its switch, and X kills the explorer. True
/// if the room needs drawing again (the grid view does; the others don't).'''),
    ("        'C' => map.debug_scan,\n", ''))
step('E10', '**`src/debug.zig`** (add below the `grid` import)', 'after_line', 'const player = @import("player.zig");\n', arg='const grid = @import("grid.zig");')
step('E11', '**`src/debug.zig`** (replace `keys`)', 'replace_fn', KEYS_E, arg='keys')
TEST_K = TESTS[TESTS.index('test "X: a flicker'):TESTS.index('/// The explorer\'s actor slot.')]
step('E12', '**`src/main.zig`** (add above `explorer`)', 'before_text', TEST_K, arg=fn('src/main.zig', 'explorer'), run='E')

# ============================================================================
# F: what the first pass saves
# ============================================================================
step('F1', "**`src/map.zig`** (replace the `debug` region's comment and first line, and add a third switch)", 'replace_text',
     lines_of('src/map.zig', '/// Three switches', 'pub const debug_scan'),
     arg=lines_of('src/map.zig', '/// Two switches', 'pub const debug_search', root=OLD))
step('F2', '**`src/debug.zig`** (replace the comment at the top)', 'replace_text',
     lines_of('src/debug.zig', '//! Switches for looking', '//! every turn'), arg=lines_of('src/debug.zig', '//! Two switches', '//! instead of reading', root=OLD))
step('F3', '**`src/debug.zig`** (replace `keys`)', 'replace_fn', KEYS, arg='keys')
step('F4', "**`src/actors.zig`** (in `step`, replace the `touching` line)", 'replace_text',
     '            if (a.state.hit_bitmap or m.peek(map.debug_scan) != 0) objects.touching(m, n);\n',
     arg='            if (a.state.hit_bitmap) objects.touching(m, n);\n', run='F')
