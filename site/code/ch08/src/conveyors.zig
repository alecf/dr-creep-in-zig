//! Conveyor belts and their control boxes. A running belt carries the
//! explorer along whether he likes it or not, and the monsters too. Its
//! control stops it, and starts it again the other way.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// A belt is 8 cells long: 32 fat pixels.
const cells = 8;
const length = 4 * cells;

/// The slats' three shades, and the arrows on the control box, unlit and
/// lit. Code 01 stays dark grey in every cell.
fn shade(color: Color) u8 {
    return @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(color);
}
const slats = [3]u8{ shade(.white), shade(.light_grey), shade(.grey) };
const shades: u8 = slats.len;
const unlit = shade(.dark_grey);
const lit = shade(.light_green);

/// A conveyor record: the belt on the floor, and its control box with
/// the button in it. Nobody has pressed anything yet.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const c = m.view(castle.Conveyor, r.at);
    c.state &= ~castle.conveyor_players;
    room.place(m, .belt, c.x, c.y);
    room.place(m, .control, c.control_x, c.control_y);
    room.place(m, .control_knob, c.control_x + 4, c.control_y + 8);
    arrows(m, c);
    if (objects.add(m, .belt, room.boxOf(m, .belt, c.x, c.y), r.at)) |n| {
        objects.slot(m, n).flags.execute = true; // a belt always has work to do
    }
    _ = objects.add(m, .control, room.boxOf(m, .control, c.control_x, c.control_y), r.at);
    m.work(20); // the sums and the stores
}

/// Light the arrow for the way belt `c` is running, or neither if it's
/// stopped.
fn arrows(m: *Machine, c: *align(1) castle.Conveyor) void {
    const on = c.state & castle.conveyor_on != 0;
    const left = c.state & castle.conveyor_left != 0;
    room.tint(m, c.control_x, c.control_y + 16, 1, 1, if (on and left) lit else unlit);
    room.tint(m, c.control_x + 8, c.control_y + 16, 1, 1, if (on and !left) lit else unlit);
}

/// A control box's `in_front`: the explorer presses fire at it. The belt
/// hears about it on its next step.
pub fn press(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    m.work(12); // the tests
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
    m.view(castle.Conveyor, objects.slot(m, n).record).state |= castle.conveyor_pressed;
}

/// A belt's `execute`, every step. A fresh press (pressed this step, not
/// last step) works the belt: running, it stops and turns round; stopped,
/// it starts. Then, every other step while it runs, its slats move on a
/// cell, by recolouring them.
pub fn run(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    const c = m.view(castle.Conveyor, o.record);
    m.work(20); // the tests
    const pressed = c.state & castle.conveyor_pressed != 0;
    if (pressed and c.state & castle.conveyor_held == 0) {
        if (c.state & castle.conveyor_on != 0) {
            c.state ^= castle.conveyor_on | castle.conveyor_left;
        } else {
            c.state |= castle.conveyor_on;
        }
        arrows(m, c);
    }
    c.state &= ~(castle.conveyor_pressed | castle.conveyor_held);
    if (pressed) c.state |= castle.conveyor_held;

    if (c.state & castle.conveyor_on == 0 or objects.clock(m) & 1 != 0) return;
    // Running left, each cell takes the shade of the cell on its right.
    o.step = if (c.state & castle.conveyor_left != 0)
        (o.step + 1) % shades
    else
        (o.step + shades - 1) % shades;
    var i: u8 = 0;
    while (i < cells) : (i += 1) {
        room.tint(m, c.x + 4 * i, c.y, 1, 1, slats[(i + o.step) % shades]);
    }
}

/// A belt's `in_front`: while it runs, it carries whoever is on it. A
/// monster goes 2 fat pixels a turn, whatever it's doing. An explorer goes
/// only while he's standing or walking (not climbing), a fat pixel a step
/// and two every eighth step, so walking against it only just loses.
pub fn carry(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(24); // the tests
    if (m.view(castle.Conveyor, o.record).state & castle.conveyor_on == 0) return;
    switch (a.kind) {
        .player => {
            const walking = a.frame >= @intFromEnum(shapes.Id.explorer_right_0) and a.frame <= @intFromEnum(shapes.Id.explorer_left_3);
            if (!walking) return;
        },
        .mummy, .frankenstein => {},
        else => return,
    }
    if (a.box.x +% player.feet_x -% o.box.x >= length) return; // its feet aren't on it
    const left = m.view(castle.Conveyor, o.record).state & castle.conveyor_left != 0;
    const dx: u8 = if (left) 0xFF else 1;
    a.box.x +%= dx;
    if (a.kind != .player or objects.clock(m) & 7 == 0) a.box.x +%= dx;
}
