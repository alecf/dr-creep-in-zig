//! Lightning machines and their switches. A machine hangs from the
//! ceiling and, while it runs, a bolt of lightning (an actor) crackles
//! below it. A switch names the machines it works by number, and throwing
//! it flips every one of them.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const castle = @import("castle.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// The stick's directions for throwing a switch: up and down.
const stick_up = 0;
const stick_down = 4;

/// The pole's colours while the machine is off, and the three it cycles
/// through while it runs: codes 01 and 10, one colour in each half.
const dull: u8 = @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.grey);
const glow = [3]u8{
    @as(u8, @intFromEnum(Color.white)) << 4 | @intFromEnum(Color.light_blue),
    @as(u8, @intFromEnum(Color.light_blue)) << 4 | @intFromEnum(Color.blue),
    @as(u8, @intFromEnum(Color.blue)) << 4 | @intFromEnum(Color.white),
};

/// A lightning record: a switch, or a machine.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const l = m.view(castle.Lightning, r.at);
    if (l.state & castle.lightning_switch != 0) {
        // A plate on the wall, and the lever in it, up or down.
        room.place(m, .lever_plate, l.x, l.y);
        const picture = lever(l.state & castle.lightning_on != 0);
        room.place(m, picture, l.x + 4, l.y + 8);
        _ = objects.add(m, .lever, room.boxOf(m, picture, l.x + 4, l.y + 8), r.at);
        return;
    }
    // The pole, a piece every 8 rows, then the emitter, 4 fat pixels to
    // the left so that it's centred under the pole.
    var i: u8 = 0;
    while (i < l.length) : (i += 1) room.place(m, .machine_pole, l.x, l.y + 8 * i);
    const tip_x = l.x - 4;
    const tip_y = l.y + 8 * l.length;
    room.place(m, .machine_tip, tip_x, tip_y);
    const n = objects.add(m, .machine, room.boxOf(m, .machine_tip, tip_x, tip_y), r.at) orelse return;
    const o = objects.slot(m, n);
    o.number = @intCast(r.at - room.first(m, .lightning).?); // how switches name it
    o.flags.execute = l.state & castle.lightning_on != 0; // running: its first step makes the bolt
    m.work(20); // the sums and the stores
}

/// A switch's `in_front`: the explorer, under its lever, pushes the stick
/// up (on) or down (off). Every machine on the switch's list flips, and
/// gets a step to catch up with its new state.
pub fn pull(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(20); // the tests
    if (a.kind != .player or !player.playing(m)) return;
    if (a.box.x +% player.feet_x -% o.box.x >= o.box.width) return; // his feet aren't under it
    const on = switch (a.stick) {
        stick_up => true,
        stick_down => false,
        else => return,
    };
    const l = m.view(castle.Lightning, o.record);
    if ((l.state & castle.lightning_on != 0) == on) return; // it's that way already
    l.state ^= castle.lightning_on;
    const first = room.first(m, .lightning) orelse return;
    for (l.machines) |number| {
        if (number == 0xFF) break; // the end of the list
        m.view(castle.Lightning, first + number).state ^= castle.lightning_on;
        const machine_n = objects.find(m, .machine, number) orelse continue;
        objects.slot(m, machine_n).flags.execute = true;
        m.work(20); // the sums and the stores
    }
    room.swap(m, lever(!on), lever(on), o.box.x, o.box.y);
}

/// The lever's picture: up while its switch is on.
fn lever(on: bool) shapes.Id {
    return if (on) .lever_up else .lever_down;
}

/// A machine's `execute`. Switched off, it stops: the bolt goes and the
/// pole goes dull. Running, its first step makes the bolt, and every
/// fourth step after that moves the pole's colours along.
pub fn run(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    const l = m.view(castle.Lightning, o.record);
    m.work(20); // the tests
    if (l.state & castle.lightning_on == 0) {
        o.flags.execute = false;
        room.tint(m, l.x, l.y, 1, l.length, dull);
        if (o.actor != actors.none) actors.slot(m, @intCast(o.actor)).state.destroy = true;
        o.actor = actors.none;
        return;
    }
    if (o.actor == actors.none) {
        const bolt = actors.add(m, .lightning) orelse return; // no sprite free: try next step
        o.actor = bolt;
        const a = actors.slot(m, bolt);
        a.box.x = o.box.x;
        a.box.y = o.box.y + 8;
        actors.setFrame(m, bolt, .bolt_0);
        return;
    }
    if (objects.clock(m) & 3 != 0) return;
    o.step = if (o.step == glow.len - 1) 0 else o.step + 1;
    room.tint(m, l.x, l.y, 1, l.length, glow[o.step]);
}

/// A bolt's turn: a new picture, never the same one twice running, and a
/// new wait before the next, from 1 to 4 steps. A switched-off machine
/// sets `destroy`, and the bolt's last turn frees its slot.
pub fn crackle(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    if (a.state.destroy) {
        a.state.destroy = false;
        a.state.free = true;
        return;
    }
    a.state.created = false;
    // Not really random: the clock, stirred with the slot number so that
    // two bolts don't dance in step. Chapter 8 makes proper dice.
    const roll = objects.clock(m) ^ (@as(u8, n) *% 0x5B);
    a.pace = 1 + (roll & 3);
    const first = @intFromEnum(shapes.Id.bolt_0);
    const next = (a.frame - first + 1 + (roll >> 2) % 3) % 4; // 1 to 3 pictures on
    actors.setFrame(m, n, @enumFromInt(first + next));
    m.work(30); // the sums
}

comptime {
    if (@intFromEnum(shapes.Id.bolt_3) != @intFromEnum(shapes.Id.bolt_0) + 3)
        @compileError("the four bolts must be in a row in shapes.Id");
}
