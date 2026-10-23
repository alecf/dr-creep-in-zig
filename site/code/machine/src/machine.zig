//! The Comet 64.
//!
//! This file is the whole computer as far as a game is concerned: 64 KB of
//! RAM, the work meter that keeps a frame honest, and the frame driver that
//! reads the joysticks, runs the game's frame interrupt and hands the
//! finished RAM to the VIDEO chip.
//!
//! A game never touches anything here except through `Machine`'s methods
//! and `m.ram`. Everything the game remembers lives in that one array.

const std = @import("std");
const builtin = @import("builtin");

pub const video = @import("video.zig");
pub const font = @import("font.zig");

comptime {
    // Two-byte values are stored low byte first, and `view` hands out
    // pointers straight into RAM, so the host must agree.
    if (builtin.cpu.arch.endian() != .little)
        @compileError("the Comet 64 needs a little-endian host");
}

/// Cycles available in one frame: 312 raster lines of 63 cycles each.
pub const frame_budget: u32 = 19_656;

/// Frames per second. The frame interrupt fires this often.
pub const frame_rate = 50;

/// Fixed hardware addresses. These never move; a game's own memory map
/// is built around them.
pub const hw = struct {
    pub const stack: u16 = 0x0100; // reserved, 256 bytes
    pub const program: u16 = 0x0800; // program image, up to 0x77FF
    pub const program_end: u16 = 0x7800;

    pub const sprite_data: u16 = 0xC000; // 32 blocks of 64 bytes
    pub const screen: u16 = 0xCC00; // 1000 bytes, one per cell
    pub const sprite_pointers: u16 = 0xCFF8; // 8 block numbers
    pub const color_ram: u16 = 0xD800; // 1000 bytes, low nibble used
    pub const bitmap: u16 = 0xE000; // 8000 bytes

    // VIDEO chip
    pub const video_chip: u16 = 0xD000;
    pub fn spriteX(n: u3) u16 {
        return 0xD000 + @as(u16, n) * 2;
    }
    pub fn spriteY(n: u3) u16 {
        return 0xD001 + @as(u16, n) * 2;
    }
    pub fn spriteColor(n: u3) u16 {
        return 0xD027 + @as(u16, n);
    }
    pub const sprite_x_msb: u16 = 0xD010;
    pub const sprite_enable: u16 = 0xD015;
    pub const sprite_double_height: u16 = 0xD017;
    pub const sprite_behind: u16 = 0xD01B;
    pub const sprite_multicolor: u16 = 0xD01C;
    pub const sprite_double_width: u16 = 0xD01D;
    pub const sprite_sprite_hits: u16 = 0xD01E;
    pub const sprite_bitmap_hits: u16 = 0xD01F;
    pub const border: u16 = 0xD020;
    pub const background: u16 = 0xD021;
    pub const sprite_mc0: u16 = 0xD025;
    pub const sprite_mc1: u16 = 0xD026;

    // SOUND chip: $D400-$D418 hold whatever the game writes.
    // TODO: audio output (three voices, envelopes, filter) arrives with
    // the music chapter; until then nothing reads these registers.
    pub const sound_chip: u16 = 0xD400;

    // Input ports
    pub const joy2: u16 = 0xDC00;
    pub const joy1: u16 = 0xDC01;
    pub const key: u16 = 0xDC02;
};

/// Joystick bits as the ports report them (a 0 bit means "pressed").
pub const joy = struct {
    pub const up: u8 = 0x01;
    pub const down: u8 = 0x02;
    pub const left: u8 = 0x04;
    pub const right: u8 = 0x08;
    pub const fire: u8 = 0x10;
};

/// The 16 colours, by palette index.
pub const Color = enum(u4) {
    black,
    white,
    red,
    cyan,
    purple,
    green,
    blue,
    yellow,
    orange,
    brown,
    pink,
    dark_grey,
    grey,
    light_green,
    light_blue,
    light_grey,
};

/// What the outside world is doing to the machine this frame. The shell
/// (browser or headless) fills this in before each `runFrame`.
pub const Input = struct {
    /// Held joystick directions, using the `joy` bits (1 = held here; the
    /// port inverts them).
    joy1: u8 = 0,
    joy2: u8 = 0,
    /// A key pressed since the last frame, as uppercase ASCII (0 = none).
    key: u8 = 0,
};

pub const Machine = struct {
    /// All of memory. The game's code, data, the screen, the hardware
    /// registers: it is all in here.
    ram: [0x10000]u8 = @splat(0),

    /// What the VIDEO chip drew at the end of the last frame (RGBA).
    screen: video.Screen = @splat(0),

    /// Set by the shell before each frame.
    input: Input = .{},

    // The work meter.
    cycles: u32 = 0, // spent so far this frame
    last_cycles: u32 = 0, // what the previous frame spent

    // Running totals, for the headless summary and the browser.
    frames: u32 = 0,
    overruns: u32 = 0,
    max_cycles: u32 = 0,
    total_cycles: u64 = 0,

    // ---- memory ---------------------------------------------------------

    /// Read one byte. 4 cycles.
    pub fn peek(m: *Machine, addr: u16) u8 {
        m.cycles +|= 4;
        return m.ram[addr];
    }

    /// Write one byte. 4 cycles.
    pub fn poke(m: *Machine, addr: u16, value: u8) void {
        m.cycles +|= 4;
        m.ram[addr] = value;
    }

    /// Read a two-byte value stored low byte first. 8 cycles.
    pub fn peek16(m: *Machine, addr: u16) u16 {
        m.cycles +|= 8;
        return @as(u16, m.ram[addr]) | @as(u16, m.ram[addr +% 1]) << 8;
    }

    /// Write a two-byte value, low byte first. 8 cycles.
    pub fn poke16(m: *Machine, addr: u16, value: u16) void {
        m.cycles +|= 8;
        m.ram[addr] = @truncate(value);
        m.ram[addr +% 1] = @truncate(value >> 8);
    }

    /// Copy `n` bytes from `src` to `dst`. Overlapping ranges are fine.
    /// 8 cycles per byte.
    pub fn copy(m: *Machine, dst: u16, src: u16, n: u16) void {
        m.cycles +|= @as(u32, n) * 8;
        if (@as(u32, dst) + n <= m.ram.len and @as(u32, src) + n <= m.ram.len) {
            @memmove(m.ram[dst..][0..n], m.ram[src..][0..n]);
        } else {
            // Rare: a range runs off the top of memory and wraps to 0.
            // Copy in the safe direction one byte at a time.
            if (dst -% src < n) {
                var i: u16 = n;
                while (i > 0) {
                    i -= 1;
                    m.ram[dst +% i] = m.ram[src +% i];
                }
            } else {
                for (0..n) |i| {
                    const k: u16 = @intCast(i);
                    m.ram[dst +% k] = m.ram[src +% k];
                }
            }
        }
    }

    /// Set `n` bytes starting at `dst` to `value`. 8 cycles per byte.
    pub fn fill(m: *Machine, dst: u16, n: u16, value: u8) void {
        m.cycles +|= @as(u32, n) * 8;
        if (@as(u32, dst) + n <= m.ram.len) {
            @memset(m.ram[dst..][0..n], value);
        } else {
            for (0..n) |i| m.ram[dst +% @as(u16, @intCast(i))] = value;
        }
    }

    /// Multiply two bytes. The CPU has no multiply instruction, so this is
    /// a software routine: 120 cycles. Lookup tables are usually cheaper.
    pub fn mul8(m: *Machine, a: u8, b: u8) u16 {
        m.cycles +|= 120;
        return @as(u16, a) * b;
    }

    /// Charge `n` cycles for work done outside peek/poke (loop overhead,
    /// arithmetic, decisions).
    pub fn work(m: *Machine, n: u32) void {
        m.cycles +|= n;
    }

    /// Cycles the previous frame used. Compare against `frame_budget`.
    pub fn meter(m: *const Machine) u32 {
        return m.last_cycles;
    }

    /// A typed window onto RAM: `m.view(Header, 0x7800)` lets you read and
    /// write the bytes at 0x7800 as a `Header`. Free on its own; charge
    /// `m.work()` for what you do with it.
    ///
    /// `T` must have a fixed byte layout: an `extern` or `packed` struct or
    /// union, a whole-byte integer, or an array of those.
    pub fn view(m: *Machine, comptime T: type, addr: u16) *align(1) T {
        comptime checkViewable(T);
        if (@as(usize, addr) + @sizeOf(T) > m.ram.len)
            @panic("view runs past the end of memory");
        return @ptrCast(&m.ram[addr]);
    }

    /// The 8 bytes of a glyph in the character ROM (top row first, bit 7
    /// is the leftmost pixel). The ROM is not in the 64 KB map; reading it
    /// this way is free.
    pub fn charRom(m: *const Machine, code: u8) *const [8]u8 {
        _ = m;
        return &font.rom[code];
    }

    // ---- the frame driver -----------------------------------------------

    /// Power on: clear memory, set the input ports to "nothing pressed",
    /// then let the game set itself up. Boot time is not metered.
    pub fn boot(m: *Machine, comptime Game: type) void {
        comptime checkGame(Game);
        m.reset();
        m.writeInput();
        Game.boot(m);
        m.cycles = 0;
    }

    /// One 50 Hz frame: latch the input ports, run the game's frame
    /// interrupt against a fresh meter, then let the VIDEO chip draw the
    /// result and report sprite collisions.
    pub fn runFrame(m: *Machine, comptime Game: type) void {
        comptime checkGame(Game);
        m.writeInput();
        m.cycles = 0;

        Game.frame(m);

        m.last_cycles = m.cycles;
        m.frames += 1;
        m.total_cycles += m.cycles;
        m.max_cycles = @max(m.max_cycles, m.cycles);
        if (m.cycles > frame_budget) m.overruns += 1;

        const hits = video.render(m);
        // Collision bits latch until the game clears them.
        m.ram[hw.sprite_sprite_hits] |= hits.sprite_sprite;
        m.ram[hw.sprite_bitmap_hits] |= hits.sprite_bitmap;
    }

    /// Back to the power-on state. (Field by field rather than `m.* = .{}`
    /// so no half-megabyte temporary lands on a small wasm stack.)
    fn reset(m: *Machine) void {
        @memset(&m.ram, 0);
        @memset(&m.screen, 0xFF000000);
        m.input = .{};
        m.cycles = 0;
        m.last_cycles = 0;
        m.frames = 0;
        m.overruns = 0;
        m.max_cycles = 0;
        m.total_cycles = 0;
    }

    fn writeInput(m: *Machine) void {
        m.ram[hw.joy1] = portByte(m.input.joy1);
        m.ram[hw.joy2] = portByte(m.input.joy2);
        if (m.input.key != 0) {
            m.ram[hw.key] = m.input.key;
            m.input.key = 0;
        }
    }
};

/// Joystick port encoding: five active-low switches, top three bits
/// always read 1.
pub fn portByte(held: u8) u8 {
    return 0xE0 | (~held & 0x1F);
}

fn checkGame(comptime Game: type) void {
    if (!@hasDecl(Game, "boot") or @TypeOf(Game.boot) != fn (*Machine) void)
        @compileError("a game needs `pub fn boot(m: *Machine) void`");
    if (!@hasDecl(Game, "frame") or @TypeOf(Game.frame) != fn (*Machine) void)
        @compileError("a game needs `pub fn frame(m: *Machine) void`");
}

fn checkViewable(comptime T: type) void {
    switch (@typeInfo(T)) {
        .int => |info| if (info.bits % 8 == 0) return,
        .@"struct" => |info| if (info.layout != .auto) return,
        .@"union" => |info| if (info.layout != .auto) return,
        .array => |info| return checkViewable(info.child),
        else => {},
    }
    @compileError("m.view needs a type with a fixed byte layout (extern/packed struct, " ++
        "whole-byte integer, or an array of those); got " ++ @typeName(T));
}

// ---- tests ---------------------------------------------------------------

const testing = std.testing;

fn newMachine() !*Machine {
    const m = try testing.allocator.create(Machine);
    m.* = .{};
    return m;
}

test {
    _ = video;
    _ = font;
}

test "costs" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.poke(0x0200, 7);
    try testing.expectEqual(4, m.cycles);
    _ = m.peek(0x0200);
    try testing.expectEqual(8, m.cycles);
    m.poke16(0x0300, 0x1234);
    _ = m.peek16(0x0300);
    try testing.expectEqual(24, m.cycles);
    m.copy(0x0400, 0x0300, 10);
    try testing.expectEqual(104, m.cycles);
    m.fill(0x0500, 5, 0xAA);
    try testing.expectEqual(144, m.cycles);
    try testing.expectEqual(@as(u16, 600), m.mul8(20, 30));
    try testing.expectEqual(264, m.cycles);
    m.work(6);
    try testing.expectEqual(270, m.cycles);
    _ = m.view([4]u8, 0x0500);
    _ = m.charRom('A');
    try testing.expectEqual(270, m.cycles);
}

test "peek16 and poke16 are little-endian" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.poke16(0x7800, 0xBEEF);
    try testing.expectEqual(0xEF, m.ram[0x7800]);
    try testing.expectEqual(0xBE, m.ram[0x7801]);
    m.ram[0x7802] = 0x34;
    m.ram[0x7803] = 0x12;
    try testing.expectEqual(0x1234, m.peek16(0x7802));
}

test "copy handles overlap and fill sets bytes" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    for (0..8) |i| m.ram[0x1000 + i] = @intCast(i + 1);
    m.copy(0x1002, 0x1000, 6); // overlapping, forwards
    try testing.expectEqualSlices(u8, &.{ 1, 2, 1, 2, 3, 4, 5, 6 }, m.ram[0x1000..0x1008]);
    m.fill(0xFFFE, 4, 9); // wraps to 0x0000
    try testing.expectEqual(9, m.ram[0xFFFF]);
    try testing.expectEqual(9, m.ram[0x0001]);
    try testing.expectEqual(0, m.ram[0x0002]);
}

test "view gives a typed window onto RAM" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    const Rec = extern struct { kind: u8, x: u8, y: u8, flags: u8 };
    const r = m.view(Rec, 0x7900);
    r.x = 40;
    try testing.expectEqual(40, m.ram[0x7901]);
    const w = m.view(u16, 0x7904);
    w.* = 0x0102;
    try testing.expectEqual(0x02, m.ram[0x7904]);
}

test "input ports are active-low with the top bits set" {
    const Game = struct {
        pub fn boot(_: *Machine) void {}
        pub fn frame(_: *Machine) void {}
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Game);
    try testing.expectEqual(0xFF, m.ram[hw.joy1]);
    try testing.expectEqual(0xFF, m.ram[hw.joy2]);
    try testing.expectEqual(0x00, m.ram[hw.key]);

    m.input = .{ .joy1 = joy.up | joy.fire, .joy2 = joy.right, .key = 'R' };
    m.runFrame(Game);
    try testing.expectEqual(0xEE, m.ram[hw.joy1]);
    try testing.expectEqual(0xF7, m.ram[hw.joy2]);
    try testing.expectEqual('R', m.ram[hw.key]);

    // The key stays until the game acknowledges it, and is delivered once.
    m.runFrame(Game);
    try testing.expectEqual('R', m.ram[hw.key]);
    m.ram[hw.key] = 0;
    m.runFrame(Game);
    try testing.expectEqual(0, m.ram[hw.key]);
}

test "the meter counts one frame at a time and flags overruns" {
    const Game = struct {
        pub fn boot(m: *Machine) void {
            m.work(1_000_000); // boot is not metered
        }
        pub fn frame(m: *Machine) void {
            m.work(if (m.frames == 1) frame_budget + 1 else 1000);
        }
    };
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.boot(Game);
    m.runFrame(Game);
    try testing.expectEqual(1000, m.meter());
    m.runFrame(Game);
    try testing.expectEqual(frame_budget + 1, m.meter());
    try testing.expectEqual(1, m.overruns);
    try testing.expectEqual(frame_budget + 1, m.max_cycles);
}
