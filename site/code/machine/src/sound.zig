//! The SOUND chip: three voices, each an oscillator with four waveforms
//! and an envelope, mixed through one volume control.
//!
//! The chip has no memory of its own beyond what an oscillator needs: it
//! reads its 25 registers (`$D400-$D418`, plain RAM) once a frame, when
//! the game's frame interrupt returns, and plays them until the next. The
//! shell asks for the samples (`Chip.render`) and sends them to a speaker
//! or a WAV file.
//!
//! The model is forgiving, like the rest of the Comet: oscillators and
//! envelopes are straight arithmetic, the filter isn't fitted, and two
//! waveforms at once are simply mixed.

const std = @import("std");

/// The chip's registers start here: seven per voice, then four more.
pub const base: u16 = 0xD400;
pub const register_count = 25;

/// Voice `v`'s seven registers start at `base + 7 * v`. These are the
/// offsets within a voice.
pub const freq_lo = 0;
pub const freq_hi = 1;
pub const pulse_lo = 2;
pub const pulse_hi = 3; // low 4 bits: the pulse width is 12 bits
pub const control = 4;
pub const attack_decay = 5; // attack in the high 4 bits, decay in the low
pub const sustain_release = 6; // sustain level high, release low

/// `$D415-$D417` belong to the filter, which this model doesn't have.
/// `$D418`'s low 4 bits are the volume, 0 (silent) to 15.
pub const volume = 0x18;

/// The bits of a voice's control register.
pub const gate: u8 = 0x01; // on: attack, decay, sustain; off: release
pub const sync: u8 = 0x02; // restart with the voice before it
pub const ring: u8 = 0x04; // triangle: flip it with the voice before it
pub const testbit: u8 = 0x08; // hold the oscillator at zero
pub const triangle: u8 = 0x10;
pub const sawtooth: u8 = 0x20;
pub const pulse: u8 = 0x40;
pub const noise: u8 = 0x80;

/// The oscillator adds the frequency register to a 24-bit counter once a
/// cycle; one lap of the counter is one cycle of the wave. So a note's
/// frequency is `register * clock / 2^24`, and with a 1 MHz clock a
/// register of 7382 is 440 Hz.
pub const clock_hz = 1_000_000;
pub const lap = 1 << 24;

/// How long the attack takes to rise from silence to full, for each value
/// of its 4 bits, in milliseconds.
pub const attack_ms = [16]f32{ 2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000 };
/// How long decay and release take to fall the whole way, full to silent.
pub const fall_ms = [16]f32{ 6, 24, 48, 72, 114, 168, 204, 240, 300, 750, 1500, 2400, 3000, 9000, 15000, 24000 };

const Stage = enum { attack, decay, release };

const Voice = struct {
    phase: f64 = 0, // 0 up to 1: how far through the wave
    level: f32 = 0, // the envelope, 0 up to 1
    stage: Stage = .release,
    gate: bool = false,
    lfsr: u32 = 0x7FFFF8, // the noise generator's 23 bits
    noise_steps: u32 = 0, // noise clocks so far, 16 a lap
    wrapped: bool = false, // the phase passed 1 this sample (for sync)
};

pub const Chip = struct {
    voices: [3]Voice = @splat(.{}),
    /// A gentle smoothing of the output, like the chip's own output stage.
    smooth: f32 = 0,

    /// Fill `out` with samples at `rate` per second, playing `regs` as
    /// they are now. Call it once for each frame slot the game used, with
    /// a frame's worth of samples (`rate / 50`): the gate bits are looked
    /// at once per call.
    pub fn render(chip: *Chip, regs: *const [register_count]u8, out: []f32, rate: u32) void {
        for (&chip.voices, 0..) |*v, i| {
            const on = regs[i * 7 + control] & gate != 0;
            if (on and !v.gate) v.stage = .attack;
            if (!on and v.gate) v.stage = .release;
            v.gate = on;
        }
        const dt: f32 = 1.0 / @as(f32, @floatFromInt(rate));
        const cycles_per_sample: f64 = @as(f64, clock_hz) / @as(f64, @floatFromInt(rate));
        const loud: f32 = @as(f32, @floatFromInt(regs[volume] & 0x0F)) / 15.0;
        const k: f32 = @min(1.0, 2.0 * std.math.pi * 12_000.0 * dt);
        for (out) |*sample| {
            var mix: f32 = 0;
            for (&chip.voices, 0..) |*v, i| {
                const r = regs[i * 7 ..][0..7];
                const before = &chip.voices[(i + 2) % 3]; // the voice that syncs and rings this one
                mix += voiceSample(v, r, before, cycles_per_sample, dt);
            }
            chip.smooth += (mix * loud / 3.0 - chip.smooth) * k;
            sample.* = chip.smooth;
        }
    }
};

fn voiceSample(v: *Voice, r: *const [7]u8, before: *const Voice, cycles_per_sample: f64, dt: f32) f32 {
    const ctrl = r[control];
    const freq: u32 = @as(u32, r[freq_lo]) | @as(u32, r[freq_hi]) << 8;

    // The envelope: straight ramps up to full, down to the sustain level,
    // and down to silence.
    const sustain: f32 = @as(f32, @floatFromInt(r[sustain_release] >> 4)) / 15.0;
    switch (v.stage) {
        .attack => {
            v.level += dt * 1000.0 / attack_ms[r[attack_decay] >> 4];
            if (v.level >= 1) {
                v.level = 1;
                v.stage = .decay;
            }
        },
        .decay => if (v.level > sustain) {
            v.level = @max(sustain, v.level - dt * 1000.0 / fall_ms[r[attack_decay] & 0x0F]);
        },
        .release => v.level = @max(0, v.level - dt * 1000.0 / fall_ms[r[sustain_release] & 0x0F]),
    }

    // The oscillator.
    v.wrapped = false;
    if (ctrl & testbit != 0) {
        v.phase = 0;
        v.lfsr = 0x7FFFF8;
        return 0;
    }
    v.phase += @as(f64, @floatFromInt(freq)) * cycles_per_sample / lap;
    if (v.phase >= 1) {
        v.phase -= @floor(v.phase);
        v.wrapped = true;
    }
    if (ctrl & sync != 0 and before.wrapped) v.phase = 0;

    // Noise steps on 16 times a lap of the counter.
    const steps: u32 = @intFromFloat(v.phase * 16);
    if (steps != v.noise_steps) {
        v.noise_steps = steps;
        const bit = ((v.lfsr >> 22) ^ (v.lfsr >> 17)) & 1;
        v.lfsr = ((v.lfsr << 1) | bit) & 0x7FFFFF;
    }

    var sum: f32 = 0;
    var waves: f32 = 0;
    const p: f32 = @floatCast(v.phase);
    if (ctrl & triangle != 0) {
        var t = if (p < 0.5) 4 * p - 1 else 3 - 4 * p;
        if (ctrl & ring != 0 and before.phase >= 0.5) t = -t;
        sum += t;
        waves += 1;
    }
    if (ctrl & sawtooth != 0) {
        sum += 2 * p - 1;
        waves += 1;
    }
    if (ctrl & pulse != 0) {
        const width: f32 = @floatFromInt(@as(u16, r[pulse_lo]) | @as(u16, r[pulse_hi] & 0x0F) << 8);
        sum += if (p * 4096 < width) 1 else -1;
        waves += 1;
    }
    if (ctrl & noise != 0) {
        // Eight of the generator's bits make the noise's level.
        const l = v.lfsr;
        const byte: u32 = ((l >> 15) & 0x80) | ((l >> 14) & 0x40) | ((l >> 11) & 0x20) | ((l >> 9) & 0x10) |
            ((l >> 6) & 0x08) | ((l >> 4) & 0x04) | ((l >> 1) & 0x02) | (l & 0x01);
        sum += @as(f32, @floatFromInt(byte)) / 127.5 - 1;
        waves += 1;
    }
    if (waves == 0) return 0;
    return sum / waves * v.level;
}

// ---- tests ---------------------------------------------------------------

const testing = std.testing;

fn playFor(chip: *Chip, regs: *const [register_count]u8, frames: usize, out: []f32) void {
    for (0..frames) |f| chip.render(regs, out[f * 882 ..][0..882], 44100);
}

fn crossings(samples: []const f32) usize {
    var n: usize = 0;
    for (samples[1..], samples[0 .. samples.len - 1]) |b, a| {
        if (a < 0 and b >= 0) n += 1;
    }
    return n;
}

fn peak(samples: []const f32) f32 {
    var p: f32 = 0;
    for (samples) |s| p = @max(p, @abs(s));
    return p;
}

test "silent at power-on, and silent with the volume at 0" {
    var chip: Chip = .{};
    var regs: [register_count]u8 = @splat(0);
    var out: [882 * 5]f32 = undefined;
    playFor(&chip, &regs, 5, &out);
    try testing.expectEqual(0, peak(&out));

    regs[freq_lo] = 0xD6;
    regs[freq_hi] = 0x1C; // 7382: 440 Hz
    regs[control] = sawtooth | gate;
    playFor(&chip, &regs, 5, &out);
    try testing.expectEqual(0, peak(&out));
}

test "a gated note plays its frequency" {
    var chip: Chip = .{};
    var regs: [register_count]u8 = @splat(0);
    regs[volume] = 15;
    regs[freq_lo] = 0xD6;
    regs[freq_hi] = 0x1C; // 7382: 440 Hz
    regs[control] = triangle | gate;
    regs[sustain_release] = 0xF0; // sustain at full
    var out: [882 * 50]f32 = undefined; // one second
    playFor(&chip, &regs, 50, &out);
    const n = crossings(&out);
    try testing.expect(n >= 438 and n <= 442);
    try testing.expect(peak(&out) > 0.3);
}

test "the gate starts the attack, and letting go releases" {
    var chip: Chip = .{};
    var regs: [register_count]u8 = @splat(0);
    regs[volume] = 15;
    regs[freq_hi] = 0x10;
    regs[control] = pulse | gate;
    regs[pulse_hi] = 0x08; // square
    regs[attack_decay] = 0x80; // attack 100 ms
    regs[sustain_release] = 0xF4; // full sustain, release 114 ms
    var out: [882 * 20]f32 = undefined;
    playFor(&chip, &regs, 2, out[0 .. 882 * 2]); // 40 ms in: still rising
    try testing.expect(chip.voices[0].level > 0.3 and chip.voices[0].level < 0.5);
    playFor(&chip, &regs, 5, out[0 .. 882 * 5]); // 140 ms in: full
    try testing.expectEqual(1, chip.voices[0].level);
    regs[control] = pulse; // let go
    playFor(&chip, &regs, 3, out[0 .. 882 * 3]); // 60 ms of release
    try testing.expect(chip.voices[0].level > 0.4 and chip.voices[0].level < 0.6);
    playFor(&chip, &regs, 4, out[0 .. 882 * 4]);
    try testing.expectEqual(0, chip.voices[0].level);
}

test "noise is noisy, and no waveform is silence" {
    var chip: Chip = .{};
    var regs: [register_count]u8 = @splat(0);
    regs[volume] = 15;
    regs[freq_hi] = 0x40;
    regs[control] = noise | gate;
    regs[sustain_release] = 0xF0;
    var out: [882 * 10]f32 = undefined;
    playFor(&chip, &regs, 10, &out);
    try testing.expect(peak(&out) > 0.2);
    try testing.expect(crossings(&out) > 500);
    regs[control] = gate; // gate on, but no waveform
    playFor(&chip, &regs, 1, out[0..882]); // the smoothing settles
    playFor(&chip, &regs, 1, out[0..882]);
    try testing.expect(peak(out[0..882]) < 0.001);
}
