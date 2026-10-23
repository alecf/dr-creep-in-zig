//! The Entrance Hall from Chapter 2 as a one-room castle, typed in by
//! hand, byte by byte.

/// The whole castle file, ready to load at $7800.
pub const bytes = &(header ++ directory ++ hall);

const header = [_]u8{
    0x54, 0x01, // the castle is $0154 bytes long, header and all
    0x80, // "this is a castle"
    0, 0, // both players start in room 0...
    0, 0, // ...at its door 0...
    3, 3, // ...with three lives each
} ++ [_]u8{0} ** (0x5F - 9) ++ [_]u8{ 0x00, 0x00 } // $785F: no final room
++ [_]u8{0} ** (0x100 - 0x61);

const directory = [_]u8{
    0x02, // red, and bit 6 is clear: this is a room, not the end
    56, 48, // its place on the castle map
    0b00_100_011, // 4 map cells wide, 3 tall
    0x0B, 0x79, // skip: $790B
    0x09, 0x79, // its objects start at $7909, right after the end byte
    0xFF, // the end of the directory, and no final room
};

/// The Entrance Hall's objects.
const hall = [_]u8{
    0x03, 0x08, 2, // doors: two of them
    32, 40, 3, 0, 1, 0, 6, 0, // upper left, leading to door 1
    152, 96, 1, 0, 0, 14, 13, 0, // middle right, leading to door 0
    0x06, 0x08, // walkways
    15, 24, 72, // upper left
    17, 108, 128, // middle right
    40, 16, 192, // the floor
    0, // no more walkways
    0x09, 0x08, 16, 64, 72, 0, // one sliding pole
    0x0C, 0x08, 9, 120, 128, 0, // one ladder
    0x0F, 0x08, 1, 136, 104, 1, // one doorbell, for door 1
    0x33, 0x08, 28, 8, 15, 0x21, // text at (28, 8), light grey, plain
} ++ "THE ENTRANCE HAL".* ++ [_]u8{
    'L' | 0x80, // the last letter has bit 7 set
    0, // no more text
    0x00, 0x00, // the end of the room
};

// ---- the same hall, written with the kit ------------------------------------

const std = @import("std");
const author = @import("author.zig");

const Room = enum { hall };

const plan: author.Castle(Room) = .{
    .start = .{ .room = .hall },
    .rooms = .{ .hall = .{
        .color = .red,
        .map = .{ .x = 56, .y = 48, .width = 4, .height = 3 },
        .door = &.{
            .{ .x = 32, .y = 40, .to = .hall, .to_door = 1 },
            .{ .x = 152, .y = 96, .to = .hall, .to_door = 0 },
        },
        .walkway = &.{
            .{ .length = 15, .x = 24, .y = 72 },
            .{ .length = 17, .x = 108, .y = 128 },
            .{ .length = 40, .x = 16, .y = 192 },
        },
        .pole = &.{.{ .length = 16, .x = 64, .y = 72 }},
        .ladder = &.{.{ .length = 9, .x = 120, .y = 128 }},
        .bell = &.{.{ .x = 136, .y = 104, .door = 1 }},
        .text = &.{.{ .x = 28, .y = 8, .color = .light_grey, .words = "THE ENTRANCE HALL" }},
    } },
};

test "the kit writes the castle you typed, byte for byte" {
    try std.testing.expectEqualSlices(u8, bytes, comptime author.build(Room, plan));
}
