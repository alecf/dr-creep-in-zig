//! Sprite frames: pictures in the shape table, unpacked into a sprite
//! block when they're needed.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const video = machine.video;
const shapes = @import("shapes.zig");

/// A sprite frame's flags byte.
pub const flag_color: u8 = 0b0000_1111; // the sprite's own colour
pub const flag_hires: u8 = 0b0001_0000; // set: hires; clear: multicolour
pub const flag_behind: u8 = 0b0010_0000; // goes behind foreground pixels
pub const flag_tall: u8 = 0b0100_0000; // double height
pub const flag_wide: u8 = 0b1000_0000; // double width

/// Unpack sprite frame `id` into sprite block `block`: three bytes a row
/// for 21 rows, with see-through filling whatever the frame doesn't
/// cover. Returns the frame's flags.
pub fn unpack(m: *Machine, id: shapes.Id, block: u8) u8 {
    var src = shapes.address(m, id);
    const width = m.peek(src);
    const height = m.peek(src + 1);
    const flags = m.peek(src + 2);
    src += 3;

    var dst = hw.sprite_data + @as(u16, block) * 64;
    var row: u8 = 0;
    while (row < 21) : (row += 1) {
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            m.poke(dst + i, if (i < width and row < height) m.peek(src + i) else 0);
        }
        if (row < height) src += width;
        dst += 3;
        m.work(8); // the tests and the loop
    }
    return flags;
}

/// Put sprite `n`'s top-left corner at castle point (x, y). A fat pixel is
/// two of the VIDEO chip's pixels and castle X 16 is its X 24, so its X
/// is 2x - 8: up to 344, a nine-bit number. The ninth bit goes in $D010.
pub fn place(m: *Machine, n: u3, x: u8, y: u8) void {
    const sx = @as(u16, x) * 2 - 8;
    const bit = @as(u8, 1) << n;
    const others = m.peek(hw.sprite_x_msb) & ~bit;
    m.poke(hw.spriteX(n), @truncate(sx)); // the low eight bits
    m.poke(hw.sprite_x_msb, if (sx > 0xFF) others | bit else others);
    m.poke(hw.spriteY(n), y + video.sprite_origin_y);
    m.work(20); // the doubling, the masks and the test
}

// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "castle X becomes sprite X, ninth bit and all" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    m.ram[hw.sprite_x_msb] = 0b1000_0010; // other sprites' ninth bits
    place(m, 0, 16, 0); // the left edge
    try std.testing.expectEqual(24, m.ram[hw.spriteX(0)]);
    try std.testing.expectEqual(0b1000_0010, m.ram[hw.sprite_x_msb]);
    try std.testing.expectEqual(50, m.ram[hw.spriteY(0)]);
    place(m, 0, 131, 171); // sprite X 254: the last before the old wall
    try std.testing.expectEqual(254, m.ram[hw.spriteX(0)]);
    try std.testing.expectEqual(0b1000_0010, m.ram[hw.sprite_x_msb]);
    place(m, 0, 169, 171); // sprite X 330 = 256 + 74
    try std.testing.expectEqual(74, m.ram[hw.spriteX(0)]);
    try std.testing.expectEqual(0b1000_0011, m.ram[hw.sprite_x_msb]);
    try std.testing.expectEqual(221, m.ram[hw.spriteY(0)]);
    place(m, 1, 20, 0); // sprite 1's bit, and only its bit, goes off
    try std.testing.expectEqual(0b1000_0001, m.ram[hw.sprite_x_msb]);
}
