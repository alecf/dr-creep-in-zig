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

/// Every shape, by ID. Each name except `glyph` has a picture of the same
/// name in art.zig.
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
fn pack(comptime name: []const u8, comptime a: Art) []const u8 {
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
        @setEvalBranchQuota(200_000);
        const ids = std.enums.values(Id);
        var directory: []const u8 = &.{};
        var shapes: []const u8 = &.{};
        var at: u16 = map.shape_table.first + ids.len * 2;
        for (ids) |id| {
            // The glyph is built at run time, in the text region.
            const where = if (id == .glyph) map.text_glyph else at;
            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first
            if (id == .glyph) continue;
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
