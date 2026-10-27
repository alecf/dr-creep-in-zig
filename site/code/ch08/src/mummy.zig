//! Mummies, their tombs and their ankhs. A mummy sleeps in a tomb of
//! sandstone blocks until someone walks past his ankh. Then the blocks
//! fall, he climbs out, and he follows the explorer along his floor,
//! for as long as the castle stands.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");
const trapdoors = @import("trapdoors.zig");

/// The tomb: 5 blocks across and 3 down, each 4 fat pixels by 8 rows.
/// Its hole is the middle three blocks of the middle row.
const across = 5;
const down = 3;

/// The ankh wakes him when the explorer's feet are fewer than 8 fat
/// pixels past its left edge.
const reach = 8;

/// Out of his tomb, he stands in front of the hole, feet on the floor
/// under the tomb: 6 fat pixels in from its left edge, 3 rows down from
/// its top.
const out_x = 6;
const out_y = 3;

/// The ankh's colours, and white for when it flashes: 8 flashes, a change
/// every fourth step.
const gold: u8 = @as(u8, @intFromEnum(Color.orange)) << 4 | @intFromEnum(Color.yellow);
const flash: u8 = @as(u8, @intFromEnum(Color.white)) << 4 | @intFromEnum(Color.white);
const flashes = 8;

/// Climbing out, one entry a turn, a turn every fourth step: a picture
/// and a step down. He starts in the hole, 8 rows up, and drops to the
/// floor. Then he walks.
const Rise = struct { dy: u8 = 0, frame: shapes.Id };
const rise = [_]Rise{
    .{ .frame = .mummy_rise_0 },
    .{ .frame = .mummy_rise_0 },
    .{ .frame = .mummy_rise_1 },
    .{ .dy = 2, .frame = .mummy_rise_1 },
    .{ .dy = 2, .frame = .mummy_rise_2 },
    .{ .dy = 2, .frame = .mummy_rise_2 },
    .{ .dy = 2, .frame = .mummy_rise_2 },
};
const rise_pace = 4;
const walk_pace = 2;
const rise_drop = 8;
comptime {
    var y: u8 = 0;
    for (rise) |r| y += r.dy;
    if (y != rise_drop) @compileError("climbing out must drop him 8 rows, from the hole to the floor");
}

/// His walk: three pictures each way, in a row in shapes.Id.
const right_0 = @intFromEnum(shapes.Id.mummy_right_0);
const left_0 = @intFromEnum(shapes.Id.mummy_left_0);
comptime {
    if (@intFromEnum(shapes.Id.mummy_right_2) != right_0 + 2 or @intFromEnum(shapes.Id.mummy_left_2) != left_0 + 2)
        @compileError("each way's three mummy pictures must be in a row in shapes.Id");
}

/// A mummy record: the tomb, open if he's out of it, and the ankh, an
/// object. Out and not dead, he's an actor too, where the castle says he
/// got to.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const u = m.view(castle.Mummy, r.at);
    var row: u8 = 0;
    while (row < down) : (row += 1) {
        var col: u8 = 0;
        while (col < across) : (col += 1) room.place(m, .brick, u.tomb_x + 4 * col, u.tomb_y + 8 * row);
    }
    if (u.state != castle.mummy_tomb) open(m, u);
    room.place(m, .ankh, u.ankh_x, u.ankh_y);
    const n = objects.add(m, .ankh, room.boxOf(m, .ankh, u.ankh_x, u.ankh_y), r.at) orelse return;
    if (u.state == castle.mummy_out) wake(m, n, false);
    m.work(20); // the tests
}

/// Knock out the middle three blocks of the tomb's middle row, and draw
/// the hole they leave.
fn open(m: *Machine, u: *align(1) castle.Mummy) void {
    const y = u.tomb_y + 8;
    var col: u8 = 1;
    while (col < across - 1) : (col += 1) room.unplace(m, .brick, u.tomb_x + 4 * col, y);
    room.place(m, .tomb_open, u.tomb_x + 4, y);
}

/// The ankh's `in_front`: the explorer walks past it. If its mummy is in
/// his tomb, he's out now, in the castle and on the screen: the ankh
/// flashes, the tomb opens, and he climbs out.
pub fn release(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(20); // the tests
    if (a.kind != .player or !player.playing(m)) return;
    if (a.box.x +% player.feet_x -% o.box.x >= reach) return;
    const u = m.view(castle.Mummy, o.record);
    if (u.state != castle.mummy_tomb) return;
    u.state = castle.mummy_out;
    u.x = u.tomb_x + out_x; // where he'll be once he's out, in case
    u.y = u.tomb_y + out_y; // the room ends before he is
    o.flags.execute = true;
    o.step = flashes;
    open(m, u);
    wake(m, n, true);
}

/// The ankh's `execute`, every fourth step after it woke him: white, then
/// gold again, 8 times over.
pub fn glow(m: *Machine, n: u8) void {
    if (objects.clock(m) & 3 != 0) return;
    const o = objects.slot(m, n);
    o.step -= 1;
    if (o.step == 0) o.flags.execute = false;
    room.tint(m, o.box.x, o.box.y, 2, 2, if (o.step & 1 != 0) flash else gold);
}

/// Ankh `n`'s mummy as an actor: climbing out of the hole, or already out
/// where the castle says. With no sprite free, he stays in the castle and
/// out of sight until the next visit.
fn wake(m: *Machine, n: u8, climbing: bool) void {
    const o = objects.slot(m, n);
    const u = m.view(castle.Mummy, o.record);
    const slot = actors.add(m, .mummy) orelse return;
    o.actor = slot;
    const a = actors.slot(m, slot);
    if (climbing) {
        a.box.x = u.tomb_x + out_x;
        a.box.y = u.tomb_y + out_y - rise_drop;
        a.pace = rise_pace;
        actors.setFrame(m, slot, rise[0].frame);
    } else {
        a.box.x = u.x;
        a.box.y = u.y;
        a.walk = rise.len;
        a.pace = walk_pace;
        actors.setFrame(m, slot, .mummy_left_0);
    }
    m.work(20); // the stores
}

/// A mummy's turn. Climbing out, the next entry of `rise`. Out, a step
/// towards the explorer's X, if he's walking the room, the mummy isn't
/// there yet, and the grid has a way along. A mummy never climbs: he
/// keeps to his floor. Every step goes into the castle.
pub fn walk(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    const o = objects.owner(m, .ankh, n) orelse return;
    if (a.state.destroy) {
        a.state.destroy = false;
        a.state.free = true;
        o.actor = actors.none;
        return;
    }
    a.state.created = false;
    trapdoors.tread(m, &o.plate, &o.last_plate);
    if (a.walk < rise.len) {
        const r = rise[a.walk];
        a.walk += 1;
        a.box.y += r.dy;
        actors.setFrame(m, n, r.frame);
        if (a.walk == rise.len) a.pace = walk_pace;
        return;
    }
    if (!player.playing(m)) return;
    const him = actors.slot(m, @intCast(m.peek(map.player_actor))).box.x;
    const x = a.box.x;
    m.work(30); // the sums and the tests
    if ((if (x > him) x - him else him - x) < 2) return; // he's there
    const ways = grid.at(m, x + player.feet_x, a.box.y + player.feet_y);
    const first: u8 = if (x < him) right_0 else left_0;
    if (x < him) {
        if (ways & grid.right == 0) return;
        a.box.x += 1;
    } else {
        if (ways & grid.left == 0) return;
        a.box.x -= 1;
    }
    const next = a.frame + 1;
    actors.setFrame(m, n, @enumFromInt(if (next > first and next < first + 3) next else first));
    const u = m.view(castle.Mummy, o.record);
    u.x = a.box.x;
    u.y = a.box.y;
}

/// A mummy's `hit`: his sprite touched another. Lightning and lasers are
/// the end of him; the explorer and Frankenstein's monster are nothing to
/// him. (A forcefield is in his group: he walks through it, if the grid
/// lets him.)
pub fn hit(m: *Machine, n: u3, other: u3) bool {
    switch (actors.slot(m, other).kind) {
        .lightning, .laser => {},
        else => return false,
    }
    const o = objects.owner(m, .ankh, n) orelse return true;
    m.view(castle.Mummy, o.record).state = castle.mummy_dead;
    return true;
}

/// A mummy's `touch`: an open trapdoor under his feet is the end of him,
/// and a trapdoor's switch flips, as it does for the explorer.
pub fn touch(m: *Machine, n: u3, object: u8) bool {
    const o = objects.owner(m, .ankh, n) orelse return false;
    switch (trapdoors.under(m, n, object)) {
        .hole => {
            m.view(castle.Mummy, o.record).state = castle.mummy_dead;
            return true;
        },
        .plate => o.plate = object,
        .nothing => {},
    }
    return false;
}
