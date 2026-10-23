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
pub const floor_top = 192; // every Training Castle room has a floor here

/// The final room isn't in the directory, so it has no colour byte.
const final_color = Color.yellow;

/// Into the castle: the room player 1 starts in.
pub fn start(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
}

/// Draw the room `room_number` names. Far too big for one frame: call it
/// with the display blanked.
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

/// A walkway: `length` pieces 4 fat pixels wide, a left end, middles and
/// a right end.
fn walkway(m: *Machine, at: u16) void {
    const w = m.view(castle.Run, at);
    var x = castle.screenX(w.x) orelse return;
    var i: u8 = 1;
    while (i <= w.length and x < 160) : (i += 1) {
        const piece: shapes.Id = if (i == 1) .walkway_left else if (i == w.length) .walkway_right else .walkway;
        screen.drawShape(m, piece, x, w.y);
        x += 4;
        m.work(12); // the tests and the loop
    }
}

/// A ladder or a pole: `length` pieces stacked 8 rows apart, top first.
fn column(m: *Machine, id: shapes.Id, at: u16) void {
    const c = m.view(castle.Run, at);
    const x = castle.screenX(c.x) orelse return;
    var y = c.y;
    var i: u8 = 0;
    while (i < c.length and y < 200) : (i += 1) {
        screen.drawShape(m, id, x, y);
        y += 8;
        m.work(8); // the tests and the loop
    }
}

/// A door: the arch (or the way out's), and in it the door itself, shut
/// or open onto the colour of the room beyond.
fn door(m: *Machine, at: u16) void {
    const d = m.view(castle.Door, at);
    const x = castle.screenX(d.x) orelse return;
    m.work(8); // the two tests
    screen.drawShape(m, if (d.exit != 0) .exit_frame else .door_frame, x, d.y);
    if (d.side & castle.door_open != 0) {
        shapes.recolor(m, .door_open, roomColors(m, d.to_room));
        screen.drawShape(m, .door_open, x + 4, d.y + 8);
    } else {
        screen.drawShape(m, .door_shut, x + 4, d.y + 8);
    }
}

/// A doorbell, in the colour of the room its door leads to.
fn bell(m: *Machine, at: u16, doors: u16) void {
    const b = m.view(castle.Bell, at);
    const x = castle.screenX(b.x) orelse return;
    const d = m.view(castle.Door, doors + @as(u16, b.door) * @sizeOf(castle.Door));
    m.work(10); // the multiply by 8 is three shifts
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    screen.drawShape(m, .bell, x, b.y);
}

/// A line of text: x, y, colour and style, then the letters.
fn line(m: *Machine, at: u16) void {
    const t = m.view(castle.Text, at);
    const x = castle.screenX(t.x) orelse return;
    const color: Color = @enumFromInt(@as(u4, @truncate(t.color)));
    _ = text.draw(m, x, t.y, color, t.style, at + @sizeOf(castle.Text));
}

/// An image is a shape that lives in the castle. Point the shape
/// directory's spare entry at it, then draw it at each place listed
/// after it.
fn image(m: *Machine, at: u16) void {
    shapes.point(m, .image, at);
    var place = at + castle.shapeSize(m, at);
    while (m.peek(place) != 0) : (place += 2) {
        const x = castle.screenX(m.peek(place)) orelse continue;
        screen.drawShape(m, .image, x, m.peek(place + 1));
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
