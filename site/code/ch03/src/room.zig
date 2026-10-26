//! The room on screen, drawn from the castle: walk the room's object
//! stream and draw everything in it that stands still.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // the bottom row of cells, as in Chapter 1

/// The final room isn't in the directory, so it has no colour byte.
const final_color = Color.yellow;

/// Into the castle: the room player 1 starts in.
pub fn start(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
}

/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    var walk = prepare(m, m.peek(map.room_number));
    var doors: u16 = 0; // where this room's door records start
    while (walk.next(m)) |r| {
        switch (r.kind) {
            .door => {
                if (doors == 0) doors = r.at;
                door(m, r.at);
            },
            .walkway => walkway(m, r.at),
            .pole => column(m, .pole, r.at),
            .ladder => column(m, .ladder, r.at),
            .bell => bell(m, r.at, doors),
            .text => line(m, r.at),
            .image => image(m, r.at),
            else => {}, // machines and monsters come alive in later chapters
        }
    }
}

/// Get room `n` ready to draw: paint the floor pieces its colour, and
/// return a walker at the start of its objects. The room after the last
/// is the final room.
fn prepare(m: *Machine, n: u8) castle.Walker {
    if (n == castle.roomCount(m)) {
        paint(m, both(@intFromEnum(final_color)));
        return .{ .at = m.peek16(castle.final_room) };
    }
    paint(m, roomColors(m, n));
    return .{ .at = m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")) };
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
/// a right end.
fn walkway(m: *Machine, at: u16) void {
    const w = m.view(castle.Run, at);
    var x = w.x;
    var i: u8 = 1;
    while (i <= w.length and x < castle.left_edge + 160) : (i += 1) {
        const piece: shapes.Id = if (i == 1) .walkway_left else if (i == w.length) .walkway_right else .walkway;
        place(m, piece, x, w.y);
        x += 4;
        m.work(12); // the tests and the loop
    }
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

/// Where the door itself sits inside its arch. This one is taller than the
/// 1984 game's (12 x 15, 16 rows down), so that the explorer fits through.
pub const door_panel_dx: u8 = 4;
pub const door_panel_dy: u8 = 8;

/// A door: the arch (or the way out's), and in it the door itself, shut
/// or open onto the colour of the room beyond.
fn door(m: *Machine, at: u16) void {
    const d = m.view(castle.Door, at);
    m.work(8); // the two tests
    place(m, if (d.exit != 0) .exit_frame else .door_frame, d.x, d.y);
    const x = d.x +| door_panel_dx;
    const y = d.y +| door_panel_dy;
    if (d.side & castle.door_open != 0) {
        shapes.recolor(m, .door_open, roomColors(m, d.to_room));
        place(m, .door_open, x, y);
    } else {
        place(m, .door_shut, x, y);
    }
}

/// A doorbell, in the colour of the room its door leads to.
fn bell(m: *Machine, at: u16, doors: u16) void {
    const b = m.view(castle.Bell, at);
    const d = m.view(castle.Door, doors + @as(u16, b.door) * @sizeOf(castle.Door));
    m.work(10); // the multiply by 8 is three shifts
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    place(m, .bell, b.x, b.y);
}

/// A line of text: x, y, colour and style, then the letters. Letters that
/// would start left of the screen are left out, as they are at the right.
fn line(m: *Machine, at: u16) void {
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
fn image(m: *Machine, at: u16) void {
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
    return true;
}
