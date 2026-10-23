---
chapter: 3
title: "Haunted Blueprints"
checkpoint: ch03
---

:::mission-briefing
By the end of this chapter the Comet 64 holds a whole castle: the
**Training Castle**, twenty rooms and a prize room in 4,324 bytes. Press
fire on the title screen and you're standing in its Gatehouse, with a
door, a doorbell and a word of welcome on the wall. Press **N** on the
keyboard and the screen goes dark for a moment and comes back as the next
room; **P** takes you back.

![The Gatehouse: the title THE GATEHOUSE in tall yellow letters, eight lines of instructions, a red brick floor, an orange doorbell and a stone arch with a wooden door on the right](images/03-gatehouse.png)

Nothing in those rooms is placed by code. Every walkway, ladder, pole,
door, bell and line of text is read out of the castle file, in the same
format the 1984 disk uses, down to the last byte. You'll design that
file, write the loader that walks it, and then build a small language
for writing castles: Zig declarations that the compiler turns into castle
bytes, and refuses to build if a door leads nowhere or a line of text
runs off the screen.

New under the hood: **structs and how their fields sit in memory**,
**two-byte values, low byte first**, **variable-length data ended by
sentinel bytes**, and **`comptime`, taken apart properly**.
:::

## The castle is the level

Think about what a castle disk gives you: fourteen castles, each one a
different maze with different machines in different places, and one
program that plays them all. Nobody wrote fourteen programs. They wrote
one engine and fourteen castles, and a castle isn't code at all. It's a
few thousand bytes of description: *a red room; a walkway along the
bottom, forty pieces long; a door on the right that leads to room 1.*

That's the big idea of this chapter, and maybe of the whole game: **data
is the program**. The engine knows how to draw a ladder. The castle says
where the ladders go. Change the bytes and you have a different game,
without touching a line of code. Chapter 2 drew the Entrance Hall with a
list of `drawShape` calls. By the end of this one, `room.zig` won't know
a single room by heart.

:::under-the-hood A level in JSON
In a JavaScript game you'd keep the castle in a file like this:

```js
{ "rooms": [ { "color": "red",
               "doors": [ { "x": 156, "y": 160, "to": "gallery" } ],
               "walkways": [ { "length": 40, "x": 16, "y": 192 } ] } ] }
```

and `JSON.parse` it into objects. It reads well. Here's what it costs.
The Training Castle written out that way, every field named, is about
21,000 bytes of text, a third of the Comet 64's memory before anything
has been parsed. Parsing it builds a tree of objects, each its own heap
allocation with a hidden header, and every name in it (`"color"`,
`"doors"`) is spelled out again in every room.

The castle file says the same things in 4,324 bytes and contains no names
at all: where a byte sits says what it means. The game never parses it.
It reads the bytes where they lie, and each record is already in the
shape the drawing code wants.
:::

## Room for a castle

The castle lives in its own 8 KB region from `$7800`, the start of the
free memory above the program image. The game also has to remember which
room is on screen, one byte. And the text region grows: castle text can be
two or three times the usual height (you'll see why later), so the scratch
shape each letter is built in grows from 23 bytes to 63, and the string
buffer moves up to make room.

**`src/map.zig`** (add below the `game` region)

```zig
/// The room on screen.
pub const room = Region{ .name = "room", .first = 0x0208, .last = 0x0208 };
pub const room_number = room.first + 0; // its place in the castle's room directory
```

**`src/map.zig`** (replace the `text` region's comment and first four lines)

```zig
/// Text: a lookup table, the shape each letter is built in, and a string.
pub const text = Region{ .name = "text", .first = 0x0300, .last = 0x037F };
pub const text_widen = text.first + 0x00; // 16 bytes: 4 glyph bits -> 4 fat pixels
pub const text_glyph = text.first + 0x10; // one letter, up to 2x24: 63 bytes
pub const text_buffer = text.first + 0x50; // a string to print
```

**`src/map.zig`** (add above the row table)

```zig
/// The castle: its header, its room directory and every room's objects,
/// exactly as the castle file holds them.
pub const castle = Region{ .name = "castle", .first = 0x7800, .last = 0x97FF };
```

**`src/map.zig`** (replace `regions`)

```zig
/// The whole map, in address order.
pub const regions = [_]Region{
    stack,
    player,
    game,
    room,
    text,
    program,
    stars,
    shape_table,
    castle,
    row_table,
    sprite_frames,
    screen_plane,
    sprite_pointers,
    video_chip,
    color_ram,
    input_ports,
    bitmap,
};
```

The overlap check now guards seventeen regions. `zig build` still gives
you Chapter 2's game, since nothing it used has moved except the text
buffer, and `text.zig` finds that through its name.

## The header: 256 bytes and a magic number

A castle file starts with a **header**, 256 bytes at `$7800`, and most of
it is empty on the disk. Only a few fields are set:

| Offset | Bytes | What |
|---|---|---|
| `$00` | 2 | the castle's size in bytes, header included |
| `$02` | 1 | `$80`, which says "this is a castle" |
| `$03` | 2 | the room each player starts in (player 1, then player 2) |
| `$05` | 2 | the door each player starts at |
| `$07` | 2 | each player's lives |
| `$5F` | 2 | where the final room's objects are, or 0 if there's no final room |

The rest is spare. While you play, the game keeps its notes in those
bytes (which room each player is in, the clock, the keys they carry),
which is why the file reserves a whole page for a header that needs a
dozen bytes. Chapter 9 moves in.

### Low byte first

Three of those fields are two bytes long, and Chapter 2 left you a
promise: "two-byte values on the Comet go low byte first; Chapter 3 says
why." A castle of `$0154` bytes stores its size like this:

```
  address:   $7800   $7801
  byte:       $54     $01        $01 × 256 + $54 = $0154 = 340
              low     high
```

This is called **little-endian**: the little end goes first. It looks
backwards to a human, who writes the big digits on the left. It's the
natural order for the Comet's processor, though, which handles one byte
at a time. Think about how you add two long numbers on paper: you start
from the right-hand column and carry leftwards. The processor does the
same thing with addresses. When it works out "this address plus 3", it
adds 3 to the low byte first, then carries into the high byte. If the
low byte arrives first, it can start adding while the high byte is still
on its way. So every two-byte value in this machine, every address in
every table and every castle, goes low byte first, and `m.peek16` puts
the two halves back together for you: `peek(a) | peek(a + 1) << 8`.

## The room directory

Right after the header, at `$7900`, comes the **room directory**: 8 bytes
for each room, room 0 first, so room *n*'s entry is at `$7900 + n × 8`.

```
     +0       +1      +2      +3      +4  +5        +6  +7
  ┌────────┬───────┬───────┬───────┬───────────┬───────────┐
  │ colour │ map x │ map y │ size  │   skip    │  objects  │
  └────────┴───────┴───────┴───────┴───────────┴───────────┘
```

- **Colour.** The low four bits are the room's colour. Bit 6 means
  something else entirely, as you'll see in a moment.
- **Map x, map y, size.** Where the room sits on the castle map that
  Chapter 9 draws, and how big it is there. The size byte holds two
  numbers at once, packed the way Chapter 2 packed two colours into a
  screen-plane byte: bits 3–5 are the width and bits 0–2 the height, in
  map cells.
- **Skip.** Two bytes nothing reads. (There's a story in them; see the
  end of the chapter.)
- **Objects.** The address of this room's objects, two bytes, low byte
  first. This is the field that matters most: everything in the room
  hangs off it.

How does the game know how many rooms there are? There's no count
anywhere. Instead, the byte after the last entry has **bit 6 set**, and
no room's colour byte ever does. (While you play, the game sets bit 7 of
a room's colour byte when you've visited it, for the map, so bit 7 is
taken.) The end byte is `$40` if the castle has a final room and `$FF` if
it doesn't. It's the same trick as Chapter 2's strings, whose last letter
carries bit 7: a **sentinel**, a value that means "stop here", tucked into
a bit the data never uses.

### A struct is a row of bytes

Here's where Zig gets to describe those 8 bytes for us. In JavaScript you
might write

```js
const entry = { color: 2, mapX: 56, mapY: 48, size: 0x23, objects: 0x7909 };
```

and that object lives wherever the engine puts it, with a hidden header
in front, its fields in whatever order the engine likes, and each number
taking 8 bytes. You can't lay it over a run of memory and read the bytes
underneath, because it isn't bytes; it's a pointer to a heap allocation
(Chapter 2's "a JavaScript reference vs. an address").

A Zig **`extern struct`** is the other thing: its fields, in the order you
wrote them, with nothing in front and nothing in between. Declare the
entry as one, and `@sizeOf(Entry)` is 8, `@offsetOf(Entry, "objects")` is
6, and the struct *is* the format. Then `m.view(Entry, address)`, from the
reference card's section 9, hands you a typed pointer straight into
memory: Chapter 2's pointer, an address, with a type attached so that
`entry.color` means "the byte at that address" and `entry.map_y` "the
byte two after it".

For the size byte, Zig can do Chapter 2's shifting and masking for us. A
**`packed struct(u8)`** is a byte cut into bit fields, listed from bit 0
up, so `size.width` reads bits 3–5 and `size.height` bits 0–2.

:::game-over Why not `objects: u16`?
The obvious way to write a two-byte field is a `u16`. Try it on a record
whose word follows a single byte:

```zig snippet
const Squeezed = extern struct { color: u8, objects: u16 };
// ... m.view(Squeezed, at) ...
```

```
error: m.view(room.Squeezed): field room.Squeezed.objects would start at byte 2, but the fields before it only fill 1: Zig inserts padding to align a u16. Use [2]u8 for it (and m.peek16), or move it
```

Zig keeps every `u16` on an even byte (its **alignment**), so it slips a
hidden padding byte in after `color`, and the struct no longer matches the
bytes in memory. The Comet's processor doesn't care where a two-byte value
starts, but Zig's `u16` does, and the castle format packs its bytes in
tight, wherever they fall: the header's final-room word sits at `$5F`, an
odd offset. The machine refuses any view type whose bytes don't line up,
with that explanation, so you find out at compile time instead of reading
garbage. Castle words are `[2]u8` in our structs, read with `m.peek16`.
:::

Here's the start of the castle module: the header, and the directory.

**`src/castle.zig`** (new file)

```zig
//! The castle file, byte for byte as the 1984 disk lays it out: a
//! 256-byte header at $7800, a room directory at $7900 (8 bytes a room),
//! then each room's objects as a stream of tagged records.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const map = @import("map.zig");

// ---- the header -----------------------------------------------------------

pub const header = map.castle.first;
pub const header_size = 0x100;
pub const size = header + 0x00; // 2 bytes: the castle's length, header included
pub const magic = header + 0x02; // always $80: "this is a castle"
pub const start_room = header + 0x03; // player 1, then player 2
pub const start_door = header + 0x05; // player 1, then player 2
pub const lives = header + 0x07; // player 1, then player 2
pub const final_room = header + 0x5F; // 2 bytes: the final room's objects, or 0
pub const magic_value: u8 = 0x80;

// ---- the room directory ---------------------------------------------------

pub const directory = header + header_size; // $7900
pub const max_rooms = 31; // so the directory and its end byte fit in one page

/// One room's entry in the directory: 8 bytes.
pub const Entry = extern struct {
    color: u8, // low four bits: the room's colour. Bit 6 set: the end.
    map_x: u8, // where the room sits on the castle map
    map_y: u8,
    size: Size, // how big it is there
    skip: [2]u8, // nothing reads these two
    objects: [2]u8, // where its object stream starts, low byte first
};

/// A room's size on the castle map, in map cells: two 3-bit numbers in a byte.
pub const Size = packed struct(u8) {
    height: u3, // bits 0-2: cells of 8 rows
    width: u3, // bits 3-5: cells of 4 fat pixels
    unused: u2 = 0,
};

/// Bit 6 of a colour byte ends the directory. The end byte is $40 when
/// the castle has a final room and $FF when it doesn't.
pub const end_flag: u8 = 0b0100_0000;
pub const end_with_final: u8 = 0x40;
pub const end_plain: u8 = 0xFF;

/// The address of room `n`'s directory entry.
pub fn entry(m: *Machine, n: u8) u16 {
    m.work(6); // n * 8 is three shifts
    return directory + @as(u16, n) * @sizeOf(Entry);
}

/// How many rooms the directory lists.
pub fn roomCount(m: *Machine) u8 {
    var n: u8 = 0;
    while (m.peek(entry(m, n)) & end_flag == 0) n += 1;
    return n;
}
```

`entry` is the multiply-free sum from the diagram (`n × 8` is three
shifts), and `roomCount` walks the directory until it finds the bit-6
sentinel. `max_rooms` is our own limit, not the 1984 game's: 31 rooms and the end
byte fit in the page from `$7900`, so room *n*'s entry is always `$7900`
plus a single byte.

:::widget hex-inspector
The Training Castle's header and directory as hex. Hover over a byte to
see its field (size, magic, start room, colour, map x, objects...) and its
value decoded; hovering an `objects` word highlights the stream it points
to.
:::

## A castle typed by hand

Before we write any tools, let's make a castle the hard way, so you know
exactly what the tools are saving you. Here's Chapter 2's Entrance Hall
as a castle file. The header and directory are as above; the room's
objects (`hall`) are the next section's subject, so for now trust that
they describe the hall's doors, walkways, ladder, pole, a doorbell and its
title.

**`src/training.zig`** (new file)

```zig
//! The Training Castle, typed in by hand: one room, the Entrance Hall
//! from Chapter 2, as castle bytes.

/// The whole castle file, ready to load at $7800.
pub const bytes = &(header ++ directory ++ hall);

const header = [_]u8{
    0x54, 0x01, // the castle is $0154 bytes long, header and all
    0x80, // "this is a castle"
    0, 0, // both players start in room 0...
    0, 0, // ...at its door 0...
    3, 3, // ...with three lives each
} ++ [_]u8{0} ** (0x5F - 9) ++ [_]u8{ 0x00, 0x00 } // $785F: no final room
++ [_]u8{0} ** (0x100 - 0x61);

const directory = [_]u8{
    0x02, // red, and bit 6 is clear: this is a room, not the end
    56, 48, // its place on the castle map
    0b00_100_011, // 4 map cells wide, 3 tall
    0x0B, 0x79, // skip: $790B
    0x09, 0x79, // its objects start at $7909, right after the end byte
    0xFF, // the end of the directory, and no final room
};

/// The Entrance Hall's objects.
const hall = [_]u8{
    0x03, 0x08, 2, // doors: two of them
    32, 40, 3, 0, 1, 0, 16, 0, // upper left, leading to door 1
    152, 96, 1, 0, 0, 0, 16, 0, // middle right, leading to door 0
    0x06, 0x08, // walkways
    15, 24, 72, // upper left
    17, 108, 128, // middle right
    40, 16, 192, // the floor
    0, // no more walkways
    0x09, 0x08, 16, 64, 72, 0, // one sliding pole
    0x0C, 0x08, 9, 120, 128, 0, // one ladder
    0x0F, 0x08, 1, 136, 104, 1, // one doorbell, for door 1
    0x33, 0x08, 28, 8, 15, 0x21, // text at (28, 8), light grey, plain
} ++ "THE ENTRANCE HAL".* ++ [_]u8{
    'L' | 0x80, // the last letter has bit 7 set
    0, // no more text
    0x00, 0x00, // the end of the room
};
```

Count along with the comments. The directory has one entry and then the
end byte, so it covers `$7900` to `$7908`, and the hall's objects start
at `$7909`, written `09 79`. The hall is 75 bytes, so the castle is
256 + 9 + 75 = 340 bytes, `$0154`, written `54 01`. Change the hall by a
single byte and that size is wrong, and nothing tells you. Hold that
thought.

Boot copies the castle into its region:

**`src/main.zig`** (add below the `player` import)

```zig
const training = @import("training.zig");
```

**`src/main.zig`** (in `boot`, add after the star map's `m.load`)

```zig
    m.load(map.castle.first, training.bytes);
```

The floor pieces get new pictures this chapter (and there are doors,
bells and a prize to come), so copy the new `art.zig` from the Warp Zone
checkpoint (`code/ch03/src/art.zig`) over yours. The walkway now looks
like this:

```zig snippet
/// Floors, ladders and poles share colours, so they can cross each other
/// without fighting over a cell. Codes 01 and 10 take the room's colour
/// when a room is drawn; code 11 stays light grey.
const stone = [3]Color{ .brown, .pink, .light_grey };

pub const walkway = room(stone, &.{
    "3333",
    "111.",
    "111.",
    "....",
    "1.11",
    "1.11",
    "3333",
});
```

Its bricks are all code 01 and its mortar is code 00, the background.
That's because of how a room gets its colour, which is our next trick.

### One colour per room

The directory gives each room one colour byte, and every walkway, ladder
and pole in the room takes that colour. The castle doesn't store a colour
per walkway, and the drawing code doesn't take a colour parameter. Instead,
right before a room is drawn, the game **repaints the floor pieces in the
shape table itself**. A walkway piece's screen-plane bytes say what colour
codes 01 and 10 are (Chapter 2's shape format); write the room's colour
into both halves of those bytes, and every walkway drawn afterwards comes
out in that colour. Ladders and poles get the same paint, so where one
crosses a walkway, its cells still agree with the bricks. This is exactly
how the 1984 game does it: the shape table is memory like everything
else, so the room changes the pictures instead of the pictures taking
orders.

**`src/shapes.zig`** (add below `address`)

```zig
/// Repaint room shape `id`: every one of its screen-plane bytes becomes
/// `colors`, the two colours for codes 01 and 10.
pub fn recolor(m: *Machine, id: Id, colors: u8) void {
    const at = address(m, id);
    const width = m.peek(at);
    const height = m.peek(at + 1);
    const pixels = m.mul8(width, height);
    const cells = m.mul8(width, (height + 7) / 8);
    m.fill(at + 3 + pixels, cells, colors);
}
```

`recolor` finds the shape's screen-plane bytes (past the 3-byte header
and `width × height` pixel bytes) and fills them. It uses `m.mul8` twice,
honestly charged at 120 cycles each, because it runs once per piece per
room, not per frame.

Now `room.zig` reads room 0's colour from the directory and paints with
it before drawing the hall it already knows:

**`src/room.zig`** (replace the imports)

```zig
const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
```

**`src/room.zig`** (in `draw`, add after `screen.clear(m);`)

```zig
    paint(m, roomColors(m, 0)); // room 0's colour, from the directory
```

**`src/room.zig`** (add at the end of the file)

```zig
/// One colour per room, not per walkway: before drawing, repaint the
/// floor pieces in the shape table itself.
fn paint(m: *Machine, colors: u8) void {
    for ([_]shapes.Id{ .walkway, .walkway_left, .walkway_right, .ladder, .pole }) |id| {
        shapes.recolor(m, id, colors);
    }
}

/// Room `n`'s colour from its directory entry, for both codes 01 and 10.
fn roomColors(m: *Machine, n: u8) u8 {
    return both(m.peek(castle.entry(m, n)) & 0x0F);
}

/// One colour in both halves of a screen-plane byte.
fn both(color: u8) u8 {
    return color << 4 | color;
}
```

`both` puts a colour in both halves of a byte, high nibble for code 01
and low for code 10, so either code paints in the room's colour. Build,
press fire, and the hall's bricks are red: the castle file said so.
Everything else in the room is still Chapter 2's hand-placed code. Time
to read the rest.

## Streams of tagged objects

A room's objects are a **stream**: groups of records, one group per kind
of object, each introduced by a two-byte **tag** that says what kind
follows. Here's the hall from `training.zig`, as the bytes sit in memory
from `$7909`:

```
  03 08  02  20 28 03 00 01 00 10 00  98 60 01 00 00 00 10 00   doors: a count, then 8 bytes each
  06 08  0F 18 48  11 6C 80  28 10 C0  00                        walkways: 3 bytes each, then a 0
  09 08  10 40 48  00                                            one sliding pole
  0C 08  09 78 80  00                                            one ladder
  0F 08  01  88 68 01                                            doorbells: a count, then 3 bytes each
  33 08  1C 08 0F 21  54 48 45 20 ... 48 41 CC  00               text: x, y, colour, style, letters; a 0
  00 00                                                          the end of the room
```

Read the tags low byte first and they're `$0803` (doors), `$0806`
(walkways), `$0809` (poles), `$080C` (ladders), `$080F` (doorbells),
`$0833` (text), and `$0000`, the end of the room. They're three apart.
There are eighteen of them, from `$0803` to `$0836`, one for each kind of
object the castle can hold: doors, walkways, poles, ladders, doorbells,
lightning machines, forcefields, mummies, keys, locks, ray guns, matter
transmitters, trapdoors, conveyors, Frankenstein's monsters, text and
pictures, plus one the castles never use.

:::inside-the-disk The tag is the address
Why `$0803`, and why three apart? Because the tags are **addresses in the
program**. The 1984 engine starts with a table of jumps at `$0803`, three
bytes each: one byte for the processor's "jump" instruction and two for
where to jump. The castle's tag for a door is the address of the door
entry in that table. To prepare a room, the engine reads a tag and jumps
straight to it, and the jump lands in the code that understands doors.
There's no lookup and no comparison: **the data carries the address of
the code that reads it.**

One entry, `$0821`, stamps a shape several times in a row. The engine's
own title screens use it; no castle does.
:::

Our tags can't be addresses in our own program, because Zig decides where
our code goes, and it isn't at `$0803`. So we turn the tag back into a
kind instead, with one
subtraction and a lookup: take away `$0803`, and look the difference up in
a 54-entry table where every third entry is a kind and the other two are
`null`. It's Chapter 2's Lookup Table Power-Up, aimed at a different
question: no division by three, no chain of comparisons. The kinds go in
an enum in jump-table order, so the tag for kind *k* is `$0803 + 3k`, and
the castle builder later in this chapter uses that sum to write tags. A
`switch` on the kind does the dispatching for now; Chapter 5 brings back
the 1984 idea properly, with a table of functions.

**`src/castle.zig`** (add at the end of the file)

```zig
// ---- object streams -------------------------------------------------------

/// Every kind of object a room can hold, in the order of the program's
/// jump table: kind k's tag code is $0803 + 3k.
pub const Kind = enum(u8) {
    door,
    walkway,
    pole,
    ladder,
    bell,
    lightning,
    forcefield,
    mummy,
    key,
    lock,
    pattern, // a shape stamped in a row; only the title screens use it
    ray_gun,
    teleport,
    trapdoor,
    conveyor,
    frankenstein,
    text,
    image,
};

pub const first_code: u16 = 0x0803;
pub const end_code: u16 = 0x0000;

/// The tag code that introduces `kind`.
pub fn code(kind: Kind) u16 {
    return first_code + 3 * @as(u16, @intFromEnum(kind));
}

/// (code - $0803) to kind. Codes are 3 apart, so two in three entries are
/// null: those numbers aren't codes at all.
const kinds: [3 * std.enums.values(Kind).len]?Kind = blk: {
    var table: [3 * std.enums.values(Kind).len]?Kind = @splat(null);
    for (std.enums.values(Kind)) |kind| table[@intFromEnum(kind) * 3] = kind;
    break :blk table;
};

/// The kind a tag code introduces, or null if it isn't one.
pub fn kindOf(m: *Machine, tag: u16) ?Kind {
    m.work(12); // a subtraction, a compare and a table read
    const offset = tag -% first_code; // below $0803 wraps round to a huge number
    return if (offset < kinds.len) kinds[offset] else null;
}
```

`tag -% first_code` is a subtraction that wraps round instead of
stopping the game (the `+%` you met with the stars, going the other way),
so a tag below `$0803` becomes an enormous number that fails the length
test. `?Kind` is "a kind or `null`", Chapter 2's optional.

Now the records. Every record in a castle is a handful of bytes with no
two-byte fields, so each is an `extern struct` of `u8`s: lay one over the
stream with `m.view` and read its fields by name. We declare all eighteen
now, including the machines and monsters that wake up in later chapters,
because the loader needs their sizes even to step over them, and
`@sizeOf` gives it the size straight from the declaration.

**`src/castle.zig`** (add at the end of the file)

```zig
// ---- records --------------------------------------------------------------

/// A door: 8 bytes.
pub const Door = extern struct {
    x: u8,
    y: u8,
    side: u8, // its wall on the castle map: 0 up, 1 right, 2 down, 3 left. Bit 7: open
    to_room: u8, // where it leads
    to_door: u8,
    map_x: u8, // where it sits on the castle map, from the room's corner
    map_y: u8,
    exit: u8, // 1: the way out of the castle
};
pub const door_open: u8 = 0b1000_0000;

/// A walkway, a sliding pole or a ladder: `length` pieces from (x, y).
pub const Run = extern struct { length: u8, x: u8, y: u8 };

/// A doorbell, and which of the room's doors it opens (0 is the first).
pub const Bell = extern struct { x: u8, y: u8, door: u8 };

/// A line of text; its letters follow, the last one with bit 7 set.
pub const Text = extern struct { x: u8, y: u8, color: u8, style: u8 };

// The machines and monsters later chapters bring to life. For now the
// loader only needs their sizes, and the authoring kit their fields.
pub const Lightning = extern struct { state: u8, x: u8, y: u8, length: u8, machines: [4]u8 };
pub const Forcefield = extern struct { button_x: u8, button_y: u8, field_x: u8, field_y: u8 };
pub const Mummy = extern struct { state: u8, ankh_x: u8, ankh_y: u8, tomb_x: u8, tomb_y: u8, runtime: [2]u8 };
pub const Key = extern struct { number: u8, shape: u8, x: u8, y: u8 };
pub const Lock = extern struct { number: u8, shape: u8, door: u8, x: u8, y: u8 };
pub const Pattern = extern struct { count: u8, shape: u8, x: u8, y: u8, step_x: u8, step_y: u8 };
pub const RayGun = extern struct { state: u8, x: u8, y: u8, length: u8, runtime: u8, control_x: u8, control_y: u8 };
pub const Trapdoor = extern struct { state: u8, x: u8, y: u8, switch_x: u8, switch_y: u8 };
pub const Conveyor = extern struct { state: u8, x: u8, y: u8, control_x: u8, control_y: u8 };
pub const Frankenstein = extern struct { state: u8, x: u8, y: u8, runtime: [4]u8 };
```

### Three ways to end a list

Look back at the hall's bytes. The groups don't all end the same way, and
that's deliberate. The castle uses three framing schemes:

- **Counted.** Doors and doorbells: after the tag comes a count, then
  that many records. No end marker.
- **End marker.** Everything else that comes in lists: records until the
  next record's first byte is an end marker, which is then skipped. For
  walkways, ladders and poles the marker is a 0 where the next length
  would be (a walkway of no pieces would be pointless anyway). Text ends
  on a 0 where the next x would be. The machines need other markers,
  because their first byte is a state that can be 0: a lightning group
  ends on a byte with bit 5 set, and ray guns, trapdoors, conveyors and
  Frankensteins on a byte with bit 7 set, the bits their state bytes never
  use.
- **One tag per thing.** A picture is a whole shape, then a list of places
  to draw it, up to a 0, and each picture gets its own tag. A matter
  transmitter is one booth and a list of pads, up to a 0, once per room.

:::power-up The Sentinel Power-Up
Mark the end of a list *inside* the data instead of storing its length:
a 0 where the next length would be, a bit the data never sets, bit 7 on
a string's last letter. It costs a byte or nothing at all, and lists can
grow and shrink without anyone updating a count. The price is that you
can't jump to the 20th entry; you walk to it. For data you read from
start to finish every time, like a room being drawn, that's no price at
all.
:::

In Zig, "one of these, and which one it is" is a **tagged union**:

**`src/castle.zig`** (add at the end of the file)

```zig
/// How a kind's records are strung together after its tag.
pub const Framing = union(enum) {
    /// A count byte, then that many records of this size.
    counted: u8,
    /// Records of this size until one starts with the end marker,
    /// which is a byte of 0 (`end` = 0) or a byte with bit `end` set.
    marked: struct { size: u8, end: u8 },
    /// Like `marked`, ended by a 0, but each record ends with a string.
    text,
    /// One booth (x, y, target), then (x, y) pads up to a 0.
    teleport,
    /// One shape, then (x, y) places to draw it, up to a 0.
    image,
};

pub fn framing(kind: Kind) Framing {
    return switch (kind) {
        .door => .{ .counted = @sizeOf(Door) },
        .bell => .{ .counted = @sizeOf(Bell) },
        .walkway, .pole, .ladder => .{ .marked = .{ .size = @sizeOf(Run), .end = 0 } },
        .lightning => .{ .marked = .{ .size = @sizeOf(Lightning), .end = 0x20 } },
        .forcefield => .{ .marked = .{ .size = @sizeOf(Forcefield), .end = 0 } },
        .mummy => .{ .marked = .{ .size = @sizeOf(Mummy), .end = 0 } },
        .key => .{ .marked = .{ .size = @sizeOf(Key), .end = 0 } },
        .lock => .{ .marked = .{ .size = @sizeOf(Lock), .end = 0 } },
        .pattern => .{ .marked = .{ .size = @sizeOf(Pattern), .end = 0 } },
        .ray_gun => .{ .marked = .{ .size = @sizeOf(RayGun), .end = 0x80 } },
        .trapdoor => .{ .marked = .{ .size = @sizeOf(Trapdoor), .end = 0x80 } },
        .conveyor => .{ .marked = .{ .size = @sizeOf(Conveyor), .end = 0x80 } },
        .frankenstein => .{ .marked = .{ .size = @sizeOf(Frankenstein), .end = 0x80 } },
        .text => .text,
        .teleport => .teleport,
        .image => .image,
    };
}

/// Does `byte`, at the start of a record, mark the end of the group?
pub fn isEnd(byte: u8, end: u8) bool {
    return if (end == 0) byte == 0 else byte & end != 0;
}
```

`union(enum)` is like a TypeScript discriminated union. A `Framing` is
exactly one of its five cases, and a `switch` on it can capture the
case's data: `.counted => |size|` gets the record size,
`.marked => |f|` gets the size and the marker.

:::pro-tip `switch` must cover everything
`framing` switches on a `Kind` with no `else`, so if you ever added a
nineteenth kind and forgot to give it a framing, the build would
stop right here: `switch must handle all possibilities`. The same goes for
every `switch` on a `Framing`. Leave out `else` when you can, and the
compiler keeps your lists in step.
:::

### The walker

Now the part that reads a stream. `Walker` is an **iterator**: a little
struct that remembers where it is, with a `next` that hands you one
record at a time, or `null` at the end of the room.

**`src/castle.zig`** (add at the end of the file)

```zig
/// One record in a room's stream: its kind, where it starts, and the
/// address after it.
pub const Record = struct { kind: Kind, at: u16, end: u16 };

/// Walks a room's object stream, one record at a time.
pub const Walker = struct {
    at: u16, // the next byte to read
    kind: Kind = .door, // the group we're in
    in_group: bool = false,
    left: u8 = 0, // records still to come in a counted group

    /// The next record, or null at the stream's end tag.
    pub fn next(w: *Walker, m: *Machine) ?Record {
        while (true) {
            if (!w.in_group) {
                const tag = m.peek16(w.at);
                w.at += 2;
                if (tag == end_code) return null;
                w.kind = kindOf(m, tag) orelse @panic("castle: that's not an object code");
                w.in_group = true;
                if (framing(w.kind) == .counted) {
                    w.left = m.peek(w.at);
                    w.at += 1;
                }
            }
            const start = w.at;
            m.work(16); // the tests and the sums below
            switch (framing(w.kind)) {
                .counted => |record_size| {
                    if (w.left == 0) {
                        w.in_group = false;
                        continue;
                    }
                    w.left -= 1;
                    w.at += record_size;
                },
                .marked => |f| {
                    if (isEnd(m.peek(w.at), f.end)) {
                        w.at += 1; // the marker is part of the group
                        w.in_group = false;
                        continue;
                    }
                    w.at += f.size;
                },
                .text => {
                    if (m.peek(w.at) == 0) {
                        w.at += 1;
                        w.in_group = false;
                        continue;
                    }
                    w.at = stringEnd(m, w.at + @sizeOf(Text));
                },
                .teleport => {
                    w.at = placesEnd(m, w.at + 3);
                    w.in_group = false; // one booth per tag
                },
                .image => {
                    w.at = placesEnd(m, w.at + shapeSize(m, w.at));
                    w.in_group = false; // one image per tag
                },
            }
            return .{ .kind = w.kind, .at = start, .end = w.at };
        }
    }
};

/// The address after a string whose last letter has bit 7 set.
fn stringEnd(m: *Machine, at: u16) u16 {
    var a = at;
    while (m.peek(a) & 0x80 == 0) a += 1;
    return a + 1;
}

/// The address after a list of (x, y) pairs ended by a 0.
fn placesEnd(m: *Machine, at: u16) u16 {
    var a = at;
    while (m.peek(a) != 0) a += 2;
    return a + 1;
}

/// How many bytes a shape takes: width, height and flags, its pixels,
/// and a screen-plane and a colour-RAM byte for each cell.
pub fn shapeSize(m: *Machine, at: u16) u16 {
    const width = m.peek(at);
    const height = m.peek(at + 1);
    return 3 + m.mul8(width, height) + 2 * m.mul8(width, (height + 7) / 8);
}

/// Object X counts fat pixels from 16, so that things can start a
/// little way off the left edge of the screen. The fat pixel the blitter
/// wants, or null for anything that starts off the left edge.
pub fn screenX(x: u8) ?u8 {
    return if (x < 16) null else x - 16;
}
```

`next` reads a tag when it isn't in the middle of a group, looks it up,
and (for a counted group) reads the count. Then it steps over one record
according to the framing, and returns it. When a group ends, `continue`
goes round the loop to read the next tag: each pass either moves on to
the next group or returns a record.
`orelse @panic(...)` unwraps the optional kind, and stops the game with a
message if a castle hands it a tag that isn't one.

The helpers at the bottom step over a string to its bit-7 letter, over a
list of places to its 0, and over a whole shape, using Chapter 2's shape
format: three header bytes, `width × height` pixels and two colour bytes
per cell. `screenX` we'll come to in a moment.

Time to check it against bytes nobody generated: a room written out by
hand with one of nearly everything, including a lightning machine and its
switch, a ray gun, a matter transmitter and a picture.

**`src/castle.zig`** (add at the end of the file)

```zig
// ---- tests ----------------------------------------------------------------

test "tag codes turn into kinds and back" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    try std.testing.expectEqual(Kind.door, kindOf(m, 0x0803).?);
    try std.testing.expectEqual(Kind.image, kindOf(m, 0x0836).?);
    try std.testing.expectEqual(null, kindOf(m, 0x0804));
    try std.testing.expectEqual(null, kindOf(m, 0x0839));
    try std.testing.expectEqual(null, kindOf(m, 0x0100));
    for (std.enums.values(Kind)) |kind| try std.testing.expectEqual(kind, kindOf(m, code(kind)).?);
}

test "the walker finds every record in a stream written by hand" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    const room = [_]u8{
        0x03, 0x08, 1, 0x9C, 0xA0, 0x01, 0x02, 0x00, 0x24, 0x10, 0x00, // one door
        0x06, 0x08, 40, 0x10, 0xC0, 0, // a walkway, then its end marker
        0x0F, 0x08, 1, 0x88, 0xA8, 0x00, // one doorbell, for door 0
        0x12, 0x08, 0x40, 0x50, 0x88, 5, 0, 0, 0, 0, // a lightning machine...
        0x80, 0x30, 0x60, 0, 0x00, 0xFF, 0xFF, 0xFF, 0x20, // ...its switch, the end
        0x24, 0x08, 0x01, 0x20, 0x40, 8, 0x48, 0x30, 0x40, 0x80, // a ray gun, end
        0x27, 0x08, 0x40, 0x98, 0x00, 0x80, 0x98, 0x00, // a booth with one pad
        0x33, 0x08, 0x14, 0x00, 0x07, 0x22, 'H', 'E', 'L', 'L', 'O' | 0x80, // text...
        0x14, 0x18, 0x01, 0x21, 'H', 'I' | 0x80, 0x00, // ...more text, the end
        0x36, 0x08, 1, 2, 0, 0xFF, 0xFF, 0x21, 0x07, 0x20, 0x08, 0x30, 0x08, 0, // an image, twice
        0x00, 0x00, // the end of the room
    };
    const at = 0x7969;
    m.load(at, &room);

    const expected = [_]Kind{ .door, .walkway, .bell, .lightning, .lightning, .ray_gun, .teleport, .text, .text, .image };
    var walk = Walker{ .at = at };
    for (expected) |kind| {
        const r = walk.next(m) orelse return error.EndedEarly;
        try std.testing.expectEqual(kind, r.kind);
    }
    try std.testing.expectEqual(null, walk.next(m));
    try std.testing.expectEqual(at + room.len, walk.at);
}
```

`zig build test` runs the two new tests along with the others (they're
inside `castle.zig`, which `room.zig` imports, so they count). If you change the lightning group's end byte
from `0x20` to `0x00`, the walker reads the end marker as a record and
everything after it goes wrong. Try it, then put it back.

## Drawing from the stream

Here's the new `room.zig`. It forgets the Entrance Hall entirely: it
walks room 0's stream and draws each record it knows.

**`src/room.zig`** (replace the whole file)

```zig
//! The room on screen, drawn from the castle: walk the room's object
//! stream and draw everything in it that stands still.

const machine = @import("machine");
const Machine = machine.Machine;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // every Training Castle room has a floor here

/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    var walk = prepare(m, 0);
    while (walk.next(m)) |r| {
        switch (r.kind) {
            .walkway => walkway(m, r.at),
            .pole => column(m, .pole, r.at),
            .ladder => column(m, .ladder, r.at),
            else => {}, // the rest: later in this chapter, and in later chapters
        }
    }
}

/// Get room `n` ready to draw: paint the floor pieces its colour, and
/// return a walker at the start of its objects.
fn prepare(m: *Machine, n: u8) castle.Walker {
    paint(m, roomColors(m, n));
    return .{ .at = m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")) };
}

/// One colour per room, not per walkway: before drawing, repaint the
/// floor pieces in the shape table itself.
fn paint(m: *Machine, colors: u8) void {
    for ([_]shapes.Id{ .walkway, .walkway_left, .walkway_right, .ladder, .pole }) |id| {
        shapes.recolor(m, id, colors);
    }
}

/// Room `n`'s colour from its directory entry, for both codes 01 and 10.
fn roomColors(m: *Machine, n: u8) u8 {
    return both(m.peek(castle.entry(m, n)) & 0x0F);
}

/// One colour in both halves of a screen-plane byte.
fn both(color: u8) u8 {
    return color << 4 | color;
}

/// A walkway: `length` pieces 4 fat pixels wide, a left end, middles and
/// a right end.
fn walkway(m: *Machine, at: u16) void {
    const w = m.view(castle.Run, at);
    var x = castle.screenX(w.x) orelse return;
    var i: u8 = 1;
    while (i <= w.length and x < 160) : (i += 1) {
        const piece: shapes.Id = if (i == 1) .walkway_left else if (i == w.length) .walkway_right else .walkway;
        screen.drawShape(m, piece, x, w.y);
        x += 4;
        m.work(12); // the tests and the loop
    }
}

/// A ladder or a pole: `length` pieces stacked 8 rows apart, top first.
fn column(m: *Machine, id: shapes.Id, at: u16) void {
    const c = m.view(castle.Run, at);
    const x = castle.screenX(c.x) orelse return;
    var y = c.y;
    var i: u8 = 0;
    while (i < c.length and y < 200) : (i += 1) {
        screen.drawShape(m, id, x, y);
        y += 8;
        m.work(8); // the tests and the loop
    }
}
```

Three things to look at.

**The coordinates.** An object's X in the castle isn't the fat pixel
Chapter 2's blitter takes. It's the fat pixel **plus 16**, so X = 16 is
the left edge of the screen and X = 175 the right. Why the offset? So
that something can start a little off the left of the screen with a
positive X (X = 4 is twelve fat pixels off the left edge), and a byte
still runs to 255, long past the right edge. Chapter 4
puts the explorer on the same scale, and that's how he'll get past the
wall made of arithmetic. `castle.screenX` is the one place the offset is
written down; it hands back `null` for anything that starts off the left
edge, and those we don't draw. Y is plain: the pixel row.

**The pieces.** A walkway is `length` pieces 4 fat pixels wide: a left
end, middles and a right end (a walkway of one piece is a left end). A
ladder or pole is `length` pieces stacked 8 rows apart, from the top
down, and in the Training Castle each one starts on a walkway and ends on
the one below, its top and bottom pieces drawn over the bricks. That's
how the 1984 game reads these records, so a real castle's ladders will
line up with its floors.

**The views.** `m.view(castle.Run, at)` is a `*align(1) castle.Run`
pointing at the record in memory. `align(1)` says it may sit at any
address, odd or even (which is why the machine only allows views of
types without padding). `w.length` is then a read of the byte at `at`.
The view itself is free; what we do with it we charge with `m.work`, as
the card asks.

`prepare` picks the room's colour and its first object out of the
directory, and `@offsetOf(castle.Entry, "objects")` is the struct telling
us the field is 6 bytes in, instead of a 6 typed by hand.

Build, press fire, and the hall is back, floors, ladder and pole, read
from 75 bytes of castle. The windows and torches are gone: the castle
format has no torches. The doors and the title are in the stream, and
the walker steps over them, because it knows how long they are even
though nothing draws them yet. Let's draw them.

## Doors, bells and words

Five new pictures go at the end of the shape IDs, where Chapter 2 asked
us to put new shapes (castles store shape IDs, so existing IDs mustn't
move): an arched doorway, the way out's doorway, a shut door, an open
one, and a doorbell. And one ID with no picture at all: `image`. Hold
that thought too.

**`src/shapes.zig`** (replace `Id` and the comment above it)

```zig
/// Every shape, by ID. Each name except `glyph` and `image` has a picture
/// of the same name in art.zig. New shapes go at the end: the walk counts
/// on the explorer's frames being in a row, and IDs are stored in castles.
pub const Id = enum(u8) {
    glyph, // built by text.zig, one letter at a time
    walkway,
    walkway_left,
    walkway_right,
    ladder,
    pole,
    door,
    window,
    torch,
    moon,
    tower,
    wall,
    explorer_right_0,
    explorer_right_1,
    explorer_right_2,
    explorer_right_3,
    explorer_left_0,
    explorer_left_1,
    explorer_left_2,
    explorer_left_3,
    door_frame,
    exit_frame,
    door_shut,
    door_open,
    bell,
    image, // points into the castle, at whichever image is being drawn
};
```

`image`, like `glyph`, has no picture in the table. Its directory entry
starts as 0 and gets pointed at a picture when there's one to draw:

**`src/shapes.zig`** (in `build`, replace the four lines at the top of the loop)

```zig
            // The glyph is built at run time, in the text region, and
            // `image` is pointed at a picture in the castle when one is drawn.
            const where = switch (id) {
                .glyph => map.text_glyph,
                .image => 0,
                else => at,
            };
            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first
            if (id == .glyph or id == .image) continue;
```

**`src/shapes.zig`** (add below `address`)

```zig
/// Point shape `id`'s directory entry at the shape stored at `at`.
pub fn point(m: *Machine, id: Id, at: u16) void {
    m.work(4); // doubling the ID
    m.poke16(map.shape_table.first + @as(u16, @intFromEnum(id)) * 2, at);
}
```

### The text style byte

Every text record carries a **style** byte after its colour. It's another
packed byte:

```
  bit:   7   6     5        4        3   2     1   0
       ┌───┬───┬─────────┬──────────┬───────┬─────────┐
       │ 0 │ 0 │ letters │ reversed │ 0   0 │ height  │
       └───┴───┴─────────┴──────────┴───────┴─────────┘
```

The low two bits say how tall the letters are: 1, 2 or 3 times the usual
8 rows, with 0 counting as 1. Each row of the glyph is drawn that many
times, which is why the glyph's scratch shape grew.
Bit 4 draws the letters reversed, cut out of a solid block. Bit 5 asks
for the letters character set rather than a set of pictures; the castles
always set it, and the Comet's ROM has only the one set. So a heading is
`$22` (letters, twice as tall) and an ordinary line `$21`, the styles the
1984 castles use for headings and for everything else.

`draw` gets a style, and one more change: it returns the address after
the string. Letters off the right edge are still left out, but the
loop now walks on to the last letter regardless, so whoever called it
knows where the string ended.

**`src/text.zig`** (replace `glyph_pixels` and the two lines below it)

```zig
/// The glyph shape's pixels start after its width, height and flags.
const glyph_pixels = map.text_glyph + 3;

/// The style byte every castle Text object carries. Bits 0-1: how tall,
/// 1 to 3 times (0 counts as 1). Bit 4: reversed, light letters cut out
/// of a solid block. Bit 5 asks for the letters (rather than picture)
/// character set, which is the only one our ROM has; castles always set it.
pub const style_height: u8 = 0b0000_0011;
pub const style_reversed: u8 = 0b0001_0000;
pub const style_letters: u8 = 0b0010_0000;
pub const plain = style_letters | 1;
```

**`src/text.zig`** (in `start`, replace the last two lines)

```zig
    m.poke(map.text_glyph + 2, 0); // no flags; the height depends on the style
```

**`src/text.zig`** (replace `draw`)

```zig
/// Print the string at `addr` with its top-left corner at fat pixel
/// (x, y), in `style` (see `style_height`). Letters are 8 fat pixels wide.
/// The string ends at the first byte with bit 7 set, which is its last
/// letter; letters that would run off the right edge of the screen are
/// left out. Returns the address after the string.
pub fn draw(m: *Machine, x: u8, y: u8, color: Color, style: u8, addr: u16) u16 {
    const tall = @max(1, style & style_height); // each glyph row drawn this many times
    const flip: u8 = if (style & style_reversed != 0) 0xFF else 0x00;
    const rows = 8 * tall;
    m.poke(map.text_glyph + 1, rows);

    // Glyph pixels are code 01, whose colour is the high half of the
    // screen-plane byte. The glyph is 2 cells wide and `tall` cells high.
    const glyph_screen = glyph_pixels + 2 * @as(u16, rows);
    const glyph_colors = glyph_screen + 2 * @as(u16, tall);
    m.fill(glyph_screen, 2 * tall, @as(u8, @intFromEnum(color)) << 4);
    m.fill(glyph_colors, 2 * tall, 0);

    var at = addr;
    var left: u16 = x;
    while (true) : (left += 8) {
        const letter = m.peek(at);
        at += 1;
        if (left <= 160 - 8) {
            const glyph = m.charRom(letter & 0x7F);
            var dst: u16 = glyph_pixels;
            for (glyph) |row| {
                const bits = row ^ flip;
                const left_half = m.peek(map.text_widen + (bits >> 4));
                const right_half = m.peek(map.text_widen + (bits & 0x0F));
                for (0..tall) |_| {
                    m.poke(dst, left_half);
                    m.poke(dst + 1, right_half);
                    dst += 2;
                }
                m.work(10 + 4 * @as(u32, tall)); // the shift, the mask, the loops
            }
            screen.drawShape(m, .glyph, @intCast(left), y);
        }
        if (letter & 0x80 != 0) return at;
    }
}
```

**`src/text.zig`** (in `say`, replace the last line)

```zig
    _ = draw(m, x, y, color, plain, map.text_buffer);
```

`for (0..tall) |_|` repeats each glyph row `tall` times, `row ^ flip`
inverts the row when the style says reversed (flip is `$FF`) and leaves
it alone when it doesn't (flip is 0), and `@max(1, ...)` turns a height
of 0 into 1. `say`, the title screen's printer, asks for plain letters,
so the title is unchanged, byte for byte.

### Drawing them

Now the room draws everything that stands still:

**`src/room.zig`** (replace the imports below `machine`, adding two)

```zig
const Machine = machine.Machine;
const Color = machine.Color;
const castle = @import("castle.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
```

**`src/room.zig`** (replace `draw`)

```zig
/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    var walk = prepare(m, 0);
    var doors: u16 = 0; // where this room's door records start
    while (walk.next(m)) |r| {
        switch (r.kind) {
            .door => {
                if (doors == 0) doors = r.at;
                door(m, r.at);
            },
            .walkway => walkway(m, r.at),
            .pole => column(m, .pole, r.at),
            .ladder => column(m, .ladder, r.at),
            .bell => bell(m, r.at, doors),
            .text => line(m, r.at),
            .image => image(m, r.at),
            else => {}, // machines and monsters come alive in later chapters
        }
    }
}
```

**`src/room.zig`** (add at the end of the file)

```zig
/// A door: the arch (or the way out's), and in it the door itself, shut
/// or open onto the colour of the room beyond.
fn door(m: *Machine, at: u16) void {
    const d = m.view(castle.Door, at);
    const x = castle.screenX(d.x) orelse return;
    m.work(8); // the two tests
    screen.drawShape(m, if (d.exit != 0) .exit_frame else .door_frame, x, d.y);
    if (d.side & castle.door_open != 0) {
        shapes.recolor(m, .door_open, roomColors(m, d.to_room));
        screen.drawShape(m, .door_open, x + 4, d.y + 8);
    } else {
        screen.drawShape(m, .door_shut, x + 4, d.y + 8);
    }
}

/// A doorbell, in the colour of the room its door leads to.
fn bell(m: *Machine, at: u16, doors: u16) void {
    const b = m.view(castle.Bell, at);
    const x = castle.screenX(b.x) orelse return;
    const d = m.view(castle.Door, doors + @as(u16, b.door) * @sizeOf(castle.Door));
    m.work(10); // the multiply by 8 is three shifts
    shapes.recolor(m, .bell, roomColors(m, d.to_room));
    screen.drawShape(m, .bell, x, b.y);
}

/// A line of text: x, y, colour and style, then the letters.
fn line(m: *Machine, at: u16) void {
    const t = m.view(castle.Text, at);
    const x = castle.screenX(t.x) orelse return;
    const color: Color = @enumFromInt(@as(u4, @truncate(t.color)));
    _ = text.draw(m, x, t.y, color, t.style, at + @sizeOf(castle.Text));
}

/// An image is a shape that lives in the castle. Point the shape
/// directory's spare entry at it, then draw it at each place listed
/// after it.
fn image(m: *Machine, at: u16) void {
    shapes.point(m, .image, at);
    var place = at + castle.shapeSize(m, at);
    while (m.peek(place) != 0) : (place += 2) {
        const x = castle.screenX(m.peek(place)) orelse continue;
        screen.drawShape(m, .image, x, m.peek(place + 1));
    }
}
```

**Doors.** A door record says where the doorway goes and which room and
door it leads to. Its last byte picks the arch: 1 for the way out of the
castle, 0 for the rest. Inside the arch, 4 fat pixels in and 8 rows down,
goes the door itself, shut, or open if bit 7 of the third byte is set,
and an open door shows **the colour of the room beyond**: `recolor` again,
with the destination's colour from its directory entry. (Chapter 5 opens
doors; this is what they'll look like.)

**Bells.** A doorbell names a door by its place in the room's door group,
0 for the first. `draw` remembers where that group starts (`doors`), so
the bell finds its door eight bytes at a time, and the bell itself takes
the colour of the room the door leads to. A bell tells you where it goes
before you ring it, and so did the 1984 game's.

**Text** is a view of the record's first four bytes and a `draw` of the
letters after them.

**Pictures** use the trick the `image` ID was waiting for. A picture in
the castle is stored in exactly Chapter 2's shape format (width, height,
flags, pixels, colours; Chapter 2 promised that one drawing routine would
serve both), so `image` points the spare directory entry *into the
castle*, at the picture, and calls `drawShape` for each place listed
after it. The blitter has no idea the shape isn't in its table. **A
pointer doesn't care what it points at**, and neither does the 1984 game,
which does the same thing with one of its own shape entries.

![The Entrance Hall drawn from the hand-typed castle: two stone arches with wooden doors on the upper-left and middle-right walkways, a red doorbell, the ladder and sliding pole, red brick floors and the title THE ENTRANCE HALL](images/03-hall.png)

Build and press fire. **There's the Entrance Hall, every piece of it out
of the castle file!** Doorways, a doorbell (red, since its door leads back
into this red room) and its name.

## Comptime, properly this time

The hand-typed castle works, and it's a liability. Its size word and its
objects pointer are numbers you worked out on paper. Add a walkway to the
hall and both are wrong, and nothing complains. Twenty rooms of that, all
pointing at each other, is a castle that breaks every time you touch it.

What we want is to write a room like this:

```zig snippet
.gatehouse = .{
    .color = .red,
    .map = spot(0),
    .door = &.{.{ .x = 156, .y = 160, .to = .gallery }},
    .walkway = &.{floor},
    .bell = &.{.{ .x = 140, .y = 168, .door = 0 }},
    .text = says("THE GATEHOUSE", &.{ "WELCOME, EXPLORER!", ... }),
},
```

and have the compiler work out every byte, every pointer and the size,
and refuse to build if a door leads to a room that doesn't lead back. The
tool for that is `comptime`. Chapter 2 used it to pack the shape table;
here's the full story.

**It's the same language, earlier.** There's no separate macro language
in Zig. Code whose inputs are all known while compiling can run while
compiling: loops, `if`s, function calls, building arrays with `++`. The
star map and the shape table were ordinary Zig run inside the compiler,
their answers frozen into the program image. The castle builder is the
same, only bigger. What can't happen at compile time is anything that
needs the running machine: no `m.peek`, no frames.

**Types are values.** At compile time a type is a value like any other,
so a function can take one and return one. `Door(Name)` below is a
function that takes the castle's enum of room names and returns a struct
type whose `to` field is one of those names. In TypeScript you'd write
`Door<Name>`; in Zig it's an ordinary function call that happens to run
in the compiler. The payoff is that `.to = .gallery` is checked: misspell
it `.galery` and the compiler says `enum 'training.Room' has no member
named 'galery'`, before a byte is written.

**Loops that change type.** Chapter 2's `@field(art, @tagName(id))` found
a declaration by name. The builder does the same over the eighteen
`Kind`s, with `@field(room, @tagName(kind))`, so the room's field for
each kind is named after the kind (`door`, `walkway`, ..., `image`). But
`room.door` is a list of doors and `room.text` a list of lines, different
types, and an ordinary loop body has one type per variable. An
**`inline for`** unrolls the loop while compiling, one copy of the body
per kind, so each copy can have its own types, and a `switch` on a kind
known at compile time keeps only the branch for that kind.

There's one limit to know about. The compiler counts the steps of
compile-time loops and gives up at 1,000 branches, in case you've written
an infinite one; `@setEvalBranchQuota` raises the limit for one job. A
castle is a big job.

Let's build it, in four pieces. The builder packs the castle's pictures
with Chapter 2's `pack`, so that has to be public:

**`src/shapes.zig`** (make `pack` public)

```zig
pub fn pack(comptime name: []const u8, comptime a: Art) []const u8 {
```

First, the declarations: what you write.

**`src/author.zig`** (new file)

```zig
//! The castle-authoring kit: describe rooms as Zig declarations, and get
//! back the castle file's bytes, checked while the game compiles.

const std = @import("std");
const Color = @import("machine").Color;
const castle = @import("castle.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const map = @import("map.zig");

// ---- what you write -------------------------------------------------------

/// Where a room sits on the castle map: x and y like an object's, and
/// its size in map cells of 4 fat pixels by 8 rows.
pub const Map = struct { x: u8 = 0, y: u8 = 0, width: u3 = 0, height: u3 = 0 };

/// A door, and the door on the far side. `Name` is the castle's enum of
/// room names, so a door can only lead to a room that exists.
pub fn Door(comptime Name: type) type {
    return struct {
        x: u8,
        y: u8,
        to: Name,
        to_door: u8 = 0,
        open: bool = false,
        exit: bool = false, // the way out of the castle: it needs no partner
    };
}

/// Walkways, ladders, poles and doorbells are written as their records.
pub const Run = castle.Run;
pub const Bell = castle.Bell;

/// A line of text, 1 to 3 times the usual 8 rows tall.
pub const Line = struct { x: u8, y: u8, color: Color = .white, height: u2 = 1, words: []const u8 };

pub const Spot = struct { x: u8, y: u8 };
pub const Teleport = struct { x: u8, y: u8, target: u8 = 0, pads: []const Spot };

/// A picture stored in the castle, and everywhere it's drawn.
pub const Image = struct { art: shapes.Art, at: []const Spot };

/// Everything one room holds. Each list is named after its `castle.Kind`.
pub fn Room(comptime Name: type) type {
    return struct {
        color: Color = .black,
        map: Map = .{},
        door: []const Door(Name) = &.{},
        walkway: []const Run = &.{},
        pole: []const Run = &.{},
        ladder: []const Run = &.{},
        bell: []const Bell = &.{},
        lightning: []const castle.Lightning = &.{},
        forcefield: []const castle.Forcefield = &.{},
        mummy: []const castle.Mummy = &.{},
        key: []const castle.Key = &.{},
        lock: []const castle.Lock = &.{},
        pattern: []const castle.Pattern = &.{},
        ray_gun: []const castle.RayGun = &.{},
        teleport: ?Teleport = null,
        trapdoor: []const castle.Trapdoor = &.{},
        conveyor: []const castle.Conveyor = &.{},
        frankenstein: []const castle.Frankenstein = &.{},
        text: []const Line = &.{},
        image: []const Image = &.{},
    };
}

/// A whole castle: a field in `rooms` for every name in `Name`, in the
/// enum's order, and a final room that isn't on the map.
pub fn Castle(comptime Name: type) type {
    return struct {
        start: struct { room: Name, door: u8 = 0 },
        lives: u8 = 3,
        rooms: std.enums.EnumFieldStruct(Name, Room(Name), null),
        final: ?Room(Name) = null,
    };
}
```

`Map`'s width and height are `u3`s, three-bit numbers, because that's what
the size byte has room for: write `.width = 9` and it doesn't build.
Walkways, ladders, poles, doorbells and all the machines are written as
their castle records, the same `extern struct`s the loader views. And
`std.enums.EnumFieldStruct(Name, Room(Name), null)` is a type-returning
function from the standard library: it makes a struct with one field for
every name in the enum. The castle must describe every room (leave one
out and it doesn't build), and the room numbers come from the enum's
order, not from the order you write them in.

Second, `build`, which lays the castle out:

**`src/author.zig`** (add at the end of the file)

```zig
// ---- what you get ---------------------------------------------------------

/// The castle file: header, room directory, then every room's objects.
pub fn build(comptime Name: type, comptime c: Castle(Name)) []const u8 {
    comptime {
        @setEvalBranchQuota(2_000_000);
        const names = std.enums.values(Name);
        if (names.len > castle.max_rooms)
            fail("a castle has at most {d} rooms, not {d}", .{ castle.max_rooms, names.len });
        const start = @field(c.rooms, @tagName(c.start.room));
        if (c.start.door >= start.door.len)
            fail("the start room, {s}, has no door {d}", .{ @tagName(c.start.room), c.start.door });

        // The streams go after the directory and its end byte, one after
        // another, so each room's address is the sum of the ones before.
        var at: u16 = castle.directory + names.len * @sizeOf(castle.Entry) + 1;
        var directory: []const u8 = &.{};
        var streams: []const u8 = &.{};
        for (names) |name| {
            const room = @field(c.rooms, @tagName(name));
            if (room.map.width == 0 or room.map.height == 0)
                fail("room {s}: give it a place and a size on the castle map", .{@tagName(name)});
            if (room.color == .black)
                fail("room {s}: a black room has black walkways", .{@tagName(name)});
            const entry = castle.Entry{
                .color = @intFromEnum(room.color),
                .map_x = room.map.x,
                .map_y = room.map.y,
                .size = .{ .width = room.map.width, .height = room.map.height },
                .skip = le(at + 2),
                .objects = le(at),
            };
            directory = directory ++ std.mem.asBytes(&entry);
            const objects = stream(Name, c, room, @tagName(name));
            streams = streams ++ objects;
            at += objects.len;
        }
        directory = directory ++ [_]u8{if (c.final == null) castle.end_plain else castle.end_with_final};
        const final_at = if (c.final == null) 0 else at;
        if (c.final) |room| streams = streams ++ stream(Name, c, room, "final");

        const total = castle.header_size + directory.len + streams.len;
        if (total > map.castle.last - map.castle.first + 1)
            fail("the castle is {d} bytes, and its region holds {d}", .{ total, map.castle.last - map.castle.first + 1 });

        var head = [_]u8{0} ** castle.header_size;
        head[0..2].* = le(total);
        head[2] = castle.magic_value;
        const first = @intFromEnum(c.start.room);
        head[3..9].* = .{ first, first, c.start.door, c.start.door, c.lives, c.lives };
        head[0x5F..0x61].* = le(final_at);

        const all = head ++ directory[0..directory.len].* ++ streams[0..streams.len].*;
        return &all;
    }
}
```

It walks the rooms in order, and each room's stream starts where the last
one ended: `at` is the running total that you worked out by hand for the
hall. `std.mem.asBytes(&entry)` is the struct read as its bytes; the same
`castle.Entry` the loader reads is the one the builder writes, so the two
can't disagree about the format. The header goes together last, now that
the size is known. `fail` (in the last piece) turns any problem into a
compile error that names the room.

Third, the streams. One branch per framing scheme, each also checking its
records:

**`src/author.zig`** (add at the end of the file)

```zig
/// One room's object stream: each kind's group in tag order (doors and
/// floors first, text and pictures last, a good order to draw in), then
/// the end tag.
fn stream(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime name: []const u8) []const u8 {
    var out: []const u8 = &.{};
    var boxes: []const Box = &.{};
    inline for (comptime std.enums.values(castle.Kind)) |kind| {
        const list = @field(room, @tagName(kind));
        const tag = le(castle.code(kind));
        switch (kind) {
            // Counted: the tag, how many, then the records.
            .door, .bell => if (list.len > 0) {
                out = out ++ tag ++ [_]u8{list.len};
                for (list, 0..) |thing, i| {
                    const what = std.fmt.comptimePrint("{s} {d}", .{ @tagName(kind), i });
                    const w, const h = if (kind == .door) .{ 20, 32 } else .{ 8, 16 };
                    onScreen(name, what, thing.x, thing.y, w, h);
                    boxes = boxes ++ [_]Box{.{ .what = what, .x = thing.x, .y = thing.y, .w = w, .h = h }};
                    const record = if (kind == .door) door(Name, c, room, name, thing, i) else bell(room, name, thing, i);
                    out = out ++ std.mem.asBytes(&record);
                }
            },
            // Runs of pieces, ended by a length of 0.
            .walkway, .pole, .ladder => if (list.len > 0) {
                out = out ++ tag;
                for (list, 0..) |r, i| {
                    const what = std.fmt.comptimePrint("{s} {d}", .{ @tagName(kind), i });
                    if (r.length == 0) fail("room {s}: {s} has length 0, which is the end marker", .{ name, what });
                    if (kind == .walkway) {
                        onScreen(name, what, r.x, r.y, 4 * @as(u16, r.length), 7);
                    } else {
                        const bottom = r.y + 8 * (r.length - 1);
                        onScreen(name, what, r.x, r.y, if (kind == .ladder) 8 else 4, bottom + 8 - r.y);
                        if (!onWalkway(room, r.x, r.y) or !onWalkway(room, r.x, bottom))
                            fail("room {s}: {s} must start and end on a walkway (rows {d} and {d})", .{ name, what, r.y, bottom });
                    }
                    out = out ++ std.mem.asBytes(&r);
                }
                out = out ++ [_]u8{0};
            },
            // Lines of text, each ending on a letter with bit 7 set; a 0 ends them all.
            .text => if (list.len > 0) {
                out = out ++ tag;
                for (list, 0..) |line, i| {
                    const what = std.fmt.comptimePrint("text {d} (\"{s}\")", .{ i, line.words });
                    if (line.height == 0) fail("room {s}: {s} has height 0", .{ name, what });
                    const w, const h = .{ 8 * line.words.len, 8 * @as(u16, line.height) };
                    onScreen(name, what, line.x, line.y, w, h);
                    boxes = boxes ++ [_]Box{.{ .what = what, .x = line.x, .y = line.y, .w = w, .h = h }};
                    const record = castle.Text{ .x = line.x, .y = line.y, .color = @intFromEnum(line.color), .style = text.style_letters | line.height };
                    out = out ++ std.mem.asBytes(&record) ++ &text.terminated(line.words);
                }
                out = out ++ [_]u8{0};
            },
            // One booth, then its pads up to a 0.
            .teleport => if (list) |t| {
                out = out ++ tag ++ [_]u8{ t.x, t.y, t.target };
                for (t.pads) |p| out = out ++ [_]u8{ p.x, p.y };
                out = out ++ [_]u8{0};
            },
            // A tag for every picture: the shape, then where it goes, up to a 0.
            .image => for (list, 0..) |picture, i| {
                const bytes = shapes.pack(std.fmt.comptimePrint("{s} image {d}", .{ name, i }), picture.art);
                out = out ++ tag ++ bytes;
                for (picture.at) |p| {
                    const what = std.fmt.comptimePrint("image {d} at ({d}, {d})", .{ i, p.x, p.y });
                    const w, const h = .{ 4 * @as(u16, bytes[0]), bytes[1] };
                    onScreen(name, what, p.x, p.y, w, h);
                    boxes = boxes ++ [_]Box{.{ .what = what, .x = p.x, .y = p.y, .w = w, .h = h }};
                    out = out ++ [_]u8{ p.x, p.y };
                }
                out = out ++ [_]u8{0};
            },
            // The machines and monsters: records as written, then the end marker.
            else => if (list.len > 0) {
                const end = castle.framing(kind).marked.end;
                out = out ++ tag;
                for (list) |r| {
                    const bytes = std.mem.asBytes(&r);
                    if (castle.isEnd(bytes[0], end))
                        fail("room {s}: a {s} starting with {d} would read as the end marker", .{ name, @tagName(kind), bytes[0] });
                    out = out ++ bytes;
                }
                out = out ++ [_]u8{end};
            },
        }
    }
    for (boxes, 0..) |a, i| {
        for (boxes[i + 1 ..]) |b| {
            if (a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h)
                fail("room {s}: {s} overlaps {s}", .{ name, a.what, b.what });
        }
    }
    return out ++ le(castle.end_code);
}
```

The `boxes` list collects the rectangle of every door, bell, line of text
and picture, so the last loop can refuse a room where two of them
overlap. `const w, const h = ...` gets two values out of one expression,
Zig's destructuring.

Last, the helpers and the checks:

**`src/author.zig`** (add at the end of the file)

```zig
/// Door `i`'s 8 bytes: check that it leads somewhere that leads back, and
/// work out where it shows on the castle map, on the wall facing the
/// room it leads to.
fn door(comptime Name: type, comptime c: Castle(Name), comptime room: Room(Name), comptime name: []const u8, comptime d: Door(Name), comptime i: usize) castle.Door {
    if (d.y % 8 != 0) fail("room {s}: door {d} has y {d}; doors sit on cell rows (multiples of 8)", .{ name, i, d.y });
    const there = @field(c.rooms, @tagName(d.to));
    if (!d.exit) {
        if (d.to_door >= there.door.len)
            fail("room {s}: door {d} leads to door {d} of {s}, which has {d}", .{ name, i, d.to_door, @tagName(d.to), there.door.len });
        const back = there.door[d.to_door];
        if (!std.mem.eql(u8, @tagName(back.to), name) or back.to_door != i)
            fail("room {s}: door {d} leads to {s} door {d}, which doesn't lead back", .{ name, i, @tagName(d.to), d.to_door });
    }
    const here = room.map;
    const width = 4 * @as(u16, here.width);
    const height = 8 * @as(u16, here.height);
    const side: u8 = if (there.map.x >= here.x + width) 1 // right
        else if (there.map.x + 4 * @as(u16, there.map.width) <= here.x) 3 // left
        else if (there.map.y + 8 * @as(u16, there.map.height) <= here.y) 0 // up
        else if (there.map.y >= here.y + height) 2 // down
        else if (d.x < 96) 3 else 1; // the way out: whichever wall it's nearer
    return .{
        .x = d.x,
        .y = d.y,
        .side = side | if (d.open) castle.door_open else 0,
        .to_room = @intFromEnum(d.to),
        .to_door = d.to_door,
        .map_x = if (side % 2 == 0) @min(width - 4, (d.x - 16) * width / 160) else 0,
        .map_y = if (side % 2 == 1) @min(height - 3, (d.y + 16) * height / 200) else 0,
        .exit = @intFromBool(d.exit),
    };
}

/// A doorbell's 3 bytes, once we know its door exists.
fn bell(comptime room: anytype, comptime name: []const u8, comptime b: Bell, comptime i: usize) Bell {
    if (b.door >= room.door.len) fail("room {s}: bell {d} rings door {d}, and the room has {d}", .{ name, i, b.door, room.door.len });
    return b;
}

/// A rectangle something covers on the screen, for the overlap check.
const Box = struct { what: []const u8, x: u16, y: u16, w: u16, h: u16 };

/// Something `w` fat pixels by `h` rows at (x, y) must be on the screen
/// and start on a whole byte.
fn onScreen(comptime name: []const u8, comptime what: []const u8, comptime x: u16, comptime y: u16, comptime w: u16, comptime h: u16) void {
    if (x < 16 or x + w > 16 + 160)
        fail("room {s}: {s} runs off the screen (x {d} to {d}; the screen is 16 to 175)", .{ name, what, x, x + w - 1 });
    if (x % 4 != 0) fail("room {s}: {s} has x {d}, which isn't on a byte; use a multiple of 4", .{ name, what, x });
    if (y + h > 200) fail("room {s}: {s} runs off the bottom (rows {d} to {d})", .{ name, what, y, y + h - 1 });
}

/// Is there a walkway along row `y`, under `x`?
fn onWalkway(comptime room: anytype, comptime x: u16, comptime y: u16) bool {
    for (room.walkway) |w| {
        if (w.y == y and x >= w.x and x < w.x + 4 * @as(u16, w.length)) return true;
    }
    return false;
}

/// A two-byte value as the Comet stores it: low byte first.
fn le(value: u16) [2]u8 {
    return .{ @truncate(value), @truncate(value >> 8) };
}

fn fail(comptime format: []const u8, args: anytype) noreturn {
    @compileError("castle: " ++ std.fmt.comptimePrint(format, args));
}
```

`door` is the busiest. It checks that the door leads to a door that
leads back (doors come in pairs, one in each room), then works out the
bytes nobody wants to type: which wall of the room it's in on the castle
map (the wall facing the room it leads to) and where along that wall
Chapter 9 should draw it.

:::game-over The castle doesn't build
Every one of these is a real message from the builder (each arrives as
`error: castle: ...`, pointing at `fail`), and every one of them would be
a broken room on a machine that didn't check:

```
castle: room gatehouse: door 0 leads to gallery door 0, which doesn't lead back
castle: room ladders: ladder 0 must start and end on a walkway (rows 128 and 184)
castle: room gatehouse: walkway 0 has length 0, which is the end marker
castle: room gatehouse: door 0 overlaps bell 0
castle: room keys: text 6 ("UP. THEN TRY THE LOCK.") runs off the screen (x 16 to 191; the screen is 16 to 175)
```

The last one caught a line in the Training Castle while it was being
written. A line holds 20 letters; that one had 22.
:::

## The Training Castle

Now the castle itself. Copy `training.zig` from the Warp Zone checkpoint
(`code/ch03/src/training.zig`) over your hand-typed one. It starts with
the room names and a few helpers:

```zig snippet
//! The Training Castle: one lesson per room, written with the authoring
//! kit. Later chapters add each room's machines and monsters.

const author = @import("author.zig");
const art = @import("art.zig");
const Run = author.Run;
const Line = author.Line;

/// Every room, in directory order: room 0 is `gatehouse`.
pub const Room = enum {
    gatehouse,
    gallery,
    ladders,
    poles,
    lightning,
    forcefields,
    trapdoors,
    conveyors,
    transmitter,
    keys,
    ray_guns,
    mummy,
    frankenstein,
    frank_trap,
    frank_ride,
    under_fire,
    mummy_storm,
    locked_away,
    two_players,
    way_out,
};

// The pieces most rooms share.
const floor = Run{ .length = 40, .x = 16, .y = 192 };
const upper_left = Run{ .length = 20, .x = 16, .y = 128 };
const upper_right = Run{ .length = 20, .x = 96, .y = 128 };
const ladder_left = Run{ .length = 9, .x = 56, .y = 128 };
const ladder_right = Run{ .length = 9, .x = 112, .y = 128 };

/// Where room `n` of the snake sits on the castle map: five rooms to a
/// row, the rows running right, left, right, left.
fn spot(n: u8) author.Map {
    const row = n / 5;
    const col = if (row % 2 == 0) n % 5 else 4 - n % 5;
    return .{ .x = 56 + 16 * col, .y = 48 + 24 * row, .width = 4, .height = 3 };
}

/// A room's words: a tall title across the top, then the lesson, a line
/// every 10 rows.
fn says(comptime title: []const u8, comptime lines: []const []const u8) []const Line {
    comptime {
        const x = 16 + (160 - 8 * title.len) / 2 / 4 * 4; // centred, on a byte
        var out: []const Line = &.{.{ .x = x, .y = 8, .color = .yellow, .height = 2, .words = title }};
        for (lines, 0..) |words, i| {
            out = out ++ [_]Line{.{ .x = 16, .y = 32 + 10 * i, .color = .light_grey, .words = words }};
        }
        const done = out[0..out.len].*;
        return &done;
    }
}
```

`spot` lays the rooms out on the castle map as a snake, five to a row,
each row running the other way, so every door leads to a neighbour on the
map. `says` is a comptime function of our own on top of the kit: give it
a heading and the lesson's lines, and it centres the heading in tall
yellow letters and stacks the lines under it. The plan follows, room by
room:

```zig snippet
/// The castle, as declarations.
pub const plan: author.Castle(Room) = .{
    .start = .{ .room = .gatehouse, .door = 0 },
    .rooms = .{
        .gatehouse = .{
            .color = .red,
            .map = spot(0),
            .door = &.{.{ .x = 156, .y = 160, .to = .gallery }},
            .walkway = &.{floor},
            .bell = &.{.{ .x = 140, .y = 168, .door = 0 }},
            .text = says("THE GATEHOUSE", &.{
                "WELCOME, EXPLORER!",
                "EVERY ROOM HAS DOORS",
                "AND MOST ARE SHUT.",
                "STAND AT THE BELL",
                "BESIDE A DOOR AND",
                "PRESS FIRE. WHEN IT",
                "OPENS, STAND IN THE",
                "DOORWAY AND PUSH UP.",
            }),
        },
        .gallery = .{
            .color = .orange,
            .map = spot(1),
            .door = &.{
                .{ .x = 16, .y = 160, .to = .gatehouse },
                .{ .x = 156, .y = 160, .to = .ladders },
            },
            .walkway = &.{floor},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .text = says("THE LONG GALLERY", &.{
                "WALKWAYS ARE THE",
                "CASTLE'S FLOORS.",
                "PUSH THE STICK LEFT",
                "OR RIGHT TO WALK.",
                "THE END OF A WALKWAY",
                "IS AS FAR AS YOU GO.",
                "THE DOOR AT THE FAR",
                "END LEADS ON.",
            }),
        },
        // ... eighteen more rooms, and the final room ...
```

and at the end of the file, the one line that turns the plan into bytes:

```zig snippet
/// The castle file's bytes, built from the plan while the game compiles.
pub const bytes = author.build(Room, plan);
```

The Training Castle teaches one thing per room, then mixes them:

| Room | Name | The lesson | Comes alive in |
|---|---|---|---|
| 0 | The Gatehouse | doors and doorbells | Chapter 5 |
| 1 | The Long Gallery | walking the walkways | Chapter 4 |
| 2 | Ladders | climbing | Chapter 4 |
| 3 | Sliding Poles | sliding down | Chapter 4 |
| 4 | Lightning | lightning machines and their switch | Chapter 6 |
| 5 | Forcefields | forcefields and the timer button | Chapter 6 |
| 6 | Trapdoors | a trapdoor and its switch | Chapter 6 |
| 7 | Conveyors | a conveyor and its control box | Chapter 6 |
| 8 | The Transmitter | the matter transmitter | Chapter 6 |
| 9 | Keys and Locks | a key and its lock | Chapter 7 |
| 10 | Ray Guns | a ray gun and its control panel | Chapter 7 |
| 11 | The Mummy | the mummy and his ankh | Chapter 8 |
| 12 | Frankenstein | the monster | Chapter 8 |
| 13 | A Trap for Frank | Frankenstein and a trapdoor | Chapter 8 |
| 14 | Frank's Ride | Frankenstein and a conveyor | Chapter 8 |
| 15 | Under Fire | a ray gun and a forcefield | Chapter 7 |
| 16 | Mummy in a Storm | the mummy and lightning | Chapter 8 |
| 17 | Locked Away | a key behind a matter transmitter | Chapter 7 |
| 18 | Two's Company | two players and one switch | Chapter 9 |
| 19 | The Way Out | the exit door | Chapter 9 |
| final | You Escaped! | the prize room | Chapter 9 |

Today every room has its walkways, ladders, poles, doors, bells and
words; the machines and monsters move in chapter by chapter, as records
added to these same declarations. Build, press fire, and you're in the
Gatehouse, the picture at the top of the chapter.

## Flipping through the castle

One more feature and you can tour the whole thing. The room on screen
becomes a byte, `room_number`; fire on the title screen sets it from the
castle header's start room; **N** and **P** step it on and back.

**`src/room.zig`** (add two imports below `Color`)

```zig
const hw = machine.hw;
const map = @import("map.zig");
```

**`src/room.zig`** (add below `floor_top`)

```zig
/// The final room isn't in the directory, so it has no colour byte.
const final_color = Color.yellow;

/// Into the castle: the room player 1 starts in.
pub fn start(m: *Machine) void {
    m.poke(map.room_number, m.peek(castle.start_room));
}
```

**`src/room.zig`** (in `draw`, replace the `prepare` line)

```zig
    var walk = prepare(m, m.peek(map.room_number));
```

**`src/room.zig`** (replace `prepare`)

```zig
/// Get room `n` ready to draw: paint the floor pieces its colour, and
/// return a walker at the start of its objects. The room after the last
/// is the final room.
fn prepare(m: *Machine, n: u8) castle.Walker {
    if (n == castle.roomCount(m)) {
        paint(m, both(@intFromEnum(final_color)));
        return .{ .at = m.peek16(castle.final_room) };
    }
    paint(m, roomColors(m, n));
    return .{ .at = m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")) };
}
```

**`src/room.zig`** (add at the end of the file)

```zig
/// N and P on the keyboard: the next or the previous room, with the
/// final room (if the castle has one) after the last. True if it moved.
pub fn flip(m: *Machine) bool {
    const key = m.peek(hw.key);
    if (key == 0) return false;
    m.poke(hw.key, 0); // seen it
    const rooms = castle.roomCount(m);
    const last = if (m.peek16(castle.final_room) != 0) rooms else rooms - 1;
    const n = m.peek(map.room_number);
    m.work(20); // the tests
    const next: u8 = switch (key) {
        'N' => if (n >= last) 0 else n + 1,
        'P' => if (n == 0) last else n - 1,
        else => return false,
    };
    m.poke(map.room_number, next);
    return true;
}
```

`flip` reads the keyboard port, writes 0 to say it's seen the key (card
section 8), and moves `room_number` on or back, round from the last room
to the first. The final room counts as the room after the last, since it
has no directory entry; `prepare` gives it its own colour and finds its
objects through the header. Last, `main.zig`:

**`src/main.zig`** (in `frame`'s `.title` branch, replace the last line)

```zig
            if (player.pressedFire(m)) {
                room.start(m);
                setMode(m, .draw_room);
            }
```

**`src/main.zig`** (in the `.room` branch, add after `player.steer(m);`)

```zig
            m.bucket(0);
            if (room.flip(m)) setMode(m, .draw_room);
```

Press N and `frame` sets the mode to `draw_room`, and the next frame is a
loading pause exactly like Chapter 2's: blank, draw, reveal on the frame
after. The explorer still walks the bottom floor of every room, as
Chapter 2 left him (every Training Castle room keeps a floor there), and
he doesn't climb or open anything yet. Chapter 4 teaches him the castle.

## Tests that read it back

Two tests for the whole game: one that flips rooms the way a player
would, and one that loads the Training Castle and walks every room's
stream to its end tag, checking that each room holds what the plan says
and that the streams sit end to end, the final room last, right up to
the size in the header.

**`src/main.zig`** (add two imports above `training`)

```zig
const castle = @import("castle.zig");
const author = @import("author.zig");
```

**`src/main.zig`** (add at the end of the file)

```zig
test "N and P flip through the castle's rooms, with a loading pause" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This());
    m.input = .{};
    _ = m.runFrame(@This()); // draws room 0
    try std.testing.expectEqual(0, m.ram[map.room_number]);

    m.input = .{ .key = 'N' };
    _ = m.runFrame(@This()); // the key
    m.input = .{};
    try std.testing.expectEqual(0, m.ram[hw.key]); // acknowledged
    _ = m.runFrame(@This()); // draws room 1
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(1, m.ram[map.room_number]);

    // P twice: back to room 0, then round to the final room.
    for (0..2) |_| {
        m.input = .{ .key = 'P' };
        _ = m.runFrame(@This());
        m.input = .{};
        _ = m.runFrame(@This());
    }
    try std.testing.expectEqual(@typeInfo(training.Room).@"enum".fields.len, m.ram[map.room_number]);
}

test "the Training Castle reads back: every room walks to its end tag" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    m.load(map.castle.first, training.bytes);
    try std.testing.expectEqual(castle.magic_value, m.ram[castle.magic]);
    try std.testing.expectEqual(training.bytes.len, m.peek16(castle.size));
    try std.testing.expectEqual(std.enums.values(training.Room).len, castle.roomCount(m));

    // The streams sit end to end after the directory, the final room last.
    var at: u16 = castle.directory + std.enums.values(training.Room).len * @sizeOf(castle.Entry) + 1;
    inline for (comptime std.enums.values(training.Room), 0..) |name, n| {
        try std.testing.expectEqual(at, m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")));
        at = try walkRoom(m, at, @field(training.plan.rooms, @tagName(name)));
    }
    try std.testing.expectEqual(at, m.peek16(castle.final_room));
    at = try walkRoom(m, at, training.plan.final.?);
    try std.testing.expectEqual(castle.header + training.bytes.len, at);

    // And a door says where it goes: the gatehouse's leads to the gallery.
    const first = m.view(castle.Door, m.peek16(castle.entry(m, 0) + @offsetOf(castle.Entry, "objects")) + 3);
    try std.testing.expectEqual(@intFromEnum(training.Room.gallery), first.to_room);
}

/// Walk one room's stream, check it holds what the plan says, and return
/// the address after its end tag.
fn walkRoom(m: *Machine, at: u16, plan: author.Room(training.Room)) !u16 {
    var found = std.enums.EnumArray(castle.Kind, usize).initFill(0);
    var walk = castle.Walker{ .at = at };
    while (walk.next(m)) |r| found.getPtr(r.kind).* += 1;
    inline for (comptime std.enums.values(castle.Kind)) |kind| {
        const list = @field(plan, @tagName(kind));
        const planned = if (kind == .teleport) @intFromBool(list != null) else list.len;
        try std.testing.expectEqual(planned, found.get(kind));
    }
    return walk.at;
}
```

`walkRoom` counts the records of each kind the walker finds and compares
them with the plan's lists, using the same `inline for` over the kinds as
the builder. If the writer and the reader ever disagreed about one byte
of the format, this test would be the first to say so.

:::byte-budget Chapter 3
**Memory.** The Training Castle is **4,324 bytes** of its 8 KB region:
the 256-byte header, a 161-byte directory (20 rooms and the end byte) and
3,907 bytes of object streams. Two thirds of the whole castle, 2,876
bytes, is text: 2,316 letters and four bytes of position, colour and
style per line. The geometry of twenty rooms fits in about a kilobyte.
The shape table grew to 1,691 bytes with the doorways, the doors and the
bell. The game's own state grew by one byte, `room_number`, and the text
region by 32.

**Time.** A room draws in **132,000 to 221,000 cycles**, 7 to 12 frame
slots, a fifth of a second of blank screen at worst. `clear` is 80,000 of
that, and nearly all the rest is letters: a plain letter costs about 670
cycles to build and stamp, a tall one about 1,160. Walking the stream
itself costs a few dozen cycles per record. Once a room is up, a frame costs
108 cycles, four more than Chapter 2 for the look at the keyboard, and
about 360 on the frame a key arrives.
:::

:::inside-the-disk Castles by the kilobyte
The fourteen castles on the 1984 disk run from about 2 KB to about 6 KB
each; the disk's own tutorial castle is thirteen rooms in 4,145 bytes. A
castle file is loaded straight to `$7800` and played where it lands, and
the game writes into it as you play, in the header's spare bytes and
in the rooms' own records: an open door is a door record with bit 7 set.

And the **skip** word, bytes 4 and 5 of every directory entry? On the
disk it always holds the room's objects address plus 2, the address
after the room's first tag, and nothing in the game ever reads it. Perhaps the castle
editor needed it; the game never did. Our
builder writes it the same way, so a castle we make looks like one of
theirs, down to the bytes nobody uses.
:::

:::game-over Common mistakes
- **`castle: that's not an object code`.** The walker found something it
  can't read as a tag: a hand-typed group with a record too many or too
  few, or a missing end marker. Count again, or let the builder do it.
- **Walkways in the wrong colour, or in Chapter 2's colours.** `paint`
  must run before anything is drawn, and the floor pieces must be the new
  `art.zig`'s (bricks in code 01, mortar in code 00).
- **Cells that change colour around a ladder.** The ladder or pole wasn't
  repainted along with the walkways, so its cells carry their own
  colours. All five floor pieces go through `paint`.
- **A doorbell in the wrong colour.** It found the wrong door: `doors`
  must be set at the room's first door record, and a bell's `door` is the
  door's place in the room's list, from 0.
- **Text that runs on into garbage.** A string without a bit-7 letter
  never ends. `text.terminated` (and the builder, which uses it) always
  marks the last letter; hand-typed text has to remember to.
- **N does nothing, or skips two rooms.** `flip` must write 0 to `$DC02`
  once it has the key, or every frame sees the same key again.
:::

:::boss-battle Tour the castle
From your project folder:

```
zig build
zig build test
zig build run -- --frames 300 --press 20:f:5 --key 60:N --key 100:N --key 140:P --key 180:P --key 220:P --dump-every 20
```

The run presses fire on the title, then N twice and P three times, which
goes up to room 2, back to room 0, and round to the final room. It
prints:

```
ran 300 frames (233 calls to frame)
cycles: max 221418 (1126%), avg 6300 (32%) of 19656
  bucket 0: max 274, avg 26
  bucket 1: max 220758, avg 6176
  bucket 2: max 644, avg 97
overruns: 0, loading pauses: 7
last frame: frames/frame_00299.ppm
```

The seven loading pauses are the title, room 0 and the five key presses.
`frame_00040.ppm` is the Gatehouse, `frame_00080.ppm` the Long Gallery,
`frame_00120.ppm` the Ladders room, and from `frame_00240.ppm` on it's
the final room:

![The final room: YOU ESCAPED! in tall yellow letters over a yellow trophy and six sparkles, the words THE TRAINING CASTLE IS BEATEN., a yellow floor and the explorer](images/03-final.png)

Then play it:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000>, press Space on the title, and use N and P
to walk the whole castle, room by room.

**You've built a castle!** It's 4,324 bytes, every one of them written
by the compiler from declarations you can read, and the engine that draws
it doesn't know a single room by heart. Next chapter, the explorer learns
to use what you built.
:::

:::warp-zone
The finished checkpoint is [`code/ch03/`](../code/ch03/), also as a
download, [`ch03.zip`](downloads/ch03.zip), which unzips into the same
`code/` folder as the others. The two bulk files are
[`code/ch03/src/art.zig`](../code/ch03/src/art.zig) and
[`code/ch03/src/training.zig`](../code/ch03/src/training.zig). To start
Chapter 4 from a known-good game, replace your project with it:

```
cd code
rm -rf my-creep
cp -r ch03 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```
:::

:::bonus-stage
- **Design your own room.** Add a name to `Room` (at the end, so the
  room numbers you know don't move), a door pair to link it in, and a
  room in the plan. The builder will tell you everything you got wrong.
  Then try to break it on purpose and read the messages.
- **A castle of your own.** Make a second plan in a new file, with its
  own `Room` enum, and load its bytes instead of `training.bytes`. Five
  rooms is a castle.
- **Hex dump.** Write a test that prints the Training Castle's first 64
  bytes with `std.debug.print("{x:0>2} ", ...)`, and find the header, the
  directory and the Gatehouse's door in it.
- **Reversed text.** Set bit 4 of a line's style (you'll need to add a
  field to `Line`, and set the bit in the builder's text branch) and
  watch the letters cut out of a block.
- **Room numbers on screen.** Print the room's number in a corner when
  it's drawn. You'll need to turn a byte into digits, which Chapter 9
  does properly.
:::
