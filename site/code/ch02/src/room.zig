//! The room: floors, a ladder, a pole and doors, placed by hand and drawn
//! from the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const screen = @import("screen.zig");
const text = @import("text.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // the bottom row of cells, as in Chapter 1

/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    text.say(m, 12, 8, .light_grey, "THE ENTRANCE HALL");

    screen.drawShape(m, .window, 64, 32);
    screen.drawShape(m, .window, 116, 64);
    screen.drawShape(m, .torch, 40, 40);
    screen.drawShape(m, .torch, 96, 96);
    screen.drawShape(m, .torch, 24, 144);

    walkway(m, 8, 72, 15); // upper left
    walkway(m, 92, 128, 15); // middle right
    walkway(m, 0, floor_top, 40); // the floor, wall to wall

    screen.drawShape(m, .door, 16, 72 - 32);
    screen.drawShape(m, .door, 136, 128 - 32);

    ladder(m, 104, 128, floor_top);
    pole(m, 48, 72, floor_top);
}

/// A walkway `pieces` bytes long: a left end, a middle, a right end.
fn walkway(m: *Machine, x: u8, y: u8, pieces: u8) void {
    screen.drawShape(m, .walkway_left, x, y);
    var i: u8 = 1;
    while (i < pieces - 1) : (i += 1) screen.drawShape(m, .walkway, x + i * 4, y);
    screen.drawShape(m, .walkway_right, x + (pieces - 1) * 4, y);
}

/// A ladder from `top` down to `bottom`, eight rows at a time.
fn ladder(m: *Machine, x: u8, top: u8, bottom: u8) void {
    var y = top;
    while (y < bottom) : (y += 8) screen.drawShape(m, .ladder, x, y);
}

/// A pole from `top` down to `bottom`.
fn pole(m: *Machine, x: u8, top: u8, bottom: u8) void {
    var y = top;
    while (y < bottom) : (y += 8) screen.drawShape(m, .pole, x, y);
}
