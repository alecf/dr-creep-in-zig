//! Forcefields and their buttons. The field is an actor that shimmers,
//! and a wall in the navigation grid. Its button takes it down, and a
//! gauge on the button counts the seconds until it comes back.

const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// The gauge has a row for each of 8 ticks, and a tick is 30 engine
/// steps: the field is down for 240 steps, nine and a bit seconds.
const ticks = 8;
const tick_steps = 30;

/// A forcefield record: the button, its gauge, the field's emitter, and
/// the field itself, up.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const f = m.view(castle.Forcefield, r.at);
    room.place(m, .button_frame, f.button_x, f.button_y);
    room.place(m, .button_lit, f.button_x + 4, f.button_y + 8);
    room.place(m, .field_top, f.field_x, f.field_y);
    const n = objects.add(m, .button, room.boxOf(m, .button_frame, f.button_x, f.button_y), r.at) orelse return;
    const field = actors.add(m, .forcefield) orelse return;
    const o = objects.slot(m, n);
    o.actor = field; // the link: the button knows its field by slot number
    const a = actors.slot(m, field);
    a.box.x = f.field_x;
    a.box.y = f.field_y + 2;
    a.pace = 4;
    raise(m, o, true);
    m.work(20); // the sums and the stores
}

/// Put button `o`'s field up, or take it down: its picture, and its wall
/// in the grid. 1984's field is under the emitter, 27 rows down.
fn raise(m: *Machine, o: *align(1) objects.Object, up: bool) void {
    const f = m.view(castle.Forcefield, o.record);
    const col = grid.column(f.field_x + 2) orelse return;
    grid.wall(m, col, (f.field_y + 27) / 8, up);
    actors.setFrame(m, @intCast(o.actor), if (up) .field_on_0 else .field_off);
}

/// A button's `in_front`: the explorer presses fire at it. The field goes
/// down (if it's up), the gauge goes out, and the countdown starts again
/// from the top.
pub fn press(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    const o = objects.slot(m, n);
    m.work(16); // the tests
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
    if (!o.flags.execute) raise(m, o, false);
    o.flags.execute = true;
    o.step = ticks;
    o.timer = tick_steps;
    const shape = shapes.address(m, .button_lit);
    for (0..ticks) |row| gauge(m, o, @intCast(row), shape, false);
}

/// A button's `execute`, every step while its field is down: every 30
/// steps, light the next row of the gauge, from the bottom. With all 8
/// lit, the field goes back up.
pub fn count(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    o.timer -= 1;
    m.work(8); // the test
    if (o.timer != 0) return;
    o.timer = tick_steps;
    o.step -= 1;
    gauge(m, o, o.step, shapes.address(m, .button_lit), true);
    if (o.step != 0) return;
    o.flags.execute = false;
    raise(m, o, true);
}

/// Light row `row` of button `o`'s gauge, or put it out: one bitmap byte,
/// copied from the gauge's shape at `shape`, or 0.
fn gauge(m: *Machine, o: *align(1) objects.Object, row: u8, shape: u16, lit: bool) void {
    const x = o.box.x + 4 - castle.left_edge;
    const at = screen.rowAddress(m, o.box.y + 8 + row) + @as(u16, x / 4) * 8;
    m.poke(at, if (lit) m.peek(shape + 3 + row) else 0);
    m.work(12); // the sums
}

/// A field's turn, every fourth step: while it's up, its two pictures
/// take turns. Its button does everything else.
pub fn shimmer(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    a.state.created = false;
    m.work(12); // the tests
    const frame: shapes.Id = @enumFromInt(a.frame);
    switch (frame) {
        .field_on_0 => actors.setFrame(m, n, .field_on_1),
        .field_on_1 => actors.setFrame(m, n, .field_on_0),
        else => {},
    }
}
