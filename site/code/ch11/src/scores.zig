//! Best times. Each castle keeps the ten fastest escapes from games for
//! one, and the ten from games for two, with the initials of whoever made
//! them, in a score file of 122 bytes: the same file, byte for byte, as
//! 1984's.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const text = @import("text.zig");
const clock = @import("clock.zig");
const player = @import("player.zig");
const files = @import("files.zig");
const typing = @import("typing.zig");

/// One best time: three initials, then seconds, minutes and hours, two
/// decimal digits to a byte. An empty place is all $FF, slower than any
/// time there is.
pub const Best = extern struct { initials: [3]u8, seconds: u8, minutes: u8, hours: u8 };
pub const places = 10;

/// The score file: its own length, then a table for games for one and a
/// table for games for two.
pub const File = extern struct { size: [2]u8, tables: [2][places]Best };
pub const file_size = @sizeOf(File);
comptime {
    if (file_size != map.scores.last - map.scores.first + 1)
        @compileError("the best times must fill their region exactly");
}

fn file(m: *Machine) *align(1) File {
    return m.view(File, map.scores.first);
}

/// Where place `k` of table `two` is.
fn address(two: u8, k: u8) u16 {
    return map.scores.first + 2 + (@as(u16, two) * places + k) * @sizeOf(Best);
}

/// Nobody's escaped yet.
pub fn fresh(m: *Machine) void {
    m.poke16(map.scores.first, file_size);
    m.fill(map.scores.first + 2, file_size - 2, 0xFF);
}

/// A time as one number to compare: hours, then minutes, then seconds.
/// Decimal digits in order compare as the numbers they are.
fn order(hours: u8, minutes: u8, seconds: u8) u32 {
    return @as(u32, hours) << 16 | @as(u32, minutes) << 8 | seconds;
}

/// Player `p` just escaped. Is his time one of the best ten? Then the
/// slower ones move down a place, his goes in with no initials yet, and
/// it's his turn to sign it. Not in a game with unlimited lives, or one
/// that was saved and resumed.
pub fn earned(m: *Machine, p: player.Number) bool {
    if (m.peek(map.shell_unlimited) != 0 or m.peek(castle.magic) & castle.restored != 0) return false;
    const t = clock.of(m, p);
    const two = m.peek(castle.two);
    const table = &file(m).tables[two];
    var k: u8 = 0;
    while (k < places) : (k += 1) {
        const b = &table[k];
        m.work(40); // the three compares
        if (order(t.hours, t.minutes, t.seconds) > order(b.hours, b.minutes, b.seconds)) continue;
        const at = address(two, k);
        m.copy(at + @sizeOf(Best), at, (places - 1 - k) * @sizeOf(Best)); // the slower ones, down one
        b.* = .{ .initials = "   ".*, .seconds = t.seconds, .minutes = t.minutes, .hours = t.hours };
        m.work(30); // the stores
        m.poke(map.shell_signing, p);
        m.poke(map.shell_place, k);
        return true;
    }
    return false;
}

/// The colour of each place, fastest first.
const colors = [places]Color{ .white, .yellow, .yellow, .orange, .orange, .orange, .pink, .pink, .pink, .pink };
const left = 28; // where the lines start

/// Both tables. If someone's signing his time, the top says so, and a
/// line waits for his initials. Call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    m.poke(hw.sprite_enable, 0);
    const signing = m.peek(map.shell_signing);
    if (signing == 0xFF) {
        text.say(m, 40, 0, .yellow, "BEST TIMES");
        const name = files.entry(m.peek(map.shell_castle));
        _ = text.draw(m, 80 - 4 * length(m, name), 8, .white, text.plain, name);
    } else {
        const coat = player.coat(@intCast(signing));
        if (signing == 0) text.say(m, 0, 0, coat, "PLAYER 1, BEST TIME!") else text.say(m, 0, 0, coat, "PLAYER 2, BEST TIME!");
        text.say(m, 8, 8, .white, "INITIALS AND RETURN");
    }
    text.say(m, 32, 24, .light_green, "ONE EXPLORER");
    text.say(m, 28, 112, .light_green, "TWO EXPLORERS");
    for (0..2) |w| {
        var k: u8 = 0;
        while (k < places) : (k += 1) line(m, @intCast(w), k);
    }
    if (signing != 0xFF) {
        const two = m.peek(castle.two);
        typing.begin(m, left, rowOf(two, m.peek(map.shell_place)), 3);
    }
}

/// Letters in the stored name at `at`.
pub fn length(m: *Machine, at: u16) u8 {
    var n: u8 = 1;
    while (m.peek(at + n - 1) & 0x80 == 0) n += 1;
    return n;
}

fn rowOf(two: u8, k: u8) u8 {
    return 32 + 88 * two + 8 * k;
}

/// One place: "ABC  01:23:45", or "..." while it's empty.
fn line(m: *Machine, two: u8, k: u8) void {
    const b = &file(m).tables[two][k];
    m.work(20); // the test
    if (b.initials[0] == 0xFF) {
        text.say(m, left, rowOf(two, k), colors[k], "...");
        return;
    }
    m.copy(map.text_buffer, address(two, k), 3); // the initials
    m.poke(map.text_buffer + 3, ' ');
    m.poke(map.text_buffer + 4, ' ');
    const end = clock.write(m, map.text_buffer + 5, b.hours, b.minutes, b.seconds);
    m.poke(end, m.peek(end) | 0x80);
    _ = text.draw(m, left, rowOf(two, k), colors[k], text.plain, map.text_buffer);
}

/// Every frame of the best times. Looking at them: fire on stick 1 or Esc
/// is done. Signing one: the initials, up to Return (or Esc, and it stays
/// unsigned); then the score file goes back to the disk. True when done.
pub fn run(m: *Machine) bool {
    const signing = m.peek(map.shell_signing);
    if (signing == 0xFF) {
        const key = m.peek(hw.key);
        if (key != 0) m.poke(hw.key, 0); // seen it
        return player.pressedFire(m, 0) or key == typing.key_esc;
    }
    switch (typing.run(m)) {
        .typing => return false,
        .done => {
            const at = address(m.peek(castle.two), m.peek(map.shell_place));
            const n = m.peek(map.shell_typed);
            m.copy(at, map.shell_line, n);
            m.poke(at + n - 1, m.peek(at + n - 1) & 0x7F); // not the end of anything here
        },
        .cancelled => {},
    }
    m.poke(map.shell_signing, 0xFF);
    m.poke(hw.control, 0); // the save is a loading pause: blank first
    _ = files.saveScores(m);
    return true;
}
