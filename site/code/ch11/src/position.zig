//! Saving a game, and resuming one. Everything a game knows between
//! rooms is in the castle buffer, header and all, so saving the game is
//! saving those bytes, and loading them back is the game, where it was.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const text = @import("text.zig");
const files = @import("files.zig");
const typing = @import("typing.zig");

/// Esc on the castle map: save the game. Other keys are left for N and P.
pub fn asked(m: *Machine) bool {
    if (m.peek(hw.key) != typing.key_esc) return false;
    m.poke(hw.key, 0); // seen it
    return true;
}

/// The screen for typing a name: to save under (`saving`), or to resume.
/// Call it with the display blanked.
pub fn draw(m: *Machine, saving: bool) void {
    m.poke(map.shell_saving, @intFromBool(saving));
    screen.clear(m);
    m.poke(hw.sprite_enable, 0);
    if (saving) text.shout(m, 44, 0, .white, "SAVE GAME") else text.shout(m, 36, 0, .white, "RESUME GAME");
    text.say(m, 28, 40, .light_green, "TYPE ITS NAME");
    text.say(m, 12, 48, .light_green, "THEN PRESS RETURN");
    text.say(m, 20, 120, .grey, "ESC TO GO BACK");
    typing.begin(m, 16, 72, typing.max_letters);
}

/// Every frame. Null while he's typing (or after a name that didn't
/// work: the screen says why, and he can try again). True when the game
/// is saved or resumed; false if he went back.
pub fn run(m: *Machine) ?bool {
    switch (typing.run(m)) {
        .typing => return null,
        .cancelled => return false,
        .done => {},
    }
    m.poke(hw.control, 0); // the disk is a loading pause: blank first
    const problem = if (m.peek(map.shell_saving) != 0) save(m) else load(m);
    m.fill(hw.bitmap + 12 * 320, 320, 0); // row 12: the last problem
    switch (problem) {
        .none => return true,
        .no_disk => text.say(m, 8, 96, .red, "THE DRIVE IS EMPTY"),
        .not_found => text.say(m, 16, 96, .red, "NOT ON THIS DISK"),
        .full => text.say(m, 16, 96, .red, "THE DISK IS FULL"),
        .not_a_game => text.say(m, 12, 96, .red, "THAT'S NOT A GAME"),
        .taken => text.say(m, 12, 96, .red, "Z AND Y ARE TAKEN"),
        .other => text.say(m, 12, 96, .red, "THE DRIVE SAYS NO"),
    }
    return null;
}

const Problem = enum { none, no_disk, not_found, full, not_a_game, taken, other };

fn problemOf(s: files.Status) Problem {
    return switch (s) {
        .ok => .none,
        .no_disk => .no_disk,
        .not_found => .not_found,
        .full => .full,
        else => .other,
    };
}

/// Save the castle buffer under the name typed, over a file of that name
/// if there is one. Names starting Z and Y are the castles' and their
/// best times'.
fn save(m: *Machine) Problem {
    const first = m.peek(map.shell_line) & 0x7F;
    if (first == 'Z' or first == 'Y') return .taken;
    files.nameFrom(m, "@0:", map.shell_line);
    return problemOf(files.save(m, map.castle.first, m.peek16(castle.size)));
}

/// Load the file named into the castle buffer. It's a game if it's a
/// castle with someone still in it. Resumed, it's marked so: no best
/// times for this one.
fn load(m: *Machine) Problem {
    files.nameFrom(m, "", map.shell_line);
    const problem = problemOf(files.load(m, map.castle.first, map.castle.last - map.castle.first + 1));
    if (problem != .none) return problem;
    m.work(20); // the tests
    if (m.peek(castle.magic) & ~castle.restored != castle.magic_value) return .not_a_game;
    if (m.peek(castle.in_game) == 0 and m.peek(castle.in_game + 1) == 0) return .not_a_game;
    m.poke(castle.magic, m.peek(castle.magic) | castle.restored);
    return .none;
}
