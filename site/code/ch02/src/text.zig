//! Text: letters from the character ROM, blown up into the bitmap one
//! glyph bit to one fat pixel, and drawn through the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const screen = @import("screen.zig");

/// The glyph shape's pixels start after its width, height and flags.
const glyph_pixels = map.text_glyph + 3;
const glyph_screen = glyph_pixels + 2 * 8; // then two screen-plane bytes
const glyph_colors = glyph_screen + 2; // and two colour-RAM bytes

/// Build the widen table, and the glyph shape's header.
pub fn start(m: *Machine) void {
    // Entry n is four glyph bits (the bits of n) as four fat pixels: a 1
    // bit becomes code 01, a 0 bit code 00. So 0b1011 becomes 01 00 01 01.
    var n: u8 = 0;
    while (n < 16) : (n += 1) {
        var byte: u8 = 0;
        var bit: u3 = 4;
        while (bit > 0) {
            bit -= 1;
            byte = byte << 2 | ((n >> bit) & 1);
        }
        m.poke(map.text_widen + n, byte);
    }
    m.poke(map.text_glyph + 0, 2); // 2 bytes wide: 8 fat pixels
    m.poke(map.text_glyph + 1, 8); // 8 rows tall
    m.poke(map.text_glyph + 2, 0); // no flags
}

/// Print the string at `addr` with its top-left corner at fat pixel
/// (x, y). Letters are 8 fat pixels wide. The string ends at the first
/// byte with bit 7 set, which is its last letter.
pub fn draw(m: *Machine, x: u8, y: u8, color: Color, addr: u16) void {
    // Glyph pixels are code 01, whose colour is the high half of the
    // screen-plane byte.
    const ink = @as(u8, @intFromEnum(color)) << 4;
    m.poke(glyph_screen, ink);
    m.poke(glyph_screen + 1, ink);
    m.poke(glyph_colors, 0);
    m.poke(glyph_colors + 1, 0);

    var at = addr;
    var left = x;
    while (true) : ({
        at += 1;
        left += 8;
    }) {
        const letter = m.peek(at);
        const glyph = m.charRom(letter & 0x7F);
        var dst: u16 = glyph_pixels;
        for (glyph) |bits| {
            m.poke(dst, m.peek(map.text_widen + (bits >> 4))); // left half
            m.poke(dst + 1, m.peek(map.text_widen + (bits & 0x0F))); // right half
            dst += 2;
            m.work(10); // the shift, the mask, the loop
        }
        screen.drawShape(m, .glyph, left, y);
        if (letter & 0x80 != 0) break;
    }
}

/// Print a string from the program: copy it into the text buffer, then
/// draw it from there.
pub fn say(m: *Machine, x: u8, y: u8, color: Color, comptime words: []const u8) void {
    const bytes = comptime terminated(words);
    m.load(map.text_buffer, &bytes);
    draw(m, x, y, color, map.text_buffer);
}

/// `words` with bit 7 set on its last letter, the way the game stores
/// every string.
pub fn terminated(comptime words: []const u8) [words.len]u8 {
    comptime {
        if (words.len == 0) @compileError("an empty string has no last letter to mark");
        if (words.len > map.text_buffer_size) @compileError("\"" ++ words ++ "\" is too long for the text buffer");
        for (words) |c| {
            if (c >= 0x80) @compileError("\"" ++ words ++ "\" uses bit 7, which marks the end");
        }
    }
    var bytes = words[0..words.len].*;
    bytes[bytes.len - 1] |= 0x80;
    return bytes;
}

test "the last letter carries the end mark" {
    const std = @import("std");
    try std.testing.expectEqualSlices(u8, &.{ 'H', 'I', '!' | 0x80 }, &terminated("HI!"));
}
