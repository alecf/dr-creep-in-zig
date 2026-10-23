//! Sprite frames: pictures in the shape table, unpacked into a sprite
//! block when they're needed.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
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
