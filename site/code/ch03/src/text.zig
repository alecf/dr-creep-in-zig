//! Text: letters from the character ROM, blown up into the bitmap one
//! glyph bit to one fat pixel, and drawn through the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const screen = @import("screen.zig");

/// The glyph shape's pixels start after its width, height and flags.
const glyph_pixels = map.text_glyph + 3;

/// The style byte every castle Text object carries. Bits 0-1: how tall,
/// 1 to 3 times (0 counts as 1). Bit 4: reversed, light letters cut out
/// of a solid block. Bit 5 asks for the letters (rather than picture)
/// character set, which is the only one our ROM has; castles always set it.
pub const style_height: u8 = 0b0000_0011;
pub const style_reversed: u8 = 0b0001_0000;
pub const style_letters: u8 = 0b0010_0000;
pub const plain = style_letters | 1;

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
    m.poke(map.text_glyph + 2, 0); // no flags; the height depends on the style
}

/// Print the string at `addr` with its top-left corner at fat pixel
/// (x, y), in `style` (see `style_height`). Letters are 8 fat pixels wide.
/// The string ends at the first byte with bit 7 set, which is its last
/// letter; letters that would run off the right edge of the screen are
/// left out. Returns the address after the string.
pub fn draw(m: *Machine, x: u8, y: u8, color: Color, style: u8, addr: u16) u16 {
    const tall = @max(1, style & style_height); // each glyph row drawn this many times
    const flip: u8 = if (style & style_reversed != 0) 0xFF else 0x00;
    const rows = 8 * tall;
    m.poke(map.text_glyph + 1, rows);

    // Glyph pixels are code 01, whose colour is the high half of the
    // screen-plane byte. The glyph is 2 cells wide and `tall` cells high.
    const glyph_screen = glyph_pixels + 2 * @as(u16, rows);
    const glyph_colors = glyph_screen + 2 * @as(u16, tall);
    m.fill(glyph_screen, 2 * tall, @as(u8, @intFromEnum(color)) << 4);
    m.fill(glyph_colors, 2 * tall, 0);

    var at = addr;
    var left: u16 = x;
    while (true) : (left += 8) {
        const letter = m.peek(at);
        at += 1;
        if (left <= 160 - 8) {
            const glyph = m.charRom(letter & 0x7F);
            var dst: u16 = glyph_pixels;
            for (glyph) |row| {
                const bits = row ^ flip;
                const left_half = m.peek(map.text_widen + (bits >> 4));
                const right_half = m.peek(map.text_widen + (bits & 0x0F));
                for (0..tall) |_| {
                    m.poke(dst, left_half);
                    m.poke(dst + 1, right_half);
                    dst += 2;
                }
                m.work(10 + 4 * @as(u32, tall)); // the shift, the mask, the loops
            }
            screen.drawShape(m, .glyph, @intCast(left), y);
        }
        if (letter & 0x80 != 0) return at;
    }
}

/// Print a string from the program: copy it into the text buffer, then
/// draw it from there.
pub fn say(m: *Machine, x: u8, y: u8, color: Color, comptime words: []const u8) void {
    const bytes = comptime terminated(words);
    m.load(map.text_buffer, &bytes);
    _ = draw(m, x, y, color, plain, map.text_buffer);
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
