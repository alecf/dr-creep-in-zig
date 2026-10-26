//! Ray guns and their control panels. A gun slides up and down its track,
//! following the explorer, and fires when he's level with it. At its
//! panel, he does the steering. A shot is a laser: an actor that lives
//! for one trip across the room.

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

/// A gun is 8 fat pixels by 11 rows. It hangs beside its track: to the
/// right of it, or, facing left, 8 fat pixels to its left.
const gun_width = 8;
const gun_height = 11;

/// The stick's directions at the panel.
const stick_up = 0;
const stick_down = 4;
const stick_still = 0x80;

/// The gun fires when the explorer's top is fewer than 5 rows from its
/// own. Its laser flies right or left: stick directions 2 and 6.
const aim = 5;
const right = 2;
const left = 6;

/// The panel's arrows are code 01 in their cells: lit green (up) or red
/// (down) while the gun moves that way, grey while it doesn't.
fn arrow(color: Color) u8 {
    return @as(u8, @intFromEnum(color)) << 4 | @intFromEnum(Color.grey);
}

comptime {
    if (@intFromEnum(shapes.Id.gun_right_3) != @intFromEnum(shapes.Id.gun_right_0) + 3 or
        @intFromEnum(shapes.Id.gun_left_3) != @intFromEnum(shapes.Id.gun_left_0) + 3)
        @compileError("each way's four gun pictures must be in a row in shapes.Id");
}

/// Where gun `g` hangs, beside its track.
fn gunX(g: *align(1) castle.RayGun) u8 {
    return if (g.state.left) g.x - gun_width else g.x + 4;
}

/// Gun `g`'s picture where it is now: the way it faces, and one of four,
/// by the low two bits of its row. A row down, the next picture: the
/// wheels turn as it slides.
fn picture(g: *align(1) castle.RayGun) shapes.Id {
    const first = @intFromEnum(if (g.state.left) shapes.Id.gun_left_0 else shapes.Id.gun_right_0);
    return @enumFromInt(first + (g.gun_y & 3));
}

/// The lowest row the gun's top can reach: its bottom on the track's last.
fn lowest(g: *align(1) castle.RayGun) u8 {
    return g.y + 8 * g.length - gun_height;
}

/// A ray gun record: the track, the gun where the castle says it got to,
/// and the panel. The gun is an object that always has work to do.
pub fn prepare(m: *Machine, r: castle.Record) void {
    const g = m.view(castle.RayGun, r.at);
    g.state.shot = false; // whatever it fired on the last visit is long gone
    var i: u8 = 0;
    while (i < g.length) : (i += 1) room.place(m, .track, g.x, g.y + 8 * i);
    if (!g.state.no_gun) {
        room.place(m, picture(g), gunX(g), g.gun_y);
        const box: actors.Box = .{ .x = gunX(g), .y = g.gun_y, .width = gun_width, .height = gun_height };
        if (objects.add(m, .gun, box, r.at)) |n| objects.slot(m, n).flags.execute = true;
    }
    room.place(m, .panel, g.control_x, g.control_y);
    lamps(m, g, false, false);
    _ = objects.add(m, .panel, room.boxOf(m, .panel, g.control_x, g.control_y), r.at);
    m.work(30); // the sums and the stores
}

/// Light gun `g`'s panel arrows: up, down, or neither.
fn lamps(m: *Machine, g: *align(1) castle.RayGun, up: bool, down: bool) void {
    room.tint(m, g.control_x, g.control_y, 2, 1, arrow(if (up) .green else .grey));
    room.tint(m, g.control_x, g.control_y + 16, 2, 1, arrow(if (down) .red else .grey));
}

/// A gun's `execute`, every fourth step. Unless the explorer at its panel
/// is steering it, it turns towards his row, and fires when he's within
/// 5 rows of it. Steered, it goes where the panel says, and fires when
/// the panel says.
pub fn run(m: *Machine, n: u8) void {
    if (objects.clock(m) & 3 != 0) return;
    const o = objects.slot(m, n);
    const g = m.view(castle.RayGun, o.record);
    m.work(30); // the tests
    var near: u8 = 0xFF; // rows between his top and the gun's
    if (!g.state.steered) {
        g.state.up = false;
        g.state.down = false;
        if (player.playing(m)) {
            const him = actors.slot(m, @intCast(m.peek(map.player_actor))).box.y;
            near = if (him > g.gun_y) him - g.gun_y else g.gun_y - him;
            if (him < g.gun_y) g.state.up = true else g.state.down = true;
        }
    }
    move(m, o, g);
    if (g.state.steered) {
        g.state.steered = false; // his panel says so again if he's still there
        if (!g.state.fire) return;
        g.state.fire = false;
    } else if (near >= aim) return;
    if (g.state.shot) return; // one laser at a time
    shoot(m, o, g);
}

/// A row up the track or a row down, if that's the way the gun wants to
/// go and there's track left. The picture follows it, and its panel's
/// arrows show which way it went.
fn move(m: *Machine, o: *align(1) objects.Object, g: *align(1) castle.RayGun) void {
    const old = picture(g);
    if (g.state.up and g.gun_y != g.y) {
        g.gun_y -= 1;
    } else if (g.state.down and g.gun_y < lowest(g)) {
        g.gun_y += 1;
    } else {
        lamps(m, g, false, false);
        return;
    }
    lamps(m, g, g.state.up, g.state.down);
    room.unplace(m, old, o.box.x, o.box.y);
    room.place(m, picture(g), o.box.x, g.gun_y);
    o.box.y = g.gun_y;
}

/// Fire: a laser from the muzzle, flying the way the gun faces. If all
/// eight sprites are busy, there's no laser, and the gun tries again on
/// its next turn.
fn shoot(m: *Machine, o: *align(1) objects.Object, g: *align(1) castle.RayGun) void {
    const n = actors.add(m, .laser) orelse return;
    const a = actors.slot(m, n);
    a.box.x = if (g.state.left) o.box.x - gun_width else o.box.x + gun_width;
    a.box.y = g.gun_y + 5; // the barrel's row
    a.way = if (g.state.left) left else right;
    actors.setFrame(m, n, .laser);
    g.state.shot = true;
    o.actor = n; // the link back: the laser's slot
}

/// A laser's turn, every step: 4 fat pixels on, until it's off the edge
/// of the screen. Its last turn frees its slot and tells its gun it can
/// fire again.
pub fn fly(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    if (a.state.destroy) {
        a.state.destroy = false;
        a.state.free = true;
        if (gunOf(m, n)) |o| {
            o.actor = actors.none;
            m.view(castle.RayGun, o.record).state.shot = false;
        }
        return;
    }
    a.state.created = false;
    a.box.x +%= if (a.way == right) 4 else 0xFC; // 0xFC is -4
    m.work(16); // the sums and the tests
    if (a.box.x >= 8 and a.box.x < castle.left_edge + 160) return;
    a.state.destroy = true; // off the edge
}

/// The gun that fired laser `n`: the one whose `actor` is n.
fn gunOf(m: *Machine, n: u3) ?*align(1) objects.Object {
    const count = m.peek(map.engine_objects);
    var i: u8 = 0;
    while (i < count) : (i += 1) {
        const o = objects.slot(m, i);
        m.work(12); // the tests and the loop
        if (o.kind == .gun and o.actor == n) return o;
    }
    return null;
}

/// A laser's `hit`: any sprite it meets stops it, an explorer or a
/// forcefield.
pub fn blocked(m: *Machine, n: u3, other: u3) bool {
    _ = m;
    _ = n;
    _ = other;
    return true;
}

/// A laser's `touch`: a lightning machine stops it, and so does any gun
/// but its own, which it leaves from right beside.
pub fn strike(m: *Machine, n: u3, object: u8) bool {
    const o = objects.slot(m, object);
    m.work(12); // the tests
    return switch (o.kind) {
        .machine => true,
        .gun => o.actor != n,
        else => false,
    };
}

/// A panel's `in_front`: the explorer stands at it, and the gun is his.
/// Up and down move it, still holds it, and fire shoots. It hears all
/// that on its next turn.
pub fn steer(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(20); // the tests
    if (a.kind != .player or !player.playing(m)) return;
    if (a.box.x +% player.feet_x -% o.box.x >= o.box.width) return; // his feet aren't at it
    const g = m.view(castle.RayGun, o.record);
    switch (a.stick) {
        stick_up => {
            g.state.up = true;
            g.state.down = false;
        },
        stick_down => {
            g.state.up = false;
            g.state.down = true;
        },
        stick_still => {
            g.state.up = false;
            g.state.down = false;
        },
        else => return,
    }
    g.state.steered = true;
    if (a.fire != 0) g.state.fire = true;
}
