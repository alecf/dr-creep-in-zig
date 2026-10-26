//! The matter transmitter: a booth, and the pads it can send you to. Each
//! pad has a colour of its own, and the lamp on the booth shows the
//! colour of the pad it will send you to.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const room = @import("room.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// The stick's direction for picking the next pad: up.
const stick_up = 0;

/// A lamp's or a pad's colours: code 10 is `color`, round a rim of dark
/// grey (code 01).
fn shade(color: u8) u8 {
    return @as(u8, @intFromEnum(Color.dark_grey)) << 4 | color;
}

/// Pad `i` is colour number i + 2: red, cyan, purple, green...
fn padColors(i: u8) u8 {
    return shade(i + 2);
}

/// Sending flashes the pad and the lamp 8 times, 2 steps on, 2 off.
const flashes = 8;

/// Where pad `i` of the booth at `at` is: the address of its x and y.
fn padAt(at: u16, i: u8) u16 {
    return at + @sizeOf(castle.Teleport) + @as(u16, i) * 2;
}

/// A teleport record: the booth, its lamp in the target pad's colour, and
/// every pad in its own colour.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const t = m.view(castle.Teleport, r.at);
    room.place(m, .booth, t.x, t.y);
    room.place(m, .lamp, t.x + 4, t.y);
    room.tint(m, t.x + 4, t.y, 2, 1, padColors(t.target));
    var i: u8 = 0;
    while (m.peek(padAt(r.at, i)) != 0) : (i += 1) {
        const x = m.peek(padAt(r.at, i));
        const y = m.peek(padAt(r.at, i) + 1);
        room.place(m, .pad, x, y);
        room.tint(m, x, y, 2, 1, padColors(i));
        m.work(10); // the loop
    }
    // The box he stands in: inside the booth, below its roof.
    _ = objects.add(m, .booth, .{ .x = t.x + 4, .y = t.y + 8, .width = 8, .height = 24 }, r.at);
}

/// A booth's `in_front`: the explorer inside it. Pushing up moves the
/// lamp on to the next pad (one every 16 steps while it's held); fire
/// sends him to the pad the lamp shows.
pub fn use(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(20); // the tests
    if (o.flags.execute or a.kind != .player or !player.playing(m)) return;
    const t = m.view(castle.Teleport, o.record);
    if (a.fire != 0) {
        const pad = padAt(o.record, t.target);
        a.box.x = m.peek(pad); // standing on it, feet on its floor
        a.box.y = m.peek(pad + 1) + 8 - player.feet_y;
        o.flags.execute = true;
        o.step = 2 * flashes;
        return;
    }
    if (a.stick != stick_up or objects.clock(m) & 15 != 0) return;
    t.target += 1;
    if (m.peek(padAt(o.record, t.target)) == 0) t.target = 0; // past the last pad: back to the first
    room.tint(m, t.x + 4, t.y, 2, 1, padColors(t.target));
}

/// A booth's `execute`, after a send: the lamp and the pad flash, white
/// and black against the pad's colour, every other step.
pub fn flash(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    const t = m.view(castle.Teleport, o.record);
    const pad = padAt(o.record, t.target);
    m.work(16); // the tests
    o.step -= 1;
    const on = o.step & 2 != 0 and o.step != 0;
    room.tint(m, m.peek(pad), m.peek(pad + 1), 2, 1, if (on) shade(@intFromEnum(Color.white)) else padColors(t.target));
    room.tint(m, t.x + 4, t.y, 2, 1, if (on) shade(@intFromEnum(Color.black)) else padColors(t.target));
    if (o.step == 0) o.flags.execute = false;
}
