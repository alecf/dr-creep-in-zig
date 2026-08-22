//! VIC-II frame renderer: given machine RAM + VIC registers, produce a
//! 320x200 RGBA image. This is an "outputs" emulation — one render per
//! frame from final register state, no cycle-level fetch pipeline. Good
//! enough for Dr. Creep, which does not change display registers
//! mid-frame (its raster IRQ is used for pacing and music).

const std = @import("std");
const machine_mod = @import("machine.zig");
const Machine = machine_mod.Machine;

pub const WIDTH = 320;
pub const HEIGHT = 200;

/// Pepto's measured C64 palette, RGBA little-endian (abgr in u32).
pub const PALETTE = [16]u32{
    0xFF000000, // black
    0xFFFFFFFF, // white
    0xFF2B3768, // red
    0xFFB2A470, // cyan
    0xFF863D6F, // purple
    0xFF438D58, // green
    0xFF792835, // blue
    0xFF6FC7B8, // yellow
    0xFF254F6F, // orange
    0xFF003943, // brown
    0xFF59679A, // light red
    0xFF444444, // dark grey
    0xFF6C6C6C, // grey
    0xFF84D29A, // light green
    0xFFB55E6C, // light blue
    0xFF959595, // light grey
};

pub fn renderFrame(m: *Machine, fb: *[WIDTH * HEIGHT]u32) void {
    const d011 = m.vic[0x11];
    const d016 = m.vic[0x16];
    const bmm = d011 & 0x20 != 0;
    const ecm = d011 & 0x40 != 0;
    const mcm = d016 & 0x10 != 0;
    const den = d011 & 0x10 != 0;

    const bg0 = PALETTE[m.vic[0x21] & 0x0F];
    if (!den) {
        @memset(fb, bg0);
        return;
    }

    const bank = m.vicBank();
    const screen_base: u16 = bank + (@as(u16, m.vic[0x18] >> 4)) * 0x0400;
    const char_base: u16 = bank + (@as(u16, (m.vic[0x18] >> 1) & 0x07)) * 0x0800;
    const bitmap_base: u16 = bank + (@as(u16, (m.vic[0x18] >> 3) & 0x01)) * 0x2000;

    var cy: usize = 0;
    while (cy < 25) : (cy += 1) {
        var cx: usize = 0;
        while (cx < 40) : (cx += 1) {
            const cell = cy * 40 + cx;
            const screen_byte = m.vicRead(@intCast(screen_base + cell));
            const color_byte = m.color_ram[cell] & 0x0F;

            var row: usize = 0;
            while (row < 8) : (row += 1) {
                const bits: u8 = if (bmm)
                    m.vicRead(@intCast(bitmap_base + cell * 8 + row))
                else
                    m.vicRead(char_base +% @as(u16, screen_byte) * 8 +% @as(u16, @intCast(row)));

                const py = cy * 8 + row;
                const px0 = cx * 8;

                if (bmm and mcm) {
                    // multicolor bitmap: 00=bg0, 01=screen hi, 10=screen lo, 11=color ram
                    var p: usize = 0;
                    while (p < 4) : (p += 1) {
                        const duo: u2 = @intCast((bits >> @intCast(6 - p * 2)) & 3);
                        const col = switch (duo) {
                            0 => bg0,
                            1 => PALETTE[screen_byte >> 4],
                            2 => PALETTE[screen_byte & 0x0F],
                            3 => PALETTE[color_byte],
                        };
                        fb[py * WIDTH + px0 + p * 2] = col;
                        fb[py * WIDTH + px0 + p * 2 + 1] = col;
                    }
                } else if (bmm) {
                    // hires bitmap: 0=screen lo nybble, 1=screen hi nybble
                    var p: usize = 0;
                    while (p < 8) : (p += 1) {
                        const bit = (bits >> @intCast(7 - p)) & 1;
                        fb[py * WIDTH + px0 + p] =
                            if (bit != 0) PALETTE[screen_byte >> 4] else PALETTE[screen_byte & 0x0F];
                    }
                } else if (mcm and color_byte & 0x08 != 0) {
                    // multicolor text (color RAM bit 3 set)
                    const mc = [4]u32{
                        bg0,
                        PALETTE[m.vic[0x22] & 0x0F],
                        PALETTE[m.vic[0x23] & 0x0F],
                        PALETTE[color_byte & 0x07],
                    };
                    var p: usize = 0;
                    while (p < 4) : (p += 1) {
                        const duo: u2 = @intCast((bits >> @intCast(6 - p * 2)) & 3);
                        fb[py * WIDTH + px0 + p * 2] = mc[duo];
                        fb[py * WIDTH + px0 + p * 2 + 1] = mc[duo];
                    }
                } else {
                    // standard (or ECM) text
                    const cell_bg = if (ecm)
                        PALETTE[m.vic[0x21 + @as(u8, screen_byte >> 6)] & 0x0F]
                    else
                        bg0;
                    var p: usize = 0;
                    while (p < 8) : (p += 1) {
                        const bit = (bits >> @intCast(7 - p)) & 1;
                        fb[py * WIDTH + px0 + p] =
                            if (bit != 0) PALETTE[color_byte] else cell_bg;
                    }
                }
            }
        }
    }

    renderSprites(m, fb, screen_base);
}

fn renderSprites(m: *Machine, fb: *[WIDTH * HEIGHT]u32, screen_base: u16) void {
    const bank = m.vicBank();
    // sprite 0 has highest priority: draw 7..0 so lower numbers overwrite
    var i: usize = 8;
    while (i > 0) {
        i -= 1;
        const mask = @as(u8, 1) << @intCast(i);
        if (m.vic[0x15] & mask == 0) continue;

        const ptr = m.vicRead(@intCast(screen_base + 0x03F8 + i));
        const data_base = bank + @as(u16, ptr) * 64;
        const sx_raw = @as(i32, m.vic[i * 2]) + if (m.vic[0x10] & mask != 0) @as(i32, 256) else 0;
        const sy = @as(i32, m.vic[i * 2 + 1]);
        // sprite coordinate origin: x=24, y=50 is the screen top-left
        const px = sx_raw - 24;
        const py = sy - 50;
        const x_exp = m.vic[0x1D] & mask != 0;
        const y_exp = m.vic[0x17] & mask != 0;
        const multi = m.vic[0x1C] & mask != 0;
        const col = PALETTE[m.vic[0x27 + i] & 0x0F];
        const mc0 = PALETTE[m.vic[0x25] & 0x0F];
        const mc1 = PALETTE[m.vic[0x26] & 0x0F];

        var row: i32 = 0;
        while (row < 21) : (row += 1) {
            var rep_y: i32 = 0;
            const reps_y: i32 = if (y_exp) 2 else 1;
            while (rep_y < reps_y) : (rep_y += 1) {
                const y = py + row * reps_y + rep_y;
                if (y < 0 or y >= HEIGHT) continue;
                var byte_i: i32 = 0;
                while (byte_i < 3) : (byte_i += 1) {
                    const bits = m.vicRead(data_base +% @as(u16, @intCast(row * 3 + byte_i)));
                    if (multi) {
                        var p: i32 = 0;
                        while (p < 4) : (p += 1) {
                            const duo: u2 = @intCast((bits >> @intCast(6 - p * 2)) & 3);
                            if (duo == 0) continue;
                            const c = switch (duo) {
                                1 => mc0,
                                2 => col,
                                3 => mc1,
                                else => unreachable,
                            };
                            const base_x = px + (byte_i * 8 + p * 2) * (if (x_exp) @as(i32, 2) else 1);
                            const w: i32 = if (x_exp) 4 else 2;
                            var dx: i32 = 0;
                            while (dx < w) : (dx += 1) {
                                const x = base_x + dx;
                                if (x >= 0 and x < WIDTH) fb[@intCast(y * WIDTH + x)] = c;
                            }
                        }
                    } else {
                        var p: i32 = 0;
                        while (p < 8) : (p += 1) {
                            if ((bits >> @intCast(7 - p)) & 1 == 0) continue;
                            const base_x = px + (byte_i * 8 + p) * (if (x_exp) @as(i32, 2) else 1);
                            const w: i32 = if (x_exp) 2 else 1;
                            var dx: i32 = 0;
                            while (dx < w) : (dx += 1) {
                                const x = base_x + dx;
                                if (x >= 0 and x < WIDTH) fb[@intCast(y * WIDTH + x)] = col;
                            }
                        }
                    }
                }
            }
        }
    }
}
