//! The Comet 64 in a web page. Built for wasm32-freestanding (no libc, no
//! runtime); `web/shell.js` drives these exports at 50 Hz and copies the
//! screen onto a canvas.

const std = @import("std");
const machine = @import("machine");
const game = @import("game");

const Machine = machine.Machine;
const video = machine.video;

// Messages from the game end up in the browser console.
extern "env" fn comet_log(ptr: [*]const u8, len: usize) void;

pub const panic = std.debug.FullPanic(struct {
    fn panic(msg: []const u8, _: ?usize) noreturn {
        comet_log(msg.ptr, msg.len);
        @trap();
    }
}.panic);

pub const std_options: std.Options = .{ .logFn = log };

fn log(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    var buf: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "[" ++ @tagName(level) ++ "] " ++ format, args) catch &buf;
    comet_log(text.ptr, text.len);
}

// Set up by `comet_boot` (`boot` resets every field), so it can live in
// zeroed memory instead of a half-megabyte data section.
var m: Machine = undefined;

/// Power on (or reset) the machine.
export fn comet_boot() void {
    m.boot(game);
}

/// Run one frame with the given held joystick bits (see `machine.joy`).
/// Returns the frame slots it used: wait that many frames before the next.
export fn comet_frame(joy1: u8, joy2: u8) u32 {
    m.input.joy1 = joy1;
    m.input.joy2 = joy2;
    return m.runFrame(game);
}

/// A key was pressed (uppercase ASCII). Delivered at the next frame.
export fn comet_key(code: u8) void {
    m.input.key = code;
}

export fn comet_screen() [*]const u32 {
    return &m.screen;
}
export fn comet_width() u32 {
    return video.width;
}
export fn comet_height() u32 {
    return video.height;
}

/// All 64 KB, for memory viewers.
export fn comet_ram() [*]const u8 {
    return &m.ram;
}

export fn comet_meter() u32 {
    return m.meter();
}
export fn comet_budget() u32 {
    return machine.frame_budget;
}
export fn comet_overruns() u32 {
    return m.stats.overruns;
}
export fn comet_loading() u32 {
    return m.stats.loading;
}

/// Last frame's cycles in meter bucket `id` (0-7).
export fn comet_bucket(id: u32) u32 {
    return if (id < 8) m.last.buckets[id] else 0;
}

/// Last frame's kind: 0 fitted, 1 overrun, 2 loading pause.
export fn comet_kind() u32 {
    return @intFromEnum(m.last.kind);
}

// One frame slot of sound at a time; 1,000 samples covers a 50,000-a-second
// speaker.
var sound_buf: [1000]f32 = undefined;

/// The sound of one frame slot, `count` samples (up to 1,000) at `rate` a
/// second, from the SOUND chip as the last frame left it. Call it once for
/// each slot `comet_frame` returned.
export fn comet_listen(rate: u32, count: u32) [*]const f32 {
    m.listen(sound_buf[0..@min(count, sound_buf.len)], rate);
    return &sound_buf;
}
