//! Switches for looking inside the game. G draws the navigation grid over
//! the room; Q makes the explorer search the castle for his way instead
//! of reading the grid, and C makes every actor check every object on
//! every turn, so the meter can show what those cost. X gives up a life.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const grid = @import("grid.zig");
const player = @import("player.zig");

/// G, Q or C on the keyboard flips its switch, and X kills the explorer.
/// True if the room needs drawing again (the grid view does; the others
/// don't).
pub fn keys(m: *Machine) bool {
    const key = m.peek(hw.key);
    const flag = switch (key) {
        'G' => map.debug_grid,
        'Q' => map.debug_search,
        'C' => map.debug_scan,
        'X' => {
            m.poke(hw.key, 0); // seen it
            player.kill(m);
            return false;
        },
        else => return false, // N, P and the rest are room.flip's
    };
    m.poke(hw.key, 0); // seen it
    m.poke(flag, m.peek(flag) ^ 1);
    m.work(12);
    return key == 'G';
}

/// With the grid view on, redraw every cell that has a way out as a map
/// of its ways, in yellow: a block in the middle, and an arm out to each
/// side he can leave by. Walkways turn into lines, ladders into rails.
pub fn overlay(m: *Machine) void {
    if (m.peek(map.debug_grid) == 0) return;
    var n: u16 = 0; // the grid, the screen plane and colour RAM all number cells alike
    while (n < grid.columns * grid.rows) : (n += 1) {
        const ways = m.peek(map.grid.first + n);
        m.work(6); // the test and the loop
        if (ways == 0) continue;
        // One bitmap byte is a row of the cell's four fat pixels.
        const middle: u8 = 0b00_11_11_00; // fat pixels 1 and 2, code 11
        const across = middle | (if (ways & grid.left != 0) @as(u8, 0b11_00_00_00) else 0) |
            (if (ways & grid.right != 0) @as(u8, 0b00_00_00_11) else 0);
        const above: u8 = if (ways & grid.up != 0) middle else 0;
        const below: u8 = if (ways & grid.down != 0) middle else 0;
        const pattern = [8]u8{ above, above, above, across, across, below, below, below };
        var at = hw.bitmap + n * 8; // the cell's eight bitmap bytes
        for (pattern) |row| {
            m.poke(at, row);
            at += 1;
        }
        m.poke(hw.color_ram + n, @intFromEnum(Color.yellow)); // code 11 in this cell
        m.work(30); // the tests and the loop
    }
}
