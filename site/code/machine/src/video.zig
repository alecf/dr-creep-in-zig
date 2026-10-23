//! The VIDEO chip.
//!
//! Once per frame, after the game's frame interrupt returns, the chip reads
//! the screen planes and its registers out of RAM and paints a picture:
//! border, the 320x200 multicolour bitmap, up to eight sprites, and the
//! work meter in the bottom border. While painting it notices sprites
//! touching each other or the bitmap, and reports that back.
//!
//! It draws the whole frame from the RAM it finds at that moment. Changing
//! a register halfway through a frame has no special effect.

const std = @import("std");
const Machine = @import("machine.zig").Machine;
const machine = @import("machine.zig");
const hw = machine.hw;

/// The picture the chip produces, border included.
pub const width = 384;
pub const height = 272;

/// Where the 320x200 display sits inside the picture.
pub const display_x = 32;
pub const display_y = 36;
pub const display_width = 320;
pub const display_height = 200;

/// Sprite coordinates of the display's top-left pixel.
pub const sprite_origin_x = 24;
pub const sprite_origin_y = 50;

/// One pixel per u32, bytes in R, G, B, A order in memory (ready for a
/// browser's ImageData).
pub const Screen = [width * height]u32;

fn rgb(r: u8, g: u8, b: u8) u32 {
    return @as(u32, r) | @as(u32, g) << 8 | @as(u32, b) << 16 | 0xFF00_0000;
}

/// The 16 colours, measured from a real picture tube.
pub const palette = [16]u32{
    rgb(0x00, 0x00, 0x00), // 0 black
    rgb(0xFF, 0xFF, 0xFF), // 1 white
    rgb(0x68, 0x37, 0x2B), // 2 red
    rgb(0x70, 0xA4, 0xB2), // 3 cyan
    rgb(0x6F, 0x3D, 0x86), // 4 purple
    rgb(0x58, 0x8D, 0x43), // 5 green
    rgb(0x35, 0x28, 0x79), // 6 blue
    rgb(0xB8, 0xC7, 0x6F), // 7 yellow
    rgb(0x6F, 0x4F, 0x25), // 8 orange
    rgb(0x43, 0x39, 0x00), // 9 brown
    rgb(0x9A, 0x67, 0x59), // 10 pink
    rgb(0x44, 0x44, 0x44), // 11 dark grey
    rgb(0x6C, 0x6C, 0x6C), // 12 grey
    rgb(0x9A, 0xD2, 0x84), // 13 light green
    rgb(0x6C, 0x5E, 0xB5), // 14 light blue
    rgb(0x95, 0x95, 0x95), // 15 light grey
};

pub fn color(index: u8) u32 {
    return palette[index & 0x0F];
}

/// Collision bits found while drawing, one bit per sprite.
pub const Hits = struct {
    sprite_sprite: u8 = 0,
    sprite_bitmap: u8 = 0,
};

/// Paint `m.screen` from RAM and return this frame's collisions.
pub fn render(m: *Machine) Hits {
    const ram = &m.ram;
    @memset(&m.screen, color(ram[hw.border]));

    const sprites = readSprites(ram);
    var hits: Hits = .{};

    for (0..display_height) |y| {
        var line: [display_width]u32 = undefined;
        var foreground: [display_width]bool = undefined;
        bitmapLine(ram, y, &line, &foreground);
        spriteLine(ram, &sprites, y, &line, &foreground, &hits);
        const row = (display_y + y) * width + display_x;
        @memcpy(m.screen[row..][0..display_width], &line);
    }

    drawMeter(m);
    return hits;
}

// ---- the bitmap ------------------------------------------------------------

/// One row of the bitmap. Each byte holds four fat pixels, leftmost in the
/// top two bits; each 2-bit code picks a colour from the cell's own set:
///
///   00 background ($D021)      01 screen byte, high nibble
///   10 screen byte, low nibble 11 colour RAM, low nibble
///
/// Codes 10 and 11 count as foreground (sprites can hide behind them and
/// collide with them).
fn bitmapLine(ram: *const [0x10000]u8, y: usize, line: *[display_width]u32, fg: *[display_width]bool) void {
    const background = color(ram[hw.background]);
    const cell_row = y / 8;
    const row_in_cell = y % 8;

    for (0..40) |cx| {
        const cell = cell_row * 40 + cx;
        const screen_byte = ram[hw.screen + cell];
        const colors = [4]u32{
            background,
            color(screen_byte >> 4),
            color(screen_byte),
            color(ram[hw.color_ram + cell]),
        };
        const bits = ram[hw.bitmap + cell * 8 + row_in_cell];
        for (0..4) |p| {
            const code: u2 = @truncate(bits >> @intCast(6 - p * 2));
            const x = cx * 8 + p * 2;
            line[x] = colors[code];
            line[x + 1] = colors[code];
            fg[x] = code >= 2;
            fg[x + 1] = code >= 2;
        }
    }
}

// ---- sprites ---------------------------------------------------------------

const Sprite = struct {
    enabled: bool,
    x: i32, // display coordinates of the left edge
    y: i32, // display coordinates of the top edge
    data: u16, // address of the 63-byte frame
    wide: bool,
    tall: bool,
    multicolor: bool,
    behind: bool,
    colors: [4]u32, // by pixel code; code 0 is transparent
};

fn readSprites(ram: *const [0x10000]u8) [8]Sprite {
    var out: [8]Sprite = undefined;
    for (&out, 0..) |*s, i| {
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        const x9 = @as(i32, ram[hw.spriteX(n)]) + if (ram[hw.sprite_x_msb] & bit != 0) @as(i32, 256) else 0;
        const own = color(ram[hw.spriteColor(n)]);
        s.* = .{
            .enabled = ram[hw.sprite_enable] & bit != 0,
            .x = x9 - sprite_origin_x,
            .y = @as(i32, ram[hw.spriteY(n)]) - sprite_origin_y,
            .data = hw.sprite_data +% @as(u16, ram[hw.sprite_pointers + i]) * 64,
            .wide = ram[hw.sprite_double_width] & bit != 0,
            .tall = ram[hw.sprite_double_height] & bit != 0,
            .multicolor = ram[hw.sprite_multicolor] & bit != 0,
            .behind = ram[hw.sprite_behind] & bit != 0,
            .colors = if (ram[hw.sprite_multicolor] & bit != 0)
                .{ 0, color(ram[hw.sprite_mc0]), own, color(ram[hw.sprite_mc1]) }
            else
                .{ 0, own, 0, 0 },
        };
    }
    return out;
}

/// Lay the sprites over one bitmap row. Sprite 0 is in front of sprite 1,
/// and so on. A sprite with its `behind` bit set is hidden by foreground
/// bitmap pixels.
fn spriteLine(
    ram: *const [0x10000]u8,
    sprites: *const [8]Sprite,
    y: usize,
    line: *[display_width]u32,
    fg: *const [display_width]bool,
    hits: *Hits,
) void {
    var cover: [display_width]u8 = @splat(0); // which sprites touch this pixel
    var front: [display_width]u32 = undefined; // colour of the frontmost one
    var front_behind: [display_width]bool = undefined;
    var any = false;

    var i: usize = 8;
    while (i > 0) {
        i -= 1;
        const s = &sprites[i];
        if (!s.enabled) continue;
        const dy = @as(i32, @intCast(y)) - s.y;
        const row = if (s.tall) @divFloor(dy, 2) else dy;
        if (dy < 0 or row >= 21) continue;

        const base = s.data +% @as(u16, @intCast(row * 3));
        const bits: u24 = @as(u24, ram[base]) << 16 | @as(u24, ram[base +% 1]) << 8 | ram[base +% 2];
        const bit = @as(u8, 1) << @intCast(i);
        const scale: i32 = if (s.wide) 2 else 1;

        // Hires: 24 one-pixel dots. Multicolour: 12 two-pixel dots.
        const dots: u5 = if (s.multicolor) 12 else 24;
        const dot_bits: u5 = if (s.multicolor) 2 else 1;
        var d: u5 = 0;
        while (d < dots) : (d += 1) {
            const shift: u5 = 24 - (d + 1) * dot_bits;
            const code: u2 = @truncate((bits >> shift) & if (s.multicolor) @as(u24, 3) else 1);
            if (code == 0) continue;
            const dot_w = @as(i32, dot_bits) * scale;
            const left = s.x + @as(i32, d) * dot_w;
            var px = @max(left, 0);
            while (px < @min(left + dot_w, display_width)) : (px += 1) {
                const x: usize = @intCast(px);
                cover[x] |= bit;
                front[x] = s.colors[code];
                front_behind[x] = s.behind;
                any = true;
            }
        }
    }
    if (!any) return;

    for (0..display_width) |x| {
        const c = cover[x];
        if (c == 0) continue;
        if (@popCount(c) > 1) hits.sprite_sprite |= c;
        if (fg[x]) hits.sprite_bitmap |= c;
        if (!(front_behind[x] and fg[x])) line[x] = front[x];
    }
}

// ---- the work meter --------------------------------------------------------

/// The meter lives in the bottom border: a bar as wide as the display,
/// filled by the fraction of the frame budget the last frame used. Green
/// is comfortable, yellow is getting tight (75% and up), and a frame over
/// budget turns the bar red and lights a stripe right across the border.
/// Both sit on a black outline so they read against any border colour.
pub const meter_y = display_y + display_height + 14;
pub const meter_h = 3;
pub const stripe_y = meter_y + meter_h + 5;
pub const stripe_h = 2;

fn drawMeter(m: *Machine) void {
    const used = m.last_cycles;
    const budget = machine.frame_budget;
    const black = palette[@intFromEnum(machine.Color.black)];
    const red = palette[@intFromEnum(machine.Color.red)];
    const fill_color = if (used > budget)
        red
    else if (@as(u64, used) * 4 >= budget * 3)
        palette[@intFromEnum(machine.Color.yellow)]
    else
        palette[@intFromEnum(machine.Color.light_green)];
    const filled: usize = @intCast(@min(display_width, (@as(u64, used) * display_width + budget - 1) / budget));

    band(m, meter_y - 1, meter_h + 2, display_x - 1, display_width + 2, black);
    band(m, meter_y, meter_h, display_x, filled, fill_color);
    if (used > budget) {
        band(m, stripe_y - 1, stripe_h + 2, 0, width, black);
        band(m, stripe_y, stripe_h, 0, width, red);
    }
}

fn band(m: *Machine, y: usize, h: usize, x: usize, w: usize, c: u32) void {
    for (y..y + h) |row| @memset(m.screen[row * width + x ..][0..w], c);
}

// ---- tests -----------------------------------------------------------------

const testing = std.testing;

fn pixel(m: *const Machine, x: usize, y: usize) u32 {
    return m.screen[(display_y + y) * width + display_x + x];
}

fn newMachine() !*Machine {
    const m = try testing.allocator.create(Machine);
    m.* = .{};
    return m;
}

test "a bitmap byte becomes four fat pixels in the cell's colours" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.ram[hw.border] = 6;
    m.ram[hw.background] = 0; // code 00: black
    m.ram[hw.screen + 41] = 0x25; // cell (1,1): 01 red, 10 green
    m.ram[hw.color_ram + 41] = 0xF7; // 11 yellow (high nibble ignored)
    m.ram[hw.bitmap + 41 * 8 + 3] = 0b00_01_10_11; // row 3 of that cell
    const hits = render(m);
    try testing.expectEqual(Hits{}, hits);

    const y = 8 + 3;
    const expected = [_]u8{ 0, 0, 2, 2, 5, 5, 7, 7 };
    for (expected, 0..) |c, i| try testing.expectEqual(palette[c], pixel(m, 8 + i, y));
    try testing.expectEqual(palette[0], pixel(m, 8, y + 1));
    try testing.expectEqual(palette[6], m.screen[0]); // border
}

test "sprites draw at the classic coordinates and report collisions" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    // Block 1: a solid 24x21 hires square.
    @memset(m.ram[hw.sprite_data + 64 ..][0..63], 0xFF);
    m.ram[hw.sprite_pointers + 0] = 1;
    m.ram[hw.sprite_pointers + 1] = 1;
    m.ram[hw.spriteX(0)] = sprite_origin_x;
    m.ram[hw.spriteY(0)] = sprite_origin_y;
    m.ram[hw.spriteColor(0)] = 1;
    m.ram[hw.spriteX(1)] = sprite_origin_x + 100;
    m.ram[hw.spriteY(1)] = sprite_origin_y + 50;
    m.ram[hw.spriteColor(1)] = 2;
    m.ram[hw.sprite_enable] = 0b11;

    // A foreground (code 11) bitmap pixel under sprite 1 only.
    m.ram[hw.color_ram + 7 * 40 + 13] = 5;
    m.ram[hw.bitmap + (7 * 40 + 13) * 8] = 0b11_00_00_00; // x 104..105, y 56

    var hits = render(m);
    try testing.expectEqual(palette[1], pixel(m, 0, 0));
    try testing.expectEqual(palette[1], pixel(m, 23, 20));
    try testing.expectEqual(palette[0], pixel(m, 24, 0));
    try testing.expectEqual(palette[0], pixel(m, 0, 21));
    try testing.expectEqual(palette[2], pixel(m, 104, 56)); // in front of bitmap
    try testing.expectEqual(Hits{ .sprite_sprite = 0, .sprite_bitmap = 0b10 }, hits);

    // Behind the bitmap: the foreground pixel shows through, still a hit.
    m.ram[hw.sprite_behind] = 0b10;
    hits = render(m);
    try testing.expectEqual(palette[5], pixel(m, 104, 56));
    try testing.expectEqual(palette[2], pixel(m, 106, 56));

    // Overlap the two sprites by one pixel column.
    m.ram[hw.spriteX(1)] = sprite_origin_x + 23;
    m.ram[hw.spriteY(1)] = sprite_origin_y + 20;
    hits = render(m);
    try testing.expectEqual(0b11, hits.sprite_sprite);
    try testing.expectEqual(palette[1], pixel(m, 23, 20)); // sprite 0 in front
    m.ram[hw.spriteX(1)] = sprite_origin_x + 24;
    hits = render(m);
    try testing.expectEqual(0, hits.sprite_sprite);
}

test "multicolour and expanded sprites" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.ram[hw.sprite_data] = 0b01_10_11_00;
    m.ram[hw.spriteX(3)] = sprite_origin_x;
    m.ram[hw.spriteY(3)] = sprite_origin_y;
    m.ram[hw.spriteColor(3)] = 2;
    m.ram[hw.sprite_mc0] = 3;
    m.ram[hw.sprite_mc1] = 4;
    m.ram[hw.sprite_multicolor] = 1 << 3;
    m.ram[hw.sprite_double_width] = 1 << 3;
    m.ram[hw.sprite_double_height] = 1 << 3;
    m.ram[hw.sprite_enable] = 1 << 3;
    _ = render(m);

    const expected = [_]u8{ 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4, 0 };
    for (expected, 0..) |c, x| {
        try testing.expectEqual(palette[c], pixel(m, x, 0));
        try testing.expectEqual(palette[c], pixel(m, x, 1)); // doubled row
    }
    try testing.expectEqual(palette[0], pixel(m, 0, 2));
}

test "sprite X beyond 255 uses the MSB register" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.ram[hw.sprite_data] = 0x80;
    m.ram[hw.spriteX(0)] = 300 - 256;
    m.ram[hw.sprite_x_msb] = 1;
    m.ram[hw.spriteY(0)] = sprite_origin_y;
    m.ram[hw.spriteColor(0)] = 1;
    m.ram[hw.sprite_enable] = 1;
    _ = render(m);
    try testing.expectEqual(palette[1], pixel(m, 300 - sprite_origin_x, 0));
}

test "the meter shows the last frame's share of the budget" {
    const m = try newMachine();
    defer testing.allocator.destroy(m);

    m.last_cycles = machine.frame_budget / 2;
    _ = render(m);
    const row = meter_y * width + display_x;
    try testing.expectEqual(palette[13], m.screen[row + 159]);
    try testing.expectEqual(palette[0], m.screen[row + 161]);

    m.last_cycles = machine.frame_budget + 1;
    _ = render(m);
    try testing.expectEqual(palette[2], m.screen[row + 319]);
    try testing.expectEqual(palette[2], m.screen[stripe_y * width]);
}
