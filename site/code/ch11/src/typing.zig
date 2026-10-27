//! Typing a line: initials for a best time, or the name of a saved game.
//! Each letter is drawn as it lands, Backspace takes the last one back,
//! Return is done and Esc gives up.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");
const text = @import("text.zig");
const player = @import("player.zig");

pub const max_letters = 16;
const placeholder = '-';

/// The keys that aren't letters.
const key_return = 13;
const key_backspace = 8;
pub const key_esc = 27;

/// Start a line at fat pixel (x, y), up to `max` letters long: a dash
/// where each letter will go.
pub fn begin(m: *Machine, x: u8, y: u8, max: u8) void {
    m.poke(map.shell_x, x);
    m.poke(map.shell_y, y);
    m.poke(map.shell_max, max);
    m.poke(map.shell_typed, 0);
    var i: u8 = 0;
    while (i < max) : (i += 1) letter(m, i, placeholder);
}

pub const Typing = enum { typing, done, cancelled };

/// Every frame: the key in the keyboard port, if there is one.
pub fn run(m: *Machine) Typing {
    const key = m.peek(hw.key);
    if (key == 0) return .typing;
    m.poke(hw.key, 0); // seen it
    const n = m.peek(map.shell_typed);
    m.work(20); // the tests
    switch (key) {
        key_return => if (n > 0) return finish(m, .done),
        key_esc => return finish(m, .cancelled),
        key_backspace => if (n > 0) {
            m.poke(map.shell_typed, n - 1);
            letter(m, n - 1, placeholder);
            if (n > 1) m.poke(map.shell_line + n - 2, m.peek(map.shell_line + n - 2) | 0x80);
        },
        'A'...'Z', '0'...'9', ' ', '.' => if (n < m.peek(map.shell_max)) {
            if (n > 0) m.poke(map.shell_line + n - 1, m.peek(map.shell_line + n - 1) & 0x7F);
            m.poke(map.shell_line + n, key | 0x80); // the last letter, for now
            m.poke(map.shell_typed, n + 1);
            letter(m, n, key);
        },
        else => {},
    }
    return .typing;
}

/// Return is stick 2's fire button too, and Space is stick 1's. Let both
/// sticks' edge detectors see this frame, so whichever key ended the line
/// isn't a press of fire on the next screen.
fn finish(m: *Machine, how: Typing) Typing {
    _ = player.pressedFire(m, 0);
    _ = player.pressedFire(m, 1);
    return how;
}

/// Draw letter `i` of the line as `c`: clear its two cells, then print it.
fn letter(m: *Machine, i: u8, c: u8) void {
    const x = m.peek(map.shell_x) + 8 * i;
    const y = m.peek(map.shell_y);
    // A cell is 8 bytes in a row in the bitmap, and a letter is two cells.
    m.fill(hw.bitmap + @as(u16, y / 8) * 320 + @as(u16, x / 4) * 8, 16, 0);
    m.poke(map.text_buffer, c | 0x80);
    _ = text.draw(m, x, y, .white, text.plain, map.text_buffer);
}
