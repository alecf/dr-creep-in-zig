def between(path, first, stop, root=CH3):
    """From the line starting with `first` (doc comment included) up to,
    not including, the line starting with `stop` (and its doc comment)."""
    lines = read(root, path).split('\n')
    s = next(i for i, l in enumerate(lines) if l.startswith(first))
    s = doc_start(lines, s)
    e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith(stop))
    e = doc_start(lines, e)
    return '\n'.join(lines[s:e]).rstrip('\n') + '\n'

# ---- B: the castle's home, header and directory, a castle by hand ----------
step('B0a', '**`src/map.zig`** (add above the row table)', 'before_line',
     between('src/map.zig', '/// The castle: its header', '/// Where each of the 200') + '\n',
     arg='/// Where each of the 200 bitmap rows starts: two bytes per row.')
step('B0b', '**`src/map.zig`** (in `regions`, add after `shape_table,`)', 'after_line', '    castle,\n', arg='    shape_table,')
step('B1', '**`src/castle.zig`** (new file)', 'whole', between('src/castle.zig', '//! The castle file', '// ---- object streams'))
step('B2', '**`src/hall.zig`** (new file)', 'whole', f3('src/hall.zig').split('\n// ---- the same hall')[0].rstrip('\n') + '\n')
step('B3', '**`src/main.zig`** (add below the `player` import)', 'after_line', 'const hall = @import("hall.zig");\n', arg='const player = @import("player.zig");')
step('B4', "**`src/main.zig`** (in `boot`, add after the star map's `m.load`)", 'after_line', '    m.load(map.castle.first, hall.bytes);\n', arg='    m.load(map.stars.first, &title.star_map);')
step('Bart', None, 'copy', None, arg='src/art.zig')
step('B5', '**`src/shapes.zig`** (add below `address`)', 'insert_after_fn', fn('src/shapes.zig', 'recolor'), arg='address')
step('B6', '**`src/room.zig`** (replace the imports)', 'replace_text',
     'const machine = @import("machine");\nconst Machine = machine.Machine;\nconst castle = @import("castle.zig");\nconst screen = @import("screen.zig");\nconst shapes = @import("shapes.zig");\nconst text = @import("text.zig");\n',
     arg='const machine = @import("machine");\nconst Machine = machine.Machine;\nconst screen = @import("screen.zig");\nconst text = @import("text.zig");\n')
step('B7', '**`src/room.zig`** (in `draw`, add after `screen.clear(m);`)', 'after_line', "    paint(m, roomColors(m, 0)); // room 0's colour, from the directory\n", arg='    screen.clear(m);')
step('B8', '**`src/room.zig`** (add at the end of the file)', 'append', fn('src/room.zig', 'paint') + '\n' + fn('src/room.zig', 'roomColors') + '\n' + fn('src/room.zig', 'both'), run='B')

# ---- C: object streams -------------------------------------------------------
step('C1', '**`src/castle.zig`** (add at the end of the file)', 'append', between('src/castle.zig', '// ---- object streams', '// ---- records'))
step('C2', '**`src/castle.zig`** (add at the end of the file)', 'append', between('src/castle.zig', '// ---- records', '// The machines and monsters later chapters'))
step('C2b', '**`src/castle.zig`** (add at the end of the file)', 'append', between('src/castle.zig', '// The machines and monsters later chapters', 'pub const Framing'))
step('C3', '**`src/castle.zig`** (add at the end of the file)', 'append', between('src/castle.zig', 'pub const Framing', 'pub const Record'))
step('C4', '**`src/castle.zig`** (add at the end of the file)', 'append', between('src/castle.zig', 'pub const Record', '// ---- tests'))
step('C5', '**`src/castle.zig`** (add at the end of the file)', 'append', tail('src/castle.zig', '// ---- tests'))
step('C6', '**`src/screen.zig`** (replace `drawShape`)', 'replace_fn', fn('src/screen.zig', 'drawShape') + '\n' + fn('src/screen.zig', 'drawPart'), arg='drawShape')
step('C7', '**`src/room.zig`** (replace the comment at the top)', 'replace_text',
     "//! The room on screen, drawn from the castle: walk the room's object\n//! stream and draw everything in it that stands still.\n",
     arg='//! The room: floors, a ladder, a pole and doors, placed by hand and drawn\n//! from the shape table.\n')
DRAW_C = fn('src/room.zig', 'draw').split('    var doors')[0].replace('prepare(m, m.peek(map.room_number))', 'prepare(m, 0)') + \
    '    while (walk.next(m)) |r| {\n        switch (r.kind) {\n            .walkway => walkway(m, r.at),\n            .pole => column(m, .pole, r.at),\n            .ladder => column(m, .ladder, r.at),\n            else => {}, // the rest: later in this chapter, and in later chapters\n        }\n    }\n}\n'
step('C8', '**`src/room.zig`** (replace `draw`)', 'replace_fn', DRAW_C, arg='draw')
step('Cdel', None, 'delete_fns', None, arg=['walkway', 'ladder', 'pole'])
PREP_C = '/// Get room `n` ready to draw: paint the floor pieces its colour, and\n/// return a walker at the start of its objects.\nfn prepare(m: *Machine, n: u8) castle.Walker {\n    paint(m, roomColors(m, n));\n    return .{ .at = m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")) };\n}\n'
step('C9', '**`src/room.zig`** (add below `draw`)', 'insert_after_fn', PREP_C, arg='draw')
step('C10', '**`src/room.zig`** (add at the end of the file)', 'append', fn('src/room.zig', 'place') + '\n' + fn('src/room.zig', 'walkway') + '\n' + fn('src/room.zig', 'column'), run='C')

# ---- D: doors, bells, words and pictures --------------------------------------
step('D1', '**`src/shapes.zig`** (replace `Id` and the comment above it)', 'replace_text',
     span('src/shapes.zig', 'pub const Id = enum(u8) {', '};'),
     arg=span('src/shapes.zig', 'pub const Id = enum(u8) {', '};', root=CH2))
OLD_WHERE = '            // The glyph is built at run time, in the text region.\n            const where = if (id == .glyph) map.text_glyph else at;\n            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first\n            if (id == .glyph) continue;\n'
step('D2', '**`src/shapes.zig`** (in `build`, replace the four lines at the top of the loop)', 'replace_text',
     span('src/shapes.zig', '            // The glyph is built at run time', '            if (id == .glyph or id == .image) continue;'), arg=OLD_WHERE)
step('D3', '**`src/shapes.zig`** (add below `address`)', 'insert_after_fn', fn('src/shapes.zig', 'point'), arg='address')
step('D0', "**`src/map.zig`** (replace the `text` region's comment and first four lines)", 'replace_text',
     span('src/map.zig', 'pub const text = Region', 'pub const text_buffer = text.first + 0x50; // a string to print'),
     arg=span('src/map.zig', 'pub const text = Region', 'pub const text_buffer = text.first + 0x30; // a string to print', root=CH2))
GP = "/// The glyph shape's pixels start after its width, height and flags.\nconst glyph_pixels = map.text_glyph + 3;\n"
step('D4', '**`src/text.zig`** (replace `glyph_pixels` and the two lines below it)', 'replace_text',
     GP + '\n' + span('src/text.zig', '/// The style byte every castle', 'pub const plain = style_letters | 1;'),
     arg=GP + 'const glyph_screen = glyph_pixels + 2 * 8; // then two screen-plane bytes\nconst glyph_colors = glyph_screen + 2; // and two colour-RAM bytes\n')
step('D5', '**`src/text.zig`** (in `start`, replace the last two lines)', 'replace_text',
     '    m.poke(map.text_glyph + 2, 0); // no flags; the height depends on the style\n',
     arg='    m.poke(map.text_glyph + 1, 8); // 8 rows tall\n    m.poke(map.text_glyph + 2, 0); // no flags\n')
step('D6', '**`src/text.zig`** (replace `draw`)', 'replace_fn', fn('src/text.zig', 'draw'), arg='draw')
step('D7', '**`src/text.zig`** (in `say`, replace the last line)', 'replace_text', '    _ = draw(m, x, y, color, plain, map.text_buffer);\n', arg='    draw(m, x, y, color, map.text_buffer);\n')
step('D8', '**`src/room.zig`** (add an import below `Machine`)', 'after_line', 'const Color = machine.Color;\n', arg='const Machine = machine.Machine;')
step('D9', '**`src/room.zig`** (replace `draw`)', 'replace_fn', fn('src/room.zig', 'draw').replace('prepare(m, m.peek(map.room_number))', 'prepare(m, 0)'), arg='draw')
step('D10', '**`src/room.zig`** (add at the end of the file)', 'append', between('src/room.zig', '/// Where the door itself sits', 'pub fn flip'), run='D')

# ---- E: the authoring kit, then the Training Castle ---------------------------
step('E1', '**`src/shapes.zig`** (make `pack` public)', 'replace_text', 'pub fn pack(comptime name: []const u8, comptime a: Art) []const u8 {\n', arg='fn pack(comptime name: []const u8, comptime a: Art) []const u8 {\n')
step('E2', '**`src/author.zig`** (new file)', 'whole', between('src/author.zig', '//! The castle-authoring kit', '// ---- what you get'))
step('E3', '**`src/author.zig`** (add at the end of the file)', 'append', between('src/author.zig', '// ---- what you get', "/// One room's object stream").replace('        check(Name, c);\n', ''))
step('E4', '**`src/author.zig`** (add at the end of the file)', 'append', between('src/author.zig', "/// One room's object stream", "/// A door's 8 bytes"))
step('E5', '**`src/author.zig`** (add at the end of the file)', 'append', between('src/author.zig', "/// A door's 8 bytes", '// ---- checking it'))
step('E6', '**`src/hall.zig`** (add at the end of the file)', 'append', tail('src/hall.zig', '// ---- the same hall'), run='E1')
step('E7', '**`src/author.zig`** (in `build`, add after the `@setEvalBranchQuota` line)', 'after_line', '        check(Name, c);\n', arg='        @setEvalBranchQuota(2_000_000);')
step('E8', '**`src/author.zig`** (add at the end of the file)', 'append', tail('src/author.zig', '// ---- checking it'))
step('E9', None, 'copy', None, arg='src/training.zig')
step('E10', '**`src/main.zig`** (add below the `hall` import)', 'after_line', 'const training = @import("training.zig");\n', arg='const hall = @import("hall.zig");')
step('E11', "**`src/main.zig`** (in `boot`, replace the castle's `m.load`)", 'replace_text', '    m.load(map.castle.first, training.bytes);\n', arg='    m.load(map.castle.first, hall.bytes);\n')
step('E12', '**`src/main.zig`** (add at the end of the file)', 'append', between('src/main.zig', '// hall.zig is no longer loaded', 'test "N and P flip'), run='E')

# ---- F: flipping through the castle ------------------------------------------
step('F0a', '**`src/map.zig`** (add below the `game` region)', 'after_line',
     between('src/map.zig', '/// The room on screen.', '/// Text: a lookup table'),
     arg='pub const game_tick = game.first + 1; // goes up by one every frame, and wraps', pad='\n')
step('F0b', '**`src/map.zig`** (in `regions`, add after `game,`)', 'after_line', '    room,\n', arg='    game,')
step('F1', '**`src/room.zig`** (add two imports below `Color`)', 'after_line', 'const hw = machine.hw;\nconst map = @import("map.zig");\n', arg='const Color = machine.Color;')
step('F2', '**`src/room.zig`** (add below `floor_top`)', 'after_line', between('src/room.zig', "/// The final room isn't in the directory", 'pub fn draw'), arg='pub const floor_top = 192; // the bottom row of cells, as in Chapter 1', pad='\n')
step('F3', '**`src/room.zig`** (in `draw`, replace the `prepare` line)', 'replace_text', '    var walk = prepare(m, m.peek(map.room_number));\n', arg='    var walk = prepare(m, 0);\n')
step('F4', '**`src/room.zig`** (replace `prepare`)', 'replace_fn', fn('src/room.zig', 'prepare'), arg='prepare')
step('F5', '**`src/room.zig`** (add at the end of the file)', 'append', fn('src/room.zig', 'flip'))
step('F6', "**`src/main.zig`** (in `frame`'s `.title` branch, replace the last line)", 'replace_text',
     '            if (player.pressedFire(m)) {\n                room.start(m);\n                setMode(m, .draw_room);\n            }\n',
     arg='            if (player.pressedFire(m)) setMode(m, .draw_room);\n')
step('F7', '**`src/main.zig`** (in the `.room` branch, add after `player.steer(m);`)', 'after_line',
     '            m.bucket(0);\n            if (room.flip(m)) setMode(m, .draw_room);\n', arg='            player.steer(m);', run='F')

# ---- G: tests ----------------------------------------------------------------
step('G1', '**`src/main.zig`** (add two imports above `training`)', 'before_line', 'const castle = @import("castle.zig");\nconst author = @import("author.zig");\n', arg='const training = @import("training.zig");')
step('G2', '**`src/main.zig`** (add at the end of the file)', 'append', tail('src/main.zig', 'test "N and P flip'), run='G')
