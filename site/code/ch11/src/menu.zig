//! The menu, from Esc on the title screen. Stick 1 moves the pointer and
//! fire chooses: resume a saved game, look at the best times, unlimited
//! lives on or off, back to the title, or another castle from the disk.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const joy = machine.joy;
const map = @import("map.zig");
const screen = @import("screen.zig");
const text = @import("text.zig");
const files = @import("files.zig");
const typing = @import("typing.zig");

/// The lines above the castles.
const Item = enum(u8) { resume_game, best_times, unlimited, exit };
const items = 4;

/// What the menu chose.
pub const Choice = enum { nothing, resume_game, best_times, exit, castle };

/// Esc on the keyboard? Any other key is seen and forgotten.
pub fn asked(m: *Machine) bool {
    const key = m.peek(hw.key);
    if (key == 0) return false;
    m.poke(hw.key, 0); // seen it
    return key == typing.key_esc;
}

/// The row of menu line `i`: the items with a row between, a heading,
/// then the castles.
fn rowOf(i: u8) u8 {
    return if (i < items) 16 * i else 72 + 8 * (i - items);
}

/// The whole menu, the pointer on the first line. Call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    m.poke(hw.sprite_enable, 0);
    text.say(m, 16, rowOf(0), .white, "RESUME GAME");
    text.say(m, 16, rowOf(1), .white, "BEST TIMES");
    lives(m);
    text.say(m, 16, rowOf(3), .white, "EXIT MENU");
    text.say(m, 16, 64, .light_green, "THE DISK'S CASTLES");
    var n: u8 = 0;
    while (n < m.peek(map.shell_castles)) : (n += 1) {
        // The castle in staging is the one picked: it's in white.
        const color: machine.Color = if (n == m.peek(map.shell_castle)) .white else .yellow;
        _ = text.draw(m, 16, rowOf(items + n), color, text.plain, files.entry(n));
    }
    m.poke(map.shell_pointer, 0);
    m.poke(map.shell_stick, m.peek(hw.joy1));
    pointer(m, '>');
}

/// UNLIMITED LIVES, reversed while it's on.
fn lives(m: *Machine) void {
    clear(m, 16, rowOf(@intFromEnum(Item.unlimited)), 15);
    const on = m.peek(map.shell_unlimited) != 0;
    const words = comptime text.terminated("UNLIMITED LIVES");
    m.load(map.text_buffer, &words);
    _ = text.draw(m, 16, rowOf(@intFromEnum(Item.unlimited)), .white, if (on) text.plain | text.style_reversed else text.plain, map.text_buffer);
}

/// Rub out `letters` letters at fat pixel (x, y): a row of cells, 8
/// bytes each, two to a letter.
fn clear(m: *Machine, x: u8, y: u8, letters: u8) void {
    m.fill(hw.bitmap + @as(u16, y / 8) * 320 + @as(u16, x / 4) * 8, @as(u16, letters) * 16, 0);
}

/// The pointer, `c`, left of its line; a space rubs it out.
fn pointer(m: *Machine, c: u8) void {
    const y = rowOf(m.peek(map.shell_pointer));
    clear(m, 0, y, 1);
    if (c == ' ') return;
    m.poke(map.text_buffer, c | 0x80);
    _ = text.draw(m, 0, y, .yellow, text.plain, map.text_buffer);
}

/// Was this switch pushed since the menu last looked? (0 is pushed.)
fn pushed(stick: u8, before: u8, bit: u8) bool {
    return stick & bit == 0 and before & bit != 0;
}

/// Every frame of the menu.
pub fn run(m: *Machine) Choice {
    if (asked(m)) return .exit;
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.shell_stick);
    m.poke(map.shell_stick, stick);
    m.work(30); // the tests
    const lines = items + m.peek(map.shell_castles);
    const at = m.peek(map.shell_pointer);
    if (pushed(stick, before, joy.up) or pushed(stick, before, joy.down)) {
        pointer(m, ' ');
        const up = pushed(stick, before, joy.up);
        m.poke(map.shell_pointer, if (up) (if (at == 0) lines - 1 else at - 1) else (if (at == lines - 1) 0 else at + 1));
        pointer(m, '>');
        return .nothing;
    }
    if (!pushed(stick, before, joy.fire)) return .nothing;
    if (at >= items) {
        m.poke(hw.control, 0); // the castle's a loading pause: blank first
        _ = files.pick(m, at - items);
        return .castle;
    }
    return switch (@as(Item, @enumFromInt(at))) {
        .resume_game => .resume_game,
        .best_times => .best_times,
        .unlimited => {
            m.poke(map.shell_unlimited, m.peek(map.shell_unlimited) ^ 1);
            lives(m);
            return .nothing;
        },
        .exit => .exit,
    };
}
