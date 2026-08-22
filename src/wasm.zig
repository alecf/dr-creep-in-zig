//! WebAssembly shell: exports a tiny C-ish API that web/creep.js drives.
//! Built for wasm32-freestanding — no emscripten, no libc. The JS side
//! fetches the game files, feeds them in, then calls frame() at 60 Hz and
//! blits the returned RGBA framebuffer to a canvas.

const std = @import("std");
const Machine = @import("core/machine.zig").Machine;
const vic = @import("core/vic.zig");
const kernal = @import("core/kernal.zig");

pub const std_options: std.Options = .{
    .logFn = wasmLog,
};

fn wasmLog(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    @trap();
}

const allocator = std.heap.wasm_allocator;

var machine: ?*Machine = null;
var fs: kernal.Fs = undefined;
var fb: [vic.WIDTH * vic.HEIGHT]u32 = @splat(0xFF000000);

/// JS allocates staging buffers through this before copying data in.
export fn wasm_alloc(len: usize) ?[*]u8 {
    const buf = allocator.alloc(u8, len) catch return null;
    return buf.ptr;
}

export fn fb_width() u32 {
    return vic.WIDTH;
}

export fn fb_height() u32 {
    return vic.HEIGHT;
}

export fn fb_ptr() [*]const u32 {
    return &fb;
}

/// Call once before add_file.
export fn boot_init() bool {
    machine = Machine.init(allocator) catch return null == null;
    fs = kernal.Fs.init(allocator);
    kernal.install(machine.?, &fs) catch return false;
    return true;
}

/// Register one game file (name and data buffers come from wasm_alloc;
/// ownership passes to the fs).
export fn add_file(name: [*]const u8, name_len: usize, data: [*]const u8, data_len: usize) bool {
    fs.addFile(name[0..name_len], data[0..data_len]) catch return false;
    return true;
}

/// Optional: 4KB C64 character ROM for the stock menu font.
export fn set_chargen(data: [*]const u8, len: usize) void {
    const m = machine orelse return;
    if (len >= 0x1000) @memcpy(&m.char_rom, data[0..0x1000]);
}

/// Load `object` and jump to its entry. Returns false if files are missing.
export fn boot_start() bool {
    const m = machine orelse return false;
    const object = fs.files.get("object") orelse return false;
    const entry = m.loadPrg(object);
    m.cpu.reset(entry);
    return true;
}

/// joystick bits (active-low u/d/l/r/f in bits 0-4)
export fn set_joy(joy1: u8, joy2: u8) void {
    const m = machine orelse return;
    m.joy1 = joy1;
    m.joy2 = joy2;
}

/// keyboard matrix: row 0-7, bit mask, pressed
export fn set_key(row: u8, mask: u8, down: bool) void {
    const m = machine orelse return;
    if (row > 7) return;
    if (down) {
        m.key_matrix[row] &= ~mask;
    } else {
        m.key_matrix[row] |= mask;
    }
}

/// Run one video frame and render. Returns false on CPU trap.
export fn frame() bool {
    const m = machine orelse return false;
    const ok = m.runFrame();
    vic.renderFrame(m, &fb);
    return ok;
}

/// debug: current 6502 PC
export fn cpu_pc() u16 {
    const m = machine orelse return 0;
    return m.cpu.pc;
}

/// debug: read a byte of emulated RAM
export fn peek(addr: u16) u8 {
    const m = machine orelse return 0;
    return m.ram[addr];
}
