//! The room on screen, prepared from the castle: walk the room's object
//! stream, draw everything in it, and make the objects that do things.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // the bottom row of cells, as in Chapter 1

/// The final room isn't in the directory, so it has no colour byte.
const final_color = Color.yellow;

/// What preparing a room does with each kind of record: a function for
/// every kind, found by number. The compiler won't build the table with a
/// kind missing.
const Prepare = *const fn (m: *Machine, r: castle.Record) void;
const prepares = std.enums.directEnumArray(castle.Kind, Prepare, 0, .{
    .door = door,
    .walkway = walkway,
    .pole = pole,
    .ladder = ladder,
    .bell = bell,
    .lightning = later,
    .forcefield = later,
    .mummy = later,
    .key = later,
    .lock = later,
    .pattern = later,
    .ray_gun = later,
    .teleport = later,
    .trapdoor = later,
    .conveyor = later,
    .frankenstein = later,
    .text = line,
    .image = image,
});

/// Prepare the whole room: draw it, build its navigation grid and fill its
/// object table, every record handed to its kind's function. Far too big
/// for one frame: call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    grid.clear(m);
    objects.clear(m);
    var walk = prepare(m, m.peek(map.room_number));
    while (walk.next(m)) |r| {
        m.work(10); // the table read and the call
        prepares[@intFromEnum(r.kind)](m, r);
    }
}

/// Machines and monsters come alive in later chapters.
fn later(m: *Machine, r: castle.Record) void {
    _ = m;
    _ = r;
}

/// Get room `n` ready to draw: paint the floor pieces its colour, and
/// return a walker at the start of its objects.
fn prepare(m: *Machine, n: u8) castle.Walker {
    const final = n == castle.roomCount(m);
    paint(m, if (final) both(@intFromEnum(final_color)) else roomColors(m, n));
    return .{ .at = stream(m, n) };
}

/// Where room `n`'s object stream starts in the castle. The room after the
/// last is the final room.
pub fn stream(m: *Machine, n: u8) u16 {
    if (n == castle.roomCount(m)) return m.peek16(castle.final_room);
    return m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects"));
}

/// Door `i` of room `n`, if the room has one. Doors come first in a
/// stream: their tag, a count, and 8 bytes for each door.
pub fn doorAt(m: *Machine, n: u8, i: u8) ?u16 {
    const at = stream(m, n);
    m.work(10); // the tests, and i * 8 is three shifts
    if (castle.kindOf(m, m.peek16(at)) != .door or i >= m.peek(at + 2)) return null;
    return at + 3 + @as(u16, i) * @sizeOf(castle.Door);
}

/// One colour per room, not per walkway: before drawing, repaint the
/// floor pieces in the shape table itself.
fn paint(m: *Machine, colors: u8) void {
    for ([_]shapes.Id{ .walkway, .walkway_left, .walkway_right, .ladder, .pole }) |id| {
        shapes.recolor(m, id, colors);
    }
}

/// Room `n`'s colour from its directory entry, for both codes 01 and 10.
fn roomColors(m: *Machine, n: u8) u8 {
    return both(m.peek(castle.entry(m, n)) & 0x0F);
}

/// One colour in both halves of a screen-plane byte.
fn both(color: u8) u8 {
    return color << 4 | color;
}

/// Draw shape `id` with its top-left corner at castle coordinates
/// (x, y), cut off where it hangs over the left edge of the screen. This
/// is the one place an object's X becomes the blitter's fat pixel.
fn place(m: *Machine, id: shapes.Id, x: u8, y: u8) void {
    m.work(8); // the test and the sums
    if (x >= castle.left_edge) {
        screen.drawShape(m, id, x - castle.left_edge, y);
    } else {
        // Four fat pixels to a byte column: leave out the columns left of the edge.
        screen.drawPart(m, id, 0, y, (castle.left_edge - x + 3) / 4);
    }
}

/// A walkway: `length` pieces 4 fat pixels wide, a left end, middles and
/// a right end. Somewhere to walk.
fn walkway(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    const w = m.view(castle.Run, r.at);
    var x = w.x;
    var i: u8 = 1;
    while (i <= w.length and x < castle.left_edge + 160) : (i += 1) {
        const piece: shapes.Id = if (i == 1) .walkway_left else if (i == w.length) .walkway_right else .walkway;
        place(m, piece, x, w.y);
        x += 4;
        m.work(12); // the tests and the loop
    }
}

/// A sliding pole, and a ladder: somewhere to climb.
fn pole(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    column(m, .pole, r.at);
}

fn ladder(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    column(m, .ladder, r.at);
}

/// A ladder or a pole: `length` pieces stacked 8 rows apart, top first.
fn column(m: *Machine, id: shapes.Id, at: u16) void {
    const c = m.view(castle.Run, at);
    var y = c.y;
    var i: u8 = 0;
    while (i < c.length and y < 200) : (i += 1) {
        place(m, id, c.x, y);
        y += 8;
        m.work(8); // the tests and the loop
    }
}

/// Where the door itself sits inside its arch, and its size. Ours is
/// taller than the 1984 game's (12 x 15, 16 rows down), so that the
/// explorer fits through. It's also the box he stands in front of.
pub const door_panel_dx: u8 = 4;
pub const door_panel_dy: u8 = 8;
pub const door_panel_width: u8 = 12;
pub const door_panel_height: u8 = 24;

/// A door: the arch (or the way out's), and in it the door itself, shut
/// or open. An object, too, for the explorer to stand in front of.
fn door(m: *Machine, r: castle.Record) void {
    const d = m.view(castle.Door, r.at);
    m.work(8); // the test
    place(m, if (d.exit != 0) .exit_frame else .door_frame, d.x, d.y);
    panel(m, r.at);
    const box: actors.Box = .{ .x = d.x +| door_panel_dx, .y = d.y +| door_panel_dy, .width = door_panel_width, .height = door_panel_height };
    const n = objects.add(m, .door, box, r.at) orelse return;
    const o = objects.slot(m, n);
    o.number = @intCast((r.at - doorAt(m, m.peek(map.room_number), 0).?) / @sizeOf(castle.Door));
    o.open = @intFromBool(d.side & castle.door_open != 0);
    m.work(20); // the sums and the stores
}

/// The door itself, from its record at `at`: shut, or open onto the colour
/// of the room beyond.
pub fn panel(m: *Machine, at: u16) void {
    const d = m.view(castle.Door, at);
    const x = d.x +| door_panel_dx;
    const y = d.y +| door_panel_dy;
    m.work(8); // the test and the sums
    if (d.side & castle.door_open != 0) {
        shapes.recolor(m, .door_open, roomColors(m, d.to_room));
        place(m, .door_open, x, y);
    } else {
        place(m, .door_shut, x, y);
    }
}

/// Wipe one row of a door's panel back to the background, as it swings
/// open: three bitmap bytes, the ones on the screen.
pub fn wipe(m: *Machine, x: u8, y: u8) void {
    const row = screen.rowAddress(m, y);
    var left = x;
    for (0..door_panel_width / 4) |_| {
        if (left >= castle.left_edge) m.poke(row + @as(u16, (left - castle.left_edge) / 4) * 8, 0);
        left += 4;
        m.work(10); // the test, the sums and the loop
    }
}

/// A doorbell, in the colour of the room its door leads to. An object,
/// too: stand at it and press fire.
fn bell(m: *Machine, r: castle.Record) void {
    const b = m.view(castle.Bell, r.at);
    const at = doorAt(m, m.peek(map.room_number), b.door) orelse return;
    const d = m.view(castle.Door, at);
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    place(m, .bell, b.x, b.y);
    const shape = shapes.address(m, .bell);
    const box: actors.Box = .{ .x = b.x, .y = b.y, .width = m.peek(shape) * 4, .height = m.peek(shape + 1) };
    const n = objects.add(m, .bell, box, r.at) orelse return;
    objects.slot(m, n).number = b.door;
    m.work(20); // the sums and the stores
}

/// A line of text: x, y, colour and style, then the letters. Letters that
/// would start left of the screen are left out, as they are at the right.
fn line(m: *Machine, r: castle.Record) void {
    const at = r.at;
    const t = m.view(castle.Text, at);
    const color: Color = @enumFromInt(@as(u4, @truncate(t.color)));
    var x = t.x;
    var letters = at + @sizeOf(castle.Text);
    while (x < castle.left_edge) : ({
        x += 8;
        letters += 1;
    }) {
        if (m.peek(letters) & 0x80 != 0) return; // the whole line is off the edge
        m.work(4);
    }
    _ = text.draw(m, x - castle.left_edge, t.y, color, t.style, letters);
}

/// An image is a shape that lives in the castle. Point the shape
/// directory's spare entry at it, then draw it at each place listed
/// after it.
fn image(m: *Machine, r: castle.Record) void {
    const at = r.at;
    shapes.point(m, .image, at);
    var spot = at + castle.shapeSize(m, at);
    while (m.peek(spot) != 0) : (spot += 2) {
        place(m, .image, m.peek(spot), m.peek(spot + 1));
        m.work(2); // the loop
    }
}

/// N and P on the keyboard: the next or the previous room, with the
/// final room (if the castle has one) after the last. True if it moved.
pub fn flip(m: *Machine) bool {
    const key = m.peek(hw.key);
    if (key == 0) return false;
    m.poke(hw.key, 0); // seen it
    const rooms = castle.roomCount(m);
    const last = if (m.peek16(castle.final_room) != 0) rooms else rooms - 1;
    const n = m.peek(map.room_number);
    m.work(20); // the tests
    const next: u8 = switch (key) {
        'N' => if (n >= last) 0 else n + 1,
        'P' => if (n == 0) last else n - 1,
        else => return false,
    };
    m.poke(map.room_number, next);
    m.poke(map.player_door, 0); // he comes in by its first door
    return true;
}

// ---- tests ----------------------------------------------------------------

test "preparing a room has a function for every kind of record" {
    try std.testing.expectEqual(std.enums.values(castle.Kind).len, prepares.len);
}
