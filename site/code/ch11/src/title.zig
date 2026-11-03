//! The title screen: the castle by moonlight, and a sky full of stars.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const screen = @import("screen.zig");
const text = @import("text.zig");
const files = @import("files.zig");

pub const star_count = 128;

/// Where the stars are: x then y for each, scattered while the game
/// compiles, keeping clear of the cells the words and the moon use.
pub const star_map: [star_count * 2]u8 = blk: {
    @setEvalBranchQuota(100_000); // compile-time loops are capped; this raises the cap
    var out: [star_count * 2]u8 = undefined;
    var seed: u32 = 1984;
    var n = 0;
    while (n < star_count) {
        seed = seed *% 1103515245 +% 12345;
        const x: u8 = @intCast((seed >> 8) % 160);
        const y: u8 = @intCast((seed >> 20) % 128);
        const row = y / 8;
        const col = x / 4;
        const busy = (row == 5 and col >= 6 and col < 34) or // THE CASTLES OF
            (row == 7 and col >= 11 and col < 29) or // DR. CREEP
            row == 9 or row == 11 or // the castle's name, and the menu
            (row == 13 and col >= 10 and col < 30) or // PRESS FIRE
            (row == 15 and col >= 5 and col < 35) or // STICK 2 FOR TWO
            (row < 3 and col >= 31 and col < 34); // the moon
        if (busy) continue;
        out[n * 2] = x;
        out[n * 2 + 1] = y;
        n += 1;
    }
    break :blk out;
};

/// Draw the title screen. Call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    // The stars' colours, in every cell: dark grey, light grey, white.
    m.fill(hw.screen, 1000, @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.light_grey));
    m.fill(hw.color_ram, 1000, @intFromEnum(Color.white));

    screen.drawShape(m, .moon, 124, 4);
    text.say(m, 24, 40, .light_blue, "THE CASTLES OF");
    text.say(m, 44, 56, .light_green, "DR. CREEP");
    if (files.ready(m)) {
        const name = files.entry(m.peek(map.shell_castle));
        _ = text.draw(m, 80 - 4 * files.length(m, name), 72, .yellow, text.plain, name);
    } else text.say(m, 24, 72, .red, "NO CASTLE DISK");
    text.say(m, 16, 88, .grey, "ESC FOR THE MENU");
    text.say(m, 40, 104, .white, "PRESS FIRE");
    text.say(m, 20, 120, .grey, "STICK 2 FOR TWO");

    // The castle: two towers, and a wall with a door in it.
    screen.drawShape(m, .tower, 8, 136);
    screen.drawShape(m, .tower, 140, 136);
    var x: u8 = 20;
    while (x < 140) : (x += 4) {
        if (x < 76 or x >= 88) screen.drawShape(m, .wall, x, 168);
    }
    screen.drawShape(m, .door, 76, 168);
}

/// Every frame, replot the stars. Every eighth frame each one moves a step
/// through off, dim, bright and brightest, a little out of step with the last.
pub fn twinkle(m: *Machine) void {
    const phase = m.peek(map.game_tick) >> 3; // a new step every 8 frames
    var i: u8 = 0;
    while (i < star_count) : (i += 1) {
        const at = map.stars.first + @as(u16, i) * 2;
        const x = m.peek(at);
        const y = m.peek(at + 1);
        screen.plot(m, x, y, @truncate(phase +% i));
        m.work(6); // the loop
    }
}
