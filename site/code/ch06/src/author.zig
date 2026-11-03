//! The castle-authoring kit: describe rooms as Zig declarations, and get
//! back the castle file's bytes, checked while the game compiles.

const std = @import("std");
const Color = @import("machine").Color;
const castle = @import("castle.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const map = @import("map.zig");

// ---- what you write -------------------------------------------------------

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
        exit: bool = false, // the way out of the castle: it needs no partner
    };
}

/// Walkways, ladders, poles and doorbells are written as their records.
pub const Run = castle.Run;
pub const Bell = castle.Bell;

/// A line of text, 1 to 3 times the usual 8 rows tall.
pub const Line = struct { x: u8, y: u8, color: Color = .white, height: u2 = 1, words: []const u8 };

pub const Spot = struct { x: u8, y: u8 };
pub const Teleport = struct { x: u8, y: u8, target: u8 = 0, pads: []const Spot };

/// A picture stored in the castle, and everywhere it's drawn.
pub const Image = struct { art: shapes.Art, at: []const Spot };

/// Everything one room holds. Each list is named after its `castle.Kind`.
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

/// A whole castle: a field in `rooms` for every name in `Name`, in the
/// enum's order, and a final room that isn't on the map.
pub fn Castle(comptime Name: type) type {
    return struct {
        start: struct { room: Name, door: u8 = 0 },
        lives: u8 = 3,
        rooms: std.enums.EnumFieldStruct(Name, Room(Name), null),
        final: ?Room(Name) = null,
    };
}

// ---- what you get ---------------------------------------------------------

/// The castle file: header, room directory, then every room's objects.
pub fn build(comptime Name: type, comptime c: Castle(Name)) []const u8 {
    comptime {
        @setEvalBranchQuota(2_000_000);
        check(Name, c);
        const names = std.enums.values(Name);

        // The streams go after the directory and its end byte, one after
        // another, so each room's address is the sum of the ones before.
        var at: u16 = castle.directory + names.len * @sizeOf(castle.Entry) + 1;
        var directory: []const u8 = &.{};
        var streams: []const u8 = &.{};
        for (names) |name| {
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
            const objects = stream(Name, c, room);
            streams = streams ++ objects;
            at += objects.len;
        }
        directory = directory ++ [_]u8{if (c.final == null) castle.end_plain else castle.end_with_final};
        const final_at = if (c.final == null) 0 else at;
        if (c.final) |room| streams = streams ++ stream(Name, c, room);

        const total = castle.header_size + directory.len + streams.len;
        if (total > map.castle.last - map.castle.first + 1)
            fail("the castle is {d} bytes, and its region holds {d}", .{ total, map.castle.last - map.castle.first + 1 });

        var head = [_]u8{0} ** castle.header_size;
        head[0..2].* = le(total);
        head[2] = castle.magic_value;
        const first = @intFromEnum(c.start.room);
        head[3..9].* = .{ first, first, c.start.door, c.start.door, c.lives, c.lives };
        head[0x5F..0x61].* = le(final_at);

        const all = head ++ directory[0..directory.len].* ++ streams[0..streams.len].*;
        return &all;
    }
}

/// One room's object stream: each kind's group in tag order (doors and
/// floors first, text and pictures last, a good order to draw in), then
/// the end tag.
fn stream(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name)) []const u8 {
    var out: []const u8 = &.{};
    inline for (comptime std.enums.values(castle.Kind)) |kind| {
        const list = @field(room, @tagName(kind));
        const tag = le(castle.code(kind));
        switch (kind) {
            // Counted: the tag, how many, then the records.
            .door => if (list.len > 0) {
                out = out ++ tag ++ [_]u8{list.len};
                for (list) |d| out = out ++ std.mem.asBytes(&door(Name, c, room, d));
            },
            .bell => if (list.len > 0) {
                out = out ++ tag ++ [_]u8{list.len};
                for (list) |b| out = out ++ std.mem.asBytes(&b);
            },
            // Runs of pieces, ended by a length of 0.
            .walkway, .pole, .ladder => if (list.len > 0) {
                out = out ++ tag;
                for (list) |r| out = out ++ std.mem.asBytes(&r);
                out = out ++ [_]u8{0};
            },
            // Lines of text, each ending on a letter with bit 7 set; a 0 ends them all.
            .text => if (list.len > 0) {
                out = out ++ tag;
                for (list) |line| {
                    const record = castle.Text{ .x = line.x, .y = line.y, .color = @intFromEnum(line.color), .style = text.style_letters | line.height };
                    out = out ++ std.mem.asBytes(&record) ++ &text.terminated(line.words);
                }
                out = out ++ [_]u8{0};
            },
            // One booth, then its pads up to a 0.
            .teleport => if (list) |t| {
                out = out ++ tag ++ [_]u8{ t.x, t.y, t.target };
                for (t.pads) |p| out = out ++ [_]u8{ p.x, p.y };
                out = out ++ [_]u8{0};
            },
            // A tag for every picture: the shape, then where it goes, up to a 0.
            .image => for (list) |picture| {
                out = out ++ tag ++ shapes.pack("a castle image", picture.art);
                for (picture.at) |p| out = out ++ [_]u8{ p.x, p.y };
                out = out ++ [_]u8{0};
            },
            // The machines and monsters: records as written, then the end marker.
            else => if (list.len > 0) {
                out = out ++ tag;
                for (list) |r| out = out ++ std.mem.asBytes(&r);
                out = out ++ [_]u8{castle.framing(kind).marked.end};
            },
        }
    }
    return out ++ le(castle.end_code);
}

/// A door's 8 bytes. Besides where it leads, it says where it shows on the
/// castle map: which wall of the room (the one facing the room it leads
/// to), where across the room from its corner, and where down.
fn door(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime d: Door(Name)) castle.Door {
    const here = room.map;
    const there = @field(c.rooms, @tagName(d.to)).map;
    const width = 4 * @as(u16, here.width);
    const height = 8 * @as(u16, here.height);
    const side: u8 = if (there.x >= here.x + width) 1 // right
        else if (there.x + 4 * @as(u16, there.width) <= here.x) 3 // left
        else if (there.y + 8 * @as(u16, there.height) <= here.y) 0 // up
        else if (there.y >= here.y + height) 2 // down
        else if (d.x < 96) 3 else 1; // the way out: whichever wall it's nearer
    const along_x = @min(width - 4, (d.x - 16) * width / 160);
    const along_y = @min(height - 3, (@as(u16, d.y) + 16) * height / 200);
    return .{
        .x = d.x,
        .y = d.y,
        .side = side | if (d.open) castle.door_open else 0,
        .to_room = @intFromEnum(d.to),
        .to_door = d.to_door,
        .map_x = switch (side) {
            1 => width - 2, // the right wall
            3 => 0, // the left wall
            else => along_x,
        },
        .map_y = switch (side) {
            0 => 0, // the top wall
            2 => height - 3, // the bottom wall
            else => along_y,
        },
        .exit = @intFromBool(d.exit),
    };
}

/// A two-byte value as the Comet stores it: low byte first.
fn le(value: u16) [2]u8 {
    return .{ @truncate(value), @truncate(value >> 8) };
}

fn fail(comptime format: []const u8, args: anytype) noreturn {
    @compileError("castle: " ++ std.fmt.comptimePrint(format, args));
}

// ---- checking it ----------------------------------------------------------

/// Everything that would make a broken castle, refused while compiling.
fn check(comptime Name: type, comptime c: Castle(Name)) void {
    const names = std.enums.values(Name);
    if (names.len > castle.max_rooms)
        fail("a castle has at most {d} rooms, not {d}", .{ castle.max_rooms, names.len });
    if (c.start.door >= @field(c.rooms, @tagName(c.start.room)).door.len)
        fail("the start room, {s}, has no door {d}", .{ @tagName(c.start.room), c.start.door });
    for (names) |name| {
        const room = @field(c.rooms, @tagName(name));
        if (room.map.width == 0 or room.map.height == 0)
            fail("room {s}: give it a place and a size on the castle map", .{@tagName(name)});
        if (room.color == .black)
            fail("room {s}: a black room has black walkways", .{@tagName(name)});
        checkRoom(Name, c, room, @tagName(name));
    }
    if (c.final) |room| checkRoom(Name, c, room, "final");
}

fn checkRoom(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime name: []const u8) void {
    var boxes: []const Box = &.{};
    for (room.door, 0..) |d, i| {
        const what = std.fmt.comptimePrint("door {d}", .{i});
        boxes = boxes ++ [_]Box{onScreen(name, what, d.x, d.y, 20, 32)};
        if (d.y % 8 != 0) fail("room {s}: {s} has y {d}; doors sit on cell rows (multiples of 8)", .{ name, what, d.y });
        if (d.exit) continue; // the way out leads nowhere
        const there = @field(c.rooms, @tagName(d.to));
        if (d.to_door >= there.door.len)
            fail("room {s}: {s} leads to door {d} of {s}, which has {d}", .{ name, what, d.to_door, @tagName(d.to), there.door.len });
        const back = there.door[d.to_door];
        if (!std.mem.eql(u8, @tagName(back.to), name) or back.to_door != i)
            fail("room {s}: {s} leads to {s} door {d}, which doesn't lead back", .{ name, what, @tagName(d.to), d.to_door });
    }
    for (room.bell, 0..) |b, i| {
        const what = std.fmt.comptimePrint("bell {d}", .{i});
        boxes = boxes ++ [_]Box{onScreen(name, what, b.x, b.y, 12, 19)};
        if (b.door >= room.door.len) fail("room {s}: {s} rings door {d}, and the room has {d}", .{ name, what, b.door, room.door.len });
    }
    for (room.walkway, 0..) |r, i| {
        const what = std.fmt.comptimePrint("walkway {d}", .{i});
        if (r.length == 0) fail("room {s}: {s} has length 0, which is the end marker", .{ name, what });
        _ = onScreen(name, what, r.x, r.y, 4 * @as(u16, r.length), 7);
    }
    // A ladder's bottom rung stands on the walkway below it. A pole stops
    // one row short: every piece of a pole slides you down, even the last.
    const columns = [_]struct { runs: []const Run, kind: []const u8, short: u16 }{
        .{ .runs = room.ladder, .kind = "ladder", .short = 0 },
        .{ .runs = room.pole, .kind = "pole", .short = 8 },
    };
    for (columns) |col| {
        for (col.runs, 0..) |r, i| {
            const what = std.fmt.comptimePrint("{s} {d}", .{ col.kind, i });
            if (r.length == 0) fail("room {s}: {s} has length 0, which is the end marker", .{ name, what });
            const bottom = r.y + 8 * (r.length - 1);
            _ = onScreen(name, what, r.x, r.y, 4, bottom + 8 - r.y);
            if (!onWalkway(room, r.x, r.y) or !onWalkway(room, r.x, bottom + col.short))
                fail("room {s}: {s} must start on a walkway and end {s} one (top piece row {d}, bottom piece row {d})", .{ name, what, if (col.short == 0) "on" else "just above", r.y, bottom });
        }
    }
    for (room.text, 0..) |line, i| {
        const what = std.fmt.comptimePrint("text {d} (\"{s}\")", .{ i, line.words });
        if (line.height == 0) fail("room {s}: {s} has height 0", .{ name, what });
        boxes = boxes ++ [_]Box{onScreen(name, what, line.x, line.y, 8 * line.words.len, 8 * @as(u16, line.height))};
    }
    for (room.image, 0..) |picture, i| {
        const bytes = shapes.pack("a castle image", picture.art);
        for (picture.at) |p| {
            const what = std.fmt.comptimePrint("image {d} at ({d}, {d})", .{ i, p.x, p.y });
            boxes = boxes ++ [_]Box{onScreen(name, what, p.x, p.y, 4 * @as(u16, bytes[0]), bytes[1])};
        }
    }
    inline for (comptime std.enums.values(castle.Kind)) |kind| {
        if (castle.framing(kind) == .marked and kind != .walkway and kind != .pole and kind != .ladder) {
            const end = castle.framing(kind).marked.end;
            for (@field(room, @tagName(kind))) |r| {
                const first = std.mem.asBytes(&r)[0];
                if (castle.isEnd(first, end))
                    fail("room {s}: a {s} starting with {d} would read as the end marker", .{ name, @tagName(kind), first });
            }
        }
    }
    for (boxes, 0..) |a, i| {
        for (boxes[i + 1 ..]) |b| {
            if (a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h)
                fail("room {s}: {s} overlaps {s}", .{ name, a.what, b.what });
        }
    }
}

/// A rectangle something covers on the screen, for the overlap check.
const Box = struct { what: []const u8, x: u16, y: u16, w: u16, h: u16 };

/// Something `w` fat pixels by `h` rows at (x, y) must be on the screen
/// and start on a whole byte. Returns the rectangle it covers.
fn onScreen(comptime name: []const u8, comptime what: []const u8, comptime x: u16, comptime y: u16, comptime w: u16, comptime h: u16) Box {
    if (x < 16 or x + w > 16 + 160)
        fail("room {s}: {s} runs off the screen (x {d} to {d}; the screen is 16 to 175)", .{ name, what, x, x + w - 1 });
    if (x % 4 != 0) fail("room {s}: {s} has x {d}, which isn't on a byte; use a multiple of 4", .{ name, what, x });
    if (y + h > 200) fail("room {s}: {s} runs off the bottom (rows {d} to {d})", .{ name, what, y, y + h - 1 });
    return .{ .what = what, .x = x, .y = y, .w = w, .h = h };
}

/// Is there a walkway along row `y`, under `x`?
fn onWalkway(comptime room: anytype, comptime x: u16, comptime y: u16) bool {
    for (room.walkway) |w| {
        if (w.y == y and x >= w.x and x < w.x + 4 * @as(u16, w.length)) return true;
    }
    return false;
}
