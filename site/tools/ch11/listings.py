# Every ```zig listing of Chapter 11, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch11) wherever the
# listing matches it, and derived from it for intermediate states.
import re
NEW = '/home/claude/dr-creep-in-zig/site/code/ch11/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch10/'

def read(root, p): return open(root + p).read()
def f11(p): return read(NEW, p)
def f10(p): return read(OLD, p)

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

def cut(text, first, stop=None):
    s = text.index(first)
    return text[s:text.index(stop, s)] if stop else text[s:]

def rep(text, *pairs):
    for a, b in pairs:
        assert text.count(a) == 1, (a, text.count(a))
        text = text.replace(a, b)
    return text

def line(text, start):
    """The whole line of `text` that starts with `start`, without its newline."""
    ls = [l for l in text.split('\n') if l.startswith(start)]
    assert len(ls) == 1, (start, ls)
    return ls[0]

STEPS = []
def step(key, label, op, text, arg=None, run=None, pad='', file=None):
    d = dict(key=key, label=label, op=op, text=text, arg=arg, run=run, pad=pad)
    if file: d['file'] = file
    STEPS.append(d)

def test(text, title):
    """The test whose name starts with `title`, and the blank line after it."""
    s = text.index('test "' + title)
    e = text.index('\n}\n', s) + 3
    return text[s:e] + '\n'

MAIN = f11('src/main.zig')
MAIN10 = f10('src/main.zig')
MAP = f11('src/map.zig')
MAP10 = f10('src/map.zig')
FILES = f11('src/files.zig')
SCORES = f11('src/scores.zig')
TYPING = f11('src/typing.zig')
TITLE = f11('src/title.zig')
GAME = f11('src/game.zig')
GAME10 = f10('src/game.zig')

def chunk(first, stop=None):
    """Main's text from the line starting `first` up to the one starting `stop` (or the end)."""
    s = MAIN.index('\n' + first) + 1
    e = MAIN.index('\n' + stop, s) + 1 if stop else len(MAIN)
    return MAIN[s:e]

# Every new screen's prongs go in at the end of the switch.
SWITCH_END = '    }\n    m.bucket(0);\n'

# ============================================================================
# A: a disk of our own, made while the game compiles
# ============================================================================
step('A1', '**`src/master.zig`** (new file)', 'whole', f11('src/master.zig'))
step('A2', '**`src/main.zig`** (add below the `tunes` import)', 'after_line',
     'const master = @import("master.zig");\n', arg='const tunes = @import("tunes.zig");')
step('A3', '**`src/main.zig`** (add above `Mode`)', 'before_text',
     cut(MAIN, '/// The disk that comes with the game.', '/// What the game is doing.'), arg='/// What the game is doing.', run='A')

# ============================================================================
# B: the castle list, and a castle from the disk
# ============================================================================
STAGING_DOC = '/// The castle as it came, untouched: each new game starts from a copy.\n'
step('B1', '**`src/map.zig`** (replace the comment on `staging`)', 'replace_text',
     cut(MAP, '/// The castle as it came off the disk', 'pub const staging'), arg=STAGING_DOC)
STAGING = line(MAP, 'pub const staging')
step('B2', '**`src/map.zig`** (add below `staging`)', 'after_line',
     cut(MAP, "/// The castle's best times", '\n/// Where each of the 200'), arg=STAGING, pad='\n')
step('B3', '**`src/map.zig`** (add below the `input_ports` line)', 'after_line',
     line(MAP, 'const disk_drive') + '\n', arg=line(MAP, 'const input_ports'))
step('B4', '**`src/map.zig`** (in `regions`, add below `staging`)', 'after_line',
     '    scores,\n    shell,\n    catalog,\n', arg='    staging,')
step('B5', '**`src/map.zig`** (in `regions`, add below `input_ports`)', 'after_line',
     '    disk_drive,\n', arg='    input_ports,')
SCORES_IMPORTS_B = 'const machine = @import("machine");\nconst Machine = machine.Machine;\nconst map = @import("map.zig");\n'
SCORES_HEAD = cut(SCORES, '//! Best times.', '/// A time as one number')
SCORES_IMPORTS = cut(SCORES, 'const machine = ', '\n/// One best time')
step('B6', '**`src/scores.zig`** (new file)', 'whole', rep(SCORES_HEAD, (SCORES_IMPORTS, SCORES_IMPORTS_B)).rstrip('\n') + '\n')
MAGIC_FINAL = '    if (m.peek(map.staging.first + 2) & ~castle.restored != castle.magic_value) return false;\n'
MAGIC_B = '    if (m.peek(map.staging.first + 2) != castle.magic_value) return false;\n'
SAVE_SCORES = fn('src/files.zig', 'saveScores')
step('B7', '**`src/files.zig`** (new file)', 'whole',
     rep(cut(FILES, '//! The game', '/// Save the best times'), (MAGIC_FINAL, MAGIC_B)).rstrip('\n') + '\n')
step('B8', '**`src/main.zig`** (add above the `master` import)', 'before_line',
     'const files = @import("files.zig");\n', arg='const master = @import("master.zig");')
BOOT_LOAD = line(MAIN10, '    m.load(map.staging.first, training.bytes);')
step('B9', '**`src/main.zig`** (add below the `master` import)', 'after_line',
     'const scores = @import("scores.zig");\n', arg='const master = @import("master.zig");')
step('B10', '**`src/main.zig`** (in `boot`, take out this line)', 'delete_text', BOOT_LOAD + '\n', arg=BOOT_LOAD + '\n')
BLANK_FIRST = '            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles'
step('B11', '**`src/main.zig`** (in the `.draw_title` prong, add below the blank)', 'after_line',
     cut(MAIN, '            // The first time: the disk', '            m.bucket(bucket_drawing);\n            title.draw'), arg=BLANK_FIRST)
step('B12', '**`src/game.zig`** (add below the `sound` import)', 'after_line',
     'const files = @import("files.zig");\n', arg='const sound = @import("sound.zig");')
step('B13', '**`src/game.zig`** (replace `chosen`)', 'replace_fn', fn('src/game.zig', 'chosen'), arg='chosen')
step('B14', '**`src/title.zig`** (add below the `text` import)', 'after_line',
     'const files = @import("files.zig");\n', arg='const text = @import("text.zig");')
BUSY_FINAL = line(TITLE, '            row == 9 or') + '\n'
BUSY_B = "            row == 9 or // the castle's name\n"
step('B15', '**`src/title.zig`** (in `star_map`, add below the DR. CREEP line)', 'after_line',
     BUSY_B, arg='            (row == 7 and col >= 11 and col < 29) or // DR. CREEP')
NO_DISK = '    } else text.say(m, 24, 72, .red, "NO CASTLE DISK");'
step('B16', '**`src/title.zig`** (in `draw`, add below DR. CREEP)', 'after_line',
     cut(TITLE, '    if (files.ready(m)) {', NO_DISK) + NO_DISK + '\n', arg='    text.say(m, 44, 56, .light_green, "DR. CREEP");')
step('B17', '**`src/main.zig`** (add at the end)', 'append', chunk('test "power on', '/// Push stick 1'), run='B')

# ============================================================================
# C: the menu
# ============================================================================
TYPING_HEAD = cut(TYPING, '//! Typing', 'pub const max_letters')
TYPING_KEYS = cut(TYPING, "/// The keys that aren't letters.", '\n/// Start a line')
step('C1', '**`src/typing.zig`** (new file)', 'whole', TYPING_HEAD + TYPING_KEYS)
step('C2', '**`src/menu.zig`** (new file)', 'whole', f11('src/menu.zig'))
step('C3', '**`src/main.zig`** (add below the `master` import)', 'after_line',
     'const menu = @import("menu.zig");\n', arg='const master = @import("master.zig");')
MODE_FINAL = cut(MAIN, 'const Mode = enum(u8) {', '};\n') + '};\n'
MODE_C = rep(MODE_FINAL, ('    draw_times,\n    times,\n    draw_name,\n    name,\n', ''))
step('C4', '**`src/main.zig`** (replace `Mode`)', 'replace_text', MODE_C, arg=line(MAIN10, 'const Mode = ') + '\n')
step('C5', '**`src/main.zig`** (in the `.title` prong, replace the first line)', 'replace_text',
     cut(MAIN, '            if (menu.asked(m)) {', '|two| {') + '|two| {\n', arg='            if (game.chosen(m)) |two| {\n')
MENU_PRONGS = cut(MAIN, '        .draw_menu => {', '        .draw_times => {')
RESUME = cut(MENU_PRONGS, '                .resume_game => {', '                },\n') + '                },\n'
LATER = '                .resume_game => {}, // soon\n'
BEST_TIMES = '                .best_times => setMode(m, .draw_times),\n'
step('C6', '**`src/main.zig`** (add at the end of the `switch`)', 'before_text',
     rep(MENU_PRONGS, (BEST_TIMES + RESUME, '                .best_times => {}, // soon\n' + LATER)), arg=SWITCH_END)
step('C7', "**`src/title.zig`** (in `star_map`, replace the castle's name line)", 'replace_text', BUSY_FINAL, arg=BUSY_B)
step('C8', '**`src/title.zig`** (in `draw`, add below NO CASTLE DISK)', 'after_line',
     line(TITLE, '    text.say(m, 16, 88') + '\n', arg=NO_DISK)
AFTER_DOC10 = cut(GAME10, '/// The room\'s over: settle up', 'pub fn after')
step('C9', '**`src/game.zig`** (replace the comment on `after`)', 'replace_text',
     cut(GAME, '/// The room\'s over: settle up', 'pub fn after'), arg=AFTER_DOC10)
step('C10', '**`src/game.zig`** (in `after`, replace the `lives` line)', 'replace_text',
     cut(GAME, '            const lost: u8', '            m.poke(castle.lives + p, lives);'),
     arg=line(GAME10, '            const lives = ') + '\n')
HOLD2_DOC = "/// Hold the two sticks' switches for `frames` frames, then let go.\n"
step('C11', '**`src/main.zig`** (add above `hold2`)', 'before_text', fn('src/main.zig', 'typeIn') + '\n', arg=HOLD2_DOC)
step('C12', '**`src/main.zig`** (add at the end)', 'append', chunk('/// Push stick 1', 'test "a best time'), run='C')

# ============================================================================
# D: best times, and typing
# ============================================================================
step('D1', '**`src/clock.zig`** (replace `print`)', 'replace_fn',
     fn('src/clock.zig', 'print') + '\n' + fn('src/clock.zig', 'write'), arg='print')
step('D2', '**`src/scores.zig`** (add below the `Machine` import)', 'after_line',
     'const Color = machine.Color;\nconst hw = machine.hw;\n', arg='const Machine = machine.Machine;')
step('D3', '**`src/scores.zig`** (add below the `map` import)', 'after_line',
     cut(SCORES, 'const castle = ', '\n/// One best time'), arg='const map = @import("map.zig");')
EARNED_FINAL = cut(SCORES, "/// it's his turn to sign it.", '    const t = clock.of')
EARNED_D = ("/// it's his turn to sign it. Not in a game with unlimited lives.\n"
            'pub fn earned(m: *Machine, p: player.Number) bool {\n'
            '    if (m.peek(map.shell_unlimited) != 0) return false;\n')
step('D4', '**`src/scores.zig`** (add at the end)', 'append',
     rep(cut(SCORES, '/// A time as one number'), (EARNED_FINAL, EARNED_D)))
step('D5', '**`src/typing.zig`** (add above the keys)', 'before_text',
     cut(TYPING, 'pub const max_letters', "/// The keys that aren't letters."), arg="/// The keys that aren't letters.")
step('D6', '**`src/typing.zig`** (add at the end)', 'append', cut(TYPING, '/// Start a line'))
step('D7', '**`src/files.zig`** (add at the end)', 'append', SAVE_SCORES)
step('D8', '**`src/main.zig`** (in `Mode`, add below `menu`)', 'after_line', '    draw_times,\n    times,\n', arg='    menu,')
step('D9', '**`src/main.zig`** (in `boot`, add below the stars)', 'after_line',
     line(MAIN, '    m.poke(map.shell_signing, 0xFF);') + '\n', arg='    m.load(map.stars.first, &title.star_map);')
step('D10', '**`src/main.zig`** (in the `.escape` prong, replace the last line)', 'replace_text',
     cut(MAIN, '            if (escape.run(m)) {', '        },\n        .draw_over'), arg=line(MAIN10, '            if (escape.run(m))') + '\n')
step('D11', '**`src/main.zig`** (in the `.menu` prong, replace the BEST TIMES line)', 'replace_text',
     BEST_TIMES, arg='                .best_times => {}, // soon\n')
step('D12', '**`src/main.zig`** (add at the end of the `switch`)', 'before_text',
     cut(MAIN, '        .draw_times => {', '        .draw_name => {'), arg=SWITCH_END)
step('D13', '**`src/main.zig`** (add above `typeIn`)', 'before_text', fn('src/main.zig', 'sign') + '\n', arg='/// Type `keys`, a key a frame.')
step('D14', '**`src/main.zig`** (in `wholeCastle`, below the `escaped` test)', 'after_line',
     '    sign(m, "ACE");\n    if (m.ram[castle.two] != 0) sign(m, "DUO"); // and player 2\'s escape\n',
     arg='    try std.testing.expectEqual(1, m.ram[castle.escaped]);')
step('D15', '**`src/main.zig`** (in "both through the way out", below the first `who`)', 'after_line',
     '    sign(m, "ONE");\n', arg='    try std.testing.expectEqual(0, game.between(m).escape.who);')
step('D16', '**`src/main.zig`** (in the same test, below the second `in_game`)', 'after_text', '    sign(m, "TWO");\n',
     arg='    try std.testing.expectEqual(1, game.between(m).escape.who);\n    try std.testing.expectEqual(0, m.ram[castle.in_game]);\n')
step('D17', '**`src/main.zig`** (in the fanfare test, below the escape song)', 'after_line',
     '    sign(m, "WIN");\n', arg='    try std.testing.expectEqual(tunes.Song.escape, song(m).?);')
step('D18', '**`src/main.zig`** (add above the power-on test)', 'before_text',
     'const drive = machine.drive;\n\n', arg='test "power on')
step('D19', '**`src/main.zig`** (add at the end)', 'append', chunk('test "a best time', 'test "saved on'), run='D')

# ============================================================================
# E: saving the game
# ============================================================================
CASTLE = f11('src/castle.zig')
step('E1', '**`src/castle.zig`** (add below `magic_value`)', 'after_line',
     cut(CASTLE, '/// Bit 0 of the magic byte', '\n// ---- the room directory'), arg='pub const magic_value: u8 = 0x80;')
step('E2', '**`src/files.zig`** (in `pick`, replace the magic test)', 'replace_text', MAGIC_FINAL, arg=MAGIC_B)
step('E3', '**`src/scores.zig`** (replace the top of `earned`)', 'replace_text', EARNED_FINAL, arg=EARNED_D)
step('E4', '**`src/position.zig`** (new file)', 'whole', f11('src/position.zig'))
step('E5', '**`src/main.zig`** (add below the `scores` import)', 'after_line',
     'const position = @import("position.zig");\n', arg='const scores = @import("scores.zig");')
step('E6', '**`src/main.zig`** (in `Mode`, add below `times`)', 'after_line', '    draw_name,\n    name,\n', arg='    times,')
step('E7', '**`src/main.zig`** (in the `.map` prong, replace the last line)', 'replace_text',
     cut(MAIN, '            if (position.asked(m)) {', '        },\n        .draw_room'),
     arg=line(MAIN10, '            if (chart.wait(m) or room.flip(m))') + '\n')
step('E8', '**`src/main.zig`** (in the `.menu` prong, replace the RESUME GAME line)', 'replace_text', RESUME, arg=LATER)
step('E9', '**`src/main.zig`** (add at the end of the `switch`)', 'before_text',
     cut(MAIN, '        .draw_name => {', SWITCH_END), arg=SWITCH_END)
step('E10', '**`src/main.zig`** (add at the end)', 'append', chunk('test "saved on', 'test "a disk of your own'), run='E')

# ============================================================================
# F: what a 1984 disk needs
# ============================================================================
SCREEN = f11('src/screen.zig')
ERASE_SIG = 'pub fn erase(m: *Machine, id: shapes.Id, x: u8, y: u8) void {\n'
step('F1', '**`src/screen.zig`** (in `erase`, replace the first line)', 'replace_text',
     cut(SCREEN, ERASE_SIG, '    var src = shapes.address(m, id);\n    const width = m.peek(src);'), arg=ERASE_SIG)
LOOP10 = '            var i: u16 = 0;\n            while (i < width and column + i < 40) : (i += 1) {\n'
step('F2', '**`src/screen.zig`** (in `erasePart`, replace the start of the loop)', 'replace_text',
     cut(fn('src/screen.zig', 'erasePart'), '            var i: u16 = skip;', '                // Both bits'), arg=LOOP10)
ROOM = f11('src/room.zig')
ROOM10 = f10('src/room.zig')
step('F3', '**`src/room.zig`** (replace `unplace`)', 'replace_fn', fn('src/room.zig', 'unplace'), arg='unplace')
step('F4', '**`src/room.zig`** (in `tint`, replace the first line)', 'replace_text',
     cut(ROOM, "    // Cells left of the screen's edge", '    m.work(16); // y / 8 * 40'), arg=line(ROOM10, '    var cell = ') + '\n')
step('F5', '**`src/room.zig`** (in `tint`, replace the inner loop)', 'replace_text',
     line(ROOM, '        while (i < wide)') + '\n', arg=line(ROOM10, '        while (i < across)') + '\n')
step('F6', '**`src/room.zig`** (add at the end)', 'append', test(ROOM, 'a machine hanging off'))
FRANK = f11('src/frankenstein.zig')
FRANK10 = f10('src/frankenstein.zig')
step('F7', '**`src/frankenstein.zig`** (add above `prepare`\'s comment)', 'before_text',
     cut(FRANK, "/// An awake Frankenstein's record", '/// A Frankenstein record:'), arg='/// A Frankenstein record:')
step('F8', '**`src/frankenstein.zig`** (in `prepare`, replace the `setFrame`)', 'replace_text',
     line(FRANK, '        actors.setFrame(m, slot, fromRecord') + '\n', arg=line(FRANK10, '        actors.setFrame(m, slot, @enumFromInt(f.frame))') + '\n')
step('F9', '**`src/frankenstein.zig`** (in `turn`, replace the frame line)', 'replace_text',
     '    f.frame = toRecord(m, a.frame);\n', arg='    f.frame = a.frame;\n')
step('F10', '**`src/frankenstein.zig`** (add at the end)', 'append', cut(FRANK, '// ---- tests'))
TRAINING = f11('src/training.zig')
step('F11', '**`src/training.zig`** (in the Frankenstein record, replace the frame)', 'replace_text',
     line(TRAINING, '                .frame = 0x84') + '\n', arg='                .frame = @intFromEnum(shapes.Id.frank_right_0),\n')
step('F12', '**`src/main.zig`** (add at the end)', 'append', chunk('test "a disk of your own'), run='F')

SNAP = set()
