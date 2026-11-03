# Every ```zig listing of Chapter 10, in typing order, with the edit it makes.
# Texts are sliced from the finished checkpoint (code/ch10) wherever the
# listing matches it, and derived from it for intermediate states.
import re, difflib
NEW = '/home/claude/dr-creep-in-zig/site/code/ch10/'
OLD = '/home/claude/dr-creep-in-zig/site/code/ch09/'

def read(root, p): return open(root + p).read()
def f10(p): return read(NEW, p)
def f9(p): return read(OLD, p)

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

def cut(text, first, stop):
    s = text.index(first)
    return text[s:text.index(stop, s)]

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

def insertions(path):
    """Each run of lines ch10 adds to `path`: (the line above it, the lines)."""
    a, b = f9(path).split('\n'), f10(path).split('\n')
    out = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == 'equal': continue
        assert tag == 'insert', (path, tag, a[i1:i2], b[j1:j2])
        k = j1 - 1
        while b[:j1].count(b[k]) > 1 or a.count(b[k]) > 1: k -= 1  # back up until the anchor is unique
        out.append(('\n'.join(b[k:j1]), '\n'.join(b[j1:j2]) + '\n'))
    return out

def after(key, label, path, anchor, text):
    """Insert `text` below `anchor`: one line, or several (then matched as text)."""
    if '\n' in anchor: step(key, label, 'after_text', text, arg=anchor + '\n', file=path)
    else: step(key, label, 'after_line', text, arg=anchor, file=path)

MAIN = f10('src/main.zig')
MAIN9 = f9('src/main.zig')
MAP = f10('src/map.zig')
MAP9 = f9('src/map.zig')
TUNES = f10('src/tunes.zig')
SOUND = f10('src/sound.zig')

# ============================================================================
# A: the SOUND chip, and a first note
# ============================================================================
step('A1', '**`src/map.zig`** (add below the `video_chip` line)', 'after_line',
     line(MAP, 'const sound_chip') + '\n', arg=line(MAP, 'const video_chip'))
step('A2', '**`src/map.zig`** (in `regions`, add below `video_chip`)', 'after_line', '    sound_chip,\n', arg='    video_chip,')
NOTES = cut(TUNES, '// ---- notes', '// ---- the composer').rstrip('\n') + '\n'
COUNT_FINAL = cut(NOTES, '/// The notes the table has', '\n\n') + '\n'
COUNT_FIRST = '/// The notes the table has: eight octaves, C0 up to B7.\npub const note_count = 96;\n'
TUNES_HEAD = cut(TUNES, '//! Music and sound effects', 'const map = ')
step('A3', '**`src/tunes.zig`** (new file)', 'whole', TUNES_HEAD + '\n' + rep(NOTES, (COUNT_FINAL, COUNT_FIRST)))
step('A4', '**`src/main.zig`** (add below the `clock` import)', 'after_line',
     'const tunes = @import("tunes.zig");\n', arg='const clock = @import("clock.zig");')
EXPERIMENT = '''            // An experiment: A4 on voice 0, a sawtooth, held at full volume.
            const v0 = hw.voice(0);
            m.poke16(v0 + machine.sound.freq_lo, tunes.frequencies[tunes.note("A4")]);
            m.poke(v0 + machine.sound.sustain_release, 0xF0);
            m.poke(v0 + machine.sound.control, machine.sound.sawtooth | machine.sound.gate);
            m.poke(hw.sound_volume, 15);
'''
step('A5', '**`src/main.zig`** (in the `.draw_title` prong, add below `title.draw(m);`)', 'after_line',
     EXPERIMENT, arg='            title.draw(m);')
step('A6', '**`src/tunes.zig`** (the fix: replace `note_count` and its comment)', 'replace_text', COUNT_FINAL, arg=COUNT_FIRST)
step('A7', '**`src/tunes.zig`** (add at the end)', 'append', test(TUNES, 'A4 is 440 Hz').rstrip('\n') + '\n', run='A')

# The reader's project right after these steps is kept, for errs.py.
SNAP = {'A5'}

# ============================================================================
# B: a tune as a program
# ============================================================================
step('B1', '**`src/sound.zig`** (new file)', 'whole', cut(SOUND, '//! The sound driver', '/// What `map.sound_playing` says').rstrip('\n') + '\n')
step('B2', '**`src/tunes.zig`** (add below the `chip` import)', 'after_line',
     'const map = @import("map.zig");\nconst sound = @import("sound.zig");\n', arg='const chip = machine.sound;')
TESTS_START = 'test "A4 is 440 Hz"'
COMPOSER = cut(TUNES, '// ---- the composer', '// ---- where it all goes')
step('B3', '**`src/tunes.zig`** (add above the test)', 'before_text', COMPOSER, arg=TESTS_START)
step('B4', '**`src/tunes.zig`** (add at the end)', 'append', test(TUNES, 'the composer weaves').rstrip('\n') + '\n')
MUSIC_LINE = line(MAP, 'pub const music = Region')
step('B5', '**`src/map.zig`** (add below the comment on the built-in tables)', 'after_line',
     MUSIC_LINE + '\n', arg='/// Built-in tables, copied to the top of the program image at boot.')
step('B6', '**`src/map.zig`** (the program image now ends below the music)', 'replace_text',
     line(MAP, 'const program = ') + '\n', arg=line(MAP9, 'const program = ') + '\n')
step('B7', '**`src/map.zig`** (in `regions`, add below `program`)', 'after_line', '    music,\n', arg='    program,')
step('B8', '**`src/tunes.zig`** (add above the tests)', 'before_text',
     cut(TUNES, '// ---- where it all goes', '/// The sound effects, numbered as in 1984.'), arg=TESTS_START)
TUNES_HEADING = line(TUNES, '// ---- the tunes')
step('B9', '**`src/tunes.zig`** (add above the tests)', 'before_text',
     TUNES_HEADING + '\n\n' + cut(TUNES, '/// Instruments for the tunes.', 'const songs = struct {'), arg=TESTS_START)
step('B10', '**`src/tunes.zig`** (add above the tests: the tunes)', 'before_text',
     cut(TUNES, 'const songs = struct {', TESTS_START), arg=TESTS_START, run='B')

# ============================================================================
# C: the driver, on the frame interrupt
# ============================================================================
step('C1', '**`src/map.zig`** (add above the text region)', 'before_text',
     cut(MAP, '/// The sound driver: where', '/// Text: a lookup table'), arg='/// Text: a lookup table')
step('C2', '**`src/map.zig`** (in `regions`, add below `players`)', 'after_line', '    sound,\n', arg='    players,')
START_FINAL = fn('src/sound.zig', 'start')
START_C = '''/// At power-on: the tunes and the frequency table into the music region,
/// and nothing playing.
pub fn start(m: *Machine) void {
    m.load(map.music.first, tunes.music);
    m.poke(map.sound_playing, nothing);
}
'''
DRIVER = cut(SOUND, '/// What `map.sound_playing` says', '/// Play a sound effect, if nothing')
step('C3', '**`src/sound.zig`** (add at the end)', 'append',
     rep(DRIVER, (START_FINAL, START_C)) + fn('src/sound.zig', 'stop'))
LAB = cut(SOUND, '// ---- tests', 'test "a note')
step('C4', '**`src/sound.zig`** (add at the end)', 'append',
     LAB + test(SOUND, 'the tempo') + test(SOUND, 'the title tune plays').rstrip('\n') + '\n')
step('C5', '**`src/main.zig`** (add above the `tunes` import)', 'before_line',
     'const sound = @import("sound.zig");\n', arg='const tunes = @import("tunes.zig");')
step('C6', '**`src/main.zig`** (add below `bucket_objects`)', 'after_line',
     'const bucket_sound = 5;\n', arg='const bucket_objects = 4;')
step('C7', '**`src/main.zig`** (in `boot`, add at the end)', 'after_line', '    sound.start(m);\n', arg='    dice.start(m);')
FRAME_TOP = cut(MAIN, '    // The music keeps time first', '    switch (mode(m)) {')
step('C8', '**`src/main.zig`** (at the top of `frame`)', 'after_line', FRAME_TOP, arg='pub fn frame(m: *Machine) void {')
step('C9', '**`src/main.zig`** (in the `.draw_title` prong, replace the experiment)', 'replace_text',
     '            sound.music(m, .title);\n', arg=EXPERIMENT)
step('C10', '**`src/main.zig`** (in the `.title` prong, add below the loading pause)', 'after_line',
     '                sound.stop(m);\n', arg='                m.poke(hw.control, 0); // the copy of the castle is a loading pause', run='C')

# ============================================================================
# D: sound effects, and what may interrupt what
# ============================================================================
step('D1', '**`src/map.zig`** (add above the built-in tables)', 'before_text',
     cut(MAP, '/// The sound effects, copied here', '/// Built-in tables'), arg='/// Built-in tables')
step('D2', '**`src/map.zig`** (in `regions`, add below `text`)', 'after_line', '    effects,\n', arg='    text,')
step('D3', '**`src/tunes.zig`** (add above the tunes\' heading)', 'before_text',
     cut(TUNES, '/// The sound effects, numbered as in 1984.', TUNES_HEADING), arg=TUNES_HEADING)
step('D4', '**`src/tunes.zig`** (add below the tunes\' heading)', 'after_line',
     '\n' + cut(TUNES, '/// The sound effects play at this tempo', '/// Instruments for the tunes.').rstrip('\n') + '\n', arg=TUNES_HEADING)
step('D5', '**`src/sound.zig`** (replace `start`)', 'replace_fn', START_FINAL, arg='start')
step('D6', '**`src/sound.zig`** (add below `music`)', 'insert_after_fn',
     fn('src/sound.zig', 'effect') + '\n' + fn('src/sound.zig', 'effectAt'), arg='music')
step('D7', '**`src/sound.zig`** (add above the tempo test)', 'before_text', test(SOUND, 'a note'), arg='test "the tempo')
step('D8', '**`src/sound.zig`** (add above the last test)', 'before_text', test(SOUND, 'what may interrupt'), arg='test "the title tune plays')
step('D9', '**`src/chart.zig`** (add below the `game` import)', 'after_line',
     'const sound = @import("sound.zig");\n', arg='const game = @import("game.zig");')
CHART = f10('src/chart.zig')
step('D10', '**`src/chart.zig`** (at the end of `wait`, replace the `return`)', 'replace_text',
     cut(CHART, '    if (c.ready[0] == 0 or c.ready[1] == 0) return false;', '\n}') + '\n',
     arg='    return c.ready[0] != 0 and c.ready[1] != 0;\n')
def chunk(first, stop=None):
    """Main's text from the line starting `first` up to the one starting `stop` (or the end)."""
    s = MAIN.index('\n' + first) + 1
    e = MAIN.index('\n' + stop, s) + 1 if stop else len(MAIN)
    return MAIN[s:e]
step('D11', '**`src/main.zig`** (add at the end)', 'append',
     chunk('/// Hold `stick` for up to', 'test "a door creaks'), run='D')

# ============================================================================
# E: every machine in the castle, and the screens between rooms
# ============================================================================
# The imports: a labelled listing for the first file, and the same lines,
# unlabelled, for the rest (a table in the prose says which get which).
IMPORT_FILES = ['doors', 'actors', 'lightning', 'forcefields', 'trapdoors', 'conveyors', 'transmitter',
                'locks', 'guns', 'mummy', 'frankenstein', 'escape', 'game']
calls = {}
for i, name in enumerate(IMPORT_FILES):
    p = 'src/%s.zig' % name
    ins = insertions(p)
    anchor, text = ins[0]
    label = '**`src/doors.zig`** (add at the end of the imports)' if name == 'doors' else None
    after('E%d' % (i + 1), label, p, anchor, text)
    calls[name] = ins[1:]
n = len(IMPORT_FILES)
CALL_LABELS = [
    ('doors', 'in `open`, below the `wipe`'),
    ('actors', 'in `flicker`, below `a.flashes -= 1;`'),
    ('lightning', 'at the end of `pull`'),
    ('forcefields', 'in `press`, below the `holding` test'),
    ('forcefields', 'in `count`, below the `gauge` line'),
    ('trapdoors', 'at the end of `swing`'),
    ('conveyors', 'in `run`, below `arrows(m, c);`'),
    ('transmitter', 'at the end of `use`'),
    ('transmitter', 'in `flash`, below `o.step -= 1;`'),
    ('locks', 'in `take`, below the `unplace`'),
    ('guns', 'in `shoot`, below the `setFrame`'),
    ('mummy', 'in `walk`, below the rising `setFrame`'),
    ('frankenstein', 'in `turn`, below `f.state.awake = true;`'),
    ('escape', 'in `draw`, below the clock'),
    ('game', 'at the end of `drawOver`'),
]
used = {}
for name, where in CALL_LABELS:
    k = used.get(name, 0); used[name] = k + 1
    anchor, text = calls[name][k]
    n += 1
    after('E%d' % n, '**`src/%s.zig`** (%s)' % (name, where), 'src/%s.zig' % name, anchor, text)
for name in calls: assert used.get(name, 0) == len(calls[name]), name
for title, stop in [('test "a door creaks', 'test "every machine'), ('test "every machine', 'test "a death flashes'),
                    ('test "a death flashes', 'test "a fanfare'), ('test "a fanfare', None)]:
    n += 1
    step('E%d' % n, '**`src/main.zig`** (add at the end)', 'append', chunk(title, stop), run='E' if stop is None else None)
