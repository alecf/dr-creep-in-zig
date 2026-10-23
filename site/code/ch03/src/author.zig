//! The castle-authoring kit: describe rooms as Zig declarations, and get
//! back the castle file's bytes, checked while the game compiles.

const std = @import("std");
const Color = @import("machine").Color;
const castle = @import("castle.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const map = @import("map.zig");

/// Where a room sits on the castle map: x and y like an object's, and
/// its size in map cells of 4 fat pixels by 8 rows.
pub const Map = struct { x: u8 = 0, y: u8 = 0, width: u3 = 0, height: u3 = 0 };

/// A door, and the door on the far side. `Name` is the castle's enum of
/// room names, so a door can only lead to a room that exists.
pub fn Door(comptime Name: type) type {
    return struct {
        x: u8,
        y: u8,
        to: Name,
        to_door: u8 = 0,
        open: bool = false,
        exit: bool = false, // the way out: it leads nowhere
    };
}

/// A doorbell, and which of the room's doors it opens (0 is the first).
pub const Bell = castle.Bell;
/// A walkway, ladder or pole: `length` pieces from (x, y).
pub const Run = castle.Run;

/// A line of text. `height` is 1, 2 or 3 times the usual 8 rows.
pub const Line = struct { x: u8, y: u8, color: Color = .white, height: u2 = 1, words: []const u8 };

pub const Spot = struct { x: u8, y: u8 };
pub const Teleport = struct { x: u8, y: u8, target: u8 = 0, pads: []const Spot };

/// A picture stored in the castle, and everywhere it's drawn.
pub const Image = struct { art: shapes.Art, at: []const Spot };

/// Everything one room holds. Each field is named after its `castle.Kind`.
pub fn Room(comptime Name: type) type {
    return struct {
        color: Color = .black,
        map: Map = .{},
        door: []const Door(Name) = &.{},
        walkway: []const Run = &.{},
        pole: []const Run = &.{},
        ladder: []const Run = &.{},
        bell: []const Bell = &.{},
        lightning: []const castle.Lightning = &.{},
        forcefield: []const castle.Forcefield = &.{},
        mummy: []const castle.Mummy = &.{},
        key: []const castle.Key = &.{},
        lock: []const castle.Lock = &.{},
        pattern: []const castle.Pattern = &.{},
        ray_gun: []const castle.RayGun = &.{},
        teleport: ?Teleport = null,
        trapdoor: []const castle.Trapdoor = &.{},
        conveyor: []const castle.Conveyor = &.{},
        frankenstein: []const castle.Frankenstein = &.{},
        text: []const Line = &.{},
        image: []const Image = &.{},
    };
}

/// A whole castle: one field in `rooms` for every tag of `Name`, in
/// `Name`'s order, and an optional final room that isn't on the map.
pub fn Castle(comptime Name: type) type {
    return struct {
        start: struct { room: Name, door: u8 = 0 },
        lives: u8 = 3,
        rooms: std.enums.EnumFieldStruct(Name, Room(Name), null),
        final: ?Room(Name) = null,
    };
}

/// The castle file: header, room directory, then every room's objects.
pub fn build(comptime Name: type, comptime c: Castle(Name)) []const u8 {
    comptime {
        @setEvalBranchQuota(2_000_000);
        const names = std.enums.values(Name);
        if (names.len == 0 or names.len > castle.max_rooms)
            fail("a castle has 1 to {d} rooms, not {d}", .{ castle.max_rooms, names.len });

        // Each room's object stream, checked as it's built.
        var streams: [names.len][]const u8 = undefined;
        for (names, 0..) |name, n| {
            const room = @field(c.rooms, @tagName(name));
            if (room.map.width == 0 or room.map.height == 0)
                fail("room {s}: give it a place and a size on the castle map", .{@tagName(name)});
            if (room.color == .black)
                fail("room {s}: a black room has invisible walkways", .{@tagName(name)});
            streams[n] = stream(Name, c, room, @tagName(name));
        }
        const final = if (c.final) |room| stream(Name, c, room, "final") else "";

        // Then lay them out: the directory and its end byte, then the
        // streams one after another.
        var at: u16 = castle.directory + names.len * @sizeOf(castle.Entry) + 1;
        var directory: []const u8 = &.{};
        for (names, 0..) |name, n| {
            const room = @field(c.rooms, @tagName(name));
            const entry = castle.Entry{
                .color = @intFromEnum(room.color),
                .map_x = room.map.x,
                .map_y = room.map.y,
                .size = .{ .width = room.map.width, .height = room.map.height },
                .skip = le(at + 2),
                .objects = le(at),
            };
            directory = directory ++ std.mem.asBytes(&entry);
            at += streams[n].len;
        }
        directory = directory ++ [_]u8{if (c.final == null) castle.end_plain else castle.end_with_final};
        const final_at: u16 = if (c.final == null) 0 else at;
        const total = castle.header_size + directory.len + streams_len(&streams) + final.len;

        const start = @intFromEnum(c.start.room);
        if (c.start.door >= @field(c.rooms, @tagName(c.start.room)).door.len)
            fail("the start room {s} has no door {d}", .{ @tagName(c.start.room), c.start.door });
        if (total > map.castle.last - map.castle.first + 1)
            fail("the castle is {d} bytes; its region holds {d}", .{ total, map.castle.last - map.castle.first + 1 });

        var head = [_]u8{0} ** castle.header_size;
        head[0..2].* = le(total);
        head[2] = castle.magic_value;
        head[3..9].* = .{ start, start, c.start.door, c.start.door, c.lives, c.lives };
        head[0x5F..0x61].* = le(final_at);

        var all: []const u8 = &head;
        all = all ++ directory;
        for (streams) |s| all = all ++ s;
        all = all ++ final;
        const done = all[0..all.len].*;
        return &done;
    }
}

fn streams_len(streams: []const []const u8) usize {
    var n: usize = 0;
    for (streams) |s| n += s.len;
    return n;
}

/// One room's object stream, in tag order, which is also a good order
/// to draw in: doors and floors first, text and pictures last.
fn stream(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime name: []const u8) []const u8 {
    var out: []const u8 = &.{};
    var boxes: []const Box = &.{};
    for (std.enums.values(castle.Kind)) |kind| {
        const list = @field(room, @tagName(kind));
        const tag = le(castle.code(kind));
        switch (kind) {
            .door => if (list.len > 0) {
                out = out ++ tag ++ [_]u8{list.len};
                for (list, 0..) |d, i| {
                    const where = std.fmt.comptimePrint("room {s}: door {d}", .{ name, i });
                    spot(where, d.x, d.y, 20, 32);
                    if (d.y % 8 != 0) fail("{s} has y {d}; doors sit on cell rows (a multiple of 8)", .{ where, d.y });
                    boxes = boxes ++ [_]Box{.{ .what = where, .x = d.x, .y = d.y, .w = 20, .h = 32 }};
                    out = out ++ std.mem.asBytes(&door(Name, c, room, name, d, i));
                }
            },
            .bell => if (list.len > 0) {
                out = out ++ tag ++ [_]u8{list.len};
                for (list, 0..) |b, i| {
                    const where = std.fmt.comptimePrint("room {s}: bell {d}", .{ name, i });
                    spot(where, b.x, b.y, 8, 16);
                    if (b.door >= room.door.len) fail("{s} rings door {d}, and the room has {d}", .{ where, b.door, room.door.len });
                    boxes = boxes ++ [_]Box{.{ .what = where, .x = b.x, .y = b.y, .w = 8, .h = 16 }};
                    out = out ++ std.mem.asBytes(&b);
                }
            },
            .walkway, .pole, .ladder => if (list.len > 0) {
                out = out ++ tag;
                for (list, 0..) |r, i| {
                    const where = std.fmt.comptimePrint("room {s}: {s} {d}", .{ name, @tagName(kind), i });
                    if (r.length == 0) fail("{s} has length 0, which is the end marker", .{where});
                    if (kind == .walkway) {
                        spot(where, r.x, r.y, 4 * @as(u16, r.length), 7);
                    } else {
                        spot(where, r.x, r.y, 4, 8 * @as(u16, r.length));
                        const bottom = r.y + 8 * (r.length - 1);
                        if (!onWalkway(room, r.x, r.y) or !onWalkway(room, r.x, bottom))
                            fail("{s} must start and end on a walkway (rows {d} and {d})", .{ where, r.y, bottom });
                    }
                    out = out ++ std.mem.asBytes(&r);
                }
                out = out ++ [_]u8{0};
            },
            .text => if (list.len > 0) {
                out = out ++ tag;
                for (list, 0..) |line, i| {
                    const where = std.fmt.comptimePrint("room {s}: text {d} (\"{s}\")", .{ name, i, line.words });
                    if (line.height == 0) fail("{s} has height 0", .{where});
                    spot(where, line.x, line.y, 8 * @as(u16, line.words.len), 8 * @as(u16, line.height));
                    boxes = boxes ++ [_]Box{.{ .what = where, .x = line.x, .y = line.y, .w = 8 * line.words.len, .h = 8 * @as(u16, line.height) }};
                    const record = castle.Text{ .x = line.x, .y = line.y, .color = @intFromEnum(line.color), .style = text.style_letters | line.height };
                    out = out ++ std.mem.asBytes(&record) ++ &text.terminated(line.words);
                }
                out = out ++ [_]u8{0};
            },
            .teleport => if (list) |t| {
                out = out ++ tag ++ [_]u8{ t.x, t.y, t.target };
                for (t.pads) |p| out = out ++ [_]u8{ p.x, p.y };
                out = out ++ [_]u8{0};
            },
            .image => for (list, 0..) |picture, i| {
                const bytes = shapes.pack(std.fmt.comptimePrint("{s} image {d}", .{ name, i }), picture.art);
                out = out ++ tag ++ bytes;
                for (picture.at) |p| {
                    const where = std.fmt.comptimePrint("room {s}: image {d} at ({d}, {d})", .{ name, i, p.x, p.y });
                    spot(where, p.x, p.y, 4 * @as(u16, bytes[0]), bytes[1]);
                    boxes = boxes ++ [_]Box{.{ .what = where, .x = p.x, .y = p.y, .w = 4 * @as(u16, bytes[0]), .h = bytes[1] }};
                    out = out ++ [_]u8{ p.x, p.y };
                }
                out = out ++ [_]u8{0};
            },
            // The machines and monsters: their records go in as written.
            else => if (list.len > 0) {
                const f = castle.framing(kind).marked;
                out = out ++ tag;
                for (list, 0..) |r| {
                    const bytes = std.mem.asBytes(&r);
                    if (castle.isEnd(bytes[0], f.end))
                        fail("room {s}: a {s} whose first byte is {d} reads as the end marker", .{ name, @tagName(kind), bytes[0] });
                    out = out ++ bytes;
                }
                out = out ++ [_]u8{if (f.end == 0) 0 else f.end};
            },
        }
    }
    for (boxes, 0..) |a, i| {
        for (boxes[i + 1 ..]) |b| {
            if (a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h)
                fail("{s} overlaps {s}", .{ a.what, b.what });
        }
    }
    return out ++ le(castle.end_code);
}

/// The 8 bytes of door `i`: where it leads, and where it is on the map.
fn door(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime name: []const u8, comptime d: Door(Name), comptime i: usize) castle.Door {
    const there = @field(c.rooms, @tagName(d.to));
    if (!d.exit) {
        if (d.to_door >= there.door.len)
            fail("room {s}: door {d} leads to door {d} of {s}, which has {d}", .{ name, i, d.to_door, @tagName(d.to), there.door.len });
        const back = there.door[d.to_door];
        if (!std.mem.eql(u8, @tagName(back.to), name) or back.to_door != i)
            fail("room {s}: door {d} leads to {s} door {d}, which doesn't lead back", .{ name, i, @tagName(d.to), d.to_door });
    }
    // Which wall of the room it's in, on the map: towards the room it leads to.
    const here = room.map;
    const side: u8 = if (there.map.x >= here.x + 4 * @as(u16, here.width)) 1 // right
        else if (there.map.x + 4 * @as(u16, there.map.width) <= here.x) 3 // left
        else if (there.map.y + 8 * @as(u16, there.map.height) <= here.y) 0 // up
        else if (there.map.y >= here.y + 8 * @as(u16, here.height)) 2 // down
        else if (d.x < 96) 3 else 1; // the exit leads out of its own room
    const cols = 4 * @as(u16, here.width);
    const rows = 8 * @as(u16, here.height);
    return .{
        .x = d.x,
        .y = d.y,
        .side = side | (if (d.open) castle.door_open else 0),
        .to_room = @intFromEnum(d.to),
        .to_door = d.to_door,
        .map_x = if (side == 0 or side == 2) @min(cols - 4, (d.x - 16) * cols / 160) else 0,
        .map_y = if (side == 1 or side == 3) @min(rows - 3, (@as(u16, d.y) + 16) * rows / 200) else 0,
        .exit = @intFromBool(d.exit),
    };
}

/// A rectangle something covers on screen, for the overlap check.
const Box = struct { what: []const u8, x: u16, y: u16, w: u16, h: u16 };

/// Check that something w fat pixels by h rows at (x, y) is on screen
/// and sits on whole bytes.
fn spot(comptime where: []const u8, x: u16, y: u16, w: u16, h: u16) void {
    if (x < 16 or x + w > 16 + 160) fail("{s} runs off the screen (x {d} to {d}; the screen is 16 to 175)", .{ where, x, x + w - 1 });
    if (x % 4 != 0) fail("{s} has x {d}, which isn't on a byte; use a multiple of 4", .{ where, x });
    if (y + h > 200) fail("{s} runs off the bottom of the screen (rows {d} to {d})", .{ where, y, y + h - 1 });
}

/// Is there a walkway along row `y` under fat pixel `x`?
fn onWalkway(comptime room: anytype, x: u16, y: u16) bool {
    for (room.walkway) |w| {
        if (w.y == y and x >= w.x and x < w.x + 4 * @as(u16, w.length)) return true;
    }
    return false;
}

/// A two-byte value, low byte first.
fn le(value: u16) [2]u8 {
    return .{ value & 0xFF, value >> 8 };
}

fn fail(comptime format: []const u8, args: anytype) noreturn {
    @compileError("castle: " ++ std.fmt.comptimePrint(format, args));
}
