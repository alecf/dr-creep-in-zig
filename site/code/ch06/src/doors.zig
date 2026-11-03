//! Doors and doorbells at work: a bell rung, a door swinging open, and the
//! explorer walking through.

const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const room = @import("room.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// A bell answers feet up to 12 fat pixels from its left edge.
const bell_reach = 12;

/// The stick's direction for walking into a door: up and to the right,
/// the way the walk goes.
const into_door = 1;

/// A bell's `in_front`: the explorer, at the bell, presses fire. If its
/// door is shut, the door gets to work.
pub fn ring(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    const bell = objects.slot(m, n);
    m.work(20); // the tests
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
    if (a.box.x +% player.feet_x -% bell.box.x >= bell_reach) return; // his feet aren't under it
    const d = objects.slot(m, objects.find(m, .door, bell.number) orelse return);
    if (d.open == 0) d.flags.execute = true;
}

/// A door's `execute`, from the step after its bell rang. The first time,
/// it opens in the castle, on both sides; then its panel is wiped a row a
/// step, from the bottom up, and last of all it's drawn open.
pub fn open(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    m.work(20); // the tests
    if (o.open == 0) {
        o.open = 1;
        o.step = room.door_panel_height - 1;
        const d = m.view(castle.Door, o.record);
        d.side |= castle.door_open;
        if (room.doorAt(m, d.to_room, d.to_door)) |far| m.view(castle.Door, far).side |= castle.door_open;
        m.work(40); // the two doors' bits
    }
    room.wipe(m, o.box.x, o.box.y + o.step);
    if (o.step != 0) {
        o.step -= 1;
        return;
    }
    o.flags.execute = false; // done
    room.panel(m, o.record);
}

/// A door's `in_front`: at an open door, the explorer pushes the stick up
/// and to the right, and walks in.
pub fn enter(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(16); // the tests
    if (o.open == 0 or a.kind != .player or a.stick != into_door) return;
    player.walkIn(m, who, o.record);
}
