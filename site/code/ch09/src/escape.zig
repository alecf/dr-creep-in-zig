//! Out! The final room, put together a piece at a time, the explorer's
//! time in the castle, and a walk across the screen, with a cheer.

const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");
const clock = @import("clock.zig");
const dice = @import("dice.zig");
const game = @import("game.zig");

/// The escape at work, in the bytes it shares with the other screens
/// between rooms (game.zig).
pub const Escape = extern struct {
    who: u8, // the player escaping
    shown: u8, // the final room's records drawn so far, or `all`
    spot: u8, // in an image record, the places drawn so far
    wait: u8, // frames until the next piece
    walk: u8, // which of the two walks he does
    leg: u8, // how far through it he is
    left: u8, // steps left in this leg
};
const all = 0xFF;

/// A piece of the final room every 10 frames.
const piece_frames = 10;

/// His walk, in legs of so many steps: to the right, to the left, or
/// cheering on the spot. One walk in eight, he goes too far and comes back.
const Way = enum { right, left, cheer };
const Leg = struct { steps: u8, way: Way };
const walks = [2][]const Leg{
    &.{ .{ .steps = 128, .way = .right }, .{ .steps = 25, .way = .cheer }, .{ .steps = 45, .way = .right } },
    &.{ .{ .steps = 172, .way = .right }, .{ .steps = 44, .way = .left }, .{ .steps = 25, .way = .cheer }, .{ .steps = 45, .way = .right } },
};

/// He walks in from just off the left edge, on the final room's floor.
const start_x = 8;
const walker: u3 = 0; // his actor slot: he's the only actor

const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);

fn escape(m: *Machine) *align(1) Escape {
    return &game.between(m).escape;
}

/// The words, on an empty screen, and the explorer, waiting off it. Call
/// it with the display blanked.
pub fn draw(m: *Machine) void {
    const p = game.escaper(m) orelse return;
    actors.clear(m);
    screen.clear(m);
    grid.clear(m);
    objects.clear(m);
    m.poke(map.room_number, castle.roomCount(m)); // the final room
    _ = room.prepare(m, castle.roomCount(m)); // its colours
    if (p == 0) text.shout(m, 16, 0, .light_green, "PLAYER 1 ESCAPES") else text.shout(m, 16, 0, .light_green, "PLAYER 2 ESCAPES");
    text.say(m, 40, 24, .yellow, "TIME:");
    clock.print(m, 88, 24, .yellow, p);
    const walk: u8 = @intFromBool(dice.roll(m) & 0x0E == 0);
    escape(m).* = .{
        .who = p,
        .shown = if (m.peek16(castle.final_room) == 0) all else 0,
        .spot = 0,
        .wait = piece_frames,
        .walk = walk,
        .leg = 0,
        .left = walks[walk][0].steps,
    };
    const n = actors.add(m, .player).?; // the table is empty
    const a = actors.slot(m, n);
    a.box.x = start_x;
    a.box.y = room.floor_top - player.feet_y;
    picture(m, .explorer_right_0, p);
}

/// Every frame. First the final room, a piece at a time; then his walk,
/// a step every other frame. True when he's gone.
pub fn run(m: *Machine) bool {
    const e = escape(m);
    m.work(20); // the tests
    if (e.shown != all) {
        e.wait -= 1;
        if (e.wait == 0) {
            e.wait = piece_frames;
            piece(m, e);
        }
        return false;
    }
    if (m.peek(map.game_tick) & 1 != 0) return false;
    const legs = walks[e.walk];
    if (e.left == 0) {
        e.leg += 1;
        if (e.leg == legs.len) {
            m.poke(castle.in_game + e.who, 0); // out of the castle, and out of the game
            return true;
        }
        e.left = legs[e.leg].steps;
    }
    e.left -= 1;
    step(m, legs[e.leg].way, @intCast(e.who));
    return false;
}

/// The next piece of the final room: its next record, or, in a picture
/// drawn in several places, the next place.
fn piece(m: *Machine, e: *align(1) Escape) void {
    var walk = castle.Walker{ .at = room.stream(m, castle.roomCount(m)) };
    var i: u8 = 0;
    while (walk.next(m)) |r| : (i += 1) {
        if (i != e.shown) continue;
        if (r.kind != .image) {
            room.build(m, r);
            e.shown += 1;
            return;
        }
        shapes.point(m, .image, r.at);
        const place = r.at + castle.shapeSize(m, r.at) + 2 * @as(u16, e.spot);
        room.place(m, .image, m.peek(place), m.peek(place + 1));
        e.spot += 1;
        if (m.peek(place + 2) == 0) { // that was its last place
            e.spot = 0;
            e.shown += 1;
        }
        return;
    }
    e.shown = all; // every record drawn
}

/// One step of the walk, and its picture: Chapter 2's walk, a new frame
/// every 2 fat pixels, or a cheer, a new frame every 4 steps.
fn step(m: *Machine, way: Way, p: player.Number) void {
    const a = actors.slot(m, walker);
    m.work(20); // the sums
    switch (way) {
        .right => {
            a.box.x += 1;
            picture(m, @enumFromInt(right_0 + ((a.box.x >> 1) & 0b11)), p);
        },
        .left => {
            a.box.x -= 1;
            picture(m, @enumFromInt(left_0 + ((a.box.x >> 1) & 0b11)), p);
        },
        .cheer => picture(m, if (escape(m).left & 0b100 != 0) .explorer_cheer_0 else .explorer_cheer_1, p),
    }
}

/// His picture, in his own coat.
fn picture(m: *Machine, id: shapes.Id, p: player.Number) void {
    const a = actors.slot(m, walker);
    if (a.frame == @intFromEnum(id)) return;
    actors.setFrame(m, walker, id);
    a.color = @intFromEnum(player.coat(p));
}
