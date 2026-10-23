//! The actor table: everything in a room that moves by itself, as a
//! sprite. Eight slots in a row, one for each of the VIDEO chip's
//! sprites: slot n is sprite n. The explorer is the only kind of actor so
//! far; lightning, lasers and monsters move in later.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// Where something is and how big: its top-left corner in castle
/// coordinates, and its size in fat pixels and rows. Actors and objects
/// both start with one.
pub const Box = extern struct { x: u8, y: u8, width: u8, height: u8 };

/// One slot: 16 bytes.
pub const Actor = extern struct {
    kind: Kind,
    state: State,
    box: Box, // where it is, and the size of its picture
    frame: u8, // the shape ID of its picture
    block: u8, // the sprite block showing it: n or n + 8
    color: u8, // its sprite's own colour
    countdown: u8, // engine steps until its next turn
    pace: u8, // engine steps from one turn to the next: 1 is every step
    flashes: u8, // flashes left while it's dying
    way: u8, // the direction of its last step
    stick: u8, // the direction its joystick read at its last turn
    fire: u8, // 1 if fire was pressed at its last turn
    walk: u8, // how far through a doorway it is
};

/// An actor's state: eight flags in one byte, the engine's to-do list.
pub const State = packed struct(u8) {
    unused: bool = false, // bit 0: the slot is empty
    hit_sprite: bool = false, // bit 1: its sprite touched another sprite
    hit_bitmap: bool = false, // bit 2: its sprite touched the room's foreground
    free: bool = false, // bit 3: empty the slot at the end of this step
    destroy: bool = false, // bit 4: its last turn: it tidies up, then it's freed
    dying: bool = false, // bit 5: flickering
    flash: bool = false, // bit 6: start dying
    created: bool = false, // bit 7: new this step
};

/// Every kind of actor. Later chapters add more.
pub const Kind = enum(u8) { player, _ };

/// What each kind does: the function that takes its turn, and whether it
/// flickers when it dies or vanishes on the spot.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
    flickers: bool,
};

/// One entry for every kind, found by number. The compiler won't build
/// the table with a kind missing.
const kinds = std.enums.directEnumArray(Kind, Behaviour, 0, .{
    .player = .{ .turn = player.turn, .flickers = true },
});

pub const slots = 8;

comptime {
    if (@sizeOf(Actor) * slots != map.actors.last - map.actors.first + 1)
        @compileError("the actor table doesn't fill its region exactly");
}

/// The whole table, as the eight structs it is.
pub fn table(m: *Machine) *align(1) [slots]Actor {
    return m.view([slots]Actor, map.actors.first);
}

/// Slot `n`.
pub fn slot(m: *Machine, n: u3) *align(1) Actor {
    return &table(m)[n];
}

/// Empty every slot, and forget any collisions, before a room starts.
pub fn clear(m: *Machine) void {
    for (table(m)) |*a| {
        a.state = .{ .unused = true };
        m.work(10); // the store and the loop
    }
    m.poke(hw.sprite_sprite_hits, 0);
    m.poke(hw.sprite_bitmap_hits, 0);
}

/// Take the first empty slot for a new actor of `kind`: every byte 0,
/// then `created`, and a turn every step. Null if all eight are taken.
pub fn add(m: *Machine, kind: Kind) ?u3 {
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (!a.state.unused) continue;
        const n: u3 = @intCast(i);
        m.fill(map.actors.first + @as(u16, n) * @sizeOf(Actor), @sizeOf(Actor), 0);
        a.kind = kind;
        a.state = .{ .created = true };
        a.block = @as(u8, n) + 8; // so its first picture goes into block n
        a.countdown = 1;
        a.pace = 1;
        m.work(20);
        return n;
    }
    return null;
}

/// Hand every actor to the VIDEO chip: where it is, its colour, its
/// picture, and which sprites are on at all. First thing in a frame.
pub fn show(m: *Machine) void {
    var on: u8 = 0;
    var multicolor: u8 = 0;
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused or a.state.destroy) continue; // gone, or going
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        on |= bit;
        if (!a.state.dying) multicolor |= bit; // dying, it flickers in one colour
        sprites.place(m, n, a.box.x, a.box.y);
        m.poke(hw.spriteColor(n), a.color);
        m.poke(hw.sprite_pointers + n, a.block);
        m.work(10); // the masks
    }
    m.poke(hw.sprite_enable, on);
    m.poke(hw.sprite_multicolor, multicolor);
}

/// One engine step for every actor, in slot order. The VIDEO chip's
/// collision reports come first, for free: an actor whose sprite touched
/// nothing in the room's foreground can't be standing in front of
/// anything, so only the ones that did look through the objects.
pub fn step(m: *Machine) void {
    const sprite_hits = m.peek(hw.sprite_sprite_hits);
    const bitmap_hits = m.peek(hw.sprite_bitmap_hits);
    m.poke(hw.sprite_sprite_hits, 0); // read them, then start again
    m.poke(hw.sprite_bitmap_hits, 0);
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused) continue;
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        a.state.hit_sprite = sprite_hits & bit != 0;
        a.state.hit_bitmap = bitmap_hits & bit != 0;
        if (a.state.destroy) {
            kinds[@intFromEnum(a.kind)].turn(m, n); // its last turn
        } else if (a.state.flash or a.state.dying) {
            flicker(m, n);
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            if (a.state.hit_bitmap or m.peek(map.debug_scan) != 0) objects.touching(m, n);
            if (!a.state.flash) kinds[@intFromEnum(a.kind)].turn(m, n);
        }
        if (a.state.free) a.state = .{ .unused = true };
        a.countdown = a.pace;
        m.work(30); // the flags
    }
}

/// Dying: flash white on every other step and black in between, eight
/// times, then take a last turn. A kind that doesn't flicker goes at once.
fn flicker(m: *Machine, n: u3) void {
    const a = slot(m, n);
    m.work(20); // the tests
    if (a.state.flash) {
        a.state.flash = false;
        if (!kinds[@intFromEnum(a.kind)].flickers) {
            a.state.destroy = true;
            return;
        }
        a.state.dying = true;
        a.flashes = 8;
        a.pace = 1;
    } else if (a.flashes == 0) {
        a.state.dying = false;
        a.state.destroy = true;
        return;
    }
    // A step every other frame, so bit 1 of the tick flips every step.
    if (m.peek(map.game_tick) & 0b10 == 0) {
        a.color = @intFromEnum(Color.white);
        a.flashes -= 1;
    } else {
        a.color = @intFromEnum(Color.black);
    }
}

/// Show picture `id` for actor `n` from the next frame on. It's unpacked
/// into the block the sprite *isn't* showing (Chapter 2's double buffer),
/// and its size becomes the box the actor touches things with.
pub fn setFrame(m: *Machine, n: u3, id: shapes.Id) void {
    const a = slot(m, n);
    const hidden = a.block ^ 8; // n <-> n + 8
    const at = shapes.address(m, id);
    a.box.width = m.peek(at) * 4; // bytes to fat pixels
    a.box.height = m.peek(at + 1);
    const flags = sprites.unpack(m, id, hidden);
    a.color = flags & sprites.flag_color;
    a.block = hidden;
    a.frame = @intFromEnum(id);
    m.work(16); // the stores
}

// ---- tests ----------------------------------------------------------------

test "eight slots: add takes the first empty one, and a full table says no" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    clear(m);
    for (0..slots) |i| try std.testing.expectEqual(@as(?u3, @intCast(i)), add(m, .player));
    try std.testing.expectEqual(@as(?u3, null), add(m, .player));
    try std.testing.expect(slot(m, 3).state.created);
    try std.testing.expectEqual(3 + 8, slot(m, 3).block);

    // Free slot 3 the way the engine does, and the next actor gets it.
    slot(m, 3).state.free = true;
    step(m);
    try std.testing.expect(slot(m, 3).state.unused);
    try std.testing.expectEqual(@as(?u3, 3), add(m, .player));
    try std.testing.expectEqual(@as(?u3, null), add(m, .player));
}

test "the table is one block: slot n is 16 n bytes in, in the field order" {
    try std.testing.expectEqual(16, @sizeOf(Actor));
    try std.testing.expectEqual(2, @offsetOf(Actor, "box"));
    try std.testing.expectEqual(1, @bitSizeOf(State) / 8);
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    slot(m, 5).box.x = 99;
    try std.testing.expectEqual(99, m.ram[map.actors.first + 5 * 16 + 2]);
    slot(m, 5).state = .{ .unused = true, .flash = true };
    try std.testing.expectEqual(0b0100_0001, m.ram[map.actors.first + 5 * 16 + 1]);
}
