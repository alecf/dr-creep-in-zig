//! The room's object table: the things in a room that an actor can stand
//! in front of, or that have work to do. Preparing the room fills it, up
//! to 32 of them, 16 bytes each: doors and doorbells, the machines and
//! the switches that work them, keys and locks, and ray guns. A key can
//! leave the table while the room runs.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const actors = @import("actors.zig");
const doors = @import("doors.zig");
const lightning = @import("lightning.zig");
const forcefields = @import("forcefields.zig");
const trapdoors = @import("trapdoors.zig");
const conveyors = @import("conveyors.zig");
const transmitter = @import("transmitter.zig");
const locks = @import("locks.zig");
const guns = @import("guns.zig");

/// One slot: 16 bytes.
pub const Object = extern struct {
    kind: Kind,
    flags: Flags,
    box: actors.Box, // the part an actor has to stand in front of
    record: u16, // where its record is in the castle
    number: u8, // which one it is: a door's place among the room's doors, a bell's door, a machine's record
    open: u8, // a door: 1 once it's open, or opening. A trapdoor: 1 if it's opening or open
    step: u8, // how far through its work it is: rows still to wipe, the picture it's on
    actor: u8, // the actor slot it runs (a bolt, a field), or actors.none
    timer: u8, // steps until its next tick
    spare: [3]u8, // for the monsters to come
};

/// An object's flags. Three are used by the engine; the low five are
/// each kind's own.
pub const Flags = packed struct(u8) {
    own: u5 = 0,
    picked: bool = false, // bit 5: picked up, so it leaves the table (keys)
    execute: bool = false, // bit 6: it has work to do: give it a turn every step
    disable: bool = false, // bit 7: nobody can stand in front of it
};

/// Every kind of object. Later chapters add more.
pub const Kind = enum(u8) { door, bell, machine, lever, button, trapdoor, plate, belt, control, booth, key, lock, gun, panel, _ };

/// What each kind does: its work for a step while its `execute` flag is
/// set, and what happens when an actor stands in front of it. Null for
/// "nothing".
const Handlers = struct {
    execute: ?*const fn (m: *Machine, n: u8) void,
    in_front: ?*const fn (m: *Machine, n: u8, who: u3) void,
};

/// One entry for every kind, found by number.
const kinds = std.enums.directEnumArray(Kind, Handlers, 0, .{
    .door = .{ .execute = doors.open, .in_front = doors.enter },
    .bell = .{ .execute = null, .in_front = doors.ring },
    .machine = .{ .execute = lightning.run, .in_front = null },
    .lever = .{ .execute = null, .in_front = lightning.pull },
    .button = .{ .execute = forcefields.count, .in_front = forcefields.press },
    .trapdoor = .{ .execute = trapdoors.swing, .in_front = null },
    .plate = .{ .execute = null, .in_front = null }, // the explorer's touch does the work
    .belt = .{ .execute = conveyors.run, .in_front = conveyors.carry },
    .control = .{ .execute = null, .in_front = conveyors.press },
    .booth = .{ .execute = transmitter.flash, .in_front = transmitter.use },
    .key = .{ .execute = null, .in_front = locks.take },
    .lock = .{ .execute = null, .in_front = locks.unlock },
    .gun = .{ .execute = guns.run, .in_front = null },
    .panel = .{ .execute = null, .in_front = guns.steer },
});

pub const slots = 32;

comptime {
    if (@sizeOf(Object) * slots != map.objects.last - map.objects.first + 1)
        @compileError("the object table doesn't fill its region exactly");
}

/// Slot `n`.
pub fn slot(m: *Machine, n: u8) *align(1) Object {
    return &m.view([slots]Object, map.objects.first)[n];
}

/// No object: what the explorer's switch bytes hold when he isn't on one.
pub const none: u8 = 0xFF;

/// The object for the room's `kind` number `number`: the link from a
/// bell to its door, a switch to its machine.
pub fn find(m: *Machine, kind: Kind, number: u8) ?u8 {
    const count = m.peek(map.engine_objects);
    var n: u8 = 0;
    while (n < count) : (n += 1) {
        const o = slot(m, n);
        m.work(12); // the tests and the loop
        if (o.kind == kind and o.number == number) return n;
    }
    return null;
}

/// The engine's clock: the frame tick, halved, so it goes up by one every
/// step.
pub fn clock(m: *Machine) u8 {
    return m.peek(map.game_tick) >> 1;
}

/// No objects, before a room is prepared.
pub fn clear(m: *Machine) void {
    m.poke(map.engine_objects, 0);
}

/// Take the next slot for an object of `kind`, standing in `box`, made
/// from the castle record at `record`. Null if the table is full; then
/// the object is drawn, but nothing can use it.
pub fn add(m: *Machine, kind: Kind, box: actors.Box, record: u16) ?u8 {
    const n = m.peek(map.engine_objects);
    if (n == slots) return null;
    m.poke(map.engine_objects, n + 1);
    m.fill(map.objects.first + @as(u16, n) * @sizeOf(Object), @sizeOf(Object), 0);
    const o = slot(m, n);
    o.kind = kind;
    o.box = box;
    o.record = record;
    o.actor = actors.none;
    m.work(30); // the stores
    return n;
}

/// One engine step for the objects: the ones that asked to run, run.
/// Everything else costs one test of one bit. A picked-up object leaves
/// the table on the spot.
pub fn step(m: *Machine) void {
    var n: u8 = 0;
    while (n < m.peek(map.engine_objects)) : (n += 1) {
        const o = slot(m, n);
        m.work(12); // the test and the loop
        if (o.flags.picked) {
            remove(m, n);
            continue; // the object moved into n waits for the next step
        }
        if (!o.flags.execute) continue;
        if (kinds[@intFromEnum(o.kind)].execute) |execute| execute(m, n) else o.flags.execute = false;
    }
}

/// Take object `n` out of the table: the last object moves into its slot,
/// and the table is one shorter. Nothing else moves.
fn remove(m: *Machine, n: u8) void {
    const last = m.peek(map.engine_objects) - 1;
    m.poke(map.engine_objects, last);
    if (n != last) m.copy(map.objects.first + @as(u16, n) * @sizeOf(Object), map.objects.first + @as(u16, last) * @sizeOf(Object), @sizeOf(Object));
}

/// Actor `who` has touched the room's foreground. Find the objects its box
/// overlaps, and tell each one it has an actor standing in front of it.
pub fn touching(m: *Machine, who: u3) void {
    const a = actors.slot(m, who);
    const count = m.peek(map.engine_objects);
    var n: u8 = 0;
    while (n < count) : (n += 1) {
        const o = slot(m, n);
        m.work(12); // the test and the loop
        if (o.flags.disable or !overlap(m, a.box, o.box)) continue;
        if (actors.touch(m, who, n)) a.state.flash = true;
        if (kinds[@intFromEnum(o.kind)].in_front) |in_front| in_front(m, n, who);
    }
}

/// Do two boxes overlap? An edge that touches counts. The sums are done in
/// a u16, so a box at the right of the screen can't wrap round.
pub fn overlap(m: *Machine, a: actors.Box, b: actors.Box) bool {
    m.work(40); // four compares, four sums
    return @as(u16, a.x) + a.width >= b.x and @as(u16, b.x) + b.width >= a.x and
        @as(u16, a.y) + a.height >= b.y and @as(u16, b.y) + b.height >= a.y;
}

// ---- tests ----------------------------------------------------------------

test "boxes overlap when any part of them does, edges included" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    const door: actors.Box = .{ .x = 160, .y = 168, .width = 12, .height = 24 };
    const at = struct {
        fn at(x: u8, y: u8) actors.Box {
            return .{ .x = x, .y = y, .width = 8, .height = 21 };
        }
    }.at;
    try std.testing.expect(overlap(m, at(162, 171), door)); // in the doorway
    try std.testing.expect(overlap(m, at(152, 171), door)); // his right edge on its left edge
    try std.testing.expect(overlap(m, at(172, 171), door)); // his left edge on its right edge
    try std.testing.expect(!overlap(m, at(151, 171), door)); // a fat pixel short
    try std.testing.expect(!overlap(m, at(173, 171), door));
    try std.testing.expect(!overlap(m, at(162, 107), door)); // on the walkway above
    try std.testing.expect(overlap(m, at(250, 171), .{ .x = 245, .y = 170, .width = 12, .height = 4 })); // no wrapping
}

test "the table has handlers for every kind, and add stops at 32" {
    try std.testing.expectEqual(std.meta.fields(Kind).len, kinds.len);
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    clear(m);
    for (0..slots) |i| try std.testing.expectEqual(@as(?u8, @intCast(i)), add(m, .bell, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, 0));
    try std.testing.expectEqual(@as(?u8, null), add(m, .bell, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, 0));
    try std.testing.expectEqual(slots, m.ram[map.engine_objects]);
}
