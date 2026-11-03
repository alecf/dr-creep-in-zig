//! Player 1: the explorer, an actor of kind `player`. He walks the
//! castle's floors, climbs its ladders, slides down its poles and goes
//! through its doors, steered by joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const map = @import("map.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const trapdoors = @import("trapdoors.zig");

/// What he's doing, as far as the room is concerned.
pub const Status = enum(u8) {
    playing, // walking the room
    doorway, // walking into a door, or out of one
    gone, // through a door: the room is over
    dead, // flickering away: the room is over
    _,
};

/// His feet: the point the grid is read at, 3 fat pixels in from his left
/// edge and 21 rows down from his top, the row his boots stand on.
pub const feet_x = 3;
pub const feet_y = 21;

/// Something under his feet: they're within 4 fat pixels of its left
/// edge, one byte of the screen.
const underfoot = 4;

/// Where he appears in a doorway: in the middle, boots on the sill.
const door_x = 6;
const door_y = 11;

/// How many engine steps the room runs on after he's gone or dead.
const ending_steps = 30;

/// The first frame of each walk: four frames facing right, then four left.
const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);
const climb_0 = @intFromEnum(shapes.Id.explorer_climb_0);
comptime {
    if (left_0 != right_0 + 4 or @intFromEnum(shapes.Id.explorer_left_3) != left_0 + 3)
        @compileError("the explorer's eight frames must be in a row in shapes.Id");
    if (@intFromEnum(shapes.Id.explorer_climb_3) != climb_0 + 3)
        @compileError("the explorer's four climbing frames must be in a row in shapes.Id");
}

/// Directions run clockwise from 0, up, to 7, up and left: the grid's bit
/// numbers. `still` is no direction at all.
const still: u8 = 0x80;

/// The eight directions, laid out the way they are on the stick.
const compass = [3][3]u8{
    .{ 7, 0, 1 }, // up and left, up, up and right
    .{ 6, still, 2 }, // left, nothing, right
    .{ 5, 4, 3 }, // down and left, down, down and right
};

/// The direction for each of the 16 ways the stick's four direction
/// switches (the low four bits of its port) can read. Worked out by the
/// compiler with `held`; up and down together, or left and right, is still.
const stick_way: [16]u8 = blk: {
    var table: [16]u8 = undefined;
    for (&table, 0..) |*way, n| {
        const u = held(n, joy.up);
        const d = held(n, joy.down);
        const l = held(n, joy.left);
        const r = held(n, joy.right);
        const row: usize = if (u) 0 else if (d) 2 else 1;
        const col: usize = if (l) 0 else if (r) 2 else 1;
        way.* = if ((u and d) or (l and r)) still else compass[row][col];
    }
    break :blk table;
};

/// One step in each direction: fat pixels across, rows down. Added with
/// a wrapping +%, so 0xFF goes back 1 and 0xFE goes back 2.
const step_x = [8]u8{ 0, 1, 1, 1, 0, 0xFF, 0xFF, 0xFF };
const step_y = [8]u8{ 0xFE, 0xFE, 0, 2, 2, 2, 0, 0xFE };

/// Walking through a doorway, one entry a turn: a step and a picture, or,
/// at the end, what he does next.
const Walk = struct { dx: u8 = 0, dy: u8 = 0, frame: shapes.Id = .explorer_back_0, then: ?Status = null };
const doorway = [_]Walk{
    // In: five steps up and to the right, into the door, seen from behind.
    .{ .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .dx = 1, .dy = 0, .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .dx = 1, .dy = 0, .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .then = .gone },
    // Out: the same five steps backwards, down and to the left, turning
    // to face the room on the last one.
    .{ .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_back_0 },
    .{ .dx = 0xFF, .dy = 0, .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_back_0 },
    .{ .dx = 0xFF, .dy = 0, .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_left_0 },
    .{ .then = .playing },
};
const walk_in = 0;
const walk_out = 7;

/// How far the walk in takes him: across and up. He arrives in a room
/// where a walk in ends, and the compiler checks the table agrees.
const walk_across = 5;
const walk_up = 3;
comptime {
    var x: u8 = 0;
    var y: u8 = 0;
    for (doorway[walk_in..walk_out]) |w| {
        x +%= w.dx;
        y +%= w.dy;
    }
    if (x != walk_across or y != 0 -% @as(u8, walk_up))
        @compileError("the doorway walk must go 5 across and 3 up");
}

/// The middle of the screen, in castle X.
const middle = castle.left_edge + 80;

/// Once, at power-on.
pub fn start(m: *Machine) void {
    m.poke(hw.sprite_mc0, @intFromEnum(Color.pink)); // code 01: skin
    m.poke(hw.sprite_mc1, @intFromEnum(Color.orange)); // code 11: hat, belt, boots
    m.poke(map.player_last_stick, 0xFF); // nothing held
}

/// A new game: the castle's start room and start door, and its lives.
pub fn newGame(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
    m.poke(map.player_door, m.peek(castle.start_door));
    m.poke(map.player_lives, m.peek(castle.lives));
}

/// Into the room, at the door he came by. If it's open he walks out of
/// it; if it's shut he starts in front of it. A room with no doors (the
/// final room) puts him in the middle of the floor.
pub fn add(m: *Machine) void {
    const n = actors.add(m, .player) orelse return; // he's the first in, so never
    m.poke(map.player_actor, n);
    m.poke(map.player_status, @intFromEnum(Status.playing));
    m.poke(map.engine_ending, 0);
    m.poke(map.player_plate, objects.none);
    m.poke(map.player_last_plate, objects.none);
    const a = actors.slot(m, n);
    a.box.x = middle;
    a.box.y = room.floor_top - feet_y;
    a.way = still;
    if (room.doorAt(m, m.peek(map.room_number), m.peek(map.player_door))) |at| {
        const d = m.view(castle.Door, at);
        a.box.x = d.x + door_x;
        a.box.y = d.y + door_y;
        if (d.side & castle.door_open != 0) {
            // Inside it, where a walk in ends, and on his way out.
            a.box.x += walk_across;
            a.box.y -= walk_up;
            a.walk = walk_out;
            a.pace = 3;
            m.poke(map.player_status, @intFromEnum(Status.doorway));
        }
    }
    m.work(40); // the sums and the stores
    actors.setFrame(m, n, if (a.box.x < middle) .explorer_right_0 else .explorer_left_0);
}

/// What he's doing.
fn status(m: *Machine) Status {
    return @enumFromInt(m.peek(map.player_status));
}

/// Is he walking the room?
pub fn playing(m: *Machine) bool {
    return status(m) == .playing;
}

/// His turn, actor `n`'s: on every engine step while he walks the room,
/// every third in a doorway.
pub fn turn(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    if (a.state.destroy) { // his last turn: he's gone, or dead
        a.state.destroy = false;
        a.state.free = true;
        return;
    }
    a.state.created = false;
    read(m, a);
    tread(m);
    switch (status(m)) {
        .playing => steer(m, n),
        .doorway => walk(m, n),
        else => {},
    }
}

/// Read joystick 1, once a turn: its direction, and whether fire is down
/// now and wasn't at his last turn. The port byte is kept for next time here
/// and nowhere else in a room, so a fire button held down is never a
/// fresh press, however far he carries it.
fn read(m: *Machine, a: *align(1) actors.Actor) void {
    const stick = m.peek(hw.joy1);
    a.stick = stick_way[stick & 0x0F];
    a.fire = @intFromBool(pressed(stick, m.peek(map.player_last_stick)));
    m.poke(map.player_last_stick, stick);
    m.work(16); // the table read and the test
}

/// A trapdoor switch flips when he steps onto it: when his touch found
/// one under his feet this turn that wasn't there last turn. Standing on
/// it doesn't flip it again.
fn tread(m: *Machine) void {
    const plate = m.peek(map.player_plate);
    if (plate != objects.none and plate != m.peek(map.player_last_plate)) trapdoors.flip(m, plate);
    m.poke(map.player_last_plate, plate);
    m.poke(map.player_plate, objects.none);
    m.work(16); // the tests
}

/// One step: read the grid under his feet, pick a way to go, take the
/// step and pick his picture.
fn steer(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    var x = a.box.x;
    var y = a.box.y;
    const fx = x + feet_x;
    const fy = y + feet_y;
    const ways = waysAt(m, fx, fy);

    // The stick's direction if that way is open. If it isn't, but it's
    // next to the way he was already going (a diagonal, say), keep going.
    const want = a.stick;
    const last = a.way;
    var way = still;
    if (want != still) {
        if (ways & bit(want) != 0) {
            way = want;
        } else if (last != still and ways & bit(last) != 0 and
            (want == (last +% 1) & 7 or want == (last -% 1) & 7))
        {
            way = last;
        }
    }
    a.way = way;

    if (way != still) {
        if (way & 3 == 2) y -= fy % 8; // off sideways: up onto the walkway's row
        if (way & 3 == 0) x = x - fx % 4 + 1; // up or down: feet in line with the rungs
        x +%= step_x[way];
        y +%= step_y[way];
        a.box.x = x;
        a.box.y = y;
    }
    m.work(60); // the sums, tests and table reads above

    // His picture. Walking: Chapter 2's walk, a frame every 2 fat pixels.
    // Up or down: a ladder has rungs that lead up from here or from just
    // below; a pole has none.
    const now = a.frame;
    var next = now;
    if (way == 2 or way == 6) {
        next = (if (way == 2) right_0 else left_0) + ((x >> 1) & 0b11);
    } else if (way == 0 or way == 4) {
        const rungs = (ways | waysAt(m, fx, fy +| 8)) & grid.up != 0;
        next = if (rungs) climb_0 + ((y >> 2) & 0b11) else @intFromEnum(shapes.Id.explorer_slide);
    } else if (now >= right_0 and now < left_0 + 4) {
        next = if (now >= left_0) left_0 else right_0; // stopped walking: stand
    } // stopped on a ladder or a pole: hold on
    if (next != now) actors.setFrame(m, n, @enumFromInt(next));
}

/// The grid bit for direction `way` (0-7).
fn bit(way: u8) u8 {
    return @as(u8, 1) << @intCast(way);
}

/// The ways out of the cell under castle point (x, y): one byte from the
/// grid, or, with the Q switch on, the slow way, from the castle itself.
fn waysAt(m: *Machine, x: u8, y: u8) u8 {
    if (m.peek(map.debug_search) != 0)
        return grid.search(m, room.stream(m, m.peek(map.room_number)), x, y);
    return grid.at(m, x, y);
}

/// Into the door whose record is at `at`: he stands in front of it and
/// walks in, and when the room is over he'll come out of the door it
/// leads to.
pub fn walkIn(m: *Machine, n: u3, at: u16) void {
    if (!playing(m)) return;
    const a = actors.slot(m, n);
    const d = m.view(castle.Door, at);
    m.poke(map.player_status, @intFromEnum(Status.doorway));
    a.walk = walk_in;
    a.pace = 3;
    a.box.x = d.x + door_x;
    a.box.y = d.y + door_y;
    m.poke(map.room_number, d.to_room);
    m.poke(map.player_door, d.to_door);
    m.work(30); // the stores
}

/// A turn in a doorway: the next entry of the `doorway` table.
fn walk(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    const w = doorway[a.walk];
    m.work(24); // the table read and the sums
    if (w.then) |then| {
        m.poke(map.player_status, @intFromEnum(then));
        a.pace = 1;
        if (then == .gone) a.state.destroy = true;
        return;
    }
    a.box.x +%= w.dx;
    a.box.y +%= w.dy;
    a.walk += 1;
    actors.setFrame(m, n, w.frame);
}

/// Give up this life (the X key): he flickers away, and the castle starts
/// him again at its start door.
pub fn kill(m: *Machine) void {
    if (die(m)) actors.slot(m, @intCast(m.peek(map.player_actor))).state.flash = true;
}

/// This life is over, if he's walking the room: he's dead. True if he
/// was, so that he starts to flicker.
fn die(m: *Machine) bool {
    if (!playing(m)) return false;
    m.poke(map.player_status, @intFromEnum(Status.dead));
    return true;
}

/// His `hit`: his sprite touched actor `other`'s. A forcefield only stands
/// in his way (the grid sees to that); anything else is deadly.
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    _ = n;
    if (actors.slot(m, other).kind == .forcefield) return false;
    return die(m);
}

/// His `touch`: he's in front of object `object`. An open trapdoor under
/// his feet is the end of him; a trapdoor's switch under them is noted,
/// for `tread` to flip on his turn.
pub fn touch(m: *Machine, n: u3, object: u8) bool {
    const a = actors.slot(m, n);
    const o = objects.slot(m, object);
    m.work(16); // the tests
    if (a.box.x +% feet_x -% o.box.x >= underfoot) return false;
    switch (o.kind) {
        .trapdoor => return die(m),
        .plate => m.poke(map.player_plate, object),
        else => {},
    }
    return false;
}

/// Is the room over? Not while he's playing or in a doorway. Once he's
/// gone through a door or died, it runs on for 30 more steps (a door
/// finishes opening, a flicker ends), and then it is.
pub fn roomOver(m: *Machine) bool {
    if (playing(m) or status(m) == .doorway) return false;
    const left = m.peek(map.engine_ending);
    m.work(10); // the tests
    if (left == 1) return true;
    m.poke(map.engine_ending, if (left == 0) ending_steps else left - 1);
    return false;
}

/// After the room, where to? Through a door, the room and the door are set
/// already. Dead, he loses a life and starts again at the castle's start.
/// False if that was his last life: the game is over.
pub fn nextRoom(m: *Machine) bool {
    if (status(m) != .dead) return true;
    const lives = m.peek(map.player_lives) -| 1;
    m.poke(map.player_lives, lives);
    if (lives == 0) return false;
    m.poke(map.room_number, m.peek(castle.start_room));
    m.poke(map.player_door, m.peek(castle.start_door));
    return true;
}

/// Was fire pressed this frame? For the title screen, where there's no
/// actor yet. It keeps the stick for next time, so call it once a frame.
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const yes = pressed(stick, m.peek(map.player_last_stick));
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return yes;
}

/// Is fire pressed now that wasn't before? The Edge Detector Power-Up as
/// a plain function of two port bytes: no memory of its own.
pub fn pressed(stick: u8, before: u8) bool {
    return held(stick, joy.fire) and !held(before, joy.fire);
}

/// Is this switch held? Joystick switches read 0 while they're pressed.
fn held(stick: u8, switch_bit: u8) bool {
    return stick & switch_bit == 0;
}

// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "a press is fire held now and not before, whatever else is held" {
    const none: u8 = 0xFF;
    const fire: u8 = 0xFF & ~joy.fire;
    try std.testing.expect(pressed(fire, none));
    try std.testing.expect(!pressed(fire, fire)); // still held: not a press
    try std.testing.expect(!pressed(none, fire)); // let go
    try std.testing.expect(!pressed(none, none));
    try std.testing.expect(pressed(fire & ~joy.right, none & ~joy.right)); // walking and pressing
}
