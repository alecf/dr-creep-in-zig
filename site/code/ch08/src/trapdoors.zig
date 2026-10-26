//! Trapdoors and their switches. A trapdoor is a hole in a walkway, and a
//! wall in the navigation grid while it's open. Its switch is a plate in
//! the floor: step onto it and the trapdoor flips.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const objects = @import("objects.zig");
const actors = @import("actors.zig");
const player = @import("player.zig");

/// The trapdoor's three pictures, from shut to open. Each covers the hole
/// and the cell above it.
const pictures = [_]shapes.Id{ .trapdoor_shut, .trapdoor_tilt, .trapdoor_open };
const shut = 0;
const open = pictures.len - 1;

/// Something is under an actor's feet when they're within 4 fat pixels
/// of its left edge, one byte of the screen.
const underfoot = 4;

/// The switch's middle: red while the trapdoor is open, green while it's
/// shut.
const danger: u8 = @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.red);
const safe: u8 = @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.green);

/// A trapdoor record: the trapdoor, in place of a piece of the walkway
/// at (x + 4, y), and its switch. Both objects get the same number, the
/// record's place in the group, so either can find the other.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const t = m.view(castle.Trapdoor, r.at);
    const number: u8 = @intCast(r.at - room.first(m, .trapdoor).?);
    const is_open = t.state & castle.trapdoor_open != 0;
    const x = t.x + 4;
    const y = t.y - 8;
    room.unplace(m, .walkway, x, t.y);
    room.place(m, pictures[if (is_open) open else shut], x, y);
    if (objects.add(m, .trapdoor, .{ .x = x, .y = y, .width = 4, .height = 16 }, r.at)) |n| {
        const o = objects.slot(m, n);
        o.number = number;
        o.open = @intFromBool(is_open);
        o.step = if (is_open) open else shut;
        o.flags.disable = !is_open; // shut, there's nothing to fall through
    }
    if (is_open) wall(m, t, true);
    room.place(m, .plate, t.switch_x, t.switch_y);
    room.tint(m, t.switch_x, t.switch_y, 1, 1, if (is_open) danger else safe);
    const n = objects.add(m, .plate, room.boxOf(m, .plate, t.switch_x, t.switch_y), r.at) orelse return;
    objects.slot(m, n).number = number;
    m.work(30); // the sums and the stores
}

/// Open trapdoor `t` stops the walkway either side of its hole leading
/// into it (1984's arithmetic: the hole is the cell after the one under
/// x). Shut, they lead across again.
fn wall(m: *Machine, t: *align(1) castle.Trapdoor, up: bool) void {
    const col = grid.column(t.x) orelse return;
    grid.wall(m, col + 1, t.y / 8, up);
}

/// The explorer stepped onto switch `plate`: flip its trapdoor, in the
/// castle and in the grid, and set it swinging.
pub fn flip(m: *Machine, plate: u8) void {
    const p = objects.slot(m, plate);
    const t = m.view(castle.Trapdoor, p.record);
    t.state ^= castle.trapdoor_open;
    const opening = t.state & castle.trapdoor_open != 0;
    wall(m, t, opening);
    room.tint(m, t.switch_x, t.switch_y, 1, 1, if (opening) danger else safe);
    const o = objects.slot(m, objects.find(m, .trapdoor, p.number) orelse return);
    o.open = @intFromBool(opening);
    o.flags.execute = true;
    if (!opening) o.flags.disable = true; // shutting: safe from the first step
    m.work(30); // the tests and the stores
}

/// A trapdoor's `execute`: one picture a step towards open or shut. Open
/// at last, it can be fallen through.
pub fn swing(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    const goal: u8 = if (o.open != 0) open else shut;
    m.work(16); // the tests
    if (o.step == goal) {
        o.flags.execute = false;
        if (o.open != 0) o.flags.disable = false;
        return;
    }
    const next = if (o.step < goal) o.step + 1 else o.step - 1;
    room.swap(m, pictures[o.step], pictures[next], o.box.x, o.box.y);
    o.step = next;
}

/// What actor `n` finds under its feet at object `object`: the hole of an
/// open trapdoor (a shut one can't be stood in front of), a switch, or
/// nothing.
pub const Under = enum { nothing, hole, plate };
pub fn under(m: *Machine, n: u3, object: u8) Under {
    const a = actors.slot(m, n);
    const o = objects.slot(m, object);
    m.work(16); // the tests
    if (a.box.x +% player.feet_x -% o.box.x >= underfoot) return .nothing;
    return switch (o.kind) {
        .trapdoor => .hole,
        .plate => .plate,
        else => .nothing,
    };
}

/// A switch flips when it's stepped onto: when an actor's touch found one
/// under its feet this turn (`plate`) that wasn't there last turn
/// (`last`). Standing on it doesn't flip it again. Then this turn's
/// becomes last turn's, and this turn's is cleared for the next touch.
pub fn tread(m: *Machine, plate: *align(1) u8, last: *align(1) u8) void {
    if (plate.* != objects.none and plate.* != last.*) flip(m, plate.*);
    last.* = plate.*;
    plate.* = objects.none;
    m.work(16); // the tests and the stores
}
