//! The castle map, between rooms: every room an explorer has been in,
//! in its colour, with its doors, and a blinking arrow at the door each
//! explorer comes in by next. Fire on each player's stick goes on.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");
const text = @import("text.zig");
const room = @import("room.zig");
const player = @import("player.zig");
const clock = @import("clock.zig");
const game = @import("game.zig");

/// The map at work, in the bytes it shares with the other screens
/// between rooms (game.zig).
pub const Chart = extern struct {
    blink: [2]u8, // frames until each player's arrow blinks again
    lit: [2]u8, // 1 while it shows
    ready: [2]u8, // 1 once he's pressed fire, or if he isn't here
    steady: u8, // 1 when both arrows are at one door: then they don't blink
};

/// Frames on, then off: player 1's arrow blinks fast, player 2's slow.
const blinks = [2]u8{ 12, 30 };

/// Where an arrow goes from its door's place on the map, by the wall the
/// door is in (up, right, down, left): outside the room, pointing in.
/// Added with a wrapping +%, so 0xFF is one back.
const arrow_dx = [4]u8{ 0xFF, 2, 0xFF, 0xFB }; // -1, +2, -1, -5
const arrow_dy = [4]u8{ 0xF6, 0xFE, 6, 0xFE }; // -10, -2, +6, -2
const arrows = [4]shapes.Id{ .arrow_down, .arrow_left, .arrow_up, .arrow_right };

/// "ONE UP" and "TWO UP" are in the colour of the lives left: 1, 2, 3.
const lives_colors = [4]Color{ .black, .pink, .yellow, .light_green };

/// The chart's bytes.
fn chart(m: *Machine) *align(1) Chart {
    return &game.between(m).chart;
}

/// Draw the map for the room about to be played. Call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    m.poke(hw.sprite_enable, 0);
    m.poke(hw.sprite_multicolor, 0b11); // the arrows' code 10 is their own colour
    const c = chart(m);
    c.* = .{ .blink = blinks, .lit = .{ 1, 1 }, .ready = .{ 1, 1 }, .steady = 0 };
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        if (!player.here(m, p)) continue;
        const e = castle.entry(m, m.peek(castle.room + p));
        m.poke(e, m.peek(e) | castle.visited); // he's been here now
        c.ready[p] = 0;
    }
    const rooms = castle.roomCount(m);
    var n: u8 = 0;
    while (n < rooms) : (n += 1) {
        m.work(10); // the test and the loop
        if (m.peek(castle.entry(m, n)) & castle.visited != 0) sketch(m, n);
    }
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        if (player.here(m, p)) label(m, p);
    }
    if (c.ready[0] == 0 and c.ready[1] == 0 and m.peek(castle.door) == m.peek(castle.door + 1)) c.steady = 1;
}

/// Room `n` on the map: a cell of floor in its colour for every map cell
/// it covers, walls round the edge, and a gap in the wall for each door.
fn sketch(m: *Machine, n: u8) void {
    const e = m.view(castle.Entry, castle.entry(m, n));
    const colors = @as(u8, @intFromEnum(Color.black)) << 4 | (e.color & 0x0F);
    for ([_]shapes.Id{ .map_floor, .map_top, .map_bottom, .map_left, .map_right }) |id| shapes.recolor(m, id, colors);
    const left = e.map_x - castle.left_edge;
    var row: u8 = 0;
    while (row < e.size.height) : (row += 1) {
        var col: u8 = 0;
        while (col < e.size.width) : (col += 1) {
            const x = left + 4 * col;
            const y = e.map_y + 8 * row;
            screen.drawShape(m, .map_floor, x, y);
            if (row == 0) screen.drawShape(m, .map_top, x, y);
            if (row == e.size.height - 1) screen.drawShape(m, .map_bottom, x, y);
            if (col == 0) screen.drawShape(m, .map_left, x, y);
            if (col == e.size.width - 1) screen.drawShape(m, .map_right, x, y);
            m.work(30); // the tests and the loops
        }
    }

    // The doors: each one's map bytes say where along its wall it is.
    const width = 4 * @as(u8, e.size.width);
    const height = 8 * @as(u8, e.size.height);
    var i: u8 = 0;
    while (room.doorAt(m, n, i)) |at| : (i += 1) {
        const d = m.view(castle.Door, at);
        switch (d.side & 3) {
            0 => gap(m, left + d.map_x, e.map_y, 2), // the top wall
            1 => gap(m, left + width - 1, e.map_y + d.map_y, 1), // the right
            2 => gap(m, left + d.map_x, e.map_y + height - 3, 2), // the bottom
            else => gap(m, left, e.map_y + d.map_y, 1), // the left
        }
    }
}

/// A doorway in a wall: `across` fat pixels by 3 rows, from (x, y), back
/// to the floor's code 10.
fn gap(m: *Machine, x: u8, y: u8, across: u8) void {
    for (0..3) |down| {
        for (0..across) |i| screen.plot(m, x + @as(u8, @intCast(i)), y + @as(u8, @intCast(down)), 0b10);
    }
}

/// Player `p`'s name and time, coloured by his lives, and his arrow.
fn label(m: *Machine, p: player.Number) void {
    const color = lives_colors[@min(m.peek(castle.lives + p), 3)];
    if (p == 0) text.say(m, 12, 8, color, "ONE UP") else text.say(m, 100, 8, color, "TWO UP");
    clock.print(m, if (p == 0) 4 else 92, 20, color, p);

    // The arrow: sprite p, from its frame in sprite block p.
    const n = m.peek(castle.room + p);
    const at = room.doorAt(m, n, m.peek(castle.door + p)) orelse return; // no doors: no arrow
    const e = m.view(castle.Entry, castle.entry(m, n));
    const d = m.view(castle.Door, at);
    const side = d.side & 3;
    _ = sprites.unpack(m, arrows[side], p);
    m.poke(hw.sprite_pointers + p, p);
    sprites.place(m, p, e.map_x +% d.map_x +% arrow_dx[side], e.map_y +% d.map_y +% arrow_dy[side]);
    m.work(30); // the sums
}

/// Every frame of the map: blink the arrows, and listen to the sticks.
/// True once everyone here has pressed fire.
pub fn wait(m: *Machine) bool {
    const c = chart(m);
    var on: u8 = 0;
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        m.work(20); // the tests
        if (!player.here(m, p)) continue;
        if (c.steady == 0) {
            c.blink[p] -= 1;
            if (c.blink[p] == 0) {
                c.blink[p] = blinks[p];
                c.lit[p] ^= 1;
            }
        }
        if (c.lit[p] != 0) on |= @as(u8, 1) << p;
        const color: Color = if (c.steady != 0) .white else player.coat(p);
        m.poke(hw.spriteColor(p), @intFromEnum(color));
        if (player.pressedFire(m, p)) c.ready[p] = 1;
    }
    m.poke(hw.sprite_enable, on);
    return c.ready[0] != 0 and c.ready[1] != 0;
}
