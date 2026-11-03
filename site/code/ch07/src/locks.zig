//! Keys and locks. A key is an object until the explorer presses fire at
//! it; then it's a number in his pocket. A lock opens its door when he
//! presses fire at it with the right number in his pocket.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// A key's or a lock's colours: code 10 is key number `number`'s colour,
/// and code 01 a white glint.
fn colors(number: u8) u8 {
    return @as(u8, @intFromEnum(Color.white)) << 4 | (number & 0x0F);
}

/// A key record: the key, in its colour, unless it was taken on an
/// earlier visit. Then there's nothing to draw, and no object.
pub fn prepareKey(m: *Machine, r: castle.Record) void {
    const k = m.view(castle.Key, r.at);
    if (k.shape == 0) return; // taken: the castle remembers
    shapes.recolor(m, .key, colors(k.number));
    room.place(m, .key, k.x, k.y);
    _ = objects.add(m, .key, room.boxOf(m, .key, k.x, k.y), r.at);
}

/// A key's `in_front`: the explorer presses fire at it, and it goes into
/// his pocket. It's rubbed out of the room and out of the castle, and the
/// object table lets it go at the end of the step.
pub fn take(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    const o = objects.slot(m, n);
    m.work(16); // the tests
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
    const count = m.peek(castle.keys_count);
    if (count == castle.pocket) return; // his pocket is full: leave it where it is
    const k = m.view(castle.Key, o.record);
    m.poke(castle.keys_held + count, k.number);
    m.poke(castle.keys_count, count + 1);
    k.shape = 0; // gone from the castle, for good
    room.unplace(m, .key, o.box.x, o.box.y);
    o.flags.picked = true;
    o.flags.disable = true; // and until it goes, nobody can stand in front of it
}

/// Is key `number` in his pocket?
pub fn carrying(m: *Machine, number: u8) bool {
    const count = m.peek(castle.keys_count);
    var i: u8 = 0;
    while (i < count) : (i += 1) {
        m.work(10); // the test and the loop
        if (m.peek(castle.keys_held + i) == number) return true;
    }
    return false;
}

/// A lock record: the lock, in the colour of the key it wants.
pub fn prepareLock(m: *Machine, r: castle.Record) void {
    const l = m.view(castle.Lock, r.at);
    shapes.recolor(m, .lock, colors(l.number));
    room.place(m, .lock, l.x, l.y);
    _ = objects.add(m, .lock, room.boxOf(m, .lock, l.x, l.y), r.at);
}

/// A lock's `in_front`: the explorer presses fire at it. With its key in
/// his pocket, its door gets to work, as if its bell had rung.
pub fn unlock(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    const l = m.view(castle.Lock, objects.slot(m, n).record);
    m.work(16); // the tests
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
    if (!carrying(m, l.number)) return;
    const d = objects.slot(m, objects.find(m, .door, l.door) orelse return);
    if (d.open == 0) d.flags.execute = true;
}
