//! The room: for now, a floor along the bottom of the screen.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;

/// The floor is the bottom row of cells, row 24 of 0-24.
const floor_row = 24;
const cells_per_row = 40;
const bytes_per_cell = 8;

/// Display row (0-199) of the floor's top line.
pub const floor_top = floor_row * 8; // 192

/// Where the floor starts in the bitmap and in colour RAM.
const floor_pixels = hw.bitmap + floor_row * cells_per_row * bytes_per_cell; // $FE00
const floor_colors = hw.color_ram + floor_row * cells_per_row; // $DBC0

pub fn paint(m: *Machine) void {
    // $FF gives all four pixels of a bitmap byte the code 11, and code 11
    // pixels take their colour from colour RAM.
    m.fill(floor_pixels, cells_per_row * bytes_per_cell, 0xFF);
    m.fill(floor_colors, cells_per_row, @intFromEnum(Color.grey));
}
