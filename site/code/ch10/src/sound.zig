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

/// What `map.sound_playing` says: an effect's number, or one of these.
pub const tune: u8 = 0xFE;
pub const nothing: u8 = 0xFF;

/// At power-on: the tunes and the frequency table into the music region,
/// the effects into theirs, and nothing playing (0 would be the laser).
pub fn start(m: *Machine) void {
    m.load(map.music.first, tunes.music);
    m.load(map.effects.first, tunes.effects);
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

/// Stop whatever's playing.
pub fn stop(m: *Machine) void {
    silence(m);
    m.poke16(map.sound_at, 0);
    m.poke(map.sound_playing, nothing);
}

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
