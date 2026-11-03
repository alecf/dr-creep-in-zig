//! The explorers: player 1 on joystick 1 and player 2 on joystick 2,
//! each an actor of kind `player`. They walk the castle's floors, climb
//! its ladders, slide down its poles and go through its doors.

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

/// Player 1 or player 2, as a number: 0 or 1. It picks his byte in each
/// of the castle header's pairs.
pub const Number = u1;

/// What the game keeps for each explorer from one of his turns to the
/// next. Where he is and what he's doing in a room is mostly his actor's
/// business (actors.zig).
pub const Player = extern struct {
    actor: u8, // the actor slot he has in this room, or actors.none
    last_stick: u8, // his joystick as it read at his last turn
    plate: u8, // the trapdoor switch under his feet this turn, or objects.none
    last_plate: u8, // the one under them last turn
    mask: u8, // the ways the other explorer leaves him for his next step
};
comptime {
    if (2 * @sizeOf(Player) != map.players.last - map.players.first + 1)
        @compileError("two Players must fill the players region exactly");
}

/// Each player's joystick port, and the colour of his coat.
const ports = [2]u16{ hw.joy1, hw.joy2 };
const coats = [2]Color{ .white, .yellow };

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
    for (records(m)) |*r| r.last_stick = 0xFF; // nothing held
}

/// Both players' records, as the two structs they are.
fn records(m: *Machine) *align(1) [2]Player {
    return m.view([2]Player, map.players.first);
}

/// Player `p`'s record.
pub fn record(m: *Machine, p: Number) *align(1) Player {
    return &records(m)[p];
}

/// Which player actor `n` is. Only for an actor of kind `player`.
pub fn number(m: *Machine, n: u3) Number {
    m.work(8); // the compare
    return @intFromBool(record(m, 1).actor == n);
}

/// Is player `p` in the room about to be played? He is if he's still in
/// the game and it's the room he's in.
pub fn here(m: *Machine, p: Number) bool {
    m.work(16); // the tests
    return m.peek(castle.in_game + p) != 0 and m.peek(castle.room + p) == m.peek(map.room_number);
}

/// Into the room: every player who's here, player 1 first.
pub fn arrive(m: *Machine) void {
    m.poke(map.engine_ending, 0);
    for (0..2) |i| {
        const p: Number = @intCast(i);
        record(m, p).actor = actors.none;
        if (here(m, p)) add(m, p);
    }
}

/// Player `p` into the room, at the door he came by. If it's open he walks
/// out of it; if it's shut he starts in front of it. A room with no doors
/// (the final room) puts him in the middle of the floor.
fn add(m: *Machine, p: Number) void {
    const n = actors.add(m, .player) orelse return; // the players come first, so never
    const r = record(m, p);
    r.actor = n;
    r.plate = objects.none;
    r.last_plate = objects.none;
    r.mask = 0xFF;
    setStatus(m, p, .playing);
    const a = actors.slot(m, n);
    a.box.x = middle;
    a.box.y = room.floor_top - feet_y;
    a.way = still;
    if (room.doorAt(m, m.peek(map.room_number), m.peek(castle.door + p))) |at| {
        const d = m.view(castle.Door, at);
        a.box.x = d.x + door_x;
        a.box.y = d.y + door_y;
        if (d.side & castle.door_open != 0) {
            // Inside it, where a walk in ends, and on his way out.
            a.box.x += walk_across;
            a.box.y -= walk_up;
            a.walk = walk_out;
            a.pace = 3;
            setStatus(m, p, .doorway);
        }
    }
    m.work(40); // the sums and the stores
    picture(m, n, if (a.box.x < middle) .explorer_right_0 else .explorer_left_0);
}

/// The colour of player `p`'s coat.
pub fn coat(p: Number) Color {
    return coats[p];
}

/// Show picture `id` for explorer `n`, in his own coat.
fn picture(m: *Machine, n: u3, id: shapes.Id) void {
    actors.setFrame(m, n, id);
    actors.slot(m, n).color = @intFromEnum(coat(number(m, n)));
}

/// What player `p` is doing.
pub fn status(m: *Machine, p: Number) Status {
    return @enumFromInt(m.peek(castle.status + p));
}

fn setStatus(m: *Machine, p: Number, s: Status) void {
    m.poke(castle.status + p, @intFromEnum(s));
}

/// Is actor `n` an explorer, walking the room?
pub fn playing(m: *Machine, n: u3) bool {
    m.work(8); // the test
    if (actors.slot(m, n).kind != .player) return false;
    return status(m, number(m, n)) == .playing;
}

/// Player `p`'s actor, if he's in this room and walking it.
pub fn walking(m: *Machine, p: Number) ?*align(1) actors.Actor {
    const n = record(m, p).actor;
    m.work(12); // the tests
    if (n == actors.none or status(m, p) != .playing) return null;
    return actors.slot(m, @intCast(n));
}

/// The explorer walking the room whose top is nearest row `y`, if
/// anyone is: what a gun turns towards. Player 2 is looked at first, and
/// only a nearer player 1 takes his place, so a tie goes to player 2.
pub fn nearest(m: *Machine, y: u8) ?*align(1) actors.Actor {
    var best: ?*align(1) actors.Actor = null;
    var gap: u8 = 0xFF;
    var i: u8 = 2;
    while (i > 0) {
        i -= 1;
        const a = walking(m, @intCast(i)) orelse continue;
        const d = if (a.box.y > y) a.box.y - y else y - a.box.y;
        m.work(20); // the sums and the test
        if (best == null or d < gap) {
            best = a;
            gap = d;
        }
    }
    return best;
}

/// Is actor `n`'s fire button down right now? Not a fresh press: held.
pub fn holding(m: *Machine, n: u3) bool {
    if (!playing(m, n)) return false;
    return held(record(m, number(m, n)).last_stick, joy.fire);
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
    const p = number(m, n);
    const r = record(m, p);
    read(m, a, p);
    trapdoors.tread(m, &r.plate, &r.last_plate);
    switch (status(m, p)) {
        .playing => steer(m, n),
        .doorway => walk(m, n),
        else => {},
    }
}

/// Read player `p`'s joystick, once a turn: its direction, and whether
/// fire is down now and wasn't at his last turn. The port byte is kept
/// for next time here and nowhere else in a room, so a fire button held
/// down is never a fresh press, however far he carries it.
fn read(m: *Machine, a: *align(1) actors.Actor, p: Number) void {
    const r = record(m, p);
    const stick = m.peek(ports[p]);
    a.stick = stick_way[stick & 0x0F];
    a.fire = @intFromBool(pressed(stick, r.last_stick));
    r.last_stick = stick;
    m.work(16); // the table read and the test
}

/// One step: read the grid under his feet, pick a way to go, take the
/// step and pick his picture.
fn steer(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    var x = a.box.x;
    var y = a.box.y;
    const fx = x + feet_x;
    const fy = y + feet_y;
    const r = record(m, number(m, n));
    const ways = waysAt(m, fx, fy) & r.mask; // less any way the other explorer is in
    r.mask = 0xFF;

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
    if (next != now) picture(m, n, @enumFromInt(next));
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
/// leads to. Through the way out, he's escaped the castle.
pub fn walkIn(m: *Machine, n: u3, at: u16) void {
    if (!playing(m, n)) return;
    const p = number(m, n);
    const a = actors.slot(m, n);
    const d = m.view(castle.Door, at);
    setStatus(m, p, .doorway);
    a.walk = walk_in;
    a.pace = 3;
    a.box.x = d.x + door_x;
    a.box.y = d.y + door_y;
    m.poke(castle.room + p, d.to_room);
    m.poke(castle.door + p, d.to_door);
    if (d.exit != 0) m.poke(castle.escaped + p, 1);
    m.work(30); // the stores
}

/// A turn in a doorway: the next entry of the `doorway` table.
fn walk(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    const w = doorway[a.walk];
    m.work(24); // the table read and the sums
    if (w.then) |then| {
        setStatus(m, number(m, n), then);
        a.pace = 1;
        if (then == .gone) a.state.destroy = true;
        return;
    }
    a.box.x +%= w.dx;
    a.box.y +%= w.dy;
    a.walk += 1;
    picture(m, n, w.frame);
}

/// Give up this life (the X key): every explorer walking the room
/// flickers away, and the castle starts him again at its start door.
pub fn kill(m: *Machine) void {
    for (0..2) |i| {
        const p: Number = @intCast(i);
        const n = record(m, p).actor;
        if (n != actors.none and die(m, @intCast(n))) actors.slot(m, @intCast(n)).state.flash = true;
    }
}

/// This life is over for explorer `n`, if he's walking the room: he's
/// dead. True if he was, so that he starts to flicker.
fn die(m: *Machine, n: u3) bool {
    if (!playing(m, n)) return false;
    setStatus(m, number(m, n), .dead);
    return true;
}

/// His `hit`: his sprite touched actor `other`'s. A forcefield only stands
/// in his way (the grid sees to that), and the other explorer only
/// jostles; anything else is deadly.
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    const b = actors.slot(m, other);
    switch (b.kind) {
        .forcefield => return false,
        .player => {
            jostle(m, n, b);
            return false;
        },
        else => return die(m, n),
    }
}

/// Two explorers touching: he can't step into the other one. With the
/// other below him, his next step can't be down; above him, it can't be
/// up. Side by side (the same Y), or with the other one on a ladder or a
/// pole, they pass straight through each other.
fn jostle(m: *Machine, n: u3, other: *align(1) actors.Actor) void {
    const a = actors.slot(m, n);
    m.work(24); // the tests
    if (other.frame >= climb_0 and other.frame <= @intFromEnum(shapes.Id.explorer_slide)) return;
    if (other.box.y == a.box.y) return;
    record(m, number(m, n)).mask = if (other.box.y > a.box.y) ~grid.down else ~grid.up;
}

/// His `touch`: he's in front of object `object`. An open trapdoor under
/// his feet is the end of him; a trapdoor's switch under them is noted,
/// for his turn to flip.
pub fn touch(m: *Machine, n: u3, object: u8) bool {
    switch (trapdoors.under(m, n, object)) {
        .hole => return die(m, n),
        .plate => record(m, number(m, n)).plate = object,
        .nothing => {},
    }
    return false;
}

/// Is the room over? Not while anyone in it is playing or in a doorway.
/// Once they've all gone through a door or died, it runs on for 30 more
/// steps (a door finishes opening, a flicker ends), and then it is. On
/// the way it notes the last player still walking the room.
pub fn roomOver(m: *Machine) bool {
    var busy = false;
    var i: u8 = 2;
    while (i > 0) { // player 2 first, so that player 1 has the last word
        i -= 1;
        const p: Number = @intCast(i);
        m.work(16); // the tests
        if (record(m, p).actor == actors.none) continue;
        switch (status(m, p)) {
            .playing => {
                m.poke(castle.last, p);
                busy = true;
            },
            .doorway => busy = true,
            else => {},
        }
    }
    if (busy) return false;
    const left = m.peek(map.engine_ending);
    m.work(10); // the tests
    if (left == 1) return true;
    m.poke(map.engine_ending, if (left == 0) ending_steps else left - 1);
    return false;
}

/// Was fire pressed on player `p`'s stick this frame? For the screens
/// between rooms, where there's no actor. It keeps the stick for next
/// time, so call it once a frame.
pub fn pressedFire(m: *Machine, p: Number) bool {
    const r = record(m, p);
    const stick = m.peek(ports[p]);
    const yes = pressed(stick, r.last_stick);
    r.last_stick = stick;
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
