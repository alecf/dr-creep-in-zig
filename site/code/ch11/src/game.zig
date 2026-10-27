//! A whole game, from the title screen's fire button to GAME OVER: who
//! plays which room next, lives, escapes, and the screens between rooms.
//! It all lives in the castle header, which a new game copies afresh.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const text = @import("text.zig");
const actors = @import("actors.zig");
const player = @import("player.zig");
const chart = @import("chart.zig");
const escape = @import("escape.zig");
const sound = @import("sound.zig");
const files = @import("files.zig");

/// The screens between rooms. Only one of them is ever on, so they share
/// the same seven bytes: an `extern union` lays its fields over each
/// other, all starting at its first byte.
pub const Between = extern union {
    chart: chart.Chart,
    escape: escape.Escape,
    over: Over,
};
comptime {
    if (@sizeOf(Between) != map.between.last - map.between.first + 1)
        @compileError("the screens between rooms must fill their region exactly");
}

/// Whichever of them is on.
pub fn between(m: *Machine) *align(1) Between {
    return m.view(Between, map.between.first);
}

/// GAME OVER stays up for 210 frames, a little over four seconds.
pub const Over = extern struct {
    wait: u8, // frames left
    unused: [6]u8,
};
const over_frames = 210;

/// On the title screen, every frame: fire on stick 1 starts a game for
/// one, fire on stick 2 a game for two. Null while nobody's pressed, or
/// there's no castle to play.
pub fn chosen(m: *Machine) ?bool {
    const one = player.pressedFire(m, 0);
    const two = player.pressedFire(m, 1);
    if (!files.ready(m)) return null;
    if (two) return true;
    if (one) return false;
    return null;
}

/// A new game: a fresh copy of the castle, every door shut and every key
/// where it was, then each player at the start. The header's scratch
/// bytes are zeros in the castle file, so the copy clears them too.
/// Thousands of bytes at 8 cycles each: call it with the display blanked.
pub fn start(m: *Machine, two: bool) void {
    m.copy(map.castle.first, map.staging.first, m.peek16(map.staging.first));
    m.poke(castle.two, @intFromBool(two));
    for (0..2) |i| {
        const p: u16 = @intCast(i);
        m.poke(castle.room + p, m.peek(castle.start_room + p));
        m.poke(castle.door + p, m.peek(castle.start_door + p));
    }
    m.poke(castle.in_game, 1);
    m.poke(castle.in_game + 1, @intFromBool(two));
    m.work(40); // the loop and the stores
}

/// Which room next? With both players in one room, that one, for both.
/// In two rooms, the one the player who wasn't last to leave a room is
/// in. With one left in the game, his. False if nobody's left.
pub fn next(m: *Machine) bool {
    const one = m.peek(castle.in_game) != 0;
    const two = m.peek(castle.in_game + 1) != 0;
    m.work(30); // the tests
    if (!one and !two) return false;
    var p: player.Number = if (one) 0 else 1;
    if (one and two and m.peek(castle.room) != m.peek(castle.room + 1))
        p = @intCast(m.peek(castle.last) ^ 1);
    m.poke(map.room_number, m.peek(castle.room + p));
    return true;
}

/// What comes after a room.
pub const Then = enum { map, escape, over };

/// The room's over: settle up with everyone who was in it. Dead, he loses
/// a life (unless the menu says lives are unlimited), and starts again at
/// the castle's start, unless that was his last: then he's out of the
/// game. Through the way out, he's escaped.
pub fn after(m: *Machine) Then {
    var then: Then = .map;
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        m.work(20); // the tests
        if (player.record(m, p).actor == actors.none) continue; // he wasn't here
        if (player.status(m, p) == .dead) {
            const lost: u8 = if (m.peek(map.shell_unlimited) != 0) 0 else 1;
            const lives = m.peek(castle.lives + p) -| lost;
            m.poke(castle.lives + p, lives);
            if (lives == 0) {
                m.poke(castle.in_game + p, 0);
                if (then == .map) then = .over;
            } else {
                m.poke(castle.room + p, m.peek(castle.start_room + p));
                m.poke(castle.door + p, m.peek(castle.start_door + p));
            }
        } else if (m.peek(castle.escaped + p) != 0) {
            then = .escape;
        }
    }
    if (then == .map) _ = next(m);
    return then;
}

/// The next player to show escaping: still in the game, and through the
/// way out.
pub fn escaper(m: *Machine) ?player.Number {
    for (0..2) |i| {
        const p: player.Number = @intCast(i);
        m.work(16); // the tests
        if (m.peek(castle.in_game + p) != 0 and m.peek(castle.escaped + p) != 0) return p;
    }
    return null;
}

/// GAME OVER, and in a game for two, whose, in his coat's colour. Call
/// it with the display blanked.
pub fn drawOver(m: *Machine) void {
    screen.clear(m);
    m.poke(hw.sprite_enable, 0);
    text.shout(m, 44, 56, .pink, "GAME OVER");
    if (m.peek(castle.two) != 0) {
        if (m.peek(castle.in_game) == 0) text.say(m, 32, 104, player.coat(0), "FOR PLAYER 1");
        if (m.peek(castle.in_game + 1) == 0) text.say(m, 32, 128, player.coat(1), "FOR PLAYER 2");
    }
    between(m).over = .{ .wait = over_frames, .unused = @splat(0) };
    sound.music(m, .over);
}

/// Every frame of GAME OVER. True when it's been up long enough.
pub fn over(m: *Machine) bool {
    const o = &between(m).over;
    o.wait -= 1;
    m.work(10); // the count and the test
    return o.wait == 0;
}
