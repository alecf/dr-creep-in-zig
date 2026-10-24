# Every ```zig listing of Chapter 3, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch03) wherever the
# listing matches it, and written out here for intermediate states.
import re, os
CH3 = '/home/user/dr-creep-in-zig/site/code/ch03/'
CH2 = '/home/user/dr-creep-in-zig/site/code/ch02/'

def read(root, p): return open(root + p).read()
def f3(p): return read(CH3, p)

def doc_start(lines, i):
    while i > 0 and lines[i-1].startswith('///'): i -= 1
    return i

def fn(path, name, root=CH3):
    lines = read(root, path).split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^(pub )?fn %s\(' % re.escape(name), l):
            s = doc_start(lines, i); j = i
            while lines[j] != '}': j += 1
            return '\n'.join(lines[s:j+1]) + '\n'
    raise SystemExit('no fn %s in %s' % (name, path))

def span(path, first, last, root=CH3):
    """From the line starting with `first` to the line equal to `last` (or
    starting with it), inclusive. A leading doc comment comes along."""
    lines = read(root, path).split('\n')
    s = next(i for i, l in enumerate(lines) if l.startswith(first))
    s = doc_start(lines, s)
    e = next(i for i in range(s, len(lines)) if lines[i] == last or (last.endswith('…') and lines[i].startswith(last[:-1])))
    return '\n'.join(lines[s:e+1]) + '\n'

def upto(path, last, root=CH3):
    lines = read(root, path).split('\n')
    e = next(i for i, l in enumerate(lines) if l == last)
    return '\n'.join(lines[:e+1]) + '\n'

def tail(path, first, root=CH3):
    t = read(root, path)
    return t[t.index(first):]

STEPS = []
def step(key, label, op, text, arg=None, run=None, pad=''):
    STEPS.append(dict(key=key, label=label, op=op, text=text, arg=arg, run=run, pad=pad))

# ---- A: the memory map -------------------------------------------------------
step('A1', '**`src/map.zig`** (add below the `game` region)', 'after_line', '''/// The room on screen.
pub const room = Region{ .name = "room", .first = 0x0208, .last = 0x0208 };
pub const room_number = room.first + 0; // its place in the castle's room directory
''', arg='pub const game_tick = game.first + 1; // goes up by one every frame, and wraps', pad='\n')
step('A2', '**`src/map.zig`** (replace the `text` region\'s comment and first four lines)', 'replace_text',
     span('src/map.zig', 'pub const text = Region', 'pub const text_buffer = text.first + 0x50; // a string to print'),
     arg=span('src/map.zig', 'pub const text = Region', 'pub const text_buffer = text.first + 0x30; // a string to print', root=CH2))
step('A3', '**`src/map.zig`** (add above the row table)', 'before_line', '''/// The castle: its header, its room directory and every room's objects,
/// exactly as the castle file holds them.
pub const castle = Region{ .name = "castle", .first = 0x7800, .last = 0x97FF };

''', arg='/// Where each of the 200 bitmap rows starts: two bytes per row.')
step('A4', '**`src/map.zig`** (replace `regions`)', 'replace_text',
     span('src/map.zig', 'pub const regions', '};'),
     arg=span('src/map.zig', 'pub const regions', '};', root=CH2), run='A')

# ---- B: the header and the directory, and a castle typed by hand ------------
step('B1', '**`src/castle.zig`** (new file)', 'whole', upto('src/castle.zig', '// ---- object streams -------------------------------------------------------').rsplit('\n// ---- object streams', 1)[0].rstrip('\n') + '\n')

HAND = '''//! The Training Castle, typed in by hand: one room, the Entrance Hall
//! from Chapter 2, as castle bytes.

/// The whole castle file, ready to load at $7800.
pub const bytes = &(header ++ directory ++ hall);

const header = [_]u8{
    0x54, 0x01, // the castle is $0154 bytes long, header and all
    0x80, // "this is a castle"
    0, 0, // both players start in room 0...
    0, 0, // ...at its door 0...
    3, 3, // ...with three lives each
} ++ [_]u8{0} ** (0x5F - 9) ++ [_]u8{ 0x00, 0x00 } // $785F: no final room
++ [_]u8{0} ** (0x100 - 0x61);

const directory = [_]u8{
    0x02, // red, and bit 6 is clear: this is a room, not the end
    56, 48, // its place on the castle map
    0b00_100_011, // 4 map cells wide, 3 tall
    0x0B, 0x79, // skip: $790B
    0x09, 0x79, // its objects start at $7909, right after the end byte
    0xFF, // the end of the directory, and no final room
};

/// The Entrance Hall's objects.
const hall = [_]u8{
    0x03, 0x08, 2, // doors: two of them
    32, 40, 3, 0, 1, 0, 16, 0, // upper left, leading to door 1
    152, 96, 1, 0, 0, 0, 16, 0, // middle right, leading to door 0
    0x06, 0x08, // walkways
    15, 24, 72, // upper left
    17, 108, 128, // middle right
    40, 16, 192, // the floor
    0, // no more walkways
    0x09, 0x08, 16, 64, 72, 0, // one sliding pole
    0x0C, 0x08, 9, 120, 128, 0, // one ladder
    0x0F, 0x08, 1, 136, 104, 1, // one doorbell, for door 1
    0x33, 0x08, 28, 8, 15, 0x21, // text at (28, 8), light grey, plain
} ++ "THE ENTRANCE HAL".* ++ [_]u8{
    'L' | 0x80, // the last letter has bit 7 set
    0, // no more text
    0x00, 0x00, // the end of the room
};
'''
step('B2', '**`src/training.zig`** (new file)', 'whole', HAND)
step('B3', '**`src/main.zig`** (add below the `player` import)', 'after_line', 'const training = @import("training.zig");\n', arg='const player = @import("player.zig");')
step('B4', '**`src/main.zig`** (in `boot`, add after the star map\'s `m.load`)', 'after_line', '    m.load(map.castle.first, training.bytes);\n', arg='    m.load(map.stars.first, &title.star_map);')
step('Bart', None, 'copy', None, arg='src/art.zig')
step('B5', '**`src/shapes.zig`** (add below `address`)', 'insert_after_fn', fn('src/shapes.zig', 'recolor'), arg='address')
step('B6', '**`src/room.zig`** (replace the imports)', 'replace_text', '''const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
''', arg='''const machine = @import("machine");
const Machine = machine.Machine;
const screen = @import("screen.zig");
const text = @import("text.zig");
''')
step('B7', '**`src/room.zig`** (in `draw`, add after `screen.clear(m);`)', 'after_line', '    paint(m, roomColors(m, 0)); // room 0\'s colour, from the directory\n', arg='    screen.clear(m);')
step('B8', '**`src/room.zig`** (add at the end of the file)', 'append', fn('src/room.zig', 'paint') + '\n' + fn('src/room.zig', 'roomColors') + '\n' + fn('src/room.zig', 'both'), run='B')

# ---- C: object streams -------------------------------------------------------
step('C1', '**`src/castle.zig`** (add at the end of the file)', 'append', span('src/castle.zig', '// ---- object streams', '    return if (offset < kinds.len) kinds[offset] else null;') + '}\n')
step('C2', '**`src/castle.zig`** (add at the end of the file)', 'append', span('src/castle.zig', '// ---- records', 'pub const Frankenstein = …'))
step('C3', '**`src/castle.zig`** (add at the end of the file)', 'append', span('src/castle.zig', 'pub const Framing', 'pub fn isEnd(byte: u8, end: u8) bool {') + '    return if (end == 0) byte == 0 else byte & end != 0;\n}\n')
step('C4', '**`src/castle.zig`** (add at the end of the file)', 'append', span('src/castle.zig', 'pub const Record', 'pub fn screenX(x: u8) ?u8 {') + '    return if (x < 16) null else x - 16;\n}\n')
step('C5', '**`src/castle.zig`** (add at the end of the file)', 'append', tail('src/castle.zig', '// ---- tests'))

ROOM_C = '''//! The room on screen, drawn from the castle: walk the room's object
//! stream and draw everything in it that stands still.

const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // every Training Castle room has a floor here

/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    var walk = prepare(m, 0);
    while (walk.next(m)) |r| {
        switch (r.kind) {
            .walkway => walkway(m, r.at),
            .pole => column(m, .pole, r.at),
            .ladder => column(m, .ladder, r.at),
            else => {}, // the rest: later in this chapter, and in later chapters
        }
    }
}

/// Get room `n` ready to draw: paint the floor pieces its colour, and
/// return a walker at the start of its objects.
fn prepare(m: *Machine, n: u8) castle.Walker {
    paint(m, roomColors(m, n));
    return .{ .at = m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")) };
}

''' + fn('src/room.zig', 'paint') + '\n' + fn('src/room.zig', 'roomColors') + '\n' + fn('src/room.zig', 'both') + '\n' + fn('src/room.zig', 'walkway') + '\n' + fn('src/room.zig', 'column')
step('C6', '**`src/room.zig`** (replace the whole file)', 'whole', ROOM_C, run='C')

# ---- D: doors, bells, words and pictures --------------------------------------
step('D1', '**`src/shapes.zig`** (replace `Id` and the comment above it)', 'replace_text',
     span('src/shapes.zig', 'pub const Id = enum(u8) {', '};'),
     arg=span('src/shapes.zig', 'pub const Id = enum(u8) {', '};', root=CH2))
OLD_WHERE = '''            // The glyph is built at run time, in the text region.
            const where = if (id == .glyph) map.text_glyph else at;
            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first
            if (id == .glyph) continue;
'''
NEW_WHERE = span('src/shapes.zig', '            // The glyph is built at run time', '            if (id == .glyph or id == .image) continue;')
step('D2', '**`src/shapes.zig`** (in `build`, replace the four lines at the top of the loop)', 'replace_text', NEW_WHERE, arg=OLD_WHERE)
step('D3', '**`src/shapes.zig`** (add below `address`)', 'insert_after_fn', fn('src/shapes.zig', 'point'), arg='address')
GP = "/// The glyph shape's pixels start after its width, height and flags.\nconst glyph_pixels = map.text_glyph + 3;\n"
step('D4', '**`src/text.zig`** (replace `glyph_pixels` and the two lines below it)', 'replace_text',
     GP + '\n' + span('src/text.zig', '/// The style byte every castle', 'pub const plain = style_letters | 1;'),
     arg=GP + '''const glyph_screen = glyph_pixels + 2 * 8; // then two screen-plane bytes
const glyph_colors = glyph_screen + 2; // and two colour-RAM bytes
''')
step('D5', '**`src/text.zig`** (in `start`, replace the last two lines)', 'replace_text',
     '    m.poke(map.text_glyph + 2, 0); // no flags; the height depends on the style\n',
     arg='''    m.poke(map.text_glyph + 1, 8); // 8 rows tall
    m.poke(map.text_glyph + 2, 0); // no flags
''')
step('D6', '**`src/text.zig`** (replace `draw`)', 'replace_fn', fn('src/text.zig', 'draw'), arg='draw')
step('D7', '**`src/text.zig`** (in `say`, replace the last line)', 'replace_text', '    _ = draw(m, x, y, color, plain, map.text_buffer);\n', arg='    draw(m, x, y, color, map.text_buffer);\n')
step('D8', '**`src/room.zig`** (replace the imports below `machine`, adding two)', 'replace_text', '''const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
''', arg='''const Machine = machine.Machine;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
''')
DRAW_D = fn('src/room.zig', 'draw').replace('    var walk = prepare(m, m.peek(map.room_number));', '    var walk = prepare(m, 0);')
step('D9', '**`src/room.zig`** (replace `draw`)', 'replace_fn', DRAW_D, arg='draw')
step('D10', '**`src/room.zig`** (add at the end of the file)', 'append',
     fn('src/room.zig', 'door') + '\n' + fn('src/room.zig', 'bell') + '\n' + fn('src/room.zig', 'line') + '\n' + fn('src/room.zig', 'image'), run='D')

# ---- E: the authoring kit and the Training Castle -----------------------------
step('E1', '**`src/shapes.zig`** (make `pack` public)', 'replace_text', 'pub fn pack(comptime name: []const u8, comptime a: Art) []const u8 {\n', arg='fn pack(comptime name: []const u8, comptime a: Art) []const u8 {\n')
step('E2', '**`src/author.zig`** (new file)', 'whole', upto('src/author.zig', '// ---- what you get ---------------------------------------------------------').rsplit('\n// ---- what you get', 1)[0].rstrip('\n') + '\n')
step('E3', '**`src/author.zig`** (add at the end of the file)', 'append', tail('src/author.zig', '// ---- what you get').split("\n/// One room's object stream")[0])
step('E4', '**`src/author.zig`** (add at the end of the file)', 'append', '/// One room\'s object stream' + tail('src/author.zig', '/// One room\'s object stream').split('/// One room\'s object stream', 1)[1].split('\n/// Door `i`\'s 8 bytes')[0])
step('E5', '**`src/author.zig`** (add at the end of the file)', 'append', tail('src/author.zig', '/// Door `i`\'s 8 bytes'))
step('E6', None, 'copy', None, arg='src/training.zig', run='E')

# ---- F: flipping through the castle ------------------------------------------
step('F1', '**`src/room.zig`** (add two imports below `Color`)', 'after_line', 'const hw = machine.hw;\nconst map = @import("map.zig");\n', arg='const Color = machine.Color;')
step('F2', '**`src/room.zig`** (add below `floor_top`)', 'after_line', span('src/room.zig', '/// The final room isn\'t in the directory', 'const final_color = Color.yellow;') + '\n' + fn('src/room.zig', 'start'), arg='pub const floor_top = 192; // every Training Castle room has a floor here', pad='\n')
step('F3', '**`src/room.zig`** (in `draw`, replace the `prepare` line)', 'replace_text', '    var walk = prepare(m, m.peek(map.room_number));\n', arg='    var walk = prepare(m, 0);\n')
step('F4', '**`src/room.zig`** (replace `prepare`)', 'replace_fn', fn('src/room.zig', 'prepare'), arg='prepare')
step('F5', '**`src/room.zig`** (add at the end of the file)', 'append', fn('src/room.zig', 'flip'))
step('F6', '**`src/main.zig`** (in `frame`\'s `.title` branch, replace the last line)', 'replace_text', '''            if (player.pressedFire(m)) {
                room.start(m);
                setMode(m, .draw_room);
            }
''', arg='            if (player.pressedFire(m)) setMode(m, .draw_room);\n')
step('F7', '**`src/main.zig`** (in the `.room` branch, add after `player.steer(m);`)', 'after_line', '''            m.bucket(0);
            if (room.flip(m)) setMode(m, .draw_room);
''', arg='            player.steer(m);', run='F')

# ---- G: tests ----------------------------------------------------------------
step('G1', '**`src/main.zig`** (add two imports above `training`)', 'before_line', 'const castle = @import("castle.zig");\nconst author = @import("author.zig");\n', arg='const training = @import("training.zig");')
step('G2', '**`src/main.zig`** (add at the end of the file)', 'append', tail('src/main.zig', 'test "N and P flip'), run='G')
