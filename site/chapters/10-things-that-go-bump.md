---
chapter: 10
title: "Things That Go Bump"
checkpoint: ch10
---

:::mission-briefing
Nine chapters of castle, and not a sound. This chapter gives the game a
voice. The title screen plays a waltz on **three voices**. A door
creaks higher as it opens, lightning crackles when you throw its switch,
a key chimes when you pick it up, and an explorer who touches the
lightning beeps lower each time he flashes. Escape and a fanfare plays.
Lose your last life and GAME OVER gets a slow, sad fall.

All of it is played by one small **interpreter**. A tune is a program,
a few bytes a note, and the interpreter runs a few of its commands each
frame. A sound effect is a tiny tune that takes over the same
interpreter for a moment.

New under the hood: **interrupts**, explained properly at last (what
`frame` has been all along), **keeping time at a fixed rate**, and a
**frequency table** worked out by the compiler.
:::

## The speaker board

Chapter 1's reference card had a section on the SOUND chip, and a note:
this model ships without its speaker board. The board has arrived. It's
in the machine folder, [`code/machine/`](../code/machine/), so replace
your `code/machine` with the new one. Every checkpoint still builds
with it, and runs exactly as before. The machine just listens now.

In the browser, the click that starts the game also turns the sound on
(browsers stay silent until you click something on the page). The
headless runner has a new option, `--wav FILE`, which saves everything
the chip plays as a sound file. Section 11 of the card now describes the
whole chip.

## Three voices

The SOUND chip plays three notes at once. Each of its three **voices**
has two parts. An **oscillator** makes a wave, a sound that repeats
over and over, at the frequency you ask for. An **envelope** makes the
wave louder and softer over time. Then all three voices go through one
volume control to the speaker.

A voice has seven registers. Voice 0's start at `$D400`, voice 1's at
`$D407` and voice 2's at `$D40E`. The first two hold the frequency.
Then come the pulse width (more on that in a moment), the control
register, and two bytes for the envelope. One more register, `$D418`,
is the volume. Like the VIDEO chip's, they're plain memory: poke them
and the chip does what they say.

The control register's top four bits pick the **waveform**, the shape of
the wave. Each shape has its own sound:

- **Triangle**: soft and round, like a flute.
- **Sawtooth**: bright and buzzy, like brass.
- **Pulse**: hollow and reedy. The pulse width sets how hollow. At 2048
  out of 4096, half up and half down, it's a square wave, the classic
  8-bit sound. Narrower, it gets thinner and nasal.
- **Noise**: a hiss. Low, it's a rumble. High, it's a crash or a
  crackle.

The control register's bit 0 is the **gate**. Think of it as a key on a
piano. Set it, and the key goes down: the note starts. Clear it, and the
key comes up: the note fades away. How it starts and fades is the
envelope's job:

:::diagram ch10-envelope
:::

The **attack** is how fast the note rises to full. A pluck has a short
one, a violin swelling in a long one. The **decay** is how fast it falls
from full to the **sustain** level, where it stays as long as the gate is
on. The **release** is how fast it fades after the gate goes off. Each
is 4 bits, so 16 settings, from 2 milliseconds to 24 seconds. The card's
envelope table has them all.

Here's the chip in our memory map:

**`src/map.zig`** (add below the `video_chip` line)

```zig
const sound_chip = Region{ .name = "SOUND chip", .first = hw.sound_chip, .last = hw.sound_volume };
```

**`src/map.zig`** (in `regions`, add below `video_chip`)

```zig
    sound_chip,
```

## The first note

A frequency register isn't in hertz. The oscillator keeps a 24-bit
counter, and on every cycle of the 1 MHz clock it adds the frequency
register to it. Each time the counter goes all the way round, the wave
has played once. A counter of 24 bits goes round after 16,777,216, so:

    register = Hz × 16,777,216 / 1,000,000 = Hz × 16.777216

The note A above middle C is 440 Hz, which makes 7,382. Middle C itself
is 261.63 Hz, which makes 4,389.

That's a multiply with a fraction in it, and the Comet's processor has
no fractions, or even a multiply instruction. Worse, each note is the
one below it times the twelfth root of 2 (about 1.0595).

None of that has to happen on the Comet. The notes never change, so we
work them all out once, while the game compiles, and store the answers
in a **frequency table**: one 16-bit register for each note. Playing a
note becomes "look up note *n*", two peeks, like Chapter 2's row
table.

We'll number the notes from C0, the lowest C, 16.35 Hz. Each octave is
12 notes, so A4 (440 Hz) is note 57, and middle C, C4, is note 48. Eight
octaves, C0 to B7, make 96 notes. Here's the start of `tunes.zig`, where
the music will live:

**`src/tunes.zig`** (new file)

```zig
//! Music and sound effects, as data: the notes' frequencies, a composer
//! that turns up to three lines of notes into one stream of commands
//! while the game compiles, and every tune and effect in the game.

const std = @import("std");
const machine = @import("machine");
const chip = machine.sound;

// ---- notes ------------------------------------------------------------

/// The notes the table has: eight octaves, C0 up to B7.
pub const note_count = 96;

/// Each note's frequency register. C0 is 16.35 Hz, and each note is the
/// one below it times the twelfth root of 2, about 1.0595. That takes
/// fractions, so the compiler works it out; the Comet just looks it up.
pub const frequencies: [note_count]u16 = blk: {
    var out: [note_count]u16 = undefined;
    for (&out, 0..) |*f, n| {
        const hz = 16.351597831287414 * @exp2(@as(f64, @floatFromInt(n)) / 12.0);
        const register: u32 = @intFromFloat(@round(hz * chip.lap / chip.clock_hz));
        if (register > 0xFFFF) @compileError(std.fmt.comptimePrint(
            "note {d} needs a frequency register of {d}, and the register has 16 bits",
            .{ n, register },
        ));
        f.* = @intCast(register);
    }
    break :blk out;
};

/// A note's number from its name: a letter, then `#` (sharp, one up) or
/// `b` (flat, one down) if it has one, then the octave. "A4" is 57.
pub fn note(comptime name: []const u8) u8 {
    return comptime number(name);
}

fn number(comptime name: []const u8) u8 {
    var n: i32 = switch (name[0]) {
        'C' => 0,
        'D' => 2,
        'E' => 4,
        'F' => 5,
        'G' => 7,
        'A' => 9,
        'B' => 11,
        else => @compileError("not a note: " ++ name),
    };
    var rest: []const u8 = name[1..];
    if (rest.len > 0 and rest[0] == '#') {
        n += 1;
        rest = rest[1..];
    } else if (rest.len > 0 and rest[0] == 'b') {
        n -= 1;
        rest = rest[1..];
    }
    if (rest.len != 1 or rest[0] < '0' or rest[0] > '7') @compileError("not a note: " ++ name);
    n += 12 * @as(i32, rest[0] - '0');
    if (n < 0 or n >= note_count) @compileError("off the end of the table: " ++ name);
    return @intCast(n);
}
```

`@exp2(x)` is 2 to the power `x`, worked out by the compiler, in
floating point (numbers with a decimal point). `n / 12.0` octaves up from
C0 is note `n`. The `@round` turns the answer into a whole number, and
`blk:` gives the block a name so `break :blk out` can hand the finished
table back as the constant's value. None of this code is in the game.
Only the 96 answers are.

`note("A4")` turns a name into its number, also while compiling. A name
is a letter, an optional sharp or flat, and an octave. Ask for
`note("H4")` and the build stops with "not a note: H4".

Let's hear one. In `main.zig`, import the new file:

**`src/main.zig`** (add below the `clock` import)

```zig
const tunes = @import("tunes.zig");
```

and, for now, an experiment on the title screen: A4 on voice 0, with a
sawtooth, the gate on, the sustain at full, and the volume up.

**`src/main.zig`** (in the `.draw_title` prong, add below `title.draw(m);`)

```zig
            // An experiment: A4 on voice 0, a sawtooth, held at full volume.
            const v0 = hw.voice(0);
            m.poke16(v0 + machine.sound.freq_lo, tunes.frequencies[tunes.note("A4")]);
            m.poke(v0 + machine.sound.sustain_release, 0xF0);
            m.poke(v0 + machine.sound.control, machine.sound.sawtooth | machine.sound.gate);
            m.poke(hw.sound_volume, 15);
```

Build now, and the compiler refuses:

```
error: note 95 needs a frequency register of 66288, and the register has 16 bits
```

The table's own check caught it. B7 is 3,951 Hz, and its register would
be 66,288. A frequency register has 16 bits, so the most it holds is
65,535, just over 3,906 Hz. B7 is off the top of the chip. So the table
stops at A#7, 95 notes:

**`src/tunes.zig`** (the fix: replace `note_count` and its comment)

```zig
/// The notes the table has: C0 up to A#7. B7 would need a frequency
/// register of 66,288, and the register has 16 bits.
pub const note_count = 95;
```

The test pins down the arithmetic. A4 must be 7,382, and the sharp and
flat names for the same note must agree:

**`src/tunes.zig`** (add at the end)

```zig
test "A4 is 440 Hz" {
    try std.testing.expectEqual(57, note("A4"));
    try std.testing.expectEqual(7382, frequencies[note("A4")]); // 440 x 16.777216
    try std.testing.expectEqual(274, frequencies[0]); // C0, 16.35 Hz
    try std.testing.expectEqual(note("A#7"), note_count - 1);
    try std.testing.expectEqual(note("C#4"), note("Db4"));
}
```

Run it with `--wav`:

```
zig build run -- --frames 150 --wav creep.wav --dump-every 50
```

```
ran 150 frames (142 calls to frame)
cycles: max 167512 (852%), avg 7836 (39%) of 19656
  bucket 0: max 44, avg 43
  bucket 1: max 167496, avg 7792
overruns: 0, loading pauses: 1
last frame: frames/frame_00149.ppm
sound: creep.wav, 3.00 seconds, loudest 33%
```

The title screen comes up as before, and `creep.wav` is three seconds
of one long, buzzy A, at its loudest a third of full volume. That's one
voice of three at full volume, and the volume control shares the
speaker between all three.

<audio controls preload="none" src="images/10-note.mp3"></audio>

It never stops. Nothing ever clears the gate. To play a tune, something
has to change these registers at the right moments, over and over, while
the game does everything else.

## A tune is a program

A tune could be stored as a recording: the speaker's position, 44,100
times a second. Three seconds of that is 132,300 numbers, and our whole
program image is 28 KB. Instead, we store what a musician would write
down: this note, on this voice, for this long.

So a tune is a little program, and the thing that plays it is an
**interpreter**: a loop that reads a command, does it, and reads the
next. The commands are bytes, so this kind of program is called
**bytecode**.

Our tunes have ten commands, numbered 0 to 9, each with the number it had
in 1984. Each starts with one byte. Its bits 7–2 are the command's number
and its bits 1–0 are the voice it's for:

:::diagram ch10-command
:::

Most commands have a byte or more after the first: the note to play, the
number of ticks to wait, an instrument's five bytes. A command's length
is fixed by its number, so the interpreter always knows where the next
one starts.

A **tick** is the interpreter's unit of time. `wait 1` means "stop here
until the next tick". Everything before a `wait` happens at once, which
is how two voices start a chord together: note on voice 0, note on voice
1, then wait.

Two of them do nothing here. `filter` is for the chip's filter, which
this model doesn't have. `long_wait` waits longer than 255 ticks; no tune
of ours needs it, since a long wait can be two short ones. We keep both
so every command keeps its 1984 number.

Here's the new file for the interpreter, `sound.zig`. For now, it's just
the command set:

**`src/sound.zig`** (new file)

```zig
//! The sound driver: one small interpreter that plays the music and the
//! sound effects, a few commands at a time, from the frame interrupt.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const chip = machine.sound;
const map = @import("map.zig");
const tunes = @import("tunes.zig");

/// The commands, numbered as in 1984. A command's first byte is its
/// number times 4, plus the voice it's for (0-2); `lengths` says how many
/// bytes it takes, that one included.
pub const Op = enum(u8) {
    note_on, // + a note: its frequency from the table, and the gate on
    note_off, // the gate off: the note fades away
    wait, // + ticks: stop here until that many have gone by
    long_wait, // 1984 has it, but no tune uses it
    instrument, // + pulse width (2 bytes), waveform, attack/decay, sustain/release
    filter, // 1984 has it; the Comet's filter isn't fitted
    transpose, // + a number to add to every note this voice plays
    volume, // + the volume, 0-15
    tempo, // + how much of a tick each frame is, in 256ths
    end, // the end of the stream; and so is any number past it
    _,
};
const lengths = [_]u8{ 2, 1, 2, 2, 6, 5, 2, 2, 2 };

/// A command's first byte.
pub fn command(op: Op, voice: u2) u8 {
    return @intFromEnum(op) << 2 | voice;
}
pub const end = command(.end, 0);
```

`Op` is an `enum(u8)` with a `_` member, so any byte is allowed, like
Chapter 5's `Kind`. Number 9 and up are all `end`.

## The composer

We could write tunes as bytes by hand, but a waltz is a few hundred of
them, and every `wait` is a sum to get right. So we'll write tunes as
text and let the compiler do the sums. Each
voice gets a line of notes, `"E5:2 C5:2 -:2"`: a name and a length, with
`-` for a rest. A **composer**, a function that runs while compiling,
turns up to three such lines into one stream of commands.

The interpreter reads one stream, but three voices play at once, so the
composer has to interleave them. It walks through time one tick at a
time and writes what each voice does at that tick:

:::diagram ch10-weave
:::

`tunes.zig` needs the map and the command set:

**`src/tunes.zig`** (add below the `chip` import)

```zig
const map = @import("map.zig");
const sound = @import("sound.zig");
```

Here's the composer:

**`src/tunes.zig`** (add above the test)

```zig
// ---- the composer -----------------------------------------------------

/// A voice's sound: its waveform (one of the bits in `machine.sound`),
/// and its envelope.
pub const Instrument = struct {
    wave: u8,
    width: u12 = 0x800, // the pulse wave's width: 2048 is a square
    attack: u4 = 0,
    decay: u4 = 0,
    sustain: u4 = 15,
    release: u4 = 0,
};

/// One voice's line of a tune: its instrument, and its notes as text.
/// Each note is a name and a length, "E5:2"; a rest is "-:2". Lengths
/// count the tune's units. Bar lines, `|`, are for reading.
pub const Part = struct { sound: Instrument, notes: []const u8 };

pub const Tune = struct {
    tempo: u8, // ticks a frame, in 256ths
    unit: u8, // ticks in one unit of length
    parts: []const Part, // voice 0, 1, 2
};

/// Each note lets go of its gate this many ticks before the next one
/// starts, so the chip sees it off for at least a frame.
const gap = 1;

const Event = struct { tick: u32, on: bool, note: u8 };

/// One part's notes as gate-on and gate-off events, in time order.
fn events(comptime unit: u8, comptime notes: []const u8) []const Event {
    var out: []const Event = &.{};
    var tick: u32 = 0;
    var tokens = std.mem.tokenizeAny(u8, notes, " \n|");
    while (tokens.next()) |token| {
        const colon = std.mem.indexOfScalar(u8, token, ':') orelse @compileError("no length: " ++ token);
        const units = std.fmt.parseInt(u8, token[colon + 1 ..], 10) catch @compileError("bad length: " ++ token);
        const ticks = @as(u32, units) * unit;
        if (ticks <= gap) @compileError("too short to hear: " ++ token);
        const name = token[0..colon];
        if (!std.mem.eql(u8, name, "-")) {
            out = out ++ [_]Event{
                .{ .tick = tick, .on = true, .note = note(name) },
                .{ .tick = tick + ticks - gap, .on = false, .note = 0 },
            };
        }
        tick += ticks;
    }
    // The end of the part, as a rest: so the tune knows how long it is.
    return out ++ [_]Event{.{ .tick = tick, .on = false, .note = 0xFF }};
}

/// The bytes of a `wait` for `ticks` ticks, in pieces of up to 255.
fn wait(comptime ticks: u32) []const u8 {
    var out: []const u8 = &.{};
    var left = ticks;
    while (left > 0) : (left -= @min(left, 255)) {
        out = out ++ [_]u8{ sound.command(.wait, 0), @min(left, 255) };
    }
    return out;
}

/// Turn a tune into commands. The parts play at once, but the driver
/// reads one stream, so the composer walks through time a tick at a
/// time, writing what each voice does at that tick, with a `wait` for
/// the ticks in between. First the tempo, then each voice's instrument
/// and its first note; so in a sound effect, the first note is byte 9.
pub fn compose(comptime t: Tune) []const u8 {
    return comptime weave(t);
}

fn weave(comptime t: Tune) []const u8 {
    @setEvalBranchQuota(1_000_000); // compile-time loops are capped; this raises the cap
    if (t.parts.len == 0 or t.parts.len > 3) @compileError("a tune has one, two or three parts");
    var lists: [3][]const Event = undefined;
    var next: [3]usize = @splat(0);
    var length: u32 = 0;
    for (t.parts, 0..) |p, v| {
        lists[v] = events(t.unit, p.notes);
        length = @max(length, lists[v][lists[v].len - 1].tick);
    }
    if (length == 0) @compileError("a tune needs some notes");

    var out: []const u8 = &.{ sound.command(.tempo, 0), t.tempo };
    var last: u32 = 0; // the tick of the last command written
    var tick: u32 = 0;
    while (tick < length) : (tick += 1) {
        // Gates off first, then on, so a voice is never cut short.
        for ([_]bool{ false, true }) |on| {
            for (t.parts, 0..) |p, v| {
                if (tick == 0 and on) {
                    const i = p.sound;
                    out = out ++ [_]u8{
                        sound.command(.instrument, @intCast(v)),
                        @truncate(i.width),
                        i.width >> 8,
                        i.wave,
                        @as(u8, i.attack) << 4 | i.decay,
                        @as(u8, i.sustain) << 4 | i.release,
                    };
                }
                const list = lists[v];
                while (next[v] < list.len and list[next[v]].tick == tick and list[next[v]].on == on) : (next[v] += 1) {
                    const e = list[next[v]];
                    if (e.note == 0xFF) continue; // the end of the part
                    out = out ++ wait(tick - last);
                    last = tick;
                    out = out ++ if (on) [_]u8{ sound.command(.note_on, @intCast(v)), e.note } else [_]u8{sound.command(.note_off, @intCast(v))};
                }
            }
        }
    }
    return out ++ wait(length - last) ++ [_]u8{sound.end};
}
```

A few details are worth a closer look.

**The gap.** Each note lets go of its gate one tick before the next note
starts. The card says why: the chip reads its registers once a frame. If
a voice's gate went off and on again in the same frame, the chip would
never see it off, and two E's in a row would sound like one long E. One
tick is at least one frame at every tempo we'll use, so the chip always
sees the key come up.

**Off before on.** At each tick the composer writes every gate-off first,
then every gate-on. A note that ends on the same tick another starts is
let go before the new one begins.

**`++`** joins two arrays into a longer one, while compiling. That's how
`out` grows, command by command, like pushing to an array in
JavaScript. The finished stream is a constant in the program image, and
the Comet never sees the composer at all.

**`@setEvalBranchQuota`.** While compiling, the compiler gives up on a
loop after 1,000 rounds unless you raise the limit. A tune needs more.

**`compose` and `weave`.** `weave` does the work, and `compose` calls it
with `comptime` in front. That forces the whole call to happen while
compiling, even when `compose` is called from ordinary code that runs
later, like a test.

Here's a test. Two voices: C4 then E4, against a rest then G4:

**`src/tunes.zig`** (add at the end)

```zig
test "the composer weaves two voices into one stream" {
    const tri: Instrument = .{ .wave = chip.triangle };
    const bytes = compose(.{ .tempo = 0x80, .unit = 2, .parts = &.{
        .{ .sound = tri, .notes = "C4:2 E4:1" },
        .{ .sound = tri, .notes = "-:1 G4:2" },
    } });
    try std.testing.expectEqualSlices(u8, &.{
        0x20, 0x80, // tempo $80
        0x10, 0x00, 0x08, 0x10, 0x00, 0xF0, // voice 0: triangle
        0x00, 48, // C4 on, at tick 0
        0x11, 0x00, 0x08, 0x10, 0x00, 0xF0, // voice 1: triangle
        0x08, 2, // wait until tick 2
        0x01, 55, // voice 1: G4
        0x08, 1, // tick 3
        0x04, // voice 0 off, a tick before its next note
        0x08, 1, // tick 4
        0x00, 52, // voice 0: E4
        0x08, 1, // tick 5
        0x04, 0x05, // both off
        0x08, 1, // tick 6, the end
        0x24,
    }, bytes);
}
```

The expected bytes are the diagram's, written out. If you ever change
the composer, this test says exactly which byte moved.

## Where the music lives

The tunes and the frequency table are built-in tables, like the star map
and the shape table. They get a region at the top of the program image,
and the program image ends below it:

**`src/map.zig`** (add below the comment on the built-in tables)

```zig
pub const music = Region{ .name = "music", .first = 0x5A00, .last = 0x5EFF }; // notes and tunes (tunes.zig)
```

**`src/map.zig`** (the program image now ends below the music)

```zig
const program = Region{ .name = "program image", .first = hw.program, .last = music.first - 1 };
```

**`src/map.zig`** (in `regions`, add below `program`)

```zig
    music,
```

Now the layout. `music` is every byte of the region: the frequency table
first, then each tune. `placed` says where each tune starts, so the
interpreter can find it:

**`src/tunes.zig`** (add above the tests)

```zig
// ---- where it all goes ------------------------------------------------

/// The tunes, by name.
pub const Song = enum(u8) { title, escape, over };

/// The music region: the frequency table, then each tune.
pub const music: []const u8 = blk: {
    var out: []const u8 = &.{};
    for (frequencies) |f| out = out ++ [_]u8{ @truncate(f), f >> 8 };
    for (std.enums.values(Song)) |s| out = out ++ @field(songs, @tagName(s)).bytes;
    if (out.len > map.music.last - map.music.first + 1) @compileError("the music doesn't fit its region");
    break :blk out;
};

/// Where note n's frequency is: two bytes, low byte first.
pub fn frequency(n: u8) u16 {
    return map.music.first + @as(u16, n) * 2;
}

/// Where each tune starts, and whether it plays again from the top.
pub const Placed = struct { at: u16, loops: bool };
pub const placed = blk: {
    var out: [std.enums.values(Song).len]Placed = undefined;
    var at: u16 = map.music.first + note_count * 2;
    for (std.enums.values(Song), 0..) |s, i| {
        const song = @field(songs, @tagName(s));
        out[i] = .{ .at = at, .loops = song.loops };
        at += song.bytes.len;
    }
    break :blk out;
};
```

`frequency(n)` is where note *n*'s register is, in Comet memory. Note
57's is `$5A72`. The interpreter will read it from there, two bytes,
like any other table.

## The Creep Waltz

Time to write some music. A tune's parts each get an **instrument**: a
waveform and an envelope, written as the struct fields from the
composer. Six will do for all our music:

**`src/tunes.zig`** (add above the tests)

```zig
// ---- the tunes ----------------------------------------------------------

/// Instruments for the tunes.
const lead: Instrument = .{ .wave = chip.pulse, .width = 0x600, .decay = 8, .sustain = 9, .release = 6 };
const chord: Instrument = .{ .wave = chip.triangle, .decay = 6, .sustain = 6, .release = 5 };
const bass: Instrument = .{ .wave = chip.triangle, .decay = 9, .sustain = 0, .release = 4 };
const brass: Instrument = .{ .wave = chip.sawtooth, .attack = 1, .decay = 7, .sustain = 10, .release = 5 };
const reed: Instrument = .{ .wave = chip.pulse, .width = 0x300, .attack = 2, .sustain = 8, .release = 6 };
const flute: Instrument = .{ .wave = chip.triangle, .attack = 3, .decay = 9, .sustain = 10, .release = 9 };
```

The `lead` is a narrow pulse that decays to a sustain a bit over half,
so long notes fade a little while held. The `bass` has no sustain at
all: every note is a pluck that dies away. The `flute` swells in slowly.

And the tunes. The title gets a waltz in A minor, three beats to the
bar, round and round. The escape gets a fanfare in A major. GAME OVER
gets four bars that fall to a low A.

:::type-in The tunes
**`src/tunes.zig`** (add above the tests: the tunes)

```zig
const songs = struct {
    /// "The Creep Waltz", for the title screen, round and round: A minor,
    /// three beats to the bar, a unit is half a beat, about 0.23 s.
    const title = .{ .loops = true, .bytes = compose(.{ .tempo = 0xB0, .unit = 8, .parts = &.{
        .{ .sound = lead, .notes =
        \\A4:2 C5:2 E5:2 | D#5:3 E5:1 F5:2 | E5:2 C5:2 A4:2 | B4:6
        \\A4:2 C5:2 E5:2 | G5:3 F5:1 E5:2 | D5:2 B4:2 G#4:2 | A4:6
        \\F5:2 E5:2 D5:2 | C5:3 B4:1 A4:2 | G#4:2 B4:2 D5:2 | E5:6
        \\A5:2 G5:2 E5:2 | F5:2 D#5:2 E5:2 | C5:2 B4:2 G#4:2 | A4:4 -:2
        },
        .{ .sound = chord, .notes =
        \\-:2 C4:2 E4:2 | -:2 D4:2 F4:2 | -:2 C4:2 E4:2 | -:2 G#3:2 B3:2
        \\-:2 C4:2 E4:2 | -:2 E4:2 G4:2 | -:2 G#3:2 D4:2 | -:2 C4:2 E4:2
        \\-:2 D4:2 F4:2 | -:2 C4:2 E4:2 | -:2 G#3:2 B3:2 | -:2 G#3:2 D4:2
        \\-:2 C4:2 E4:2 | -:2 D4:2 F4:2 | -:2 G#3:2 B3:2 | -:2 C4:2 -:2
        },
        .{ .sound = bass, .notes =
        \\A2:2 -:4 | D2:2 -:4 | A2:2 -:4 | E2:2 -:4
        \\A2:2 -:4 | C3:2 -:4 | E2:2 -:4 | A2:2 -:4
        \\D2:2 -:4 | A2:2 -:4 | E2:2 -:4 | E2:2 -:4
        \\A2:2 -:4 | D2:2 -:4 | E2:2 -:4 | A1:2 -:4
        },
    } }) };

    /// The escape: a fanfare in A major, once. A unit is a sixteenth.
    const escape = .{ .loops = false, .bytes = compose(.{ .tempo = 0xE0, .unit = 4, .parts = &.{
        .{ .sound = brass, .notes =
        \\A4:2 C#5:2 E5:2 A5:6 E5:2 A5:2 | B5:3 A5:1 G#5:2 B5:2 E6:8
        \\C#6:2 B5:2 A5:2 G#5:2 F#5:2 E5:2 D5:2 C#5:2 | B4:2 E5:2 G#5:2 B5:2 A5:8
        },
        .{ .sound = reed, .notes =
        \\C#4:16 | B3:8 E4:8 | A3:8 D4:8 | E4:8 C#4:8
        },
        .{ .sound = bass, .notes =
        \\A2:4 E2:4 A2:4 E2:4 | E2:4 B2:4 E2:4 B2:4 | F#2:4 C#3:4 D2:4 A2:4 | E2:4 E2:4 A2:8
        },
    } }) };

    /// GAME OVER: a slow fall in A minor, over in under four seconds.
    const over = .{ .loops = false, .bytes = compose(.{ .tempo = 0x80, .unit = 4, .parts = &.{
        .{ .sound = flute, .notes = "E5:3 D5:3 C5:3 B4:3 | A4:4 G#4:2 A4:6" },
        .{ .sound = chord, .notes = "C4:6 F4:6 | E4:6 C4:6" },
        .{ .sound = bass, .notes = "A2:6 D2:6 | E2:6 A1:6" },
    } }) };
};
```
:::

These are text, so read them like sheet music. In the waltz, each bar is
three beats and each beat is two units. The bass plays the first beat of
every bar and the chord voice plays the other two, the "oom-pah-pah" of
a waltz. The lead's `D#5:3 E5:1` is a dotted rhythm, a long note and a
quick one, the little shiver that makes it creepy.

The `tempo` and `unit` fields are about time, which needs a section of
its own. Build, test, and run the same as before:

```
zig build run -- --frames 150 --wav creep.wav --dump-every 50
```

```
ran 150 frames (142 calls to frame)
cycles: max 167512 (852%), avg 7836 (39%) of 19656
  bucket 0: max 44, avg 43
  bucket 1: max 167496, avg 7792
overruns: 0, loading pauses: 1
last frame: frames/frame_00149.ppm
sound: creep.wav, 3.00 seconds, loudest 33%
```

The same buzzy A. The music is in memory now, but nothing plays it yet.
That's the interpreter's job, and it has to keep time.

## Interrupts

Music has to keep time while the game does everything else. A beat that
comes late while a room is being drawn is a beat everyone hears.

Many programs of the era had a **main loop**: one long loop that read
the stick, moved things and drew, forever. It runs as fast as it can,
and a busy room makes it slower. So a main loop can't keep time by
itself.

Keeping time is what **interrupts** are for. An interrupt is a signal
from the hardware to the processor. When it comes, the processor stops
whatever it was doing, saves its place, and runs a short function called
the **interrupt handler**. When the handler returns, the processor picks
up where it left off. The program it interrupted never notices, except
that a little time went missing.

The Comet's video hardware sends an interrupt every time the beam gets
back to the top of the screen: the **frame interrupt**. That's 50 times a
second, exactly 20 milliseconds apart, however busy the game is. And
since Chapter 1, our `frame` has been its handler. The machine calls
`frame` when the beam reaches the top. There's no main loop at all. Our
whole game runs inside the handler, and between frames the processor
waits for the next interrupt.

:::diagram ch10-interrupt
:::

That's why everything in this game has kept time without trying. A
mummy's step every few frames is a step every few times 20 ms.

There's one catch. While `frame` is still running, the processor can't
start it again. A handler that hasn't finished can't be interrupted by
its own interrupt. So a frame that runs long, like a loading pause,
swallows the slots it covers, and the next `frame` starts at the next
slot after it ends. The music stops moving for that long. The chip keeps
playing the registers it last read, so a held note holds, and the tune
picks up where it was when the pause ends. A loading pause is a blank
screen anyway, and a held note over it sounds deliberate.

## Fixed-rate timing

So the frame interrupt gives us a clock, 50 times a second. But the
waltz wants about 34 ticks a second, and the effects about 46. How do
you get 34 out of 50?

The answer is a fraction, kept in a byte. Each frame, add the **tempo**
to a byte called the **beat**. The beat wraps around past 255, and each
time it wraps, that's a tick:

:::diagram ch10-beat
:::

The tempo is how much of a tick each frame is, in 256ths. A tempo of
128 (`$80`) is half a tick per frame, so 25 ticks a second. `$B0` is 176
of 256, so 34.375. In general it's 50 × tempo / 256 ticks a second. The
ticks come on some frames and not others, but they never drift. After
256 frames, there have been exactly `tempo` ticks.

The same trick works for any rate that doesn't divide 50, like a
monster that moves 1.3 pixels a frame. In 1984, the music had a
separate timer of its own. We have one interrupt and a byte.

That makes each tune's lengths easy to work out. The waltz's unit is 8
ticks at `$B0`, about 0.23 seconds, and its 16 bars are 768 ticks, about
22.3 seconds. The fanfare's 256 ticks at `$E0` take 5.85 seconds.

## The driver

The interpreter, with its timing, is the **sound driver**. It needs a few
bytes to remember where it's got to between frames:

**`src/map.zig`** (add above the text region)

```zig
/// The sound driver: where it's got to in the music or the sound effect
/// it's playing, and its timing (sound.zig).
pub const sound = Region{ .name = "sound", .first = 0x021B, .last = 0x0225 };
pub const sound_at = sound.first + 0; // two bytes: the next command, or 0 for silence
pub const sound_loop = sound.first + 2; // two bytes: where the tune starts again at its end, or 0
pub const sound_wait = sound.first + 4; // ticks to go before the next command
pub const sound_tempo = sound.first + 5; // added to the beat every frame
pub const sound_beat = sound.first + 6; // a tick each time this goes past 255
pub const sound_playing = sound.first + 7; // what's playing: an effect, a tune, or nothing
pub const sound_transpose = sound.first + 8; // three bytes: added to each voice's notes
```

**`src/map.zig`** (in `regions`, add below `players`)

```zig
    sound,
```

`sound_at` is the interpreter's own program counter: the address of the
next command. `sound_tempo` and `sound_beat` are the fraction from the
last section.

And here's the driver:

**`src/sound.zig`** (add at the end)

```zig
/// What `map.sound_playing` says: an effect's number, or one of these.
pub const tune: u8 = 0xFE;
pub const nothing: u8 = 0xFF;

/// At power-on: the tunes and the frequency table into the music region,
/// and nothing playing.
pub fn start(m: *Machine) void {
    m.load(map.music.first, tunes.music);
    m.poke(map.sound_playing, nothing);
}

/// Every frame: the beat goes on, and on each tick, the commands that are
/// due, up to the next `wait`.
pub fn step(m: *Machine) void {
    const at = m.peek16(map.sound_at);
    m.work(6); // the test
    if (at == 0) return; // silence
    const beat = @addWithOverflow(m.peek(map.sound_beat), m.peek(map.sound_tempo));
    m.poke(map.sound_beat, beat[0]);
    m.work(6); // the add and the test
    if (beat[1] == 0) return; // no tick this frame
    const wait = m.peek(map.sound_wait);
    if (wait > 1) {
        m.poke(map.sound_wait, wait - 1);
        return;
    }
    run(m, at);
}

/// Read commands from `from` and do them, until a `wait` or the end.
fn run(m: *Machine, from: u16) void {
    var at = from;
    while (true) {
        const first = m.peek(at);
        const op: Op = @enumFromInt(first >> 2);
        const v: u2 = @truncate(first);
        const voice = hw.voice(v);
        m.work(16); // the shift, the mask and the jump
        switch (op) {
            .note_on => {
                const n = m.peek(at + 1) +% m.peek(map.sound_transpose + v);
                if (n < tunes.note_count) m.poke16(voice + chip.freq_lo, m.peek16(tunes.frequency(n)));
                m.poke(voice + chip.control, m.peek(voice + chip.control) | chip.gate);
            },
            .note_off => m.poke(voice + chip.control, m.peek(voice + chip.control) & ~chip.gate),
            .wait => {
                m.poke(map.sound_wait, m.peek(at + 1));
                m.poke16(map.sound_at, at + 2);
                return;
            },
            .instrument => {
                m.copy(voice + chip.pulse_lo, at + 1, 2);
                const gate = m.peek(voice + chip.control) & chip.gate; // a new waveform, the gate as it was
                m.poke(voice + chip.control, m.peek(at + 3) | gate);
                m.copy(voice + chip.attack_decay, at + 4, 2);
            },
            .transpose => m.poke(map.sound_transpose + v, m.peek(at + 1)),
            .volume => m.poke(hw.sound_volume, m.peek(at + 1)),
            .tempo => m.poke(map.sound_tempo, m.peek(at + 1)),
            .long_wait, .filter => {},
            else => {
                const loop = m.peek16(map.sound_loop);
                if (loop != 0) {
                    at = loop; // a tune that plays again from the top
                    continue;
                }
                m.poke16(map.sound_at, 0);
                m.poke(map.sound_playing, nothing);
                return;
            },
        }
        at += lengths[@intFromEnum(op)];
    }
}

/// Every voice's gate and waveform off, at once.
fn silence(m: *Machine) void {
    for (0..3) |v| m.poke(hw.voice(@intCast(v)) + chip.control, 0);
}

/// Start the stream at `at`: silence, full volume, nothing transposed,
/// and its first commands now.
fn begin(m: *Machine, at: u16, loop: u16, what: u8) void {
    silence(m);
    m.poke(hw.sound_volume, 15);
    m.fill(map.sound_transpose, 3, 0);
    m.poke(map.sound_wait, 0);
    m.poke(map.sound_beat, 0);
    m.poke16(map.sound_loop, loop);
    m.poke(map.sound_playing, what);
    run(m, at);
}

/// Play a tune. Music always plays: whatever was playing stops.
pub fn music(m: *Machine, song: tunes.Song) void {
    const s = tunes.placed[@intFromEnum(song)];
    begin(m, s.at, if (s.loops) s.at else 0, tune);
}

/// Stop whatever's playing.
pub fn stop(m: *Machine) void {
    silence(m);
    m.poke16(map.sound_at, 0);
    m.poke(map.sound_playing, nothing);
}
```

`step` runs every frame. `@addWithOverflow` adds two bytes and gives
back the 8-bit sum and the carry, as a pair: the carry is the tick. On
a tick, an unfinished `wait` counts down. Otherwise it's time for
`run`.

`run` is the interpreter itself. Its loop reads a command's first byte,
splits it into the command and the voice, and does it, until it reaches
a `wait` or the end. A `wait` stores where it got to and how long to
wait, and returns.

Playing a note is three steps: look up the frequency in the table at
`$5A00`, copy it into the voice's frequency registers, and set the gate.
The `instrument` command keeps the gate as it was, so changing a voice's
sound never cuts off its note.

`begin` starts a stream. It silences all three voices, turns the volume
up, and runs the stream's first commands at once, before returning. A
sound starts in the frame that asks for it. `music` plays a tune from
the top, and `stop` silences everything.

At the end of a stream, a tune that loops jumps back to its start and
keeps reading, in the same tick.

The tests use a little game of their own, `Lab`, that boots the driver
and steps it, and nothing else:

**`src/sound.zig`** (add at the end)

```zig
// ---- tests ---------------------------------------------------------------

const Lab = struct {
    pub fn boot(m: *Machine) void {
        start(m);
    }
    pub fn frame(m: *Machine) void {
        step(m);
    }
};

fn powerOn() !*Machine {
    const m = try std.testing.allocator.create(Machine);
    m.boot(Lab);
    return m;
}

fn frames(m: *Machine, n: usize) void {
    for (0..n) |_| _ = m.runFrame(Lab);
}

test "the tempo: a tick on some frames and not others" {
    const m = try powerOn();
    defer std.testing.allocator.destroy(m);
    music(m, .over); // tempo $80: a tick every other frame
    var ticks: usize = 0;
    for (0..100) |_| {
        const before = m.ram[map.sound_beat];
        frames(m, 1);
        if (m.ram[map.sound_beat] < before) ticks += 1;
    }
    try std.testing.expectEqual(50, ticks);
}

test "the title tune plays round and round" {
    const m = try powerOn();
    defer std.testing.allocator.destroy(m);
    music(m, .title);
    const top = tunes.placed[@intFromEnum(tunes.Song.title)].at;
    var laps: usize = 0;
    var last = m.peek16(map.sound_at);
    for (0..50 * 60) |_| { // a minute
        frames(m, 1);
        const now = m.peek16(map.sound_at);
        if (now < last) laps += 1;
        try std.testing.expect(now > top);
        last = now;
    }
    try std.testing.expect(laps >= 2);
    try std.testing.expectEqual(tune, m.ram[map.sound_playing]);
}
```

The tempo test counts beat wrap-arounds over 100 frames at `$80`: 50.
The waltz test plays a minute of title music and checks that the driver
came back round to the top at least twice and never wandered out of the
tune.

## Keeping time in `frame`

In `main.zig`, import the driver beside the tunes:

**`src/main.zig`** (add above the `tunes` import)

```zig
const sound = @import("sound.zig");
```

give the sound its own bucket on the work meter:

**`src/main.zig`** (add below `bucket_objects`)

```zig
const bucket_sound = 5;
```

and load the music at power-on:

**`src/main.zig`** (in `boot`, add at the end)

```zig
    sound.start(m);
```

Now the important part. Where in `frame` does `step` go? At the very
top, before anything else:

**`src/main.zig`** (at the top of `frame`)

```zig
    // The music keeps time first: whatever the frame goes on to do, the
    // next commands are due now.
    m.bucket(bucket_sound);
    sound.step(m);
    m.bucket(0);
```

Two reasons. First, every prong of `frame`'s switch ends in its own
way, and some finish early. At the top, nothing can skip the step: it
runs once every frame, always. Second, it keeps the order of things
simple. Anything later in the frame may start a sound, and `begin` runs
its first commands at once. That sound's first tick then comes on the
next frame's step, never in the same frame it started.

The experiment's work is done. The title starts the waltz instead:

**`src/main.zig`** (in the `.draw_title` prong, replace the experiment)

```zig
            sound.music(m, .title);
```

And when you press fire for a game, the music stops before the castle
is copied:

**`src/main.zig`** (in the `.title` prong, add below the loading pause)

```zig
                sound.stop(m);
```

Build, test, and run the title for 24 seconds:

```
zig build run -- --frames 1200 --wav creep.wav --dump-every 100
```

```
ran 1200 frames (1192 calls to frame)
cycles: max 167926 (854%), avg 6886 (35%) of 19656
  bucket 0: max 44, avg 43
  bucket 1: max 167896, avg 6795
  bucket 5: max 424, avg 46
overruns: 0, loading pauses: 1
last frame: frames/frame_01199.ppm
sound: creep.wav, 24.00 seconds, loudest 75%
```

<audio controls preload="none" src="images/10-waltz.mp3"></audio>

That's the Creep Waltz, once round and into its second time. Here are its
first four bars as a picture: time goes left to right and pitch goes up.
The bright dashes are notes. The lowest are the bass, once a bar, with
the chord voice's pairs above them and the lead's melody on top. The
fainter copies higher up are each note's **harmonics**, the extra
frequencies that make a sawtooth or a pulse sound different from a
plain tone.

![A picture of sound: four bars of the waltz, time left to right and pitch upwards on a scale from A1 to A6. The bass notes are short bright marks once a bar near A2, the chord voice's pairs of notes sit around A3 to A4, and the lead's melody moves above them, with fainter copies of each note stacked higher up](images/10-waltz.png)

Bucket 5 is the driver: a few dozen cycles on most frames, and a few
hundred on a frame that starts three notes. A sliver of the frame.

## Sound effects

Now the castle. A sound effect is a short tune, one or two voices a few
ticks long, so the effects use the same driver. Playing an effect points
`sound_at` at its stream, and the driver doesn't know the difference.
One interpreter: whoever owns `sound_at`, its stream pointer, is
playing.

So what happens when a sound is asked for while another is playing? Our
rules, which are 1984's:

- **Music always plays.** `music` takes over the driver, whatever was
  playing.
- **An effect never interrupts anything.** If the driver is busy, with a
  tune or with another effect, the new effect is simply dropped.
- **First come, first served.** An effect that's started plays to the
  end.

Music plays on the screens between rooms and effects play in the
rooms, so they never compete. Between effects, whatever started first
wins. Effects are a few ticks long, so a dropped one is soon followed
by the next.

The effects get a region of their own in free memory, rather than a
place among the built-in tables at the top of the program image. You'll
see why in a moment:

**`src/map.zig`** (add above the built-in tables)

```zig
/// The sound effects, copied here at boot so the game can change a note
/// in one before it plays it (tunes.zig).
pub const effects = Region{ .name = "sound effects", .first = 0x0380, .last = 0x04FF };
```

**`src/map.zig`** (in `regions`, add below `text`)

```zig
    effects,
```

Thirteen effects, numbered as in 1984. `effect_at` says where each one
starts, and checks something about each effect while it's at it:

**`src/tunes.zig`** (add above the tunes' heading)

```zig
/// The sound effects, numbered as in 1984.
pub const Effect = enum(u8) {
    laser,
    trapdoor,
    forcefield,
    door,
    teleport,
    teleport_change,
    lightning,
    frankenstein,
    flash,
    map_close,
    conveyor,
    mummy,
    key,
};

/// The effects region: every effect, one after the other.
pub const effects: []const u8 = blk: {
    var out: []const u8 = &.{};
    for (std.enums.values(Effect)) |e| out = out ++ @field(sounds, @tagName(e));
    if (out.len > map.effects.last - map.effects.first + 1) @compileError("the effects don't fit their region");
    break :blk out;
};

/// Where each effect starts.
pub const effect_at = blk: {
    var out: [std.enums.values(Effect).len]u16 = undefined;
    var at: u16 = map.effects.first;
    for (std.enums.values(Effect), 0..) |e, i| {
        out[i] = at;
        const bytes = @field(sounds, @tagName(e));
        if (bytes[pitch - 1] != sound.command(.note_on, 0)) @compileError("effect " ++ @tagName(e) ++ " must start with a note on voice 0");
        at += bytes.len;
    }
    break :blk out;
};

/// The byte of an effect that holds its first note: change it, and the
/// effect plays higher or lower.
pub const pitch = 9;
```

The check is there for `pitch`. Every effect starts with a tempo
command (2 bytes), voice 0's instrument (6 bytes), then voice 0's first
note, so the note's number is always byte 9. Change byte 9, and the
effect plays higher or lower. That's why the effects live in RAM: the
game patches the note before it plays the effect, and one effect makes
many sounds.

Now the effects themselves. They play at their own tempo, `$EA`, about
46 ticks a second, so their lengths are in single ticks, about 22 ms
each:

**`src/tunes.zig`** (add below the tunes' heading)

```zig
/// The sound effects play at this tempo: 234/256 of a tick a frame, about
/// 46 ticks a second.
pub const effect_tempo = 0xEA;

/// A sound effect: one or two voices, lengths in ticks.
fn effect(comptime parts: []const Part) []const u8 {
    return compose(.{ .tempo = effect_tempo, .unit = 1, .parts = parts });
}

const sounds = struct {
    const laser = effect(&.{.{ .sound = .{ .wave = chip.sawtooth, .release = 4 }, .notes = "C6:2 C5:2" }});
    const trapdoor = effect(&.{.{ .sound = .{ .wave = chip.sawtooth, .release = 3 }, .notes = "C2:3" }});
    const forcefield = effect(&.{.{ .sound = .{ .wave = chip.triangle, .release = 2 }, .notes = "C5:2" }});
    const door = effect(&.{.{ .sound = .{ .wave = chip.pulse, .width = 0x200, .release = 3 }, .notes = "C3:2" }});
    const teleport = effect(&.{
        .{ .sound = .{ .wave = chip.triangle | chip.ring, .release = 6 }, .notes = "C5:3" },
        .{ .sound = .{ .wave = 0 }, .notes = "-:2" },
        .{ .sound = .{ .wave = 0 }, .notes = "E6:3" }, // no waveform: it only rings voice 0
    });
    const teleport_change = effect(&.{.{ .sound = .{ .wave = chip.pulse, .attack = 1, .release = 5 }, .notes = "C5:5" }});
    const lightning = effect(&.{.{ .sound = .{ .wave = chip.noise, .release = 3 }, .notes = "C5:2" }});
    const frankenstein = effect(&.{
        .{ .sound = .{ .wave = chip.sawtooth, .attack = 4, .decay = 6, .sustain = 8, .release = 8 }, .notes = "A1:12" },
        .{ .sound = .{ .wave = chip.noise, .attack = 4, .sustain = 6, .release = 7 }, .notes = "D2:12" },
    });
    const flash = effect(&.{.{ .sound = .{ .wave = chip.triangle, .release = 4 }, .notes = "C5:2" }});
    const map_close = effect(&.{.{ .sound = .{ .wave = chip.triangle, .release = 6 }, .notes = "A5:3 E6:4" }});
    const conveyor = effect(&.{.{ .sound = .{ .wave = chip.noise, .release = 3 }, .notes = "F#2:2 D2:2" }});
    const mummy = effect(&.{.{ .sound = .{ .wave = chip.noise, .release = 5 }, .notes = "C2:3" }});
    const key = effect(&.{.{ .sound = .{ .wave = chip.pulse, .release = 7 }, .notes = "C6:3 G6:3 C7:4" }});
};
```

The teleport uses the **ring** bit: voice 2's wave flips voice 0's
triangle over, a metallic clang. Voice 2 has no waveform of its own, so
it's only there to ring voice 0.

The driver loads the effects at power-on:

**`src/sound.zig`** (replace `start`)

```zig
/// At power-on: the tunes and the frequency table into the music region,
/// the effects into theirs, and nothing playing (0 would be the laser).
pub fn start(m: *Machine) void {
    m.load(map.music.first, tunes.music);
    m.load(map.effects.first, tunes.effects);
    m.poke(map.sound_playing, nothing);
}
```

and gets two new ways to play one:

**`src/sound.zig`** (add below `music`)

```zig
/// Play a sound effect, if nothing else is playing. An effect never
/// interrupts music, or another effect: it's dropped.
pub fn effect(m: *Machine, e: tunes.Effect) void {
    m.work(6); // the test
    if (m.peek(map.sound_playing) != nothing) return;
    begin(m, tunes.effect_at[@intFromEnum(e)], 0, @intFromEnum(e));
}

/// Play a sound effect with its first note changed to `note`.
pub fn effectAt(m: *Machine, e: tunes.Effect, note: u8) void {
    m.work(6); // the test
    if (m.peek(map.sound_playing) != nothing) return;
    const at = tunes.effect_at[@intFromEnum(e)];
    m.poke(at + tunes.pitch, note);
    begin(m, at, 0, @intFromEnum(e));
}
```

The test `if (m.peek(map.sound_playing) != nothing) return;` is the
whole of our interrupt rules: an effect plays only into silence. That's
why `start` sets `sound_playing` to `nothing` (`$FF`). Power-on memory
is 0, and effect 0 is the laser, so without that line the driver would
think a laser was playing forever and drop every effect.

Two more tests: a note's registers and timing, tick by tick,

**`src/sound.zig`** (add above the tempo test)

```zig
test "a note: its frequency, its instrument, and the gate" {
    const m = try powerOn();
    defer std.testing.allocator.destroy(m);
    effect(m, .forcefield); // a triangle, C5 for 2 ticks
    const v0 = hw.voice(0);
    try std.testing.expectEqual(tunes.frequencies[tunes.note("C5")], m.peek16(v0 + chip.freq_lo));
    try std.testing.expectEqual(chip.triangle | chip.gate, m.ram[v0 + chip.control]);
    try std.testing.expectEqual(15, m.ram[hw.sound_volume]);
    try std.testing.expectEqual(@intFromEnum(tunes.Effect.forcefield), m.ram[map.sound_playing]);
    frames(m, 1); // 234 of 256: no tick yet
    try std.testing.expectEqual(chip.triangle | chip.gate, m.ram[v0 + chip.control]);
    frames(m, 1); // 468: tick 1, and the gate off, a tick before the end
    try std.testing.expectEqual(chip.triangle, m.ram[v0 + chip.control]);
    frames(m, 1); // tick 2: the end
    try std.testing.expectEqual(nothing, m.ram[map.sound_playing]);
    try std.testing.expectEqual(0, m.peek16(map.sound_at));
}
```

and the rules:

**`src/sound.zig`** (add above the last test)

```zig
test "what may interrupt what" {
    const m = try powerOn();
    defer std.testing.allocator.destroy(m);
    effect(m, .door);
    effect(m, .key); // the door's still playing: dropped
    try std.testing.expectEqual(@intFromEnum(tunes.Effect.door), m.ram[map.sound_playing]);
    music(m, .title); // music always plays
    try std.testing.expectEqual(tune, m.ram[map.sound_playing]);
    effect(m, .key); // and an effect never interrupts it
    try std.testing.expectEqual(tune, m.ram[map.sound_playing]);
    stop(m);
    effectAt(m, .door, tunes.note("G3"));
    try std.testing.expectEqual(tunes.frequencies[tunes.note("G3")], m.peek16(hw.voice(0) + chip.freq_lo));
}
```

## The map's chime

The first effect to wire up is the easiest. When everyone is ready on
the castle map, it closes with a two-note chime:

**`src/chart.zig`** (add below the `game` import)

```zig
const sound = @import("sound.zig");
```

**`src/chart.zig`** (at the end of `wait`, replace the `return`)

```zig
    if (c.ready[0] == 0 or c.ready[1] == 0) return false;
    sound.effect(m, .map_close);
    return true;
```

And a test for the title, with three helpers that every sound test from
here on will use. `hear` holds the stick until a given effect starts.
`pitchNow` reads voice 0's frequency register. `song` works out which
tune is playing from where `sound_at` points.

**`src/main.zig`** (add at the end)

```zig
/// Hold `stick` for up to `frames` frames, until sound effect `e` starts.
/// True if it did.
fn hear(m: *Machine, e: tunes.Effect, stick: u8, frames: usize) bool {
    for (0..frames) |_| {
        hold(m, stick, 1);
        if (m.ram[map.sound_playing] == @intFromEnum(e)) return true;
    }
    return false;
}

/// The note voice 0 is playing: its frequency register.
fn pitchNow(m: *Machine) u16 {
    return std.mem.readInt(u16, m.ram[hw.voice(0)..][0..2], .little);
}

/// Which tune the driver is in the middle of, if any.
fn song(m: *Machine) ?tunes.Song {
    if (m.ram[map.sound_playing] != sound.tune) return null;
    const at = std.mem.readInt(u16, m.ram[map.sound_at..][0..2], .little);
    var found: ?tunes.Song = null;
    for (tunes.placed, 0..) |p, i| {
        if (at >= p.at) found = @enumFromInt(i);
    }
    return found;
}

test "the title plays its tune on three voices, a game stops it, and the map closes with a chime" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(tunes.Song.title, song(m).?);
    var gated: u8 = 0;
    for (0..200) |_| {
        hold(m, 0, 1);
        for (0..3) |v| {
            if (m.ram[hw.voice(@intCast(v)) + machine.sound.control] & machine.sound.gate != 0) gated |= @as(u8, 1) << @intCast(v);
        }
    }
    try std.testing.expectEqual(0b111, gated); // all three voices have played
    var samples: [882]f32 = undefined;
    m.listen(&samples, 44100); // and the speaker has something to say
    var loudest: f32 = 0;
    for (samples) |s| loudest = @max(loudest, @abs(s));
    try std.testing.expect(loudest > 0.05);
    hold(m, machine.joy.fire, 1);
    try std.testing.expectEqual(sound.nothing, m.ram[map.sound_playing]);
    for (0..3) |v| try std.testing.expectEqual(0, m.ram[hw.voice(@intCast(v)) + machine.sound.control]);
    hold(m, 0, 7); // the map
    try std.testing.expect(hear(m, .map_close, machine.joy.fire, 2));
}
```

It checks the waltz on all three voices, the speaker (`m.listen` asks
the chip for a frame's worth of sound), fire to stop it, and the
chime.

```
zig build run -- --frames 400 --press 300:f:3 --press 330:f:3 --wav creep.wav --dump-every 10
```

```
ran 400 frames (374 calls to frame)
cycles: max 236574 (1203%), avg 6786 (34%) of 19656
  bucket 0: max 37362, avg 158
  bucket 1: max 235218, avg 6530
  bucket 2: max 1308, avg 24
  bucket 3: max 406, avg 30
  bucket 4: max 36, avg 2
  bucket 5: max 176, avg 40
overruns: 0, loading pauses: 4
last frame: frames/frame_00399.ppm
sound: creep.wav, 8.00 seconds, loudest 72%
```

Fire at frame 300 cuts the waltz off, the map comes up, and fire at
frame 330 closes it with a chime:

<audio controls preload="none" src="images/10-chime.mp3"></audio>

## A voice for every machine

Now every machine in the castle. Each file that plays a sound imports
the driver, and the ones that choose a note import the tunes too. In
`doors.zig`:

**`src/doors.zig`** (add at the end of the imports)

```zig
const sound = @import("sound.zig");
const tunes = @import("tunes.zig");
```

Add the same lines at the end of the imports in each of these files:

| File | Add |
|---|---|
| `actors.zig`, `forcefields.zig`, `lightning.zig`, `mummy.zig`, `trapdoors.zig` | `sound` and `tunes` |
| `transmitter.zig` | `dice`, `sound` and `tunes` |
| `conveyors.zig`, `escape.zig`, `frankenstein.zig`, `game.zig`, `guns.zig`, `locks.zig` | `sound` |

Then the sounds, one line each. The door creaks a little higher for each
row it opens:

**`src/doors.zig`** (in `open`, below the `wipe`)

```zig
    sound.effectAt(m, .door, tunes.note("C3") + room.door_panel_height - o.step); // higher each row
```

`door_panel_height - o.step` counts up as the door opens, so the creak
climbs two octaves, to C5. A bell has no sound of its own: you hear the
door it opens.

A dying explorer beeps each time he flashes white, a little lower each
time, from C4 plus 28 down to C4:

**`src/actors.zig`** (in `flicker`, below `a.flashes -= 1;`)

```zig
        sound.effectAt(m, .flash, tunes.note("C4") + a.flashes * 4); // lower each flash
```

Lightning's switch crackles, high when it turns the lightning on, low
when it turns it off:

**`src/lightning.zig`** (at the end of `pull`)

```zig
    sound.effectAt(m, .lightning, if (on) tunes.note("C6") else tunes.note("C4"));
```

The forcefield's button buzzes for as long as you hold it. Each time
`press` sees fire held, it plays a short C3, and a new one starts as soon
as the last one ends:

**`src/forcefields.zig`** (in `press`, below the `holding` test)

```zig
    sound.effectAt(m, .forcefield, tunes.note("C3"));
```

When you let go, the gauge counts down, and each tick of the countdown
plays a blip, higher each time, like a clock running out:

**`src/forcefields.zig`** (in `count`, below the `gauge` line)

```zig
    sound.effectAt(m, .forcefield, tunes.note("C4") + (ticks - o.step) * 2); // higher each tick
```

The trapdoor's switch plays a rasp as the trapdoor swings, a little
higher for each picture:

**`src/trapdoors.zig`** (at the end of `swing`)

```zig
    sound.effectAt(m, .trapdoor, tunes.note("C2") + next * 3);
```

A conveyor's control box clunks when you switch it:

**`src/conveyors.zig`** (in `run`, below `arrows(m, c);`)

```zig
        sound.effect(m, .conveyor);
```

The transmitter plays two sounds. Moving the lamp to the next pad is a
note, higher for each pad. Sending an explorer is a warble: every other
step of the flash, a random note from the dice:

**`src/transmitter.zig`** (at the end of `use`)

```zig
    sound.effectAt(m, .teleport_change, tunes.note("C4") + t.target * 2);
```

**`src/transmitter.zig`** (in `flash`, below `o.step -= 1;`)

```zig
    if (o.step & 1 == 0) sound.effectAt(m, .teleport, tunes.note("C4") + (dice.roll(m) & 0x1F)); // a warble
```

Picking up a key plays its three-note chime. Opening a lock needs no
sound of its own: its door creaks open.

**`src/locks.zig`** (in `take`, below the `unplace`)

```zig
    sound.effect(m, .key);
```

A gun's shot zaps:

**`src/guns.zig`** (in `shoot`, below the `setFrame`)

```zig
    sound.effect(m, .laser);
```

A mummy climbing out of his tomb grinds, higher for each step up:

**`src/mummy.zig`** (in `walk`, below the rising `setFrame`)

```zig
        sound.effectAt(m, .mummy, tunes.note("C2") + a.walk * 3); // higher as he climbs
```

Frankenstein growls when he wakes:

**`src/frankenstein.zig`** (in `turn`, below `f.state.awake = true;`)

```zig
        sound.effect(m, .frankenstein);
```

The escape plays its fanfare as soon as the time is printed:

**`src/escape.zig`** (in `draw`, below the clock)

```zig
    sound.music(m, .escape);
```

And GAME OVER plays its tune:

**`src/game.zig`** (at the end of `drawOver`)

```zig
    sound.music(m, .over);
```

:::inside-the-disk Whose notes?
1984 plays its thirteen effects from the same fourteen places (the
forcefield's from two), and patches the note the same way before
playing it. Its door climbs as ours does, its
dying explorer's beeps fall, and its transmitter warbles at random. Its
note numbers and formulas are its own, and so are its sounds: ours are
new, and our gun's zap is the same for every gun, where 1984's depends
on which gun fired. The map's chime is 1984's idea.

1984 has no sound for a bell, the map's blinking arrow, a lock or an
escape, and its music plays only on the title. The fanfare and GAME
OVER's fall are ours, and so is every note of the waltz.
:::

## Every machine, through the stick

Four tests play the sounds through the stick, as a player would. The
door creaks higher, row by row, ending at least two octaves up:

**`src/main.zig`** (add at the end)

```zig
test "a door creaks higher as it opens" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0); // the Gatehouse
    hold(m, machine.joy.left, 34); // to the bell
    try std.testing.expect(hear(m, .door, machine.joy.fire, 8));
    var first = pitchNow(m);
    const lowest = first;
    for (0..60) |_| {
        hold(m, 0, 1);
        if (m.ram[map.sound_playing] != @intFromEnum(tunes.Effect.door)) continue;
        try std.testing.expect(pitchNow(m) >= first);
        first = pitchNow(m);
    }
    try std.testing.expect(first > lowest * 3); // two octaves up: four times the frequency, or near it
}
```

Every other machine, room by room through the Training Castle, from
Lightning to Frankenstein, hearing each one:

:::type-in Every machine's voice
**`src/main.zig`** (add at the end)

```zig
test "every machine in the castle has a voice, through the stick" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 4); // Lightning: up to the switch, and pull it down
    while (feet(m) < 57) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.up, 200);
    while (feet(m) > 34) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .lightning, machine.joy.down, 4));

    inRoom(m, 5); // Forcefields: the button, then the countdown's first tick
    while (explorer(m).box.x > 122) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .forcefield, machine.joy.fire, 4));
    hold(m, 0, 10);
    const press = pitchNow(m);
    try std.testing.expect(hear(m, .forcefield, 0, 70));
    try std.testing.expect(pitchNow(m) > press);

    inRoom(m, 6); // Trapdoors: the switch on the way to the bell
    try std.testing.expect(hear(m, .trapdoor, machine.joy.left, 300));

    inRoom(m, 7); // Conveyors: the control box
    while (feet(m) > 101) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .conveyor, machine.joy.fire, 4));

    inRoom(m, 8); // the Transmitter: move the lamp, then send him
    while (explorer(m).box.x > 116) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .teleport_change, machine.joy.up, 40));
    hold(m, 0, 10);
    try std.testing.expect(hear(m, .teleport, machine.joy.fire, 8));

    inRoom(m, 9); // Keys and Locks: up and along to the key
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.up, 200);
    hold(m, machine.joy.right, 200);
    try std.testing.expect(hear(m, .key, machine.joy.fire, 4));

    inRoom(m, 10); // Ray Guns: past the muzzle
    try std.testing.expect(hear(m, .laser, machine.joy.right, 200));

    inRoom(m, 11); // the Mummy: past the ankh, and he climbs out
    while (feet(m) < 56) hold(m, machine.joy.right, 2);
    try std.testing.expect(hear(m, .mummy, 0, 60));

    inRoom(m, 12); // Frankenstein: down the pole to his floor
    while (feet(m) < 89) hold(m, machine.joy.right, 2);
    try std.testing.expect(hear(m, .frankenstein, machine.joy.down, 80));
}
```
:::

A death, in the Lightning room. Walk along the floor into the lightning,
and the flash's beeps fall:

**`src/main.zig`** (add at the end)

```zig
test "a death flashes with a beep that falls each time" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 4); // Lightning: along the floor, into it
    try std.testing.expect(hear(m, .flash, machine.joy.right, 300));
    var last = pitchNow(m);
    var beeps: usize = 1;
    for (0..40) |_| {
        hold(m, 0, 1);
        if (m.ram[map.sound_playing] != @intFromEnum(tunes.Effect.flash) or pitchNow(m) == last) continue;
        try std.testing.expect(pitchNow(m) < last);
        last = pitchNow(m);
        beeps += 1;
    }
    try std.testing.expect(beeps >= 4);
}
```

And the screens between rooms: the fanfare, GAME OVER's fall, and the
waltz again on the title:

**`src/main.zig`** (add at the end)

```zig
test "a fanfare for the escape, a slow fall for GAME OVER, and the waltz again" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 19); // the Way Out
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.escape)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.escape, song(m).?);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.over, song(m).?);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.title)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.title, song(m).?);
}
```

Every machine in the castle has a voice now.

:::power-up The Bytecode Power-Up
When a thing is mostly data with a little behaviour, like a tune, write
a tiny interpreter and store the data as commands. Five bytes of "play
C4 on voice 1, wait 8" replace thousands of bytes of recorded sound.
Give each command a fixed length, so the interpreter always knows where
the next one starts.
:::

:::power-up The Fraction Power-Up
To do something at a rate the clock doesn't divide, add a fraction to a
byte every frame (or whatever the clock gives you), and act on the
carry. The rate is exact over time, with
no division and no drift. The byte's size sets how fine the fraction
can be.
:::

:::byte-budget Chapter 10
**Memory.** The music region, `$5A00`–`$5EFF`, holds 1,029 of its 1,280
bytes: the frequency table (190 bytes), the waltz (482), the fanfare
(263) and GAME OVER (94). The program image now ends at `$59FF`. The
sound effects, `$0380`–`$04FF`, are 267 of 384 bytes, 16 to 31 bytes
each. The driver's state is 11 bytes at `$021B`–`$0225`. The 22-second
waltz is 482 bytes. Recorded at 44,100 samples a second, one byte each,
it would be nearly a megabyte.

**Time.** Loading the music and effects at power-on is free. The
driver's step costs 14 cycles in silence and a few dozen on most
frames. A tick that starts three notes costs a few hundred; the most
in the Boss Battle run below is in its bucket 5 line. Starting a tune
costs about 420 cycles, and starting an effect about 250. An effect
that's dropped costs 10.
:::

:::game-over Common mistakes
- **"note 95 needs a frequency register of 66288".** The table stops at
  A#7: `note_count` is 95.
- **Silence.** The volume register is 0 at power-on: `begin` must poke
  `hw.sound_volume`. And `frame` must call `sound.step` every frame.
- **Notes run together, and two of the same note sound as one.** The
  composer's `gap` must be at least 1, so each gate goes off before the
  next note.
- **No sound effects at all in the castle.** The title's tune is still
  playing, and effects never interrupt music. The title must call
  `sound.stop` when a game starts.
- **No sound effects even before any music.** `start` must set
  `sound_playing` to `nothing`. A 0 there means the laser is playing.
- **One voice drifts behind the others.** A length in that part is
  wrong, and every note after it moves too. Count each bar's units.
- **Every door creaks at the same note.** `effectAt` must poke the note
  into byte `tunes.pitch` of the effect before `begin` runs it.
:::

:::boss-battle The whole castle, with sound
From your project folder:

```
zig build
zig build test
zig build run -- --frames 3780 --press 300:f:5@2 --press 320:f:3 --press 320:f:3@2 --key 340:N --key 355:N --key 370:N --key 385:N --key 400:N --key 415:N --key 430:N --key 445:N --key 460:N --key 475:N --key 490:N --key 505:N --key 520:N --key 535:N --key 550:N --key 565:N --key 580:N --key 595:N --press 625:l:52 --press 625:l:52@2 --press 677:u:60 --press 740:r:46 --press 786:f:400 --press 795:l:182@2 --press 977:f:4@2 --press 981:l:60@2 --press 1041:ur:4@2 --press 1190:l:46 --press 1236:d:100 --press 1336:l:250 --press 1590:ur:4 --press 1710:f:3 --press 1710:f:3@2 --press 1742:l:240 --press 1742:l:240@2 --press 1982:f:4 --press 1982:f:4@2 --press 1992:l:60 --press 1992:l:60@2 --press 2054:ur:4 --press 2054:ur:4@2 --dump-every 10 --wav creep.wav
```

This is Chapter 9's Boss Battle game for two, after 280 frames of the
waltz, with the sound saved. It prints:

```
ran 3780 frames (3523 calls to frame)
cycles: max 244072 (1241%), avg 3349 (17%) of 19656
  bucket 0: max 37370, avg 81
  bucket 1: max 241532, avg 2814
  bucket 2: max 2510, avg 147
  bucket 3: max 2618, avg 250
  bucket 4: max 2170, avg 20
  bucket 5: max 228, avg 34
overruns: 0, loading pauses: 28
last frame: frames/frame_03779.ppm
sound: creep.wav, 75.60 seconds, loudest 98%
```

Listen to `creep.wav`:

<audio controls preload="none" src="images/10-boss.mp3"></audio>

The waltz, then the map's chime. In Two's Company, player 1 holds the
forcefield's button: a steady buzz for eight seconds. Player 2 rings the
bell while it buzzes, and the door opens without a creak. The buzz had
the driver first, so the creak was dropped: first come, first served.
When player 1 lets go, the countdown blips eight times, climbing. Then
the map's chime again, the Way Out's door creaks, a fanfare plays for
each escape, GAME OVER falls to its low A, and the waltz starts again.

Then play it, with the sound on:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000> and click the screen. Every room has
something to hear.

**The castle has a voice!** Next chapter, the castles on the disk.
:::

:::warp-zone
The finished checkpoint is [`code/ch10/`](../code/ch10/), also as a
download, [`ch10.zip`](downloads/ch10.zip), which unzips into the same
`code/` folder as the others. It needs the new machine from
[`code/machine/`](../code/machine/). To start Chapter 11 from a
known-good game, replace your project with it:

```
cd code
rm -rf my-creep
cp -r ch10 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```
:::

:::bonus-stage
- **Priorities.** Give each effect a priority, and let a more important
  effect interrupt a less important one. Should the key's chime cut off
  the forcefield's buzz?
- **A tune for the map.** Write a short tune for the castle map. What
  happens to the map's chime?
- **Vibrato.** Add a command that wobbles a voice's frequency up and
  down a little every frame. Where does the wobble's state live?
- **Transpose.** The driver has a transpose command that no tune uses.
  Use it to play the waltz's last four bars again, a tone higher.
:::
