---
chapter: 5
title: "Ding Dong, You're Dead"
checkpoint: ch05
---

:::mission-briefing
The Gatehouse has had a doorbell since Chapter 3, and its sign has been
telling you to ring it. This chapter, it rings. Stand at the bell, press
fire, and the door beside it slides open a row at a time. Push the stick
up and to the right and the explorer walks into the doorway, and out of
another door in the next room. From there you can walk the Training
Castle room to room, through every door its bells open, and the doors
stay open behind you. He can also die now: he flickers away, loses a
life, and starts again at the castle's front door.

![The Gatehouse: the explorer at the doorbell, and the door beside it half open, its lower half already wiped away to black](images/05-bell.png)

Behind the doors is the engine every later chapter runs on: a table of
**actors**, the things that move, and a table of **objects**, the things
they can stand in front of. Both have a fixed number of slots, so there's
nothing to allocate.

New under the hood: **an array of structs is one block of memory**,
**fixed-capacity slot tables**, and **tables of functions**. Chapter 3
promised the last one.
:::

## A castle full of things

Think about a busy room late in a castle. Two explorers are working a
switch together while a mummy shuffles after one of them. A ray gun's
laser streaks across the room. Frankenstein's monster is waking up in his
alcove, and lightning crackles under three machines, a sprite for each
bolt. That's eight things that move, and every one is a sprite: the Comet
has exactly eight. Around them stand the things they use: doors,
doorbells, switches, keys, locks, control panels. A busy room can have a
couple of dozen.

Every frame the game has to visit all of them. It moves the movers, finds
out who is touching what, and lets each thing that has something to do do
it. How you lay that crowd out in memory decides what visiting it costs.

:::under-the-hood `monsters.push(new Monster())`
In JavaScript you'd write a class and keep a list:

```
class Monster {
  constructor(x, y) { this.x = x; this.y = y; }
  update() { /* chase the player */ }
}
const monsters = [];
monsters.push(new Monster(40, 100));
```

Every `new` asks the engine for a fresh piece of the heap, somewhere,
with a hidden header of its own. The array doesn't hold monsters. It holds
**pointers** to them, and the monsters themselves are scattered wherever
the allocator found room:

```
  monsters ──► [ ptr │ ptr │ ptr ]
                 │      │     └──────────────► { header, x, y, ... }
                 │      └──► { header, x, y, ... }
                 └────────────────────────────────────► { header, x, y, ... }
```

Visiting them follows a pointer per monster. When one dies it becomes
garbage, and a collector finds it and frees it later, at a moment you
don't choose. `update()` is found by looking up the object's prototype.
Python's list of objects works the same way.

The 1984 game can't afford any of that, and doesn't need it. There will
never be more than eight movers, so it keeps **eight slots in one block
of memory**, one after another, and a slot that isn't in use is marked
free:

```
  $BD00 ┌──────────┬──────────┬──────────┬─────┬──────────┐
        │  slot 0  │  slot 1  │  slot 2  │ ... │  slot 7  │
        └──────────┴──────────┴──────────┴─────┴──────────┘
          16 bytes   16 bytes   16 bytes          ends at $BD7F
```

Slot *n* is at `$BD00 + 16n`. There are no pointers to follow, nothing to
allocate and nothing to collect.
:::

### Sixteen bytes an actor

Anything that moves by itself is an **actor**, and the actor table gets
its own region at `$BD00`, where the 1984 game keeps its own. Slot *n*
goes with sprite *n*, so the table has exactly eight slots.

The explorer moves into slot 0. His position, his picture and his last
step all become his actor's business, so the `player` region shrinks to
what the game has to remember about player 1 *between* rooms: which slot
he has, what he's up to, his lives, the joystick byte from his last turn,
and the door he comes into a room by. `player_last_stick` keeps its
address, `$0203`.

**`src/map.zig`** (replace the `player` region, its comment and its seven bytes)

```zig
/// What the game knows about player 1 from room to room, five bytes in a
/// row. Where he is and what he's doing in a room is his actor's business
/// (actors.zig).
pub const player = Region{ .name = "player", .first = 0x0200, .last = 0x0204 };
pub const player_actor = player.first + 0; // the actor slot he has in this room
pub const player_status = player.first + 1; // a player.Status: playing, in a doorway, gone, dead
pub const player_lives = player.first + 2; // lives left, counting this one
pub const player_last_stick = player.first + 3; // joystick 1 as it read at his last turn
pub const player_door = player.first + 4; // the door he comes into the room by
```

**`src/map.zig`** (add below the row table)

```zig
/// The actor table: a 16-byte slot for each of the VIDEO chip's eight
/// sprites (actors.zig).
pub const actors = Region{ .name = "actors", .first = 0xBD00, .last = 0xBD00 + 8 * 16 - 1 };
```

**`src/map.zig`** (in `regions`, add after `row_table,`)

```zig
    actors,
```

`player_status`, `player_lives` and `player_door` wait for later in the
chapter. Now the slot itself, in a new file:

**`src/actors.zig`** (new file)

```zig
//! The actor table: everything in a room that moves by itself, as a
//! sprite. Eight slots in a row, one for each of the VIDEO chip's
//! sprites: slot n is sprite n. The explorer is the only kind of actor so
//! far; lightning, lasers and monsters move in later.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");
const player = @import("player.zig");

/// Where something is and how big: its top-left corner in castle
/// coordinates, and its size in fat pixels and rows. Actors and objects
/// both start with one.
pub const Box = extern struct { x: u8, y: u8, width: u8, height: u8 };

/// One slot: 16 bytes.
pub const Actor = extern struct {
    kind: Kind,
    state: State,
    box: Box, // where it is, and the size of its picture
    frame: u8, // the shape ID of its picture
    block: u8, // the sprite block showing it: n or n + 8
    color: u8, // its sprite's own colour
    countdown: u8, // engine steps until its next turn
    pace: u8, // engine steps from one turn to the next: 1 is every step
    flashes: u8, // flashes left while it's dying
    way: u8, // the direction of its last step
    stick: u8, // the direction its joystick read at its last turn
    fire: u8, // 1 if fire was pressed at its last turn
    walk: u8, // how far through a doorway it is
};

/// An actor's state: eight flags in one byte, the engine's to-do list.
pub const State = packed struct(u8) {
    unused: bool = false, // bit 0: the slot is empty
    hit_sprite: bool = false, // bit 1: its sprite touched another sprite
    hit_bitmap: bool = false, // bit 2: its sprite touched the room's foreground
    free: bool = false, // bit 3: empty the slot at the end of this step
    destroy: bool = false, // bit 4: its last turn: it tidies up, then it's freed
    dying: bool = false, // bit 5: flickering
    flash: bool = false, // bit 6: start dying
    created: bool = false, // bit 7: new this step
};
```

`Box` is a corner and a size, four bytes. The objects later in the chapter
start with one too, and that's how we'll test whether an actor is standing
in front of something. `Actor` is sixteen bytes, all of them `u8`s or
structs of `u8`s, so it's an `extern struct` with no padding (Chapter 3).
Here's slot 0 with the explorer in it, standing in the Gatehouse's
doorway:

```
  offset:  0     1      2   3   4   5    6      7      8      9      10    ...   15
        ┌──────┬──────┬───┬───┬───┬───┬──────┬──────┬──────┬──────┬──────┬─────┬──────┐
        │ kind │state │ x │ y │ w │ h │frame │block │colour│count │ pace │ ... │ walk │
        │  0   │ $00  │162│171│ 8 │21 │  16  │  0   │  1   │  1   │  1   │     │  0   │
        └──────┴──────┴───┴───┴───┴───┴──────┴──────┴──────┴──────┴──────┴─────┴──────┘
                        └──── box ────┘
```

`state` is eight flags in a byte, a `packed struct(u8)` like the room
size byte of Chapter 3, and these are the 1984 game's bits in the 1984
game's order. Most of them are about an actor's life. A new actor is
`created`. One that's been killed gets `flash`, then flickers for a while
as `dying`. One whose time is up gets `destroy`, which buys it one last
turn to tidy up, and then `free`, which empties the slot at the end of the
engine's step. `unused` marks an empty slot. The other two bits,
`hit_sprite` and `hit_bitmap`, come from the VIDEO chip, and they're the
best trick in the chapter. They wait for the doorbell.

:::widget byte-diagram
The actor table live: eight rows of 16 bytes at `$BD00`, with slot 0's
fields named and its `state` byte split into its eight flags.
:::

### A table of functions

Every kind of actor does something different on its turn. The explorer
reads the joystick; a mummy (Chapter 8) chases the nearest explorer; a
laser (Chapter 7) flies until it hits something. The engine walks the
table without knowing any of that, so it needs a way to get from a slot's
`kind` byte to the right code.

**`src/actors.zig`** (add at the end of the file)

```zig
/// Every kind of actor. Later chapters add more.
pub const Kind = enum(u8) { player, _ };

/// What each kind does: the function that takes its turn.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
};

/// One entry for every kind, found by number. The compiler won't build
/// the table with a kind missing.
const kinds = std.enums.directEnumArray(Kind, Behaviour, 0, .{
    .player = .{ .turn = player.turn },
});
```

`*const fn (m: *Machine, n: u3) void` is a **function pointer**. Chapter
2 showed you that a pointer is an address. Code lives at addresses too, in
the program image, and a function pointer is the address where a
function's code starts. `player.turn`, written without the brackets that
would call it, *is* that address. `Behaviour` is a struct holding one, so
`kinds[k].turn(m, n)` reads an address out of the table and calls the code
it points to:

```
  slot 0:  kind = 0 ──► kinds[0] = .{ .turn = ──┐ }
                                                 └──► player.turn's code, in the program image
```

In JavaScript you'd write `const kinds = { player: { turn: playerTurn } }`
and call `kinds[a.kind].turn(m, n)`. It's the same idea, looked up by
name in a hash table while the game runs, and a missing entry is
`undefined is not a function` in the middle of play. Ours is looked up by
number in an array, and a missing entry stops the build.

`kinds` is built by `std.enums.directEnumArray`, from the standard
library's enum helpers. You hand it a struct with a field for every tag of
`Kind`, the same kind of struct as Chapter 3's `EnumFieldStruct`, and it
hands back an array with each tag's entry at the tag's number. So the
table is indexed by `@intFromEnum(kind)` with no searching, and a kind
without an entry is a compile error. With only one kind it's a short
table; Chapter 6 makes it longer.

`Kind` has a `_` in it, which makes it a **non-exhaustive** enum: any byte
is a legal `Kind`, even ones with no name. The machine insists on that for
a field it reads straight out of memory (reference card, section 9),
because a byte in RAM can hold anything. If a bug ever puts a kind with no
entry in a slot, indexing `kinds` with it stops the game with an
out-of-bounds panic, instead of jumping somewhere strange.

:::pro-tip `fn` or `*const fn`?
`fn (m: *Machine, n: u3) void` on its own is a function *type*, something
only the compiler deals in; you can't keep one in a table that exists
while the game runs. `*const fn (m: *Machine, n: u3) void` is a pointer to
a function of that type: an address, which you can store, copy and call
through. Tables hold the second. Write a bare `fn` type in a struct field
and Zig makes the whole struct compile-time only.
:::

:::power-up The Jump Table Power-Up
When a value picks which code runs, keep the code's addresses in a table
and use the value as the index. One read and one call, however many kinds
there are, and adding a kind means adding a row, not threading a new case
through every `switch` in the game. A JavaScript class gets the same effect
by looking `update` up on its prototype; a jump table is that lookup made
into one array read, decided at compile time.
:::

:::inside-the-disk Six kinds, eight bytes each
The 1984 engine keeps a record for each of its six kinds of actor (the
explorer, lightning, forcefield, mummy, laser, Frankenstein's monster) at
`$088F`: eight bytes, three of them pairs that hold the addresses of its
routines (its turn, what happens when it hits another sprite, what happens
when it hits an object), then two bytes of flags, one of which says
whether it flickers when it dies. Its object kinds get a pair of addresses
each at `$0842`, one for "do your work" and one for "someone is standing
in front of you", and an address of zero means "this kind doesn't". It's
the table you're building, down to the empty entries.
:::

### Slots, not lists

Now the table itself, and the two things every slot table needs: emptying
it, and finding a free slot.

**`src/actors.zig`** (add at the end of the file)

```zig
pub const slots = 8;

comptime {
    if (@sizeOf(Actor) * slots != map.actors.last - map.actors.first + 1)
        @compileError("the actor table doesn't fill its region exactly");
}

/// The whole table, as the eight structs it is.
pub fn table(m: *Machine) *align(1) [slots]Actor {
    return m.view([slots]Actor, map.actors.first);
}

/// Slot `n`.
pub fn slot(m: *Machine, n: u3) *align(1) Actor {
    return &table(m)[n];
}

/// Empty every slot, before a room starts.
pub fn clear(m: *Machine) void {
    for (table(m)) |*a| {
        a.state = .{ .unused = true };
        m.work(10); // the store and the loop
    }
}

/// Take the first empty slot for a new actor of `kind`: every byte 0,
/// then `created`, and a turn every step. Null if all eight are taken.
pub fn add(m: *Machine, kind: Kind) ?u3 {
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (!a.state.unused) continue;
        const n: u3 = @intCast(i);
        m.fill(map.actors.first + @as(u16, n) * @sizeOf(Actor), @sizeOf(Actor), 0);
        a.kind = kind;
        a.state = .{ .created = true };
        a.block = @as(u8, n) + 8; // so its first picture goes into block n
        a.countdown = 1;
        a.pace = 1;
        m.work(20);
        return n;
    }
    return null;
}
```

`table` is the big idea in one line. `m.view([slots]Actor, ...)` is
Chapter 3's typed view, aimed at an *array* of structs, and in Zig an
array of structs is exactly the diagram above: eight `Actor`s, one after
another, 128 bytes with nothing between them. `table(m)[5]` is the 16
bytes at `$BD50`, and `slot(m, 5).box.x` is the byte at `$BD52`. The
`*align(1)` in the return types says the struct may start at any address,
since memory has no reason to line it up (Chapter 3 again). The view
costs nothing, so the loops charge `m.work` for their own effort.

`add` is the slot finder: it walks the table for the first slot marked
`unused`, wipes its 16 bytes, and hands back its number. If all eight are
taken it returns `null`, and the caller decides what that means. For the
explorer, who is always the first into a room, it never happens.

:::power-up The Slot Table Power-Up
Decide the most you'll ever need, make that many slots in one block, and
give every slot a "free" flag. Adding is finding the first free slot;
removing is setting its flag. There's no allocator, no fragmentation, no
garbage collector, and the worst case is known before the game ships:
eight actors cost 128 bytes, always. The price is a hard limit. Here the
hardware sets it anyway: there are eight sprites, so there are eight
actors.
:::

The rest of the file is what the engine does with the table every frame:

**`src/actors.zig`** (add at the end of the file)

```zig
/// Hand every actor to the VIDEO chip: where it is, its colour, its
/// picture, and which sprites are on at all. First thing in a frame.
pub fn show(m: *Machine) void {
    var on: u8 = 0;
    var multicolor: u8 = 0;
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused) continue;
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        on |= bit;
        multicolor |= bit;
        sprites.place(m, n, a.box.x, a.box.y);
        m.poke(hw.spriteColor(n), a.color);
        m.poke(hw.sprite_pointers + n, a.block);
        m.work(10); // the masks
    }
    m.poke(hw.sprite_enable, on);
    m.poke(hw.sprite_multicolor, multicolor);
}

/// One engine step for every actor, in slot order: each one whose
/// countdown runs out takes its turn.
pub fn step(m: *Machine) void {
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused) continue;
        const n: u3 = @intCast(i);
        if (a.state.destroy) {
            kinds[@intFromEnum(a.kind)].turn(m, n); // its last turn
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            kinds[@intFromEnum(a.kind)].turn(m, n);
        }
        if (a.state.free) a.state = .{ .unused = true };
        a.countdown = a.pace;
        m.work(30); // the flags
    }
}

/// Show picture `id` for actor `n` from the next frame on. It's unpacked
/// into the block the sprite *isn't* showing (Chapter 2's double buffer),
/// and its size becomes the box the actor touches things with.
pub fn setFrame(m: *Machine, n: u3, id: shapes.Id) void {
    const a = slot(m, n);
    const hidden = a.block ^ 8; // n <-> n + 8
    const at = shapes.address(m, id);
    a.box.width = m.peek(at) * 4; // bytes to fat pixels
    a.box.height = m.peek(at + 1);
    const flags = sprites.unpack(m, id, hidden);
    a.color = flags & sprites.flag_color;
    a.block = hidden;
    a.frame = @intFromEnum(id);
    m.work(16); // the stores
}
```

**`show`** is Chapter 1's shadow copy, for every actor at once: each
slot in use gets its position, colour and picture handed to its sprite,
and its bit set in the sprite-enable and multicolour registers.

**`step`** is one **engine step**, which the main loop will run every
other frame. Each actor has a `countdown`: every step takes one off it,
and when it reaches 0 the actor gets its turn and the countdown starts
again from `pace`. With a pace of 1 an actor gets a turn every step; the
explorer will use a pace of 3 for the slow walk through a doorway. An
actor marked `destroy` gets its last turn straight away, and one marked
`free` becomes `unused`, so a slot is emptied by the engine, never in the
middle of anyone's turn.

**`setFrame`** is Chapter 2's double-buffered unpack, moved here from
`player.zig` so every actor can use it. It also writes the picture's size
into the actor's box: the size of what you see is the size of what you
touch.

### The explorer moves in

The explorer's code now reads and writes his slot instead of the old
`player` bytes. First the file's top, and the imports: he uses `actors`
now, not `sprites`.

**`src/player.zig`** (replace the comment at the top)

```zig
//! Player 1: the explorer, an actor of kind `player`. He walks the
//! castle's floors, climbs its ladders, slides down its poles and goes
//! through its doors, steered by joystick 1.
```

**`src/player.zig`** (replace the `sprites` import)

```zig
const actors = @import("actors.zig");
```

Delete the `sprite` constant and the comment above it: his sprite is now
his slot number. `start` sets the two colours every multicolour sprite
shares and leaves the rest to `actors.show`:

**`src/player.zig`** (replace `start`)

```zig
/// Once, at power-on.
pub fn start(m: *Machine) void {
    m.poke(hw.sprite_mc0, @intFromEnum(Color.pink)); // code 01: skin
    m.poke(hw.sprite_mc1, @intFromEnum(Color.orange)); // code 11: hat, belt, boots
    m.poke(map.player_last_stick, 0xFF); // nothing held
}
```

`enter` becomes `add`, which takes a slot and puts him in a doorway, as
`enter` did:

**`src/player.zig`** (replace `enter`)

```zig
/// Into the room: an actor slot, and his place in its first doorway,
/// facing into the room. A room with no doors (the final room) puts him in
/// the middle of the floor.
pub fn add(m: *Machine) void {
    const n = actors.add(m, .player) orelse return; // he's the first in, so never
    m.poke(map.player_actor, n);
    const a = actors.slot(m, n);
    a.box.x = castle.left_edge + 80;
    a.box.y = room.floor_top - feet_y;
    a.way = still;
    if (room.firstDoor(m)) |at| {
        const d = m.view(castle.Door, at);
        a.box.x = d.x + door_x;
        a.box.y = d.y + door_y;
    }
    m.work(40); // the sums and the stores
    actors.setFrame(m, n, if (a.box.x < castle.left_edge + 80) .explorer_right_0 else .explorer_left_0);
}
```

`show` goes, since `actors.show` does it for everyone. In its place, his
turn, and a function that reads the joystick for it:

**`src/player.zig`** (replace `show`)

```zig
/// His turn, actor `n`'s: on every engine step.
pub fn turn(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    a.state.created = false;
    read(m, a);
    steer(m, n);
}

/// Read joystick 1, once a turn: its direction, and whether fire is down
/// now and wasn't at his last turn. The port byte is kept for next time here
/// and nowhere else in a room, so a fire button held down is never a
/// fresh press, however far he carries it.
fn read(m: *Machine, a: *align(1) actors.Actor) void {
    const stick = m.peek(hw.joy1);
    a.stick = stick_way[stick & 0x0F];
    a.fire = @intFromBool(pressed(stick, m.peek(map.player_last_stick)));
    m.poke(map.player_last_stick, stick);
    m.work(16); // the table read and the test
}
```

`read` is where Chapter 2's warning about `pressedFire` finally gets
dealt with. The edge detector remembers the stick from last time, and if
the explorer only asked "was fire pressed?" while he stood at a bell, a
button held all the way across the room would look like a fresh press
when he arrived. So `read` runs on every turn, wherever he is, keeps the
port byte in `player_last_stick` once and only once, and records what it
found in his slot: the stick's direction, and whether fire was pressed
this turn. Anything that wants to know asks his slot. (A turn is every
other frame, so a tap shorter than that can slip between two looks; no
thumb is that quick.)

`steer` itself hardly changes: his position and his last direction come
from his box and his `way` byte, the stick's direction from `read`, and
pictures go through `actors.setFrame`. The `game_tick` test at its top
goes, because the engine step now sets the pace for everybody.

:::type-in `steer`, reading and writing his slot
**`src/player.zig`** (replace `steer`)

```zig
/// One step: read the grid under his feet, pick a way to go, take the
/// step and pick his picture.
fn steer(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    var x = a.box.x;
    var y = a.box.y;
    const fx = x + feet_x;
    const fy = y + feet_y;
    const ways = waysAt(m, fx, fy);

    // The stick's direction if that way is open. If it isn't, but it's
    // next to the way he was already going (a diagonal, say), keep going.
    const want = a.stick;
    const last = a.way;
    var way = still;
    if (want != still) {
        if (ways & bit(want) != 0) {
            way = want;
        } else if (last != still and ways & bit(last) != 0 and
            (want == (last +% 1) & 7 or want == (last -% 1) & 7))
        {
            way = last;
        }
    }
    a.way = way;

    if (way != still) {
        if (way & 3 == 2) y -= fy % 8; // off sideways: up onto the walkway's row
        if (way & 3 == 0) x = x - fx % 4 + 1; // up or down: feet in line with the rungs
        x +%= step_x[way];
        y +%= step_y[way];
        a.box.x = x;
        a.box.y = y;
    }
    m.work(60); // the sums, tests and table reads above

    // His picture. Walking: Chapter 2's walk, a frame every 2 fat pixels.
    // Up or down: a ladder has rungs that lead up from here or from just
    // below; a pole has none.
    const now = a.frame;
    var next = now;
    if (way == 2 or way == 6) {
        next = (if (way == 2) right_0 else left_0) + ((x >> 1) & 0b11);
    } else if (way == 0 or way == 4) {
        const rungs = (ways | waysAt(m, fx, fy +| 8)) & grid.up != 0;
        next = if (rungs) climb_0 + ((y >> 2) & 0b11) else @intFromEnum(shapes.Id.explorer_slide);
    } else if (now >= right_0 and now < left_0 + 4) {
        next = if (now >= left_0) left_0 else right_0; // stopped walking: stand
    } // stopped on a ladder or a pole: hold on
    if (next != now) actors.setFrame(m, n, @enumFromInt(next));
}
```
:::

Delete `setFrame` from `player.zig` (it lives in `actors.zig` now), and
split the press test out of `pressedFire`, so it's a plain function of two
bytes that anything can use:

**`src/player.zig`** (replace `pressedFire`)

```zig
/// Was fire pressed this frame? For the title screen, where there's no
/// actor yet. It keeps the stick for next time, so call it once a frame.
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const yes = pressed(stick, m.peek(map.player_last_stick));
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return yes;
}

/// Is fire pressed now that wasn't before? The Edge Detector Power-Up as
/// a plain function of two port bytes: no memory of its own.
pub fn pressed(stick: u8, before: u8) bool {
    return held(stick, joy.fire) and !held(before, joy.fire);
}
```

Now the frame. The room branch shows every actor, and every other frame
runs an engine step in a bucket of its own:

**`src/main.zig`** (add below the `player` import)

```zig
const actors = @import("actors.zig");
```

**`src/main.zig`** (add below `bucket_sprites`)

```zig
const bucket_actors = 3;
```

**`src/main.zig`** (in the `.draw_room` branch, replace `player.enter(m);`)

```zig
            actors.clear(m);
            player.add(m);
```

**`src/main.zig`** (in the `.room` branch, replace everything from `m.bucket(bucket_sprites);` to `player.steer(m);`)

```zig
            m.bucket(bucket_sprites);
            actors.show(m);

            // Then the castle itself, one engine step every other frame:
            // 25 a second. What it decides shows up next frame.
            if (m.peek(map.game_tick) & 1 == 0) {
                m.bucket(bucket_actors);
                actors.step(m);
            }
```

The tests still poke at the old `player` bytes. With your editor's find
and replace, replace each of these everywhere it appears in `main.zig`'s
tests (any you miss won't compile, because `map.player_x` and the rest
are gone):

| Replace | With |
|---|---|
| `m.ram[map.player_x]` | `explorer(m).box.x` |
| `m.ram[map.player_y]` | `explorer(m).box.y` |
| `m.ram[map.player_frame]` | `explorer(m).frame` |
| `m.ram[map.player_block]` | `explorer(m).block` |

and add the function they now call:

**`src/main.zig`** (add above `inRoom`)

```zig
/// The explorer's actor slot.
fn explorer(m: *Machine) *align(1) actors.Actor {
    return actors.slot(m, @intCast(m.ram[map.player_actor]));
}
```

Two new tests: one for the slot table, and one for the press rule.

:::type-in The slot table's tests, and the press rule's
**`src/actors.zig`** (add at the end of the file)

```zig
// ---- tests ----------------------------------------------------------------

test "eight slots: add takes the first empty one, and a full table says no" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    clear(m);
    for (0..slots) |i| try std.testing.expectEqual(@as(?u3, @intCast(i)), add(m, .player));
    try std.testing.expectEqual(@as(?u3, null), add(m, .player));
    try std.testing.expect(slot(m, 3).state.created);
    try std.testing.expectEqual(3 + 8, slot(m, 3).block);

    // Free slot 3 the way the engine does, and the next actor gets it.
    slot(m, 3).state.free = true;
    step(m);
    try std.testing.expect(slot(m, 3).state.unused);
    try std.testing.expectEqual(@as(?u3, 3), add(m, .player));
    try std.testing.expectEqual(@as(?u3, null), add(m, .player));
}

test "the table is one block: slot n is 16 n bytes in, in the field order" {
    try std.testing.expectEqual(16, @sizeOf(Actor));
    try std.testing.expectEqual(2, @offsetOf(Actor, "box"));
    try std.testing.expectEqual(1, @bitSizeOf(State) / 8);
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    slot(m, 5).box.x = 99;
    try std.testing.expectEqual(99, m.ram[map.actors.first + 5 * 16 + 2]);
    slot(m, 5).state = .{ .unused = true, .flash = true };
    try std.testing.expectEqual(0b0100_0001, m.ram[map.actors.first + 5 * 16 + 1]);
}
```

**`src/player.zig`** (add at the end of the file)

```zig
// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "a press is fire held now and not before, whatever else is held" {
    const none: u8 = 0xFF;
    const fire: u8 = 0xFF & ~joy.fire;
    try std.testing.expect(pressed(fire, none));
    try std.testing.expect(!pressed(fire, fire)); // still held: not a press
    try std.testing.expect(!pressed(none, fire)); // let go
    try std.testing.expect(!pressed(none, none));
    try std.testing.expect(pressed(fire & ~joy.right, none & ~joy.right)); // walking and pressing
}
```
:::

Build and run. Nothing looks different, and that's the point: the
explorer walks, climbs and slides exactly as he did, but he's actor 0
now, and everything he does goes through the table. The meter has
noticed: a frame costs about twice what it did in Chapter 4, because
`show` and `step` visit all eight slots, seven of them empty. That's the
price of an engine with room for seven more actors, and it's a fixed
price: an empty slot costs one test.

:::widget budget-meter
The frame budget, bucket by bucket, in the Gatehouse: Chapter 4's frames
beside this chapter's, then (as the chapter goes on) at the bell, while
the door opens, and with C on.
:::

## A promise from Chapter 3

Chapter 3's `room.draw` picks each record's code with a `switch`. Now it
gets a table of functions too: one per kind of record, taking the record
and preparing it.

**`src/room.zig`** (add above the `machine` import)

```zig
const std = @import("std");
```

**`src/room.zig`** (replace `draw`)

```zig
/// What preparing a room does with each kind of record: a function for
/// every kind, found by number. The compiler won't build the table with a
/// kind missing.
const Prepare = *const fn (m: *Machine, r: castle.Record) void;
const prepares = std.enums.directEnumArray(castle.Kind, Prepare, 0, .{
    .door = door,
    .walkway = walkway,
    .pole = pole,
    .ladder = ladder,
    .bell = bell,
    .lightning = later,
    .forcefield = later,
    .mummy = later,
    .key = later,
    .lock = later,
    .pattern = later,
    .ray_gun = later,
    .teleport = later,
    .trapdoor = later,
    .conveyor = later,
    .frankenstein = later,
    .text = line,
    .image = image,
});

/// Draw the whole room, and build its navigation grid on the way, every
/// record handed to its kind's function. Far too big for one frame: call
/// it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    grid.clear(m);
    var walk = prepare(m, m.peek(map.room_number));
    while (walk.next(m)) |r| {
        m.work(10); // the table read and the call
        prepares[@intFromEnum(r.kind)](m, r);
    }
}

/// Machines and monsters come alive in later chapters.
fn later(m: *Machine, r: castle.Record) void {
    _ = m;
    _ = r;
}
```

Eleven kinds point at `later`, which does nothing; Chapter 6 starts
replacing them. Leave a kind out and the build stops:

```
missing struct field: image
```

Every function in the table has to have exactly the type `Prepare` says,
so the drawers that took an address now take a `castle.Record`. The bell
used to be handed the address of the room's doors; now it asks for its
door by number, with a function that replaces `firstDoor`:

**`src/room.zig`** (replace `firstDoor`)

```zig
/// Door `i` of room `n`, if the room has one. Doors come first in a
/// stream: their tag, a count, and 8 bytes for each door.
pub fn doorAt(m: *Machine, n: u8, i: u8) ?u16 {
    const at = objects(m, n);
    m.work(10); // the tests, and i * 8 is three shifts
    if (castle.kindOf(m, m.peek16(at)) != .door or i >= m.peek(at + 2)) return null;
    return at + 3 + @as(u16, i) * @sizeOf(castle.Door);
}
```

`doorAt` finds door `i` of any room, not only the one on screen, which
the doors will need shortly. The rest is new signatures. A walkway, a
ladder or a pole also builds its part of the grid, so the `grid.add` that
Chapter 4 called for every record moves into their own functions:

**`src/room.zig`** (replace the comment above `walkway` and its first two lines)

```zig
/// A walkway: `length` pieces 4 fat pixels wide, a left end, middles and
/// a right end. Somewhere to walk.
fn walkway(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    const w = m.view(castle.Run, r.at);
```

**`src/room.zig`** (add above `column`)

```zig
/// A sliding pole, and a ladder: somewhere to climb.
fn pole(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    column(m, .pole, r.at);
}

fn ladder(m: *Machine, r: castle.Record) void {
    grid.add(m, r);
    column(m, .ladder, r.at);
}
```

**`src/room.zig`** (in `door`, replace the first two lines)

```zig
fn door(m: *Machine, r: castle.Record) void {
    const d = m.view(castle.Door, r.at);
```

**`src/room.zig`** (replace `bell`)

```zig
/// A doorbell, in the colour of the room its door leads to.
fn bell(m: *Machine, r: castle.Record) void {
    const b = m.view(castle.Bell, r.at);
    const at = doorAt(m, m.peek(map.room_number), b.door) orelse return;
    const d = m.view(castle.Door, at);
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    place(m, .bell, b.x, b.y);
}
```

**`src/room.zig`** (in `line`, replace the first line)

```zig
fn line(m: *Machine, r: castle.Record) void {
    const at = r.at;
```

**`src/room.zig`** (in `image`, replace the first line)

```zig
fn image(m: *Machine, r: castle.Record) void {
    const at = r.at;
```

**`src/player.zig`** (in `add`, replace the `firstDoor` line)

```zig
    if (room.doorAt(m, m.peek(map.room_number), 0)) |at| {
```

and a test that the table has a function for every kind:

**`src/room.zig`** (add at the end of the file)

```zig
// ---- tests ----------------------------------------------------------------

test "preparing a room has a function for every kind of record" {
    try std.testing.expectEqual(std.enums.values(castle.Kind).len, prepares.len);
}
```

Build and run: the castle draws exactly as before, and preparing a room
is now one table read and one call per record.

## Things in the room

### The object table

An **object** is something in a room an actor can stand in front of, or
that has work of its own to do: a door, a doorbell, and later the
switches, keys, locks and control panels. Preparing a room fills the
object table, and the 1984 game gives it 32 slots. Each one is 16 bytes,
so the table takes the two pages from `$BE00`, right after the actors.

**`src/map.zig`** (add below the `actors` region)

```zig
/// The room's object table: 32 slots of 16 bytes (objects.zig).
pub const objects = Region{ .name = "objects", .first = 0xBE00, .last = 0xBE00 + 32 * 16 - 1 };
```

**`src/map.zig`** (in `regions`, add after `actors,`)

```zig
    objects,
```

The table needs a count of slots in use, and the room will soon need to
know how it ends. Two bytes go in a new region at `$020D`, leaving
`$020C` for one more debug switch at the end of the chapter:

**`src/map.zig`** (add below the `debug` region)

```zig
/// The room at work: how many objects it has, and how it ends.
pub const engine = Region{ .name = "engine", .first = 0x020D, .last = 0x020E };
pub const engine_objects = engine.first + 0; // object slots in use (objects.zig)
pub const engine_ending = engine.first + 1; // steps until the room is over, or 0 while it isn't ending
```

**`src/map.zig`** (in `regions`, add after `debug,`)

```zig
    engine,
```

**`src/objects.zig`** (new file)

```zig
//! The room's object table: the things in a room that an actor can stand
//! in front of, or that have work to do. Preparing the room fills it, up
//! to 32 of them, 16 bytes each. Doors and doorbells, for now.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const actors = @import("actors.zig");
const doors = @import("doors.zig");

/// One slot: 16 bytes.
pub const Object = extern struct {
    kind: Kind,
    flags: Flags,
    box: actors.Box, // the part an actor has to stand in front of
    record: u16, // where its record is in the castle
    number: u8, // a door: its place among the room's doors. A bell: its door's
    open: u8, // a door: 1 once it's open, or opening
    step: u8, // a door: rows of its panel still to wipe
    spare: [5]u8, // for the machines and monsters to come
};

/// An object's flags. Three are used by the engine; the low five are
/// each kind's own.
pub const Flags = packed struct(u8) {
    own: u5 = 0,
    picked: bool = false, // bit 5: picked up, so it leaves the table (keys)
    execute: bool = false, // bit 6: it has work to do: give it a turn every step
    disable: bool = false, // bit 7: nobody can stand in front of it
};

/// Every kind of object. Later chapters add more.
pub const Kind = enum(u8) { door, bell, _ };
```

`record` is a `u16`, the first one in a structure of ours. That's fine
because we arranged it: it starts at byte 6, an even byte, so Zig adds no
padding and the machine accepts the view (Chapter 3's rule). `number`,
`open` and `step` are the door's and the bell's; other kinds will use
their bytes in their own way, and five spare bytes wait for them.

The flags byte has 1984's three: `disable` (nobody can stand in front of
it), `execute` (it has work to do) and `picked` (a key that's been taken,
in Chapter 7). The other five bits belong to each kind. Then the
handlers:

**`src/objects.zig`** (add at the end of the file)

```zig
/// What each kind does: its work for a step while its `execute` flag is
/// set, and what happens when an actor stands in front of it. Null for
/// "nothing".
const Handlers = struct {
    execute: ?*const fn (m: *Machine, n: u8) void,
    in_front: ?*const fn (m: *Machine, n: u8, who: u3) void,
};

/// One entry for every kind, found by number.
const kinds = std.enums.directEnumArray(Kind, Handlers, 0, .{
    .door = .{ .execute = doors.open, .in_front = null },
    .bell = .{ .execute = null, .in_front = doors.ring },
});
```

This time the function pointers are **optional**: `?*const fn`. A bell
has nothing to do on its own, so its `execute` is `null`, and code that
calls a handler checks first, with Chapter 2's `if (x) |v|`. The door's
`in_front` is `null` too, for now.

**`src/objects.zig`** (add at the end of the file)

```zig
pub const slots = 32;

comptime {
    if (@sizeOf(Object) * slots != map.objects.last - map.objects.first + 1)
        @compileError("the object table doesn't fill its region exactly");
}

/// Slot `n`.
pub fn slot(m: *Machine, n: u8) *align(1) Object {
    return &m.view([slots]Object, map.objects.first)[n];
}

/// No objects, before a room is prepared.
pub fn clear(m: *Machine) void {
    m.poke(map.engine_objects, 0);
}

/// Take the next slot for an object of `kind`, standing in `box`, made
/// from the castle record at `record`. Null if the table is full; then
/// the object is drawn, but nothing can use it.
pub fn add(m: *Machine, kind: Kind, box: actors.Box, record: u16) ?u8 {
    const n = m.peek(map.engine_objects);
    if (n == slots) return null;
    m.poke(map.engine_objects, n + 1);
    m.fill(map.objects.first + @as(u16, n) * @sizeOf(Object), @sizeOf(Object), 0);
    const o = slot(m, n);
    o.kind = kind;
    o.box = box;
    o.record = record;
    m.work(30); // the stores
    return n;
}
```

`add` hands out slots in order, and a room that has more than 32 objects
gets the first 32 to work with; the rest are drawn and do nothing. That's
what 1984 does.

**`src/objects.zig`** (add at the end of the file)

```zig
/// One engine step for the objects: the ones that asked to run, run.
/// Everything else costs one test of one bit.
pub fn step(m: *Machine) void {
    const count = m.peek(map.engine_objects);
    var n: u8 = 0;
    while (n < count) : (n += 1) {
        const o = slot(m, n);
        m.work(12); // the test and the loop
        if (!o.flags.execute) continue;
        if (kinds[@intFromEnum(o.kind)].execute) |execute| execute(m, n) else o.flags.execute = false;
    }
}

/// Actor `who` has touched the room's foreground. Find the objects its box
/// overlaps, and tell each one it has an actor standing in front of it.
pub fn touching(m: *Machine, who: u3) void {
    const a = actors.slot(m, who);
    const count = m.peek(map.engine_objects);
    var n: u8 = 0;
    while (n < count) : (n += 1) {
        const o = slot(m, n);
        m.work(12); // the test and the loop
        if (o.flags.disable or !overlap(m, a.box, o.box)) continue;
        if (kinds[@intFromEnum(o.kind)].in_front) |in_front| in_front(m, n, who);
    }
}

/// Do two boxes overlap? An edge that touches counts. The sums are done in
/// a u16, so a box at the right of the screen can't wrap round.
pub fn overlap(m: *Machine, a: actors.Box, b: actors.Box) bool {
    m.work(40); // four compares, four sums
    return @as(u16, a.x) + a.width >= b.x and @as(u16, b.x) + b.width >= a.x and
        @as(u16, a.y) + a.height >= b.y and @as(u16, b.y) + b.height >= a.y;
}
```

**`step`** is the object half of the engine step. Look at what it
costs: one test of one bit per object. Most objects spend most of their
lives with nothing to do. A door is shut, or open, and either way it's
standing still. Only a door that has been rung has work: wiping its panel
a row at a time. So the bell that rings it sets its `execute` flag, and
`step` runs only the objects whose flag is up. The flag is the to-do list: there's no
queue of jobs to allocate, and a finished job clears its own bit.

**`touching`** is the other half: an actor has bumped into the room, and
it finds out what into. **`overlap`** is the test: two boxes overlap
unless one is entirely left of, right of, above or below the other, and
an edge that touches counts. The sums are done in a `u16`, because a box
at the right of the screen plus its width can pass 255 (Chapter 4's
overflow lesson, coming due).

### Who's touching what

Who calls `touching`, and when? It could be every actor, every turn,
against every object. A busy room has 8 actors and 32 objects, and that's
256 box tests every step, which we'll measure at the end of the chapter.
Most of them answer "no": an explorer on an empty stretch of floor isn't
touching anything.

The VIDEO chip can tell us that for free. As the beam draws, it notices
every sprite pixel that lands on a **foreground** pixel of the bitmap
(codes `10` and `11`, section 5 of the reference card) and sets that
sprite's bit in `$D01F`. Doors, doorbells and every other object are drawn
into the bitmap with foreground colours in them, so an actor that touched
nothing in the foreground can't be standing in front of anything.
`$D01E` does the same for sprites touching each other.

So the engine reads the two registers once a step, writes 0 to start them
counting again, and copies each actor's bit into its `hit_bitmap` and
`hit_sprite` flags. Only an actor with `hit_bitmap` set looks through the
objects. The hardware does the cheap, rough test on every pixel, and our
code does the exact one only when it might say yes.

**`src/actors.zig`** (add below the `sprites` import)

```zig
const objects = @import("objects.zig");
```

**`src/actors.zig`** (in `clear`, add at the end, and replace the comment above it)

```zig
/// Empty every slot, and forget any collisions, before a room starts.
pub fn clear(m: *Machine) void {
    for (table(m)) |*a| {
        a.state = .{ .unused = true };
        m.work(10); // the store and the loop
    }
    m.poke(hw.sprite_sprite_hits, 0);
    m.poke(hw.sprite_bitmap_hits, 0);
}
```

**`src/actors.zig`** (replace `step`)

```zig
/// One engine step for every actor, in slot order. The VIDEO chip's
/// collision reports come first, for free: an actor whose sprite touched
/// nothing in the room's foreground can't be standing in front of
/// anything, so only the ones that did look through the objects.
pub fn step(m: *Machine) void {
    const sprite_hits = m.peek(hw.sprite_sprite_hits);
    const bitmap_hits = m.peek(hw.sprite_bitmap_hits);
    m.poke(hw.sprite_sprite_hits, 0); // read them, then start again
    m.poke(hw.sprite_bitmap_hits, 0);
    for (table(m), 0..) |*a, i| {
        m.work(10); // the test and the loop
        if (a.state.unused) continue;
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        a.state.hit_sprite = sprite_hits & bit != 0;
        a.state.hit_bitmap = bitmap_hits & bit != 0;
        if (a.state.destroy) {
            kinds[@intFromEnum(a.kind)].turn(m, n); // its last turn
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            if (a.state.hit_bitmap) objects.touching(m, n);
            kinds[@intFromEnum(a.kind)].turn(m, n);
        }
        if (a.state.free) a.state = .{ .unused = true };
        a.countdown = a.pace;
        m.work(30); // the flags
    }
}
```

`clear` now also clears the registers, so a hit from the last room's
frames can't leak into a new one. The `hit_sprite` flag waits for
something that two sprites can bump into, which is Chapter 6's lightning.

### Ringing the bell

Doors and doorbells get a file of their own:

**`src/doors.zig`** (new file)

```zig
//! Doors and doorbells at work: a bell rung, a door swinging open.

const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");
const castle = @import("castle.zig");
const room = @import("room.zig");
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const player = @import("player.zig");

/// A bell answers feet up to 12 fat pixels from its left edge.
const bell_reach = 12;

/// A bell's `in_front`: the explorer, at the bell, presses fire. If its
/// door is shut, the door gets to work.
pub fn ring(m: *Machine, n: u8, who: u3) void {
    const a = actors.slot(m, who);
    const bell = objects.slot(m, n);
    m.work(20); // the tests
    if (a.kind != .player or a.fire == 0) return;
    if (a.box.x +% player.feet_x -% bell.box.x >= bell_reach) return; // his feet aren't under it
    const d = objects.slot(m, find(m, bell.number) orelse return);
    if (d.open == 0) d.flags.execute = true;
}

/// The object for the room's door `number`.
fn find(m: *Machine, number: u8) ?u8 {
    const count = m.peek(map.engine_objects);
    var n: u8 = 0;
    while (n < count) : (n += 1) {
        const o = objects.slot(m, n);
        m.work(12); // the tests and the loop
        if (o.kind == .door and o.number == number) return n;
    }
    return null;
}

/// A door's `execute`, from the step after its bell rang. The first time,
/// it opens in the castle, on both sides; then its panel is wiped a row a
/// step, from the bottom up, and last of all it's drawn open.
pub fn open(m: *Machine, n: u8) void {
    const o = objects.slot(m, n);
    m.work(20); // the tests
    if (o.open == 0) {
        o.open = 1;
        o.step = room.door_panel_height - 1;
        const d = m.view(castle.Door, o.record);
        d.side |= castle.door_open;
        if (room.doorAt(m, d.to_room, d.to_door)) |far| m.view(castle.Door, far).side |= castle.door_open;
        m.work(40); // the two doors' bits
    }
    room.wipe(m, o.box.x, o.box.y + o.step);
    if (o.step != 0) {
        o.step -= 1;
        return;
    }
    o.flags.execute = false; // done
    room.panel(m, o.record);
}
```

**`ring`** is the bell's `in_front`. It's the explorer (a laser can't ring
a doorbell), fire was pressed on his last turn (Chapter 1's Edge Detector,
the way `read` recorded it), and his feet are within 12 fat pixels of the
bell's left edge. That last test is the 1984 game's own: the wrapping
`-%` turns "left of the bell" into a huge number, so one comparison covers
both sides. Then it finds the bell's door among the objects, and if the
door is shut, sets its `execute` flag. That's all a bell does.

**`open`** is the door's `execute`, and it runs once a step until the door
is open. The first time, it opens the door **in the castle**: it sets bit
7 of the door's `side` byte, the open bit of Chapter 3's door record, and
the same bit on the door it leads to, in the other room. A door is one
opening in a wall, so it's open from both sides, and because the bit is
in the castle, it stays open when you leave and come back. Then it wipes
the panel one row a step, from the bottom up, and when it reaches the top
it draws the open door.

The 1984 door does exactly this, but its panel is 15 rows tall and opens
in 15 steps, about 0.6 seconds. Ours is 24 rows, tall enough for the
explorer (Chapter 3), and takes 24 steps: a little under a second, and it
looks like a portcullis going up.

`ring` measures from the explorer's feet, so `feet_x` becomes public.
Then the room makes the objects, so `room.zig` imports the two tables.
Its own `objects` function would now clash with the `objects` import. It
finds where a room's stream starts, so it becomes `stream`:

**`src/player.zig`** (replace the `feet_x` line)

```zig
pub const feet_x = 3;
```

**`src/room.zig`** (replace the comment at the top)

```zig
//! The room on screen, prepared from the castle: walk the room's object
//! stream, draw everything in it, and make the objects that do things.
```

**`src/room.zig`** (add below the `text` import)

```zig
const actors = @import("actors.zig");
const objects = @import("objects.zig");
```

**`src/room.zig`** (replace the comment above `objects` and its first line)

```zig
/// Where room `n`'s object stream starts in the castle. The room after the
/// last is the final room.
pub fn stream(m: *Machine, n: u8) u16 {
```

**`src/room.zig`** (in `prepare`, replace the last line)

```zig
    return .{ .at = stream(m, n) };
```

**`src/room.zig`** (in `doorAt`, replace the first line)

```zig
    const at = stream(m, n);
```

**`src/player.zig`** (in `waysAt`, replace `room.objects`)

```zig
        return grid.search(m, room.stream(m, m.peek(map.room_number)), x, y);
```

**`src/main.zig`** (in the test that searches the castle, replace the `objects` line and the lines down to the one that uses it)

```zig
        const stream = room.stream(m, @intCast(n));
        for (0..grid.rows) |row| {
            for (0..grid.columns) |col| {
                const x: u8 = @intCast(16 + 4 * col);
                const y: u8 = @intCast(8 * row);
                try std.testing.expectEqual(grid.at(m, x, y), grid.search(m, stream, x, y));
```

Preparing a room starts with an empty object table:

**`src/room.zig`** (replace the comment above `draw` and its first three lines)

```zig
/// Prepare the whole room: draw it, build its navigation grid and fill its
/// object table, every record handed to its kind's function. Far too big
/// for one frame: call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    grid.clear(m);
    objects.clear(m);
```

and the door and the bell make their objects as they're drawn:

**`src/room.zig`** (replace `door_panel_dx`, `door_panel_dy` and `door`, and the comments above them)

```zig
/// Where the door itself sits inside its arch, and its size. Ours is
/// taller than the 1984 game's (12 x 15, 16 rows down), so that the
/// explorer fits through. It's also the box he stands in front of.
pub const door_panel_dx: u8 = 4;
pub const door_panel_dy: u8 = 8;
pub const door_panel_width: u8 = 12;
pub const door_panel_height: u8 = 24;

/// A door: the arch (or the way out's), and in it the door itself, shut
/// or open. An object, too, for the explorer to stand in front of.
fn door(m: *Machine, r: castle.Record) void {
    const d = m.view(castle.Door, r.at);
    m.work(8); // the test
    place(m, if (d.exit != 0) .exit_frame else .door_frame, d.x, d.y);
    panel(m, r.at);
    const box: actors.Box = .{ .x = d.x +| door_panel_dx, .y = d.y +| door_panel_dy, .width = door_panel_width, .height = door_panel_height };
    const n = objects.add(m, .door, box, r.at) orelse return;
    const o = objects.slot(m, n);
    o.number = @intCast((r.at - doorAt(m, m.peek(map.room_number), 0).?) / @sizeOf(castle.Door));
    o.open = @intFromBool(d.side & castle.door_open != 0);
    m.work(20); // the sums and the stores
}

/// The door itself, from its record at `at`: shut, or open onto the colour
/// of the room beyond.
pub fn panel(m: *Machine, at: u16) void {
    const d = m.view(castle.Door, at);
    const x = d.x +| door_panel_dx;
    const y = d.y +| door_panel_dy;
    m.work(8); // the test and the sums
    if (d.side & castle.door_open != 0) {
        shapes.recolor(m, .door_open, roomColors(m, d.to_room));
        place(m, .door_open, x, y);
    } else {
        place(m, .door_shut, x, y);
    }
}

/// Wipe one row of a door's panel back to the background, as it swings
/// open: three bitmap bytes, the ones on the screen.
pub fn wipe(m: *Machine, x: u8, y: u8) void {
    const row = screen.rowAddress(m, y);
    var left = x;
    for (0..door_panel_width / 4) |_| {
        if (left >= castle.left_edge) m.poke(row + @as(u16, (left - castle.left_edge) / 4) * 8, 0);
        left += 4;
        m.work(10); // the test, the sums and the loop
    }
}
```

**`src/room.zig`** (replace `bell`)

```zig
/// A doorbell, in the colour of the room its door leads to. An object,
/// too: stand at it and press fire.
fn bell(m: *Machine, r: castle.Record) void {
    const b = m.view(castle.Bell, r.at);
    const at = doorAt(m, m.peek(map.room_number), b.door) orelse return;
    const d = m.view(castle.Door, at);
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    place(m, .bell, b.x, b.y);
    const shape = shapes.address(m, .bell);
    const box: actors.Box = .{ .x = b.x, .y = b.y, .width = m.peek(shape) * 4, .height = m.peek(shape + 1) };
    const n = objects.add(m, .bell, box, r.at) orelse return;
    objects.slot(m, n).number = b.door;
    m.work(20); // the sums and the stores
}
```

The door's box is its panel. That's the 1984 rule too, and 1984's panel
is 12 × 15, 16 rows down the arch; ours is 12 × 24, 8 rows down. So
`door_panel_dx`, `door_panel_dy`, `door_panel_width` and
`door_panel_height` now describe the box as well as the picture, and
everything about a door's geometry comes from those four names. A door's
`number` is how far its record is from the room's first door, in
8-byte steps; `.?` unwraps an optional that can't be `null` (this room
is drawing a door, so it has one), and stops the game if it ever is.
`panel` draws the door shut or open from its castle bit, both when the
room is prepared and when a door finishes opening. `wipe` clears one row
of it.

Last, the main loop runs the objects after the actors, in bucket 4:

**`src/main.zig`** (add below the `actors` import)

```zig
const objects = @import("objects.zig");
```

**`src/main.zig`** (add below `bucket_actors`)

```zig
const bucket_objects = 4;
```

**`src/main.zig`** (in the `.draw_room` branch, replace `room.draw(m);`)

```zig
            room.draw(m); // and its objects
```

**`src/main.zig`** (in the `.room` branch, add below `actors.step(m);`)

```zig
                m.bucket(bucket_objects);
                objects.step(m);
```

:::type-in The object table's tests
**`src/objects.zig`** (add at the end of the file)

```zig
// ---- tests ----------------------------------------------------------------

test "boxes overlap when any part of them does, edges included" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    const door: actors.Box = .{ .x = 160, .y = 168, .width = 12, .height = 24 };
    const at = struct {
        fn at(x: u8, y: u8) actors.Box {
            return .{ .x = x, .y = y, .width = 8, .height = 21 };
        }
    }.at;
    try std.testing.expect(overlap(m, at(162, 171), door)); // in the doorway
    try std.testing.expect(overlap(m, at(152, 171), door)); // his right edge on its left edge
    try std.testing.expect(overlap(m, at(172, 171), door)); // his left edge on its right edge
    try std.testing.expect(!overlap(m, at(151, 171), door)); // a fat pixel short
    try std.testing.expect(!overlap(m, at(173, 171), door));
    try std.testing.expect(!overlap(m, at(162, 107), door)); // on the walkway above
    try std.testing.expect(overlap(m, at(250, 171), .{ .x = 245, .y = 170, .width = 12, .height = 4 })); // no wrapping
}

test "the table has handlers for every kind, and add stops at 32" {
    try std.testing.expectEqual(std.meta.fields(Kind).len, kinds.len);
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    clear(m);
    for (0..slots) |i| try std.testing.expectEqual(@as(?u8, @intCast(i)), add(m, .bell, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, 0));
    try std.testing.expectEqual(@as(?u8, null), add(m, .bell, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, 0));
    try std.testing.expectEqual(slots, m.ram[map.engine_objects]);
}
```
:::

Build and run. Walk left to the bell and press fire. **The door opens!**
Its panel wipes away from the bottom up, a row a step, and when it's gone
the doorway shows the orange of the Long Gallery, the room it leads to. Push into it and nothing happens
yet: he hasn't learned to walk through.

## Through the door

How do you go through a door? Chapter 3's sign says "push up", and that
sign was wrong. The 1984 game wants the stick pushed **up and to the
right**, direction 1 on Chapter 4's compass, and nothing else: up alone
does nothing, on either wall. It's easy to remember once you've seen the
walk: he steps up and to the right into the doorway, five fat pixels
across and three rows up, as if the door were set back into the wall.

The walk is a table, one entry a turn: a step and a picture, or, at the
end, what he does next. He walks in seen from behind, in two new
pictures drawn narrow enough to stay inside the door's panel, and walks
out the same way, backwards, down and to the left, turning to face the
room on the last step. In and out, a turn is every third engine step, so
the walk takes a little under a second each way.

The explorer needs a status. Add it at the top of `player.zig`, with the
number of steps a room carries on after he's left it, and the walk:

**`src/player.zig`** (add above `feet_x`)

```zig
/// What he's doing, as far as the room is concerned.
pub const Status = enum(u8) {
    playing, // walking the room
    doorway, // walking into a door, or out of one
    gone, // through a door: the room is over
    dead, // flickering away: the room is over
    _,
};
```

**`src/player.zig`** (add below `door_y`, after a blank line)

```zig
/// How many engine steps the room runs on after he's gone or dead.
const ending_steps = 30;
```

`Status` ends in `_` for the same reason `Kind` does: it's read back out of
memory with `@enumFromInt`. The two back views go at the end of `Id`, as
new shapes always do, and here they are:

**`src/shapes.zig`** (in `Id`, add at the end, after `explorer_slide`)

```zig
    explorer_back_0,
    explorer_back_1,
```

**`src/art.zig`** (add above `// ---- pictures for the castle`)

```zig
/// Walking into a doorway, seen from behind: narrow, so that he fits
/// inside the door's panel, one boot lifted and then the other.
pub const explorer_back_0 = frame(.white, &.{
    ".33.....",
    ".33.....",
    "33333...",
    ".111....",
    ".111....",
    "..1.....",
    "22222...",
    "22222...",
    "22222...",
    "12221...",
    "12221...",
    "12221...",
    "13331...",
    ".222....",
    ".222....",
    ".2.2....",
    ".2.2....",
    ".2.3....",
    ".2.33...",
    ".3......",
    "33......",
});

pub const explorer_back_1 = frame(.white, &.{
    ".33.....",
    ".33.....",
    "33333...",
    ".111....",
    ".111....",
    "..1.....",
    "22222...",
    "22222...",
    "22222...",
    "12221...",
    "12221...",
    "12221...",
    "13331...",
    ".222....",
    ".222....",
    ".2.2....",
    ".2.2....",
    ".3.2....",
    "33.2....",
    "...3....",
    "...33...",
});
```

Then the walk:

**`src/player.zig`** (add below `step_y`, after a blank line)

```zig
/// Walking through a doorway, one entry a turn: a step and a picture, or,
/// at the end, what he does next.
const Walk = struct { dx: u8 = 0, dy: u8 = 0, frame: shapes.Id = .explorer_back_0, then: ?Status = null };
const doorway = [_]Walk{
    // In: five steps up and to the right, into the door, seen from behind.
    .{ .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .dx = 1, .dy = 0, .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .dx = 1, .dy = 0, .frame = .explorer_back_0 },
    .{ .dx = 1, .dy = 0xFF, .frame = .explorer_back_1 },
    .{ .then = .gone },
    // Out: the same five steps backwards, down and to the left, turning
    // to face the room on the last one.
    .{ .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_back_0 },
    .{ .dx = 0xFF, .dy = 0, .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_back_0 },
    .{ .dx = 0xFF, .dy = 0, .frame = .explorer_back_1 },
    .{ .dx = 0xFF, .dy = 1, .frame = .explorer_left_0 },
    .{ .then = .playing },
};
const walk_in = 0;
const walk_out = 7;

/// How far the walk in takes him: across and up. He arrives in a room
/// where a walk in ends, and the compiler checks the table agrees.
const walk_across = 5;
const walk_up = 3;
comptime {
    var x: u8 = 0;
    var y: u8 = 0;
    for (doorway[walk_in..walk_out]) |w| {
        x +%= w.dx;
        y +%= w.dy;
    }
    if (x != walk_across or y != 0 -% @as(u8, walk_up))
        @compileError("the doorway walk must go 5 across and 3 up");
}

/// The middle of the screen, in castle X.
const middle = castle.left_edge + 80;
```

`Walk`'s fields have defaults, so an entry names only what it needs, and
`then: ?Status = null` means "keep walking". The table is a `const`, part
of the program image, and it holds `shapes.Id`s and `Status`es, since
nothing but the compiled code ever reads it. (Only data in the Comet's
memory has to be all whole bytes.) The `comptime` block adds up the walk
in and checks it against `walk_across` and `walk_up`, which say where a
walk in ends; arriving through an open door starts him there.

A game starts in the castle's start room, by its start door:

**`src/player.zig`** (add below `start`)

```zig
/// A new game: the castle's start room and start door.
pub fn newGame(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
    m.poke(map.player_door, m.peek(castle.start_door));
}
```

Now `add` uses the door he came by, and if that door is open, he isn't
standing in front of it: he's inside, at the end of a walk in, and on
his way out.

**`src/player.zig`** (replace `add`)

```zig
/// Into the room, at the door he came by. If it's open he walks out of
/// it; if it's shut he starts in front of it. A room with no doors (the
/// final room) puts him in the middle of the floor.
pub fn add(m: *Machine) void {
    const n = actors.add(m, .player) orelse return; // he's the first in, so never
    m.poke(map.player_actor, n);
    m.poke(map.player_status, @intFromEnum(Status.playing));
    m.poke(map.engine_ending, 0);
    const a = actors.slot(m, n);
    a.box.x = middle;
    a.box.y = room.floor_top - feet_y;
    a.way = still;
    if (room.doorAt(m, m.peek(map.room_number), m.peek(map.player_door))) |at| {
        const d = m.view(castle.Door, at);
        a.box.x = d.x + door_x;
        a.box.y = d.y + door_y;
        if (d.side & castle.door_open != 0) {
            // Inside it, where a walk in ends, and on his way out.
            a.box.x += walk_across;
            a.box.y -= walk_up;
            a.walk = walk_out;
            a.pace = 3;
            m.poke(map.player_status, @intFromEnum(Status.doorway));
        }
    }
    m.work(40); // the sums and the stores
    actors.setFrame(m, n, if (a.box.x < middle) .explorer_right_0 else .explorer_left_0);
}
```

**`src/player.zig`** (add below `add`)

```zig
/// What he's doing.
fn status(m: *Machine) Status {
    return @enumFromInt(m.peek(map.player_status));
}

/// Is he walking the room?
pub fn playing(m: *Machine) bool {
    return status(m) == .playing;
}
```

`turn` learns the other statuses. A turn with `destroy` set is his last:
he marks himself `free` and is gone. Playing, he steers; in a doorway, he
walks:

**`src/player.zig`** (replace `turn`)

```zig
/// His turn, actor `n`'s: on every engine step while he walks the room,
/// every third in a doorway.
pub fn turn(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    if (a.state.destroy) { // his last turn: he's gone, or dead
        a.state.destroy = false;
        a.state.free = true;
        return;
    }
    a.state.created = false;
    read(m, a);
    switch (status(m)) {
        .playing => steer(m, n),
        .doorway => walk(m, n),
        else => {},
    }
}
```

**`src/player.zig`** (add below `waysAt`)

```zig
/// Into the door whose record is at `at`: he stands in front of it and
/// walks in, and when the room is over he'll come out of the door it
/// leads to.
pub fn walkIn(m: *Machine, n: u3, at: u16) void {
    if (!playing(m)) return;
    const a = actors.slot(m, n);
    const d = m.view(castle.Door, at);
    m.poke(map.player_status, @intFromEnum(Status.doorway));
    a.walk = walk_in;
    a.pace = 3;
    a.box.x = d.x + door_x;
    a.box.y = d.y + door_y;
    m.poke(map.room_number, d.to_room);
    m.poke(map.player_door, d.to_door);
    m.work(30); // the stores
}

/// A turn in a doorway: the next entry of the `doorway` table.
fn walk(m: *Machine, n: u3) void {
    const a = actors.slot(m, n);
    const w = doorway[a.walk];
    m.work(24); // the table read and the sums
    if (w.then) |then| {
        m.poke(map.player_status, @intFromEnum(then));
        a.pace = 1;
        if (then == .gone) a.state.destroy = true;
        return;
    }
    a.box.x +%= w.dx;
    a.box.y +%= w.dy;
    a.walk += 1;
    actors.setFrame(m, n, w.frame);
}

/// Is the room over? Not while he's playing or in a doorway. Once he's
/// gone through a door or died, it runs on for 30 more steps (a door
/// finishes opening, a flicker ends), and then it is.
pub fn roomOver(m: *Machine) bool {
    if (playing(m) or status(m) == .doorway) return false;
    const left = m.peek(map.engine_ending);
    m.work(10); // the tests
    if (left == 1) return true;
    m.poke(map.engine_ending, if (left == 0) ending_steps else left - 1);
    return false;
}
```

**`walkIn`** is called by the door. He snaps to his place in front of it,
starts the walk at its first entry, and slows to a turn every third step.
The room and the door are changed straight away to where the door leads,
because that's where he'll be when this room is over. **`walk`** takes one
entry a turn. At the end of the walk in, his status is `gone` and his
slot gets `destroy`; at the end of the walk out, he's `playing`.

**`roomOver`** decides when. Once he's gone through a door (or, coming
up, died), the room carries on for 30 more steps, a little over a second,
so that a door still opening finishes, and then it's over. The `0` in
`engine_ending` means "not ending", and `add` puts it back for each new
room.

The door gets its `in_front`, which checks it's open, that this is the
explorer, and that the stick says up and to the right:

**`src/doors.zig`** (add below `bell_reach`, after a blank line)

```zig
/// The stick's direction for walking into a door: up and to the right,
/// the way the walk goes.
const into_door = 1;
```

**`src/doors.zig`** (in `ring`, replace the first test)

```zig
    if (a.kind != .player or a.fire == 0 or !player.playing(m)) return;
```

**`src/doors.zig`** (replace the comment at the top)

```zig
//! Doors and doorbells at work: a bell rung, a door swinging open, and the
//! explorer walking through.
```

**`src/doors.zig`** (add at the end of the file)

```zig
/// A door's `in_front`: at an open door, the explorer pushes the stick up
/// and to the right, and walks in.
pub fn enter(m: *Machine, n: u8, who: u3) void {
    const o = objects.slot(m, n);
    const a = actors.slot(m, who);
    m.work(16); // the tests
    if (o.open == 0 or a.kind != .player or a.stick != into_door) return;
    player.walkIn(m, who, o.record);
}
```

**`src/objects.zig`** (in `kinds`, replace the door's entry)

```zig
    .door = .{ .execute = doors.open, .in_front = doors.enter },
```

`ring` now also checks that he's playing, so a bell can't ring while he's
walking through a doorway.

Delete `room.start`; `player.newGame` does its job now. N and P put him
in a room by its first door:

**`src/room.zig`** (in `flip`, add below the `room_number` line)

```zig
    m.poke(map.player_door, 0); // he comes in by its first door
```

**`src/main.zig`** (in the `.title` branch, replace `room.start(m);`)

```zig
                player.newGame(m);
```

When the room is over, the game prepares the next one, the room `walkIn`
chose:

**`src/main.zig`** (in the `.room` branch, add below `objects.step(m);`)

```zig
                m.bucket(0);
                if (player.roomOver(m)) setMode(m, .draw_room);
```

And the Gatehouse's sign gets the right instructions:

**`src/training.zig`** (in the `gatehouse` room, replace the last line of its text)

```zig
                "PUSH UP AND RIGHT.",
```

:::type-in The doors' tests
**`src/main.zig`** (add above `explorer`, near the end of the file)

```zig
test "a doorbell opens its door, on both sides of the wall" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0); // the Gatehouse: the door at x 156, its bell at x 140
    const door = objects.slot(m, 0);
    try std.testing.expectEqual(objects.Kind.door, door.kind);
    try std.testing.expectEqual(0, door.open);
    hold(m, machine.joy.left, 34); // 17 steps: feet at 148, under the bell
    try std.testing.expectEqual(145, explorer(m).box.x);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(1, door.open); // ringing
    try std.testing.expect(door.flags.execute);
    hold(m, 0, 60); // a row of the panel a step
    try std.testing.expect(!door.flags.execute);
    try std.testing.expect(m.view(castle.Door, room.doorAt(m, 0, 0).?).side & castle.door_open != 0);
    try std.testing.expect(m.view(castle.Door, room.doorAt(m, 1, 0).?).side & castle.door_open != 0); // the Gallery's side
}

test "fire held on the way to a bell is not a press" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    hold(m, machine.joy.left | machine.joy.fire, 34); // pressed far from the bell, then held
    hold(m, machine.joy.fire, 10);
    try std.testing.expectEqual(0, objects.slot(m, 0).open);
    hold(m, 0, 2);
    hold(m, machine.joy.fire, 4); // let go and pressed again, at the bell
    try std.testing.expectEqual(1, objects.slot(m, 0).open);
}

test "through the door and out of the one it leads to, and back again" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    hold(m, machine.joy.left, 34);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60); // back to the door, and wait for it
    hold(m, machine.joy.up, 4); // up alone isn't the way in
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(1, m.ram[map.room_number]); // the Long Gallery
    try std.testing.expectEqual(0, m.ram[map.player_door]); // by its door 0
    hold(m, 0, 160);
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    try std.testing.expectEqual(16 + 6, explorer(m).box.x); // walked out, in front of it
    try std.testing.expectEqual(160 + 11, explorer(m).box.y);

    // The way back is open already: the Gatehouse's door stays open.
    hold(m, machine.joy.up | machine.joy.right, 4);
    hold(m, 0, 160);
    try std.testing.expectEqual(0, m.ram[map.room_number]);
    try std.testing.expectEqual(1, objects.slot(m, 0).open);
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
}
```
:::

The tests ring the Gatehouse bell and check that the door opens on both
sides of the wall; that a fire button held across the room doesn't ring
the bell, and a press at the bell does; and that he goes through the door
into the Long Gallery, comes out of its door 0, and can walk straight back
through a door that's still open.

Build and run. Ring the bell, walk back to the door, and push up and to
the right:

![The Gatehouse: the explorer seen from behind, stepping up into the open doorway, with the orange of the next room around him](images/05-doorway.png)

He walks into the doorway and is gone, and a moment later the Long
Gallery appears with him walking out of its door. **You're in the next
room!** The Gallery's bell opens its far door, and so on, through the
whole castle. Every door you open stays open, so the way back is always
there. (The green door in The Way Out leads back into its own room for
now: Chapter 9 makes it the way out of the castle.)

:::inside-the-disk Up and to the right
The 1984 game stores the stick's direction in the explorer's record on
every turn, and a door's "stand in front of me" routine lets him in only
when that byte is 1: up and to the right. Every door, on either wall. The
walk is a 12-entry table, four bytes an entry (a step across, a step down,
a picture, and what to do next, `$FF` for "carry on"), and the walk out
starts halfway down it. The 1984 doorbell also isn't fussy about presses:
it's happy with fire *held*, because ringing an open door does nothing.
We use a press, as Chapter 1 promised, so that a held button never rings a
bell by accident.
:::

## Ding dong, you're dead

Nothing in the Training Castle can kill the explorer yet. Chapter 6 brings
the lightning, the trapdoors and the rest. But dying is the actor table's
business, not the lightning's, so the engine learns it now.

The 1984 game has a key that kills you on purpose, for when you've
trapped yourself: you lose a life and start again. Ours is **X**, for
crossing out a life (not K: that's joystick 2's down, and none of the
switches use a joystick key). Here's the whole lifecycle, and every step
after the first is a flag in the actor's state byte:

```
  (alive) ──X──► flash ──► dying: 8 flashes, white / black ──► destroy ──► free ──► unused
                                                              (last turn)  (end of step)
```

`flash` says "start dying". The engine turns it into `dying`, gives the
actor eight flashes, and makes it flicker: white on every other step,
black in between, and in a single colour, because a dying sprite is shown
without its multicolour. When the flashes run out it's `destroy`, then
`free`, then an empty slot. The explorer's status says `dead`, so the room
ends 30 steps later, and the game takes a life and starts him again **at
the castle's start door**. That's how 1984 does it: dying sends you back
to the beginning of the castle, though every door you opened stays open.

The actor side first. Whether a kind flickers or vanishes on the spot is
part of its behaviour:

**`src/actors.zig`** (add below the `Machine` import)

```zig
const Color = machine.Color;
```

**`src/actors.zig`** (replace `Behaviour` and `kinds`, and the comment above `Behaviour`)

```zig
/// What each kind does: the function that takes its turn, and whether it
/// flickers when it dies or vanishes on the spot.
const Behaviour = struct {
    turn: *const fn (m: *Machine, n: u3) void,
    flickers: bool,
};

/// One entry for every kind, found by number. The compiler won't build
/// the table with a kind missing.
const kinds = std.enums.directEnumArray(Kind, Behaviour, 0, .{
    .player = .{ .turn = player.turn, .flickers = true },
});
```

**`src/actors.zig`** (in `step`, replace the `else` branch)

```zig
        } else if (a.state.flash or a.state.dying) {
            flicker(m, n);
        } else {
            a.countdown -= 1;
            if (a.countdown != 0) continue;
            if (a.state.hit_bitmap) objects.touching(m, n);
            if (!a.state.flash) kinds[@intFromEnum(a.kind)].turn(m, n);
        }
```

**`src/actors.zig`** (add below `step`)

```zig
/// Dying: flash white on every other step and black in between, eight
/// times, then take a last turn. A kind that doesn't flicker goes at once.
fn flicker(m: *Machine, n: u3) void {
    const a = slot(m, n);
    m.work(20); // the tests
    if (a.state.flash) {
        a.state.flash = false;
        if (!kinds[@intFromEnum(a.kind)].flickers) {
            a.state.destroy = true;
            return;
        }
        a.state.dying = true;
        a.flashes = 8;
        a.pace = 1;
    } else if (a.flashes == 0) {
        a.state.dying = false;
        a.state.destroy = true;
        return;
    }
    // A step every other frame, so bit 1 of the tick flips every step.
    if (m.peek(map.game_tick) & 0b10 == 0) {
        a.color = @intFromEnum(Color.white);
        a.flashes -= 1;
    } else {
        a.color = @intFromEnum(Color.black);
    }
}
```

**`src/actors.zig`** (in `show`, replace the `unused` test, and the `multicolor` line four lines down)

```zig
        if (a.state.unused or a.state.destroy) continue; // gone, or going
        const n: u3 = @intCast(i);
        const bit = @as(u8, 1) << n;
        on |= bit;
        if (!a.state.dying) multicolor |= bit; // dying, it flickers in one colour
```

`flicker` runs in place of a turn for as long as the actor is dying.
`show` leaves out an actor marked `destroy`, so the explorer doesn't
reappear in full colour for the step between his last flash and his
slot's emptying. (If touching an object sets an actor's `flash`, as Chapter 6's trapdoors
will, it skips its turn that step and starts to flicker on the next.)

Now the explorer: lives at the start of a game, a way to die, and the
decision after the room.

**`src/player.zig`** (in `newGame`, add at the end, and replace the comment above it)

```zig
/// A new game: the castle's start room and start door, and its lives.
pub fn newGame(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
    m.poke(map.player_door, m.peek(castle.start_door));
    m.poke(map.player_lives, m.peek(castle.lives));
}
```

**`src/player.zig`** (add below `walk`)

```zig
/// Give up this life (the X key): he flickers away, and the castle starts
/// him again at its start door.
pub fn kill(m: *Machine) void {
    if (!playing(m)) return;
    m.poke(map.player_status, @intFromEnum(Status.dead));
    actors.slot(m, @intCast(m.peek(map.player_actor))).state.flash = true;
}
```

**`src/player.zig`** (add below `roomOver`)

```zig
/// After the room, where to? Through a door, the room and the door are set
/// already. Dead, he loses a life and starts again at the castle's start.
/// False if that was his last life: the game is over.
pub fn nextRoom(m: *Machine) bool {
    if (status(m) != .dead) return true;
    const lives = m.peek(map.player_lives) -| 1;
    m.poke(map.player_lives, lives);
    if (lives == 0) return false;
    m.poke(map.room_number, m.peek(castle.start_room));
    m.poke(map.player_door, m.peek(castle.start_door));
    return true;
}
```

`-|` is Chapter 4's saturating subtract, so lives can't wrap round to
255. When the last one goes, `nextRoom` says no, and the game goes back to
the title screen. That's a minimal game over; Chapter 9 gives it the
words, and gives every new game a fresh copy of the castle (for now, the
doors you opened are still open in the next game).

**`src/main.zig`** (in the `.room` branch, replace the `roomOver` line)

```zig
                if (player.roomOver(m)) setMode(m, if (player.nextRoom(m)) .draw_room else .draw_title);
```

The X key goes in `debug.keys` with the others:

**`src/debug.zig`** (add below the `grid` import)

```zig
const player = @import("player.zig");
```

**`src/debug.zig`** (replace `keys`)

```zig
/// G or Q on the keyboard flips its switch, and X kills the explorer. True
/// if the room needs drawing again (the grid view does; the others don't).
pub fn keys(m: *Machine) bool {
    const key = m.peek(hw.key);
    const flag = switch (key) {
        'G' => map.debug_grid,
        'Q' => map.debug_search,
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
```

:::type-in Dying's test
**`src/main.zig`** (add above `explorer`)

```zig
test "X: a flicker, a life lost, back to the start; no lives left, the title" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2); // the Ladders room
    try std.testing.expectEqual(3, m.ram[map.player_lives]);
    m.input = .{ .key = 'X' };
    _ = m.runFrame(@This());
    m.input = .{};
    hold(m, 0, 8);
    try std.testing.expect(explorer(m).state.dying);
    try std.testing.expectEqual(0, m.ram[hw.sprite_multicolor] & 1); // one colour while he flickers
    hold(m, 0, 100);
    try std.testing.expectEqual(2, m.ram[map.player_lives]);
    try std.testing.expectEqual(0, m.ram[map.room_number]); // the castle's start
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
    for (0..2) |_| {
        m.input = .{ .key = 'X' };
        _ = m.runFrame(@This());
        m.input = .{};
        hold(m, 0, 100);
    }
    try std.testing.expectEqual(0, m.ram[map.player_lives]);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);
}
```
:::

Build and run, go a few rooms in, and press X:

![The Lightning room: the explorer at the door he came in by, flashing white, flat and in one colour, partway through flickering away](images/05-flicker.png)

He flickers and is gone, and a moment later he walks out of the
Gatehouse door. Three Xs in a row and it's the title screen.

## What the first pass saves

How much did the VIDEO chip's collision bits save? Let's turn them off
and find out. A third debug switch, **C**, makes every actor check every
object on every turn, touching or not:

**`src/map.zig`** (replace the `debug` region's comment and first line, and add a third switch)

```zig
/// Three switches for looking inside the game (debug.zig): 0 off, 1 on.
pub const debug = Region{ .name = "debug", .first = 0x020A, .last = 0x020C };
pub const debug_grid = debug.first + 0; // G: draw the navigation grid over the room
pub const debug_search = debug.first + 1; // Q: search the castle instead of reading the grid
pub const debug_scan = debug.first + 2; // C: check every object for every actor, every turn
```

**`src/debug.zig`** (replace the comment at the top)

```zig
//! Switches for looking inside the game. G draws the navigation grid over
//! the room; Q makes the explorer search the castle for his way instead
//! of reading the grid, and C makes every actor check every object on
//! every turn, so the meter can show what those cost. X gives up a life.
```

**`src/debug.zig`** (replace `keys`)

```zig
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
```

**`src/actors.zig`** (in `step`, replace the `touching` line)

```zig
            if (a.state.hit_bitmap or m.peek(map.debug_scan) != 0) objects.touching(m, n);
```

:::widget toggle
The C switch, live, with buckets 3 (actors) and 4 (objects) of the budget
meter beside it.
:::

Stand the explorer on a bare stretch of the Gatehouse floor, away from
the door and the bell, and watch
bucket 3. An engine step costs 246 cycles; press C and it's 354. The
Gatehouse has two objects, the door and the bell, so that's 54 cycles an
object, for an explorer who isn't touching either. It doesn't sound like
much, and in this room it isn't. Now fill the room the way a real castle
does: 8 actors and 32 objects, every actor testing every object, every
step. That's 8 × 32 × 54 = 13,824 cycles, seven tenths of the frame,
spent finding out that nobody is standing in front of anything.
With the first pass, an actor on open floor doesn't look at the objects
at all. Only an actor touching the room's foreground pays for the box
tests, and only on the steps it's touching.

The objects' execute flags are the same idea from the other side. Each
idle object costs one bit test, 12 cycles, in `objects.step`. The two
objects in the Gatehouse cost 28 cycles a step between them, and a full
table of 32 would cost about 390. If every object were called every step
to decide for itself whether it had anything to do, the room would pay
for a call and a look at its state for every door that's been standing
still since the castle was built.

:::power-up The Only-If-Asked Power-Up
Don't visit everything to find the few things that need you. Let the
things that need you say so: a hardware bit that's set when a sprite
touched something, a flag an object raises when it has work. Then a full
room costs what its busy parts cost, and the idle ones are free.
:::

:::byte-budget Chapter 5
**Memory.** The actor table is **128 bytes** at `$BD00–$BD7F` and the
object table **512 bytes** at `$BE00–$BFFF`, both fixed for good. The
`player` region shrank from seven bytes to five, the debug region grew by
one, and the engine region is two. The handler tables and the doorway
walk live in the program image: the two `kinds` tables hold a few function
pointers, the preparers' table 18. The Training Castle grew by 10 bytes,
to 4,333, for the Gatehouse's longer last line, and the shape table by
94 bytes, to 2,045, for the two back views.

**Time.** Preparing a room now also fills the object table: the rooms
take 143,106 to 236,478 cycles to prepare. That's 13 frame slots at
worst, one more than Chapter 4: the Gatehouse's longer sign tipped it
over. In play, a frame with no engine step costs 170 cycles, and one with
a step 448 standing still, about 1,200 with a change of picture. A door
opening costs about 75 cycles a step to wipe a row (400 on the first
step, which opens both doors in the castle) and 2,100 on the step it's
drawn open.
:::

:::game-over Common mistakes
- **`error: missing struct field`** from `directEnumArray`. A kind has no
  entry in its table. Add one (`later` will do, for a castle kind that
  has nothing to prepare yet).
- **The bell rings as he walks up to it.** Something other than `read`
  writes `player_last_stick`, or `read` isn't called on every turn. Keep
  the stick byte's one store in `read`.
- **He walks to the door and stands there.** Up alone doesn't take him
  through it: push up and to the right. If it still won't, check the door's
  `in_front` entry in `objects.kinds` is `doors.enter`, not `null`.
- **Nothing in the room reacts to him.** `actors.step` reads the
  collision registers, and they're only set while the display is on and
  the sprites are enabled. Check `actors.show` runs at the top of the
  `.room` branch.
- **The door opens, and the next room's door is shut.** `open` must set
  the open bit on the door it leads to as well, through `room.doorAt`.
- **He reappears in colour for a moment before he vanishes.** `show`
  needs to leave out actors marked `destroy`.
- **`error: local constant shadows declaration of 'objects'`.** A local
  variable named like an import. Zig doesn't let names shadow each other;
  rename the local, as the grid test did with `stream`.
:::

:::boss-battle Ring, walk, and die
From your project folder:

```
zig build
zig build test
zig build run -- --frames 2300 --press 20:f:5 --press 60:l:34 --press 100:f:5 --press 160:r:20 --press 200:ur:10 --press 350:r:180 --press 540:f:5 --press 600:r:40 --press 650:ur:10 --press 840:r:176 --press 1020:u:80 --press 1100:r:60 --press 1165:f:5 --press 1220:r:30 --press 1255:ur:10 --press 1500:r:96 --press 1600:d:70 --press 1675:r:140 --press 1820:f:5 --press 1880:r:30 --press 1915:ur:10 --key 2150:X --dump-every 10
```

The run presses fire on the title and rings the Gatehouse bell, walks
through its door into the Long Gallery, rings that bell and goes through
to the Ladders room, climbs to the upper door and goes through to Sliding
Poles, slides down and goes on into the Lightning room, and there presses
X. It prints:

```
ran 2300 frames (2227 calls to frame)
cycles: max 236824 (1204%), avg 1125 (5%) of 19656
  bucket 0: max 78, avg 27
  bucket 1: max 235548, avg 702
  bucket 2: max 1260, avg 141
  bucket 3: max 1074, avg 227
  bucket 4: max 2124, avg 26
overruns: 0, loading pauses: 7
last frame: frames/frame_02299.ppm
```

`frame_00120.ppm` has the Gatehouse door half open (the picture at the top
of the chapter), `frame_00230.ppm` the explorer walking into it,
`frame_00800.ppm` him walking out of the Ladders room's door, and
`frame_02170.ppm` him flickering in the Lightning room. By `frame_02290.ppm`
he's walking out of the Gatehouse door again, two lives left.

Then play it:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000>, press Space, and explore: arrows to walk
and climb, Space to ring a bell, up and right at an open door, X to give
up a life, C to switch off the first pass, and N, P, G and Q as before.

**The castle is open!** Every door in the Training Castle opens with its
bell, and every room is a walk away from the last. The rooms in the
middle of the castle are still empty of their machines and monsters.
Next chapter, the switches and the machines move in.
:::

:::warp-zone
The finished checkpoint is [`code/ch05/`](../code/ch05/), also as a
download, [`ch05.zip`](downloads/ch05.zip), which unzips into the same
`code/` folder as the others. To start Chapter 6 from a known-good game,
replace your project with it:

```
cd code
rm -rf my-creep
cp -r ch05 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```
:::

:::bonus-stage
- **Further in.** 1984 walks the explorer into a doorway in six
  pictures. Draw four more back views, smaller and smaller, and give the
  `doorway` table one per step.
- **A room of doors.** Add a room with three doors, two of them leading to
  each other inside the room, and a bell for each. Walk in circles.
- **A meter of your own.** Count, in a spare byte, how many box tests ran
  in the last step, and draw it on the screen. Watch it with C on and off.
- **Faster doors.** Wipe two rows a step, which is about 1984's speed,
  and decide which you like better.
:::
