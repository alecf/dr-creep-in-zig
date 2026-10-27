//! Music and sound effects, as data: the notes' frequencies, a composer
//! that turns up to three lines of notes into one stream of commands
//! while the game compiles, and every tune and effect in the game.

const std = @import("std");
const machine = @import("machine");
const chip = machine.sound;
const map = @import("map.zig");
const sound = @import("sound.zig");

// ---- notes ------------------------------------------------------------

/// The notes the table has: C0 up to A#7. B7 would need a frequency
/// register of 66,288, and the register has 16 bits.
pub const note_count = 95;

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
    {
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
}

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

// ---- the tunes ----------------------------------------------------------

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

/// Instruments for the tunes.
const lead: Instrument = .{ .wave = chip.pulse, .width = 0x600, .decay = 8, .sustain = 9, .release = 6 };
const chord: Instrument = .{ .wave = chip.triangle, .decay = 6, .sustain = 6, .release = 5 };
const bass: Instrument = .{ .wave = chip.triangle, .decay = 9, .sustain = 0, .release = 4 };
const brass: Instrument = .{ .wave = chip.sawtooth, .attack = 1, .decay = 7, .sustain = 10, .release = 5 };
const reed: Instrument = .{ .wave = chip.pulse, .width = 0x300, .attack = 2, .sustain = 8, .release = 6 };
const flute: Instrument = .{ .wave = chip.triangle, .attack = 3, .decay = 9, .sustain = 10, .release = 9 };

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

test "A4 is 440 Hz" {
    try std.testing.expectEqual(57, note("A4"));
    try std.testing.expectEqual(7382, frequencies[note("A4")]); // 440 x 16.777216
    try std.testing.expectEqual(274, frequencies[0]); // C0, 16.35 Hz
    try std.testing.expectEqual(note("A#7"), note_count - 1);
    try std.testing.expectEqual(note("C#4"), note("Db4"));
}

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
