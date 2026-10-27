//! Frankenstein's monster. He stands asleep in his alcove until an
//! explorer comes onto his floor in front of him. Then he walks the
//! castle's walkways, ladders and poles, choosing his way at every
//! junction by where the explorer is. He's slower than you, and he never
//! gives up.

const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");
const trapdoors = @import("trapdoors.zig");
const sound = @import("sound.zig");

/// Directions, as everywhere: 0 up, 2 right, 4 down, 6 left, and `still`.
const still: u8 = 0x80;
const right = 2;

/// He stands on the walkway under his alcove, 24 rows below its top. Asleep,
/// his left edge is the record's X; the alcove's picture starts 4 fat
/// pixels further left, so that he stands inside it.
const alcove_height = 24;
const alcove_dx = 4;

/// He wakes when the explorer's top is fewer than 4 rows from his.
const level = 4;

/// A turn every other step: a fat pixel along, or two rows up or down.
const pace = 2;

/// His pictures: three for each way he walks, four climbing, all in a row
/// in shapes.Id.
const right_0 = @intFromEnum(shapes.Id.frank_right_0);
const left_0 = @intFromEnum(shapes.Id.frank_left_0);
const climb_0 = @intFromEnum(shapes.Id.frank_climb_0);
comptime {
    if (@intFromEnum(shapes.Id.frank_right_2) != right_0 + 2 or @intFromEnum(shapes.Id.frank_left_2) != left_0 + 2 or
        @intFromEnum(shapes.Id.frank_climb_3) != climb_0 + 3)
        @compileError("Frankenstein's walking and climbing pictures must be in rows in shapes.Id");
}

/// An awake Frankenstein's record keeps his picture by 1984's numbers,
/// so a castle saved in the middle of a game means the same thing here
/// and on a 1984 disk: $84 to $86 walking right, $87 to $89 left, $8A
/// sliding down a pole, $8B to $8E climbing, $8F asleep.
const pictures = [_]shapes.Id{
    .frank_right_0, .frank_right_1, .frank_right_2, .frank_left_0,  .frank_left_1,  .frank_left_2,
    .frank_slide,   .frank_climb_0, .frank_climb_1, .frank_climb_2, .frank_climb_3, .frank_asleep,
};
const first_picture = 0x84;

/// The picture a record's frame byte names.
fn fromRecord(m: *Machine, byte: u8) shapes.Id {
    m.work(10); // the subtract and the test
    const i = byte -% first_picture;
    return if (i < pictures.len) pictures[i] else .frank_asleep;
}

/// The frame byte for a picture.
fn toRecord(m: *Machine, frame: u8) u8 {
    for (pictures, 0..) |id, i| {
        m.work(6); // the loop
        if (@intFromEnum(id) == frame) return first_picture + @as(u8, @intCast(i));
    }
    return first_picture + pictures.len - 1;
}

/// A Frankenstein record: three cells of walkway under his alcove lose
/// their way back in, so that nobody walks in behind him and he only
/// walks out. Then the alcove, an object, and the monster himself, unless
/// he's dead.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const f = m.view(castle.Frankenstein, r.at);
    if (grid.column(f.x)) |col| {
        // 1984's arithmetic: facing right, his own cell and the two after
        // it; facing left, the cell before his, his, and the one after.
        const first = if (f.state.left) col -| 1 else col;
        const closed: u8 = if (f.state.left) grid.right else grid.left;
        const row = (f.y + alcove_height) / 8;
        for (0..3) |i| {
            const at = grid.cell(m, first + @as(u8, @intCast(i)), row);
            m.poke(at, m.peek(at) & ~closed);
        }
    }
    const picture: shapes.Id = if (f.state.left) .alcove_left else .alcove_right;
    room.place(m, picture, f.x -% alcove_dx, f.y);
    const n = objects.add(m, .alcove, room.boxOf(m, picture, f.x -% alcove_dx, f.y), r.at) orelse return;
    if (f.state.dead) return;
    const slot = actors.add(m, .frankenstein) orelse return; // no sprite: he waits in the castle
    objects.slot(m, n).actor = slot;
    const a = actors.slot(m, slot);
    a.pace = pace;
    if (f.state.awake) {
        a.box.x = f.frank_x;
        a.box.y = f.frank_y;
        a.way = f.way;
        actors.setFrame(m, slot, fromRecord(m, f.frame));
    } else {
        a.box.x = f.x;
        a.box.y = f.y + alcove_height - player.feet_y;
        a.way = still;
        actors.setFrame(m, slot, .frank_asleep);
    }
    m.work(40); // the sums and the stores
}

/// His turn. Asleep, he only checks whether to wake. Awake, he chooses a
/// way, takes a step, and the castle remembers where he got to.
pub fn turn(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    const o = objects.owner(m, .alcove, n) orelse return;
    if (a.state.destroy) {
        a.state.destroy = false;
        a.state.free = true;
        o.actor = actors.none;
        return;
    }
    a.state.created = false;
    const f = m.view(castle.Frankenstein, o.record);
    if (!f.state.awake) {
        if (!wakes(m, a, f)) return;
        f.state.awake = true;
        sound.effect(m, .frankenstein);
        a.way = still;
    }
    trapdoors.tread(m, &o.plate, &o.last_plate);
    const ways = grid.at(m, a.box.x + player.feet_x, a.box.y + player.feet_y);
    a.way = choose(m, a, ways);
    move(m, n, ways);
    f.frank_x = a.box.x;
    f.frank_y = a.box.y;
    f.frame = toRecord(m, a.frame);
    f.way = a.way;
    m.work(20); // the stores
}

/// Does he wake? Only for an explorer walking the room, on his level
/// (their tops fewer than 4 rows apart), and in front of him. Either
/// explorer will do.
fn wakes(m: *Machine, a: *align(1) actors.Actor, f: *align(1) castle.Frankenstein) bool {
    for (0..2) |p| {
        const him = (player.walking(m, @intCast(p)) orelse continue).box;
        const y = a.box.y;
        m.work(24); // the sums and the tests
        if ((if (him.y > y) him.y - y else y - him.y) >= level) continue;
        if (if (f.state.left) him.x <= a.box.x else him.x > a.box.x) return true;
    }
    return false;
}

/// Which way now, from the cell whose ways are `ways`. One way out: that
/// one. Two, straight through (a corridor), and he's going one of them:
/// keep going. Otherwise it's a junction, and the explorer decides: the
/// direction he's farthest away in comes first, then the other, as long
/// as the grid has it. No way at all, or none towards the explorer: stand.
fn choose(m: *Machine, a: *align(1) actors.Actor, ways: u8) u8 {
    m.work(60); // the loops and the tests
    var open: u8 = 0;
    var lowest: u8 = 0;
    var d: u8 = 8;
    while (d > 0) {
        d -= 2;
        if (ways & bit(d) != 0) {
            open += 1;
            lowest = d;
        }
    }
    if (open == 0) return still;
    if (open == 1) return lowest;
    if (open == 2 and ways & bit(lowest ^ 4) != 0 and a.way != still and ways & bit(a.way) != 0) return a.way;

    // How far the explorers are in each of the four directions, by
    // number: up, right, down, left. With two, the nearer one's distance
    // counts. 0xFF for a way nobody is.
    var far = [4]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
    for (0..2) |p| {
        const him = (player.walking(m, @intCast(p)) orelse continue).box;
        var apart = [4]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
        if (him.x >= a.box.x) apart[1] = him.x - a.box.x else apart[3] = a.box.x - him.x;
        if (him.y < a.box.y) apart[0] = a.box.y - him.y else apart[2] = him.y - a.box.y;
        for (&far, apart) |*f, his| f.* = @min(f.*, his);
        m.work(40); // the sums and the tests
    }
    // The farthest first. Each time round, only distances shorter than
    // the last one tried, and a tie goes to the lower number.
    var shorter: u8 = 0xFF;
    while (true) {
        var pick: ?u8 = null;
        var most: u8 = 0;
        var i: u8 = 4;
        while (i > 0) {
            i -= 1;
            if (far[i] >= shorter or far[i] < most) continue;
            most = far[i];
            pick = i;
        }
        const way = 2 * (pick orelse return still);
        if (ways & bit(way) != 0) return way;
        shorter = most;
        m.work(40); // another time round
    }
}

/// The grid bit for direction `way`.
fn bit(way: u8) u8 {
    return @as(u8, 1) << @intCast(way);
}

/// A step the way he chose, and his picture. Along: up onto the
/// walkway's row and a fat pixel over, the next picture of his walk.
/// Up or down: in line with the rungs, and two rows. With rungs here or
/// just below, he climbs; with none, it's a pole, and he slides down.
fn move(m: *Machine, n: u3, ways: u8) void {
    const a = actors.slot(m, n);
    const way = a.way;
    if (way == still) return; // and he keeps the picture he has
    const fx = a.box.x + player.feet_x;
    const fy = a.box.y + player.feet_y;
    m.work(40); // the sums and the tests
    var next: u8 = undefined;
    if (way & 3 == 2) {
        a.box.y -= fy % 8;
        const first: u8 = if (way == right) right_0 else left_0;
        a.box.x = if (way == right) a.box.x + 1 else a.box.x - 1;
        next = a.frame + 1;
        if (next <= first or next >= first + 3) next = first;
    } else {
        a.box.x = a.box.x - fx % 4 + 1;
        const rungs = (ways | grid.at(m, fx, fy +| 8)) & grid.up != 0;
        if (rungs) {
            a.box.y = if (way == 0) a.box.y - 2 else a.box.y + 2;
            next = climb_0 + ((a.box.y >> 1) & 3);
        } else {
            a.box.y += 2;
            next = @intFromEnum(shapes.Id.frank_slide);
        }
    }
    if (next != a.frame) actors.setFrame(m, n, @enumFromInt(next));
}

/// His `hit`. Asleep, nothing touches him. Awake, lightning or a laser is
/// the end of him; the explorer, a forcefield or a mummy is nothing to him.
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    const o = objects.owner(m, .alcove, n) orelse return false;
    const f = m.view(castle.Frankenstein, o.record);
    if (!f.state.awake) return false;
    switch (actors.slot(m, other).kind) {
        .lightning, .laser => {},
        else => return false,
    }
    f.state.awake = false;
    f.state.dead = true;
    return true;
}

/// His `touch`: an open trapdoor under his feet is the end of him, awake
/// or asleep, and a trapdoor's switch flips, as it does for anyone.
pub fn touch(m: *Machine, n: u3, object: u8) bool {
    const o = objects.owner(m, .alcove, n) orelse return false;
    switch (trapdoors.under(m, n, object)) {
        .hole => {
            const f = m.view(castle.Frankenstein, o.record);
            f.state.awake = false;
            f.state.dead = true;
            return true;
        },
        .plate => o.plate = object,
        .nothing => {},
    }
    return false;
}

// ---- tests ----------------------------------------------------------------

test "every picture of an awake Frankenstein goes into his record by 1984's number, and back" {
    const std = @import("std");
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    for (pictures) |id| try std.testing.expectEqual(id, fromRecord(m, toRecord(m, @intFromEnum(id))));
    try std.testing.expectEqual(0x84, toRecord(m, @intFromEnum(shapes.Id.frank_right_0)));
    try std.testing.expectEqual(shapes.Id.frank_climb_0, fromRecord(m, 0x8B));
    try std.testing.expectEqual(shapes.Id.frank_asleep, fromRecord(m, 0x8F));
}
