//! The castle file, byte for byte as the 1984 disk lays it out: a
//! 256-byte header at $7800, a room directory at $7900 (8 bytes a room),
//! then each room's objects as a stream of tagged records.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");

// ---- the header -----------------------------------------------------------

pub const header = map.castle.first;
pub const header_size = 0x100;
pub const size = header + 0x00; // 2 bytes: the castle's length, header included
pub const magic = header + 0x02; // always $80: "this is a castle"
pub const start_room = header + 0x03; // player 1, then player 2
pub const start_door = header + 0x05; // player 1, then player 2
pub const lives = header + 0x07; // player 1, then player 2
pub const final_room = header + 0x5F; // 2 bytes: the final room's objects, or 0
pub const magic_value: u8 = 0x80;

// ---- the room directory ---------------------------------------------------

pub const directory = header + header_size; // $7900
pub const max_rooms = 31; // so the directory and its end byte fit in one page

/// One room's entry in the directory: 8 bytes.
pub const Entry = extern struct {
    color: u8, // low four bits: the room's colour. Bit 6 set: the end.
    map_x: u8, // where the room sits on the castle map
    map_y: u8,
    size: Size, // how big it is there
    skip: [2]u8, // nothing reads these two
    objects: [2]u8, // where its object stream starts, low byte first
};

/// A room's size on the castle map, in map cells: two 3-bit numbers in a byte.
pub const Size = packed struct(u8) {
    height: u3, // bits 0-2: cells of 8 rows
    width: u3, // bits 3-5: cells of 4 fat pixels
    unused: u2 = 0,
};

/// Bit 6 of a colour byte ends the directory. The end byte is $40 when
/// the castle has a final room and $FF when it doesn't.
pub const end_flag: u8 = 0b0100_0000;
pub const end_with_final: u8 = 0x40;
pub const end_plain: u8 = 0xFF;

/// The address of room `n`'s directory entry.
pub fn entry(m: *Machine, n: u8) u16 {
    m.work(6); // n * 8 is three shifts
    return directory + @as(u16, n) * @sizeOf(Entry);
}

/// How many rooms the directory lists.
pub fn roomCount(m: *Machine) u8 {
    var n: u8 = 0;
    while (m.peek(entry(m, n)) & end_flag == 0) : (n += 1) m.work(2);
    return n;
}

// ---- object streams -------------------------------------------------------

/// Every kind of object a room can hold, in the order of the program's
/// jump table: kind k's tag code is $0803 + 3k.
pub const Kind = enum(u8) {
    door,
    walkway,
    pole,
    ladder,
    bell,
    lightning,
    forcefield,
    mummy,
    key,
    lock,
    pattern, // a shape stamped in a row; only the title screens use it
    ray_gun,
    teleport,
    trapdoor,
    conveyor,
    frankenstein,
    text,
    image,
};

pub const first_code: u16 = 0x0803;
pub const end_code: u16 = 0x0000;

/// The tag code that introduces `kind`.
pub fn code(kind: Kind) u16 {
    return first_code + 3 * @as(u16, @intFromEnum(kind));
}

/// (code - $0803) to kind. Codes are 3 apart, so two in three entries are
/// null: those numbers aren't codes at all.
const kinds: [3 * std.enums.values(Kind).len]?Kind = blk: {
    var table: [3 * std.enums.values(Kind).len]?Kind = @splat(null);
    for (std.enums.values(Kind)) |kind| table[@intFromEnum(kind) * 3] = kind;
    break :blk table;
};

/// The kind a tag code introduces, or null if it isn't one.
pub fn kindOf(m: *Machine, tag: u16) ?Kind {
    m.work(12); // a subtraction, a compare and a table read
    const offset = tag -% first_code; // below $0803 wraps round to a huge number
    return if (offset < kinds.len) kinds[offset] else null;
}

// ---- records --------------------------------------------------------------

/// A door: 8 bytes.
pub const Door = extern struct {
    x: u8,
    y: u8,
    side: u8, // its wall on the castle map: 0 up, 1 right, 2 down, 3 left. Bit 7: open
    to_room: u8, // where it leads
    to_door: u8,
    map_x: u8, // where it sits on the castle map, from the room's corner
    map_y: u8,
    exit: u8, // 1: the way out of the castle
};
pub const door_open: u8 = 0b1000_0000;

/// A walkway, a sliding pole or a ladder: `length` pieces from (x, y).
pub const Run = extern struct { length: u8, x: u8, y: u8 };

/// A doorbell, and which of the room's doors it opens (0 is the first).
pub const Bell = extern struct { x: u8, y: u8, door: u8 };

/// A line of text; its letters follow, the last one with bit 7 set.
pub const Text = extern struct { x: u8, y: u8, color: u8, style: u8 };

/// A lightning machine, or a switch that works machines. A machine hangs
/// `length` pieces down from (x, y). A switch lists up to four machines,
/// each by how far its record is from the room's first lightning record
/// (records are 8 bytes, so 0, 8, 16...), with $FF ending the list early.
pub const Lightning = extern struct { state: u8, x: u8, y: u8, length: u8, machines: [4]u8 };
pub const lightning_switch: u8 = 0b1000_0000; // a switch, not a machine
pub const lightning_on: u8 = 0b0100_0000; // a machine: running. A switch: thrown up

/// A forcefield: its button, and the field itself.
pub const Forcefield = extern struct { button_x: u8, button_y: u8, field_x: u8, field_y: u8 };

/// A trapdoor in a walkway, and the switch in the floor that works it.
pub const Trapdoor = extern struct { state: u8, x: u8, y: u8, switch_x: u8, switch_y: u8 };
pub const trapdoor_open: u8 = 0b0000_0001;

/// A conveyor belt, and its control box. Bits 2-5 of `state` are the
/// game's, while the room is on screen: which players have pressed the
/// control this step, and which did last step.
pub const Conveyor = extern struct { state: u8, x: u8, y: u8, control_x: u8, control_y: u8 };
pub const conveyor_on: u8 = 0b0000_0001; // running
pub const conveyor_left: u8 = 0b0000_0010; // carrying things to the left
pub const conveyor_pressed: u8 = 0b0000_0100; // player 1 pressed the control this step
pub const conveyor_held: u8 = 0b0001_0000; // ...and last step
pub const conveyor_players: u8 = 0b0011_1100; // all four of those bits, for both players

/// A matter transmitter's booth, and the pad its lamp picks. The pads
/// follow it: x, y for each, up to a 0.
pub const Teleport = extern struct { x: u8, y: u8, target: u8 };

/// A key: its number, which is its colour too and the number of the lock
/// it opens, and its picture: the 1984 disk's picture number, $50 plus
/// the colour. We draw our own key in that colour, so all `shape` tells
/// us is whether the key is still there. 0 means it's been taken.
pub const Key = extern struct { number: u8, shape: u8, x: u8, y: u8 };

/// A lock: the number of the key it wants (its colour too), a picture
/// number nobody reads, and which of the room's doors it opens (0 is
/// the first).
pub const Lock = extern struct { number: u8, shape: u8, door: u8, x: u8, y: u8 };

/// A ray gun, on a track `length` pieces long that hangs from (x, y), and
/// its control panel. `gun_y` is where the gun is on its track: the gun
/// moves, and the castle remembers where it got to.
pub const RayGun = extern struct { state: Gun, x: u8, y: u8, length: u8, gun_y: u8, control_x: u8, control_y: u8 };

/// A ray gun's state: eight flags in one byte, kept in the castle. The
/// castle file sets `left` and `no_gun`; the rest are the game's, while
/// the room is on screen.
pub const Gun = packed struct(u8) {
    left: bool = false, // bit 0: it faces left, and fires to the left
    down: bool = false, // bit 1: it's moving down its track
    up: bool = false, // bit 2: it's moving up
    fire: bool = false, // bit 3: the explorer at its panel pressed fire
    no_gun: bool = false, // bit 4: a track and a panel, and no gun
    steered: bool = false, // bit 5: the explorer at its panel is steering it
    shot: bool = false, // bit 6: its laser is in the air, so it can't fire again
    end: bool = false, // bit 7: not a gun at all, the end of the room's guns
};

// The monsters the next chapter brings to life, and the title screens'
// pattern. For now the loader only needs their sizes, and the authoring
// kit their fields.
pub const Mummy = extern struct { state: u8, ankh_x: u8, ankh_y: u8, tomb_x: u8, tomb_y: u8, runtime: [2]u8 };
pub const Pattern = extern struct { count: u8, shape: u8, x: u8, y: u8, step_x: u8, step_y: u8 };
pub const Frankenstein = extern struct { state: u8, x: u8, y: u8, runtime: [4]u8 };

/// How a kind's records are strung together after its tag.
pub const Framing = union(enum) {
    /// A count byte, then that many records of this size.
    counted: u8,
    /// Records of this size until one starts with the end marker: a byte
    /// of 0 when `end` is 0, otherwise a byte with any of `end`'s bits set.
    marked: struct { size: u8, end: u8 },
    /// Like `marked`, ended by a 0, but each record ends with a string.
    text,
    /// One booth (x, y, target), then (x, y) pads up to a 0.
    teleport,
    /// One shape, then (x, y) places to draw it, up to a 0.
    image,
};

pub fn framing(kind: Kind) Framing {
    return switch (kind) {
        .door => .{ .counted = @sizeOf(Door) },
        .bell => .{ .counted = @sizeOf(Bell) },
        .walkway, .pole, .ladder => .{ .marked = .{ .size = @sizeOf(Run), .end = 0 } },
        .lightning => .{ .marked = .{ .size = @sizeOf(Lightning), .end = 0x20 } },
        .forcefield => .{ .marked = .{ .size = @sizeOf(Forcefield), .end = 0 } },
        .mummy => .{ .marked = .{ .size = @sizeOf(Mummy), .end = 0 } },
        .key => .{ .marked = .{ .size = @sizeOf(Key), .end = 0 } },
        .lock => .{ .marked = .{ .size = @sizeOf(Lock), .end = 0 } },
        .pattern => .{ .marked = .{ .size = @sizeOf(Pattern), .end = 0 } },
        .ray_gun => .{ .marked = .{ .size = @sizeOf(RayGun), .end = 0x80 } },
        .trapdoor => .{ .marked = .{ .size = @sizeOf(Trapdoor), .end = 0x80 } },
        .conveyor => .{ .marked = .{ .size = @sizeOf(Conveyor), .end = 0x80 } },
        .frankenstein => .{ .marked = .{ .size = @sizeOf(Frankenstein), .end = 0x80 } },
        .text => .text,
        .teleport => .teleport,
        .image => .image,
    };
}

/// Does `byte`, at the start of a record, mark the end of the group?
pub fn isEnd(byte: u8, end: u8) bool {
    return if (end == 0) byte == 0 else byte & end != 0;
}

/// One record in a room's stream: its kind, where it starts, and the
/// address after it.
pub const Record = struct { kind: Kind, at: u16, end: u16 };

/// Walks a room's object stream, one record at a time.
pub const Walker = struct {
    at: u16, // the next byte to read
    kind: Kind = .door, // the group we're in
    in_group: bool = false,
    left: u8 = 0, // records still to come in a counted group

    /// The next record, or null at the stream's end tag.
    pub fn next(w: *Walker, m: *Machine) ?Record {
        while (true) {
            if (!w.in_group) {
                const tag = m.peek16(w.at);
                w.at += 2;
                if (tag == end_code) return null;
                w.kind = kindOf(m, tag) orelse @panic("castle: that's not an object code");
                w.in_group = true;
                if (framing(w.kind) == .counted) {
                    w.left = m.peek(w.at);
                    w.at += 1;
                }
            }
            const start = w.at;
            m.work(16); // the tests and the sums below
            switch (framing(w.kind)) {
                .counted => |record_size| {
                    if (w.left == 0) {
                        w.in_group = false;
                        continue;
                    }
                    w.left -= 1;
                    w.at += record_size;
                },
                .marked => |f| {
                    if (isEnd(m.peek(w.at), f.end)) {
                        w.at += 1; // the marker is part of the group
                        w.in_group = false;
                        continue;
                    }
                    w.at += f.size;
                },
                .text => {
                    if (m.peek(w.at) == 0) {
                        w.at += 1;
                        w.in_group = false;
                        continue;
                    }
                    w.at = stringEnd(m, w.at + @sizeOf(Text));
                },
                .teleport => {
                    w.at = placesEnd(m, w.at + 3);
                    w.in_group = false; // one booth per tag
                },
                .image => {
                    w.at = placesEnd(m, w.at + shapeSize(m, w.at));
                    w.in_group = false; // one image per tag
                },
            }
            return .{ .kind = w.kind, .at = start, .end = w.at };
        }
    }
};

/// The address after a string whose last letter has bit 7 set.
fn stringEnd(m: *Machine, at: u16) u16 {
    var a = at;
    while (m.peek(a) & 0x80 == 0) : (a += 1) m.work(2);
    return a + 1;
}

/// The address after a list of (x, y) pairs ended by a 0.
fn placesEnd(m: *Machine, at: u16) u16 {
    var a = at;
    while (m.peek(a) != 0) : (a += 2) m.work(2);
    return a + 1;
}

/// How many bytes a shape takes: width, height and flags, its pixels,
/// and a screen-plane and a colour-RAM byte for each cell.
pub fn shapeSize(m: *Machine, at: u16) u16 {
    const width = m.peek(at);
    const height = m.peek(at + 1);
    return 3 + m.mul8(width, height) + 2 * m.mul8(width, (height + 7) / 8);
}

/// Object X counts fat pixels from 16 to the left of the screen, so that
/// things can start a little way off its left edge: X = 16 is the edge.
pub const left_edge: u8 = 16;

// ---- tests ----------------------------------------------------------------

test "tag codes turn into kinds and back" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    try std.testing.expectEqual(Kind.door, kindOf(m, 0x0803).?);
    try std.testing.expectEqual(Kind.image, kindOf(m, 0x0836).?);
    try std.testing.expectEqual(null, kindOf(m, 0x0804));
    try std.testing.expectEqual(null, kindOf(m, 0x0839));
    try std.testing.expectEqual(null, kindOf(m, 0x0100));
    for (std.enums.values(Kind)) |kind| try std.testing.expectEqual(kind, kindOf(m, code(kind)).?);
}

test "the walker finds every record in a stream written by hand" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    const room = [_]u8{
        0x03, 0x08, 1, 0x9C, 0xA0, 0x01, 0x02, 0x00, 0x24, 0x10, 0x00, // one door
        0x06, 0x08, 40, 0x10, 0xC0, 0, // a walkway, then its end marker
        0x0F, 0x08, 1, 0x88, 0xA8, 0x00, // one doorbell, for door 0
        0x12, 0x08, 0x40, 0x50, 0x88, 5, 0, 0, 0, 0, // a lightning machine...
        0x80, 0x30, 0x60, 0, 0x00, 0xFF, 0xFF, 0xFF, 0x20, // ...its switch, the end
        0x24, 0x08, 0x01, 0x20, 0x40, 8, 0x48, 0x30, 0x40, 0x80, // a ray gun, end
        0x27, 0x08, 0x40, 0x98, 0x00, 0x80, 0x98, 0x00, // a booth with one pad
        0x33, 0x08, 0x14, 0x00, 0x07, 0x22, 'H', 'E', 'L', 'L', 'O' | 0x80, // text...
        0x14, 0x18, 0x01, 0x21, 'H', 'I' | 0x80, 0x00, // ...more text, the end
        0x36, 0x08, 1, 2, 0, 0xFF, 0xFF, 0x21, 0x07, 0x20, 0x08, 0x30, 0x08, 0, // an image, twice
        0x00, 0x00, // the end of the room
    };
    const at = 0x7969;
    m.load(at, &room);

    const expected = [_]Kind{ .door, .walkway, .bell, .lightning, .lightning, .ray_gun, .teleport, .text, .text, .image };
    var walk = Walker{ .at = at };
    for (expected) |kind| {
        const r = walk.next(m) orelse return error.EndedEarly;
        try std.testing.expectEqual(kind, r.kind);
    }
    try std.testing.expectEqual(null, walk.next(m));
    try std.testing.expectEqual(at + room.len, walk.at);
}
