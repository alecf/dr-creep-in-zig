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

var m: Machine = .{};

/// Power on (or reset) the machine.
export fn comet_boot() void {
    m.boot(game);
}

/// Run one frame with the given held joystick bits (see `machine.joy`).
export fn comet_frame(joy1: u8, joy2: u8) void {
    m.input.joy1 = joy1;
    m.input.joy2 = joy2;
    m.runFrame(game);
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
    return m.overruns;
}
