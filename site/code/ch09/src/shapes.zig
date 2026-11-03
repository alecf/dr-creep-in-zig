//! The shape table: every picture in the game (room pieces, letters and
//! sprite frames) in one table, found by ID.
//!
//! In memory the table starts with a directory, a two-byte pointer per
//! shape, and then the shapes themselves. Each shape is
//!
//!   width (bytes)  height (rows)  flags  pixels: width * height bytes
//!
//! and a room shape then carries its colours: one screen-plane byte per
//! cell, then one colour-RAM byte per cell, width * ceil(height / 8) each.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const art = @import("art.zig");

/// Every shape, by ID. Each name except `glyph` and `image` has a picture
/// of the same name in art.zig. New shapes go at the end: the walk counts
/// on the explorer's frames being in a row, and IDs are stored in castles.
pub const Id = enum(u8) {
    glyph, // built by text.zig, one letter at a time
    walkway,
    walkway_left,
    walkway_right,
    ladder,
    pole,
    door,
    window,
    torch,
    moon,
    tower,
    wall,
    explorer_right_0,
    explorer_right_1,
    explorer_right_2,
    explorer_right_3,
    explorer_left_0,
    explorer_left_1,
    explorer_left_2,
    explorer_left_3,
    door_frame,
    exit_frame,
    door_shut,
    door_open,
    bell,
    image, // points into the castle, at whichever image is being drawn
    explorer_climb_0,
    explorer_climb_1,
    explorer_climb_2,
    explorer_climb_3,
    explorer_slide,
    explorer_back_0,
    explorer_back_1,
    machine_pole,
    machine_tip,
    bolt_0,
    bolt_1,
    bolt_2,
    bolt_3,
    lever_plate,
    lever_up,
    lever_down,
    button_frame,
    button_lit,
    field_top,
    field_on_0,
    field_on_1,
    field_off,
    trapdoor_shut,
    trapdoor_tilt,
    trapdoor_open,
    plate,
    belt,
    control,
    control_knob,
    booth,
    lamp,
    pad,
    key,
    lock,
    track,
    gun_right_0,
    gun_right_1,
    gun_right_2,
    gun_right_3,
    gun_left_0,
    gun_left_1,
    gun_left_2,
    gun_left_3,
    panel,
    laser,
    brick,
    tomb_open,
    ankh,
    mummy_rise_0,
    mummy_rise_1,
    mummy_rise_2,
    mummy_right_0,
    mummy_right_1,
    mummy_right_2,
    mummy_left_0,
    mummy_left_1,
    mummy_left_2,
    alcove_right,
    alcove_left,
    frank_asleep,
    frank_right_0,
    frank_right_1,
    frank_right_2,
    frank_left_0,
    frank_left_1,
    frank_left_2,
    frank_climb_0,
    frank_climb_1,
    frank_climb_2,
    frank_climb_3,
    frank_slide,
    map_floor,
    map_top,
    map_bottom,
    map_left,
    map_right,
    arrow_down,
    arrow_up,
    arrow_right,
    arrow_left,
    explorer_cheer_0,
    explorer_cheer_1,
};

/// A picture as art.zig draws it: one string per row, one character per
/// fat pixel. '.' is code 00, and '1', '2', '3' are codes 01, 10, 11.
pub const Art = struct {
    flags: u8 = 0,
    /// Room shapes: the colours for codes 01, 10 and 11. Sprite frames
    /// have none (their colours are the sprite's).
    colors: ?[3]Color = null,
    rows: []const []const u8,
};

/// A room shape: drawn into the bitmap, with these colours in every cell.
pub fn room(colors: [3]Color, rows: []const []const u8) Art {
    return .{ .colors = colors, .rows = rows };
}

/// A sprite frame: a multicolour sprite picture, at most 12 fat pixels
/// wide and 21 rows tall. Code 10 takes the sprite's own colour.
pub fn frame(color: Color, rows: []const []const u8) Art {
    return .{ .flags = @intFromEnum(color), .rows = rows };
}

/// The same picture facing the other way.
pub fn mirror(comptime a: Art) Art {
    comptime {
        var rows: [a.rows.len][]const u8 = undefined;
        for (a.rows, 0..) |row, r| {
            var flipped: [row.len]u8 = undefined;
            for (row, 0..) |ch, i| flipped[row.len - 1 - i] = ch;
            const done = flipped;
            rows[r] = &done;
        }
        const done = rows;
        return .{ .flags = a.flags, .colors = a.colors, .rows = &done };
    }
}

/// Turn a picture into the bytes the shape table holds. Every mistake in
/// the art is a compile error.
pub fn pack(comptime name: []const u8, comptime a: Art) []const u8 {
    comptime {
        const height = a.rows.len;
        const pixels = a.rows[0].len;
        if (pixels % 4 != 0)
            @compileError(std.fmt.comptimePrint("shape {s}: {d} fat pixels wide; shapes are whole bytes of 4", .{ name, pixels }));
        const width = pixels / 4;
        if (a.colors == null and (width > 3 or height > 21))
            @compileError("shape " ++ name ++ ": sprite frames are at most 12 fat pixels by 21 rows");

        var out: []const u8 = &.{ width, height, a.flags };
        for (a.rows, 0..) |row, r| {
            if (row.len != pixels)
                @compileError(std.fmt.comptimePrint("shape {s}: row {d} is {d} fat pixels wide, not {d}", .{ name, r, row.len, pixels }));
            for (0..width) |b| {
                var byte: u8 = 0;
                for (row[b * 4 ..][0..4]) |ch| {
                    const code: u8 = switch (ch) {
                        '.' => 0b00,
                        '1' => 0b01,
                        '2' => 0b10,
                        '3' => 0b11,
                        else => @compileError(std.fmt.comptimePrint("shape {s}: row {d} has '{c}'; use . 1 2 3", .{ name, r, ch })),
                    };
                    byte = byte << 2 | code; // leftmost pixel ends up in the top bits
                }
                out = out ++ [_]u8{byte};
            }
        }

        if (a.colors) |c| {
            const cells = width * ((height + 7) / 8);
            const screen_byte = @as(u8, @intFromEnum(c[0])) << 4 | @intFromEnum(c[1]);
            out = out ++ [_]u8{screen_byte} ** cells ++ [_]u8{@intFromEnum(c[2])} ** cells;
        }
        return out;
    }
}

/// The whole table, directory first, built while the game compiles. The
/// pointers in the directory are addresses in the Comet 64's memory:
/// where each shape will be once boot copies the table into place.
pub const table: []const u8 = build();

fn build() []const u8 {
    comptime {
        @setEvalBranchQuota(200_000); // compile-time loops are capped; this raises the cap
        const ids = std.enums.values(Id);
        var directory: []const u8 = &.{};
        var shapes: []const u8 = &.{};
        var at: u16 = map.shape_table.first + ids.len * 2;
        for (ids) |id| {
            // The glyph is built at run time, in the text region, and
            // `image` is pointed at a picture in the castle when one is drawn.
            const where = switch (id) {
                .glyph => map.text_glyph,
                .image => 0,
                else => at,
            };
            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first
            if (id == .glyph or id == .image) continue;
            const bytes = pack(@tagName(id), @field(art, @tagName(id)));
            shapes = shapes ++ bytes;
            at += bytes.len;
        }
        const all = directory ++ shapes;
        if (all.len > map.shape_table.last - map.shape_table.first + 1)
            @compileError("the shape table doesn't fit in its region");
        const done = all[0..all.len].*;
        return &done;
    }
}

/// Where shape `id` lives: follow its pointer in the directory.
pub fn address(m: *Machine, id: Id) u16 {
    m.work(4); // doubling the ID
    return m.peek16(map.shape_table.first + @as(u16, @intFromEnum(id)) * 2);
}

/// Point shape `id`'s directory entry at the shape stored at `at`.
pub fn point(m: *Machine, id: Id, at: u16) void {
    m.work(4); // doubling the ID
    m.poke16(map.shape_table.first + @as(u16, @intFromEnum(id)) * 2, at);
}

/// Repaint room shape `id`: every one of its screen-plane bytes becomes
/// `colors`, the two colours for codes 01 and 10.
pub fn recolor(m: *Machine, id: Id, colors: u8) void {
    const at = address(m, id);
    const width = m.peek(at);
    const height = m.peek(at + 1);
    const pixels = m.mul8(width, height);
    const cells = m.mul8(width, (height + 7) / 8);
    m.fill(at + 3 + pixels, cells, colors);
}

test "a picture packs into width, height, flags, pixels and colours" {
    const bytes = comptime pack("test", room(.{ .red, .green, .blue }, &.{
        "123.....",
        "33333333",
    }));
    try std.testing.expectEqualSlices(u8, &.{
        2, 2, 0, // 2 bytes wide, 2 rows, no flags
        0b01_10_11_00, 0b00_00_00_00, // row 0
        0b11_11_11_11, 0b11_11_11_11, // row 1
        0x25, 0x25, // screen plane, per cell: red (2) high, green (5) low
        0x06, 0x06, // colour RAM, per cell: blue (6)
    }, bytes);
}
