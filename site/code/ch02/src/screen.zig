//! The bitmap: finding a pixel's byte, setting one fat pixel, and drawing
//! shapes from the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");
const shapes = @import("shapes.zig");

/// Build the row table: the address of the first byte of each of the 200
/// bitmap rows. Done once, at boot, without a single multiply.
pub fn start(m: *Machine) void {
    var addr: u16 = hw.bitmap;
    var y: u16 = 0;
    while (y < 200) : (y += 1) {
        m.poke16(map.row_table.first + y * 2, addr);
        // The next line down inside a cell is the next byte. Below a
        // cell's last line comes the top of the cell underneath, 320 bytes
        // on from this cell's top line: 313 on from its last.
        addr += if (y % 8 == 7) 313 else 1;
    }
}

/// The address of the first byte of bitmap row `y` (0-199).
pub fn rowAddress(m: *Machine, y: u8) u16 {
    m.work(4); // doubling y: one shift
    return m.peek16(map.row_table.first + @as(u16, y) * 2);
}

/// The bitmap byte that holds fat pixel (x, y). x runs 0-159.
fn pixelByte(m: *Machine, x: u8, y: u8) u16 {
    m.work(6); // x / 4 * 8: three shifts
    return rowAddress(m, y) + @as(u16, x / 4) * 8;
}

/// How far fat pixel x's two bits sit from the right of its byte: 6 for
/// the leftmost pixel of the four, then 4, 2 and 0.
fn pixelShift(x: u8) u3 {
    return @intCast(6 - (x % 4) * 2);
}

/// Set fat pixel (x, y) to colour code 0-3, leaving the other three
/// pixels in its byte alone.
pub fn plot(m: *Machine, x: u8, y: u8, code: u2) void {
    const addr = pixelByte(m, x, y);
    const shift = pixelShift(x);
    const mask = @as(u8, 0b11) << shift;
    const old = m.peek(addr);
    m.poke(addr, (old & ~mask) | @as(u8, code) << shift);
    m.work(12); // the shifts, the mask and the OR
}

/// The colour code (0-3) of fat pixel (x, y).
pub fn codeAt(m: *Machine, x: u8, y: u8) u2 {
    const addr = pixelByte(m, x, y);
    m.work(8); // the shift
    return @truncate(m.peek(addr) >> pixelShift(x));
}

/// Wipe the screen: every pixel code 00, every cell's colours 0.
pub fn clear(m: *Machine) void {
    m.fill(hw.bitmap, 8000, 0);
    m.fill(hw.screen, 1000, 0);
    m.fill(hw.color_ram, 1000, 0);
}

/// Draw shape `id` with its top-left corner at fat pixel (x, y). x is
/// rounded down to a multiple of 4, because shapes sit on whole bitmap
/// bytes. Anything past the right or bottom edge of the screen is cut off.
pub fn drawShape(m: *Machine, id: shapes.Id, x: u8, y: u8) void {
    var src = shapes.address(m, id);
    const width = m.peek(src);
    const height = m.peek(src + 1);
    src += 3; // past width, height and flags
    const column = x / 4;

    // The pixels, a row at a time, ORed over whatever is already there.
    var row: u16 = 0;
    while (row < height) : (row += 1) {
        const line = y + row;
        if (line < 200) {
            var dst = rowAddress(m, @intCast(line)) + @as(u16, column) * 8;
            var i: u16 = 0;
            while (i < width and column + i < 40) : (i += 1) {
                m.poke(dst, m.peek(dst) | m.peek(src + i));
                dst += 8; // the same line of the next cell along
                m.work(4);
            }
        }
        src += width;
    }

    // The colours: rows of cells, one screen-plane byte and one colour-RAM
    // byte per cell. A shape that doesn't start on a cell's top line
    // reaches one more row of cells, which gets the last row's colours.
    const cell_rows = (height + 7) / 8;
    const reach = cell_rows + @intFromBool(y % 8 != 0);
    const screen_src = src;
    const color_src = src + cell_rows * width;
    // The top line of a cell row is bitmap + row * 320; one eighth of
    // the distance from the bitmap's start is row * 40, the cell number.
    var cell = (rowAddress(m, y & 0b1111_1000) - hw.bitmap) / 8 + column;
    var r: u16 = 0;
    while (r < reach and y / 8 + r < 25) : (r += 1) {
        const from = @min(r, cell_rows - 1) * width;
        var i: u16 = 0;
        while (i < width and column + i < 40) : (i += 1) {
            m.poke(hw.screen + cell + i, m.peek(screen_src + from + i));
            m.poke(hw.color_ram + cell + i, m.peek(color_src + from + i));
            m.work(4);
        }
        cell += 40;
    }
}

// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "the row table agrees with the reference card's formula" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    for (0..200) |y| {
        const card: u16 = @intCast(hw.bitmap + (y / 8) * 320 + y % 8);
        try std.testing.expectEqual(card, rowAddress(m, @intCast(y)));
    }
}

test "plot sets one fat pixel and leaves its neighbours alone" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    m.ram[hw.bitmap + 8 + 3] = 0b11_11_11_11; // row 3 of cell 1: fat pixels 4-7
    plot(m, 6, 3, 0b01);
    try std.testing.expectEqual(0b11_11_01_11, m.ram[hw.bitmap + 8 + 3]);
    try std.testing.expectEqual(0b01, codeAt(m, 6, 3));
    try std.testing.expectEqual(0b11, codeAt(m, 7, 3));
}
