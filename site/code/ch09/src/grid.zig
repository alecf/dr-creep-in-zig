//! The navigation grid: one byte for each 8x8 cell of the screen, saying
//! which ways the explorer can leave it. Built while a room is drawn, so
//! that every step he takes is a single read.

const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const castle = @import("castle.zig");

/// The grid has the screen's shape: 40 cells across, 25 down, each one
/// 4 fat pixels wide and 8 rows tall.
pub const columns = 40;
pub const rows = 25;

/// Directions are numbered clockwise from up, 0 to 7, and bit d of a
/// cell's byte is set when direction d is open. Only the four straight
/// directions are ever set; the diagonals (the odd bits) never are.
pub const up: u8 = 0b0000_0001; // direction 0
pub const right: u8 = 0b0000_0100; // direction 2
pub const down: u8 = 0b0001_0000; // direction 4
pub const left: u8 = 0b0100_0000; // direction 6

/// Every cell closed, before a room adds its walkways, ladders and poles.
pub fn clear(m: *Machine) void {
    m.fill(map.grid.first, columns * rows, 0);
}

/// The grid column under castle X `x`, or null off the screen. Castle X
/// counts from 16, which is exactly four cells, so the column is x / 4 - 4.
pub fn column(x: u8) ?u8 {
    if (x < castle.left_edge or x >= castle.left_edge + 160) return null;
    return x / 4 - 4;
}

/// The address of cell (col, row). The grid is one run of bytes, a row
/// after a row, so the cell is row * 40 + col bytes in.
pub fn cell(m: *Machine, col: u8, row: u8) u16 {
    m.work(16); // row * 40 is row * 32 + row * 8: two shifts and an add
    const r: u16 = row;
    return map.grid.first + (r << 5) + (r << 3) + col;
}

/// The ways out of the cell under castle point (x, y). There are none off
/// the screen.
pub fn at(m: *Machine, x: u8, y: u8) u8 {
    const col = column(x) orelse return 0;
    if (y >= 8 * rows) return 0;
    return m.peek(cell(m, col, y / 8));
}

/// Put up a wall in cell (col, row), or take it down again. The wall
/// isn't in the cell: the cell on its left loses its way right, and the
/// cell on its right its way left, so nothing walks in. Whatever is
/// already inside can still walk out. A trapdoor's hole is a wall, and so
/// is a forcefield.
pub fn wall(m: *Machine, col: u8, row: u8, raised: bool) void {
    if (col == 0 or col + 1 >= columns) return; // no cells beyond the edge to change
    const before = cell(m, col - 1, row);
    const after = cell(m, col + 1, row);
    if (raised) {
        m.poke(before, m.peek(before) & ~right);
        m.poke(after, m.peek(after) & ~left);
    } else {
        m.poke(before, m.peek(before) | right);
        m.poke(after, m.peek(after) | left);
    }
    m.work(16); // the tests and the masks
}

/// The ways out of piece `i` (counting from 1) of a walkway, ladder or
/// pole `length` pieces long.
fn piece(kind: castle.Kind, i: u8, length: u8) u8 {
    return switch (kind) {
        // Right from the first piece, left from the last, both in between.
        .walkway => if (i == 1) right else if (i == length) left else left | right,
        // Down from the top rung, up from the bottom one, both in between.
        .ladder => (if (i != 1) up else 0) | (if (i != length) down else 0),
        // Every piece of a pole slides you down. There's no way back up.
        .pole => down,
        else => 0,
    };
}

/// Add a record's cells to the grid, if it's a walkway, a ladder or a
/// pole: a walkway's pieces run right from (x, y), the others' down.
pub fn add(m: *Machine, r: castle.Record) void {
    switch (r.kind) {
        .walkway, .ladder, .pole => {},
        else => return, // nothing else in a room is somewhere to walk
    }
    const o = m.view(castle.Run, r.at);
    var x = o.x;
    var y = o.y;
    var i: u8 = 1;
    while (i <= o.length and x < castle.left_edge + 160 and y < 8 * rows) : (i += 1) {
        if (column(x)) |col| {
            const a = cell(m, col, y / 8);
            m.poke(a, m.peek(a) | piece(r.kind, i, o.length));
        }
        if (r.kind == .walkway) x += 4 else y += 8;
        m.work(16); // the tests, the sums and the loop
    }
}

/// The same answer as `at`, the slow way: no grid, only the castle. Walk
/// the room's whole object stream (from `objects`) and work out the cell
/// under castle point (x, y) from every walkway, ladder and pole in it.
pub fn search(m: *Machine, objects: u16, x: u8, y: u8) u8 {
    const col = column(x) orelse return 0;
    if (y >= 8 * rows) return 0;
    const row = y / 8;
    var ways: u8 = 0;
    var walk = castle.Walker{ .at = objects };
    while (walk.next(m)) |r| {
        switch (r.kind) {
            .walkway, .ladder, .pole => {},
            else => continue,
        }
        const o = m.view(castle.Run, r.at);
        m.work(24); // the tests and the sums
        // Which of its pieces, counting from 1, covers this cell?
        var i: u8 = 0;
        if (r.kind == .walkway) {
            if (o.y / 8 == row and o.x / 4 <= col + 4) i = col + 4 - o.x / 4 + 1;
        } else {
            if (o.x / 4 == col + 4 and o.y / 8 <= row) i = row - o.y / 8 + 1;
        }
        if (i != 0 and i <= o.length) ways |= piece(r.kind, i, o.length);
    }
    return ways;
}
