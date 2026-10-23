---
chapter: 1
title: "It's Alive!"
checkpoint: ch01
---

:::mission-briefing
By the end of this chapter the Comet 64 will show a castle floor, and
standing on it, a little explorer in a hat who goes wherever you push the
joystick. Press fire and he changes colour.

![The Chapter 1 checkpoint: a blue border, a grey stone floor, and the explorer sprite standing on it](images/01-its-alive.png)

On the way you'll meet the machine properly. You'll find out that all of
its memory is one long row of bytes, that every colour on the screen is
a number sitting at an address, why addresses are written in hex, and
how a joystick fits five switches into a single byte. You'll also lay
down the first entry in the game's **memory map**, the table that will
keep track of every byte the game uses from here to the final chapter.

New under the hood: **bytes and `u8`**, **memory as one big array of
addresses**, **hex**, and **a single bit as an on/off switch**.
:::

## Plug in, power up

Think back to the first time a game answered you. You pushed the stick
and a little figure on the screen moved, right away, exactly as far as
you pushed. It's so basic that you forget it's the moment a game comes
alive. Everything else (the ladders, the doors, the monsters) is built
on top of that one loop: read the stick, move the figure, draw it, fifty
times a second.

That's this chapter. By the end, the Comet 64 will be doing all of it
with code you wrote, and you'll know what every line is doing to the
machine.

Open your `my-creep` project from the Prologue. Before we touch the game,
one bit of housekeeping. The starter kit names its headless runner
`starter`, and this isn't a starter kit any more. It's Dr. Creep.

**`build.zig`** (change the name)

```zig
const std = @import("std");
const machine = @import("machine");

pub fn build(b: *std.Build) void {
    machine.addGame(b, .{ .name = "creep", .root = b.path("src/main.zig") });
}
```

That's the last time we'll change `build.zig`. Everything from here on
happens in `src/`.

## 65,536 bytes in a row

Here's the whole of the starter's `src/main.zig`:

```zig
//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const machine = @import("machine");
const Machine = machine.Machine;

// Two VIDEO chip registers. Each holds a colour number (0-15).
const border_color = 0xD020;
const background_color = 0xD021;

pub fn boot(m: *Machine) void {
    m.poke(border_color, 4); // purple
    m.poke(background_color, 0); // black
}

pub fn frame(m: *Machine) void {
    _ = m;
}
```

Two functions. The machine calls `boot` once, when it powers on, and
`frame` fifty times a second after that. Both get `m: *Machine`, "a
pointer to a `Machine`": like passing an object to a function in
JavaScript, `boot` gets the machine itself, not a copy of it. (Chapter 2
shows what a pointer really is.) And `boot` does one thing, twice: `m.poke(address, value)`.

To see what that means, here's the most important line in the whole
Comet 64, from the machine's own definition in `machine/src`:

```zig snippet
ram: [0x10000]u8 = @splat(0),
```

That's an array of 65,536 bytes (`0x10000` is 65,536; we'll get to the
notation in a moment), all starting at zero. **That's all the memory the
computer has.** Your game's data, the castle, the picture on the screen,
the joystick, the chips that make the picture: every one of them lives
somewhere in that one array.

An **address** is an index into it. Address 0 is the first byte; address
65,535 is the last. "Poke 4 into address `0xD020`" means "set
`ram[0xD020]` to 4". "Peek at address `0xDC01`" means "read
`ram[0xDC01]`". The 1980s names stuck around because they're good names.

:::under-the-hood Where does `x` live?
In JavaScript you write

```js
let x = 0;
```

and the engine finds somewhere to keep `x`. You don't know where, and
you don't need to: maybe it's in a CPU register, maybe it's on a stack,
maybe it's a slot in a closure object somewhere on the heap. The engine
moves things around, grows the heap when it fills, and cleans up after
you. Your program has gigabytes to play with and never sees an address.

The Comet 64 has 64 KB, and it hands all of it to you. There's no engine
deciding where things go, because there's nobody else to decide. So in
this game, `x` doesn't live "somewhere". It lives at **`$0200`**,
because we'll say so, and anyone who wants to know where the player is
can read that byte. Picking those addresses, and writing them down so two
things never pick the same one, is a big part of what writing a game for
this machine is. We'll start doing it shortly.

And the cost is out in the open: in this game, `x` costs exactly one
byte, and reading it costs 4 cycles. You'll know both numbers for every
piece of state you ever add.
:::

### A byte, and why it stops at 255

Each element of `ram` is a `u8`: an **unsigned 8-bit integer**. That's
Zig for "a byte". It's eight bits, each one a 0 or a 1, and eight bits
can be arranged 2×2×2×2×2×2×2×2 = **256** different ways. So a `u8` holds
any whole number from 0 to 255, and nothing else.

```
  bit:   7     6     5     4     3     2     1     0
       ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
       │  1  │  1  │  1  │  1  │  1  │  1  │  1  │  1  │  = 255, the biggest u8
       └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
  worth: 128    64    32    16     8     4     2     1
```

Each bit is worth twice the one to its right, the same way each digit in
a decimal number is worth ten times the one to its right. Add up the
worths of the bits that are on and you have the byte's value. All eight
on is 128 + 64 + 32 + 16 + 8 + 4 + 2 + 1 = 255. To write 256 you'd need a
ninth bit, worth 256, and a byte doesn't have one.

That sounds like trivia, but it's going to stop our explorer in his
tracks before the chapter's out. In JavaScript every number is a 64-bit
float and you never think about how big it can get. On the Comet 64,
nearly every number in the game is a byte, and a byte runs out at 255.

:::pro-tip Zig knows how big a byte is
Integer literals in Zig (`4`, `0xD020`, `255`) don't have a size of
their own. They take the type of wherever you put them, and Zig checks,
at compile time, that they fit:

```zig snippet
const x: u8 = 256;
```

```
error: type 'u8' cannot represent integer value '256'
```

The same goes for passing a number to `m.poke`, whose value parameter is
a `u8`. Try `m.poke(border_color, 300)` and the build fails. This is
one of Zig's quiet superpowers for this kind of work: a whole class of
"why is the screen the wrong colour" bugs becomes a compile error. (What
happens when a byte overflows *while the game is running* is a story for
Chapter 4. Spoiler: Zig stops the game and tells you.)
:::

## Counting in hex

You've probably seen numbers like `0xFF` in JavaScript, or colours like
`#FF8800` in CSS. That's **hexadecimal**, base 16. Instead of ten digits
it has sixteen: `0`–`9`, then `A` (10), `B` (11), `C`, `D`, `E`, up to
`F` (15). In Zig, as in JavaScript, a hex number starts with `0x`. The
Comet 64's reference card writes the same numbers with a `$` in front,
which is how programmers of its day wrote them: `$D020` on the card is
`0xD020` in your code.

Why bother? Because **one hex digit is exactly four bits**:

| Hex | Bits | | Hex | Bits |
|---|---|---|---|---|
| `0` | `0000` | | `8` | `1000` |
| `1` | `0001` | | `9` | `1001` |
| `2` | `0010` | | `A` | `1010` |
| `3` | `0011` | | `B` | `1011` |
| `4` | `0100` | | `C` | `1100` |
| `5` | `0101` | | `D` | `1101` |
| `6` | `0110` | | `E` | `1110` |
| `7` | `0111` | | `F` | `1111` |

So **two hex digits are exactly one byte**, `$00` to `$FF`, and **four
hex digits are exactly one address**, `$0000` to `$FFFF`. Decimal doesn't
line up with bits at all; hex lines up perfectly. You can read a byte's
bits straight off its hex: `$A5` is `1010` `0101`.

It pays off most with addresses. Here's part of the Comet 64's memory
map from the reference card, in both bases:

| What | Hex | Decimal |
|---|---|---|
| Sprite frames | `$C000` | 49,152 |
| Screen plane | `$CC00` | 52,224 |
| VIDEO chip | `$D000` | 53,248 |
| Colour RAM | `$D800` | 55,296 |
| Joystick ports | `$DC00` | 56,320 |
| Bitmap | `$E000` | 57,344 |

In decimal those are noise. In hex they're round numbers, and you can
see the structure: everything from `$D000` to `$DFFF` is hardware, the
VIDEO chip's registers start at `$D000`, and the border colour is
register `$20` of it, at `$D020`. The first two hex digits of an address
tell you which 256-byte **page** of memory you're in (`$D0`), and the
last two tell you where in that page (`$20`). Once you've used it for an
hour you'll find decimal addresses hard to read.

:::widget memory-map
All 64 KB of the Comet 64 as one strip, coloured by region and labelled
from the reference card. Hover to see an address in hex and decimal and
the region it's in.
:::

Open the reference card, [`machine/REFERENCE.md`](../code/machine/REFERENCE.md),
and look at section 2, the memory map. That's the floor plan of the
machine. Keep it open in a tab; we'll be in and out of it all chapter.

## A colour is a byte at an address

Back to `boot`:

```zig snippet
m.poke(border_color, 4); // purple
```

`border_color` is `0xD020`. The card's section 4 says `$D020` is the
**border colour** register: the VIDEO chip reads that byte every time it
draws the border, and the palette in section 10 says colour 4 is purple.
So that line puts the number 4 at address `$D020`, and the border is
purple. That's the whole trick. There isn't a `setBorderColour` function
anywhere in the machine. There's a byte, and the chip looks at it.

Try it. Change the `4` to a `6`, run `zig build wasm`, and reload the
page (with the Prologue's web server still running), and the border
turns blue. One number,
one byte, one colour. **This is the big idea of the chapter, and of the
whole machine: the hardware is memory.** The screen, the sprites and the
joysticks are all bytes at fixed addresses, and you work them by reading
and writing those bytes.

Now let's tidy up. The starter defines its own names for the two
addresses, but the machine already has a name for every one of them, in
`machine.hw`, listed in the card's Zig-name column. And the colours have
names too: `machine.Color` is an enum of the sixteen palette entries,
and `@intFromEnum` turns one into its palette number.

**`src/main.zig`** (replace the whole file)

```zig
//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
}

pub fn frame(m: *Machine) void {
    _ = m;
}
```

`hw.border` is `0xD020` and `Color.blue` is 6, so this does exactly what
your edit did. The difference is that the next person to read it (you,
in three weeks) doesn't need the card open to know what it means. From
here on, addresses in game code are always named constants. A bare
`0xD020` in the middle of a function is a puzzle; `hw.border` is a
sentence.

:::pro-tip `_ = m;`
Zig refuses to compile a function that ignores one of its parameters.
`_ = m;` is how you say "yes, I know, I'm not using it yet." It goes
away as soon as `frame` has something to do.
:::

## Laying a floor

A castle room needs a floor, and the floor is our first look at the
screen itself. The card's section 3 has the full story of how the
display works, and Chapter 2 is all about it. For now you need three
facts.

1. The display is 320 × 200 pixels, split into **cells** of 8 × 8: 40
   cells across, 25 rows of cells down.
2. The **bitmap**, 8,000 bytes from `$E000`, holds the pixels. Each cell
   gets 8 bytes in a row, one per line of the cell, and the cells run
   left to right, then top to bottom. So each row of cells is 40 × 8 =
   320 bytes.
3. A bitmap byte of `$FF` (all eight bits on) paints its piece of the
   line in the colour held in **colour RAM**, a second plane of 1,000
   bytes from `$D800`, one byte per cell.

So a floor along the bottom of the screen is two runs of bytes: the
bitmap bytes of cell row 24 set to `$FF`, and the colour RAM bytes of
row 24 set to a colour. Where do those runs start? Row 24 begins 24 × 320
= 7,680 bytes into the bitmap, and 7,680 is `$1E00`, so:

```
  bitmap:      $E000 + $1E00 = $FE00    (320 bytes, $FE00–$FF3F)
  colour RAM:  $D800 + 24 × 40 = $D800 + $3C0 = $DBC0    (40 bytes, $DBC0–$DBE7)
```

Both runs end on the last byte of their plane, which is a good sign we
did the sums right: the floor is the bottom row, so it should go right to
the end.

Make a new file for the room. It'll grow into the room-drawing code in
the chapters to come.

**`src/room.zig`** (new file)

```zig
//! The room: for now, a floor along the bottom of the screen.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;

/// The floor is the bottom row of cells, row 24 of 0-24.
const floor_row = 24;
const cells_per_row = 40;
const bytes_per_cell = 8;

/// Display row (0-199) of the floor's top line.
pub const floor_top = floor_row * 8; // 192

/// Where the floor starts in the bitmap and in colour RAM.
const floor_pixels = hw.bitmap + floor_row * cells_per_row * bytes_per_cell; // $FE00
const floor_colors = hw.color_ram + floor_row * cells_per_row; // $DBC0

pub fn paint(m: *Machine) void {
    // $FF gives all four pixels of a bitmap byte the code 11, and code 11
    // pixels take their colour from colour RAM.
    m.fill(floor_pixels, cells_per_row * bytes_per_cell, 0xFF);
    m.fill(floor_colors, cells_per_row, @intFromEnum(Color.grey));
}
```

We let Zig do the sums (`floor_pixels` works out to `0xFE00` at compile
time) and leave the answer in a comment, so a reader can check it
against the card. `m.fill(address, count, value)` sets `count` bytes in a
row to `value`: here, 320 bitmap bytes to `$FF` and 40 colour bytes to
grey. (The comment mentions "four pixels" and "code 11": a bitmap byte
actually holds four double-width pixels of two bits each. Chapter 2
unpacks that. Here, all bits on means colour RAM's colour, and that's all
we need.)

A Zig file keeps its declarations to itself unless they're marked
`pub`: `paint` and `floor_top` are public, and the rest is private to
the room. Now call it from `boot`.

**`src/main.zig`** (add the import below `hw`, and call `room.paint` in `boot`)

```zig
const hw = machine.hw;
const room = @import("room.zig");

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    room.paint(m);
}
```

Build it for the browser and reload: a strip of grey stone runs along the
bottom of the black display. Every pixel of it is a byte you put there.

## Fifty times a second

Before we put anything on that floor that moves, let's look at `frame`
properly, because it's the heartbeat of the whole game.

The machine calls `frame` fifty times a second, and each call is one
**frame**: one picture on the screen. There's no "move left for half a
second" call anywhere. Motion is an illusion built out of tiny changes:
each frame, the game reads the joystick, moves the explorer one pixel,
and the screen shows him one pixel further along. Do that fifty times a
second and the eye sees him walk. Every game of the era worked this way,
and so will every system we build: the doors, the conveyors, the
monsters. Each does a little bit of its job every frame.

Here's the catch, and it's the rule this whole tutorial is played by.
**A frame has a time limit.** The Comet 64's processor runs 19,656
**cycles** per frame (312 lines of 63 cycles each; you'll see why
shortly), and everything your `frame` does has to fit. Every operation
costs something: a peek or a poke is 4 cycles, a `fill` or `load` is 8
per byte, and your own sums and decisions you charge with `m.work(n)`.
The card's section 9 has the full price list.

The machine adds up what you spend on the **work meter**. Remember the
thin bar in the bottom border? That's it. It fills from left to right as
a frame uses more of its budget: green while you're under three
quarters, yellow when it's getting tight, and red, with a red stripe
across the border, if a frame goes over. The headless runner reports the
same numbers in its summary.

If you've written a JavaScript game, you've met this as "keep each frame
under 16 ms". The difference is that your browser's 16 ms is millions of
operations, and you mostly hit the limit when something goes badly
wrong. On the Comet 64, 19,656 cycles is about 4,900 peeks. Redrawing
the bitmap a byte at a time would take 32,000 cycles for the pokes
alone: well over a whole frame. So every chapter of this tutorial has a
second job besides "make it work": make it fit. Think of it as the
level's clock.

`boot` doesn't count, by the way. The meter starts with the first frame,
so the 2,880 cycles of `m.fill` that lay the floor are on the house.

:::widget budget-meter
The work meter for this chapter's checkpoint, live: one bar per frame,
the frame's budget marked, and the cycles of the last frame in numbers.
:::

## The memory map

The explorer needs a position, and the position has to survive from one
frame to the next. In most languages you'd reach for a global:

```zig snippet
var player_x: u8 = 160; // not in this game
```

Zig would compile that. We don't write it, and the rule is absolute for
the whole tutorial: **all of the game's changing state lives in
`m.ram`.** Constants (tables, pictures, the castle you ship) are fine as
Zig `const`s: they're part of the program image, the code and data
you'd have on the disk. But anything that changes while the game runs
gets an address.

Why be so strict? Because on a 64 KB machine, a byte nobody wrote down
is a byte you'll end up spending twice. A Zig `var` would be tucked away
inside the program image, at an address only the compiler knows, where
the memory map can't account for it. In 1984 there's no "somewhere else":
there's the 64 KB, and you decide what goes where. The rule pays for
itself in other ways too. Every bit of state is in one
place, so the memory-map widget can show it live, a test can check it,
and you can never wonder where something is: it's wherever the memory
map says.

The **memory map** is the game's own record of which addresses it uses
for what. It starts tiny here and grows every chapter, and Zig checks it
for us. Here's the plan for this chapter:

| Address | Bytes | What |
|---|---|---|
| `$0100–$01FF` | 256 | the processor's stack (reserved: hands off) |
| `$0200–$0203` | 4 | **the player** |
| `$0800–$77FF` | 28 KB | the program image (reserved) |
| `$C000–$C7FF` | 2 KB | sprite frames |
| `$CFF8–$CFFF` | 8 | sprite pointers |
| `$D000–$D02E` | 47 | the VIDEO chip |
| `$D800–$DBE7` | 1,000 | colour RAM |
| `$DC00–$DC02` | 3 | input ports |
| `$E000–$FF3F` | 8,000 | the bitmap |

Only one row in there is ours: four bytes at `$0200`, the first free
address above the stack. The others belong to the hardware, but they go
in the map anyway, so that nothing of ours can ever land on top of them.
Here's what the player's four bytes hold:

```
    $0200      $0201         $0202              $0203
┌──────────┬──────────┬──────────────┬───────────────────┐
│ player_x │ player_y │ player_color │ player_last_stick │
└──────────┴──────────┴──────────────┴───────────────────┘
```

**`src/map.zig`** (new file)

```zig
//! The game's memory map: every stretch of memory the game uses, and
//! what it's for. Nothing the game remembers lives anywhere else.

const hw = @import("machine").hw;

pub const Region = struct {
    name: []const u8,
    first: u16,
    last: u16,
};

// ---- the game's own memory ----------------------------------------------

/// Everything the game knows about the player, four bytes in a row.
pub const player = Region{ .name = "player", .first = 0x0200, .last = 0x0203 };
pub const player_x = player.first + 0; // sprite X, 24 (left edge) to 255
pub const player_y = player.first + 1; // sprite Y, 50 (top edge) and down
pub const player_color = player.first + 2; // palette number, 1-15
pub const player_last_stick = player.first + 3; // joystick 1 as it read last frame

// ---- memory the hardware gives us ---------------------------------------

const stack = Region{ .name = "stack (reserved)", .first = hw.stack, .last = hw.stack + 256 - 1 };
const program = Region{ .name = "program image", .first = hw.program, .last = hw.program_end - 1 };
const sprite_frames = Region{ .name = "sprite frames", .first = hw.sprite_data, .last = hw.sprite_data + 32 * 64 - 1 };
const sprite_pointers = Region{ .name = "sprite pointers", .first = hw.sprite_pointers, .last = hw.sprite_pointers + 8 - 1 };
const video_chip = Region{ .name = "VIDEO chip", .first = hw.video_chip, .last = hw.spriteColor(7) };
const color_ram = Region{ .name = "colour RAM", .first = hw.color_ram, .last = hw.color_ram + 1000 - 1 };
const input_ports = Region{ .name = "input ports", .first = hw.joy2, .last = hw.key };
const bitmap = Region{ .name = "bitmap", .first = hw.bitmap, .last = hw.bitmap + 8000 - 1 };

/// The whole map, in address order.
pub const regions = [_]Region{
    stack,
    player,
    program,
    sprite_frames,
    sprite_pointers,
    video_chip,
    color_ram,
    input_ports,
    bitmap,
};

// Checked while the game compiles: two regions sharing a byte is a build
// error, not a mystery bug three chapters from now.
comptime {
    for (regions, 0..) |a, i| {
        if (a.last < a.first) @compileError("memory map: " ++ a.name ++ " ends before it starts");
        for (regions[i + 1 ..]) |b| {
            if (a.first <= b.last and b.first <= a.last)
                @compileError("memory map: " ++ a.name ++ " overlaps " ++ b.name);
        }
    }
}
```

A few things to notice.

**Addresses are `u16`.** Two bytes, sixteen bits, 0 to 65,535: exactly
enough to name every byte in a 64 KB machine. That's not a coincidence.
The Comet 64 has 64 KB *because* its addresses are 16 bits wide.

**Each region records its first and last byte**, the same way the card
writes ranges (`$0200–$0203`). The player's four field addresses are
worked out from the region's start, so if the player ever moves, it
moves in one place. Naming convention, from here to the end: a region is
a `Region` constant named for what it holds, and its fields are
`u16` address constants named `region_field`, all in `map.zig`. The
hardware regions work their last byte out from the card's sizes
(`hw.bitmap + 8000 - 1`), so each line explains itself instead of
asking you to check a number.

**The `comptime` block runs while Zig compiles your game**, not while it
runs. It compares every region with every region after it (two ranges
overlap when each starts before the other ends), and if two share even
one byte, `@compileError` stops the build and says which two. By the time
the game boots, the check has already passed, so it costs the Comet 64
nothing. Chapter 3 builds whole castle rooms with `comptime`; this is
the gentlest possible start.

A little new syntax, in passing: `[_]Region{...}` lets the compiler count
the array's length for you; `for (regions, 0..) |a, i|` walks the array
with each element's index alongside; `regions[i + 1 ..]` is a slice, the
rest of the array after `i`; `++` joins strings, which works because
everything here is known at compile time. And `//!` comments describe
the whole file, while `///` comments describe the declaration below them.

:::game-over Two things in one place
Say that one day you give the monsters a table at `$01F0` without
checking the map. Without the check, the monster table and the
processor's stack would quietly share bytes, and you'd find out weeks
later when the game crashed only on Tuesdays. With it:

```
error: memory map: stack (reserved) overlaps monsters
```

The fix is to give one of them a different address. That's the whole
point of keeping the map: collisions between regions become compile
errors, the cheapest kind of bug there is.
:::

## A sprite is 63 bytes

Now for the star of the show.

You know sprites from the player's side: the figures that glide around
over the background without smudging it, which flicker when too many
crowd onto one line. On the Comet 64 they're a feature of the VIDEO chip.
It can draw up to **eight** of them, anywhere on the display, over the
top of the bitmap. You don't draw a sprite into the bitmap at all. You
hand the chip a picture and a position, and it draws it as the screen is
painted, every frame, for free. Change the position, and next frame
the sprite is somewhere else. That's why every game of the era used them
for whatever moved: the player, the monsters, the bullets.

The card's section 5 has the details. A sprite's picture is **24 pixels
wide and 21 tall**, and in the plain kind, a **hires** sprite, each pixel
is **one bit**: 1 is a pixel in the sprite's colour, 0 is see-through.
Twenty-four bits is three bytes, so each row is three bytes and the
whole picture is 21 × 3 = **63 bytes**.

This is the first place you meet the chapter's fourth idea, the **single
bit as an on/off switch**: a pixel is on or off, and one bit says which.
And because each bit is a pixel, we can write the picture so you can see
it. Zig has binary literals: `0b00111100` is the byte whose bits are
`00111100`, which is `$3C`, or 60. Lay three of those per line and the
1s draw the picture.

**`src/player.zig`** (new file)

```zig
//! Player 1: a hires sprite you steer with joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const video = machine.video;
const map = @import("map.zig");
const room = @import("room.zig");

/// The player's picture: 21 rows of 24 pixels, three bytes a row, one bit
/// per pixel. A 1 is a pixel in the sprite's colour; a 0 is see-through.
const picture = [63]u8{
    0b00000000, 0b00000000, 0b00000000,
    0b00000000, 0b00111100, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000001, 0b11111111, 0b10000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01011010, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b00111100, 0b00000000,
    0b00000000, 0b00011000, 0b00000000,
    0b00000001, 0b11111111, 0b10000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b11100111, 0b00000000,
};

/// The player is sprite 0, showing sprite block 0.
const sprite = 0;
const block = 0;

/// How far the sprite may go. X stops at 255 because that's the most a
/// byte can hold; the right-hand strip of the screen needs a ninth bit.
const min_x = video.sprite_origin_x;
const max_x = 255;
const min_y = video.sprite_origin_y;
const max_y = video.sprite_origin_y + room.floor_top - 21; // boots on the floor

pub fn start(m: *Machine) void {
    m.load(hw.sprite_data + block * 64, &picture);
    m.poke(hw.sprite_pointers + sprite, block);
    m.poke(hw.sprite_enable, 0b0000_0001); // bit 0 on: sprite 0 is shown

    m.poke(map.player_x, 160);
    m.poke(map.player_y, max_y);
    m.poke(map.player_color, @intFromEnum(Color.white));
    m.poke(map.player_last_stick, 0xFF); // nothing held
}
```

Squint at the `picture` table and you can see him: a hat with a brim, a
face with two eyes (the two 0s in the middle of `01011010`), arms held
out from the body, two legs and a pair of boots. The top row is empty
and the boots are on the very bottom row, which will matter when we
stand him on the floor. Draw your own if you like (the Bonus Stage has
ideas); keep it to 63 bytes.

`start` sets everything up, once, at power-on:

- **`m.load`** copies a `const` table from your program into memory, here
  into sprite block 0 at `$C000`. `&picture` hands `load` the table's
  address rather than a copy of its 63 bytes: in front of a name, `&`
  means "address of". (Between two numbers, as you'll see shortly, it
  means something else entirely.) Sprite pictures live in 64-byte blocks
  from `$C000` (63 bytes of picture and one spare, so the arithmetic
  stays round: block *N* starts at `$C000 + N × 64`).
- **The sprite pointer** for sprite 0, at `$CFF8`, says which block
  sprite 0 shows. Swapping that one byte for another block number is how
  sprites animate, a trick we'll lean on hard from Chapter 2.
- **`$D015` turns sprites on**, one bit per sprite. Bit 0 is sprite 0,
  bit 1 is sprite 1, and so on up to bit 7. Writing `0b0000_0001` sets
  bit 0 and leaves the other seven off: sprite 0 on, the rest hidden.
  Eight sprites, eight bits, one byte. You'll see that pattern all over
  the VIDEO chip.
- Then the player's own four bytes: a starting position, a colour, and
  `player_last_stick`, which we'll come to.

The limits deserve a look. **Sprite coordinates count from above and to
the left of the display**, so that a sprite can slide in from off-screen:
X = 24, Y = 50 puts the sprite's top-left pixel on the display's
top-left pixel. `machine.video.sprite_origin_x` and `sprite_origin_y`
hold those two numbers. The top limit, `min_y`, is the top of the
display; the bottom, `max_y`, puts the bottom row of the picture on the
line above the floor: 50 + 192 − 21 = 221. On the left, `min_x` is
the display's left edge.

And on the right, `max_x` is 255. That's the most a byte can hold, and
the player's X is a byte. The display is 320 pixels wide, so sprite X
ought to go up to 24 + 320 − 24 = 320; the VIDEO chip keeps a ninth bit of
X for each sprite, in `$D010`, to get there. We're not using it yet. So
our explorer will stop about three quarters of the way across, at an
invisible wall made of arithmetic. Remember that wall: you'll see it
in a minute.

:::pro-tip Underscores and binary
Zig lets you put `_` anywhere inside a number to make it readable:
`0b0000_0001`, `0xFF_FF`, `1_000_000`. The compiler ignores them. For a
byte of separate on/off bits, `0b0000_0001` says much more than `1`,
even though it's the same number.
:::

Now call `start` from `boot`.

**`src/main.zig`** (add the import below `room`, and call `player.start` in `boot`)

```zig
const room = @import("room.zig");
const player = @import("player.zig");

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    room.paint(m);
    player.start(m);
}
```

Build and reload. The floor's there. The explorer isn't.

That's not a bug in the picture. Look at what `start` wrote: the
picture, the pointer, the enable bit, and four bytes at `$0200`. It never
told the VIDEO chip *where* to draw sprite 0, or in what colour. The chip's position
registers, `$D000` and `$D001`, are still 0 from power-on, and (0, 0)
is up and to the left of the display, off in the border where sprites
don't show. (His colour register is still 0 too: black, on a black
screen.) The explorer's position is in *our* memory, at `$0200`.
Something has to copy it into the chip.

## Racing the beam

The copying happens every frame, and there's one rule about *when*.

The Comet 64's picture is drawn by a beam that sweeps down the tube from
top to bottom, one line at a time, fifty times a second. The VIDEO chip
draws each line from the registers and memory **as they are at the
moment the beam passes**. Your `frame` starts with the beam at the very
top of the tube, and as your code spends cycles, the beam moves down: 63
cycles per line. It reaches the top of the display after **3,213
cycles**.

So here's the rule: **write your hardware registers at the start of
`frame`.** Anything you write in the first 3,213 cycles is in place
before the beam gets to the display, and the whole picture shows it.
Write a sprite's registers later, while the beam is halfway down the
sprite, and the top half is drawn the old way and the bottom half the
new way. That's a **tear**, and you've seen it in games, as a figure
that seems to split for a frame when it moves.

There's plenty more to say about the beam (the card's section 6 has it,
and a later chapter explains what really happens between frames). For
now the habit is enough: hardware first, then think.

**`src/player.zig`** (add below `start`)

```zig
/// Copy the player's position and colour into the VIDEO chip.
pub fn show(m: *Machine) void {
    m.poke(hw.spriteX(sprite), m.peek(map.player_x));
    m.poke(hw.spriteY(sprite), m.peek(map.player_y));
    m.poke(hw.spriteColor(sprite), m.peek(map.player_color));
}
```

`hw.spriteX(n)`, `hw.spriteY(n)` and `hw.spriteColor(n)` are small
functions that give sprite *n*'s register addresses (`$D000 + 2n`,
`$D001 + 2n` and `$D027 + n`). Three peeks and three pokes: 24 cycles,
well inside the 3,213.

**`src/main.zig`** (replace `frame`)

```zig
pub fn frame(m: *Machine) void {
    // Hardware first. The beam reaches the top of the display 3,213
    // cycles into the frame; registers written before then can't tear.
    player.show(m);
}
```

Build and reload, and there he is: white, standing on the grey floor.

**It's alive!** Well, it's standing there. Close enough for one more
section.

:::secret-passage Coming up: a tear
Want to see a tear for yourself? Once the explorer can move and change
colour, there's a Secret Passage at the end of "Fire!" that breaks him
on purpose.
:::

:::inside-the-disk The shadow registers
The 1984 disk follows the same rule, and goes one better. The game's
logic doesn't write the VIDEO chip's sprite registers directly. It
keeps a **shadow copy** of them, 30 bytes near the very bottom of
memory: every sprite's X and Y, the ninth-bit byte, the enable bits,
the border colour, a couple of screen-control bytes and all eight
sprite pointers. The game logic reads and writes only the shadow. Then
the frame interrupt, first thing every frame, copies the whole shadow
into the chip in one go.

That means the game can move a sprite whenever it likes, halfway through
working out a monster's move, say, and the chip never sees a half-finished
position. Our `show` is the same idea, one sprite wide: the player's
bytes at `$0200` are the shadow, and `show` copies them into the chip
before the beam arrives.
:::

## Reading the joystick

Now let's give him somewhere to go.

From the player's side, a joystick is a stick and a button. From the
machine's side, it's five switches: up, down, left, right and fire. Each
switch is either closed (pressed) or open (not), which is one bit of
information, so the Comet 64 packs all five into a single byte and puts
it at an address. Joystick 1 is at **`$DC01`** (`hw.joy1`):

```
  bit:   7   6   5    4     3     2    1    0
       ┌───┬───┬───┬──────┬─────┬────┬────┬────┐
       │ 1 │ 1 │ 1 │ fire │right│left│down│ up │
       └───┴───┴───┴──────┴─────┴────┴────┴────┘
```

The top three bits are always 1. And here's the twist: **a switch reads 0
while it's pressed, and 1 when it isn't.** It's called **active-low**. In
the joystick, pressing a direction connects that switch's wire to
ground, which reads as 0; let go and a resistor pulls the wire back up
to 1. So
with nothing touched, all eight bits are 1 and the port reads `$FF`.
Hold left and bit 2 drops to 0: `$FB`. Hold up and fire together and
bits 0 and 4 drop: `1110 1110`, or `$EE`.

So the question "is left held?" is the question "is bit 2 of this byte a
0?" To ask it, we need to look at one bit and ignore the other seven.
That's what **`&`**, bitwise AND, is for. It compares two bytes bit by
bit, and each bit of the result is 1 only where *both* inputs have a 1.
AND the port with a byte that has only bit 2 set (`0b0000_0100`, called
a **mask**), and every bit except bit 2 is forced to 0. What's left
tells you about bit 2 alone:

```
  holding left:         port  1111 1011   ($FB)
                      & mask  0000 0100   (joy.left)
                      =       0000 0000   zero: left is held

  not holding left:     port  1111 1111   ($FF)
                      & mask  0000 0100   (joy.left)
                      =       0000 0100   not zero: left is free
```

The machine gives you the five masks by name: `machine.joy.up`, `.down`,
`.left`, `.right` and `.fire`. (Chapter 2 does a lot more with masks and
with moving bits around inside a byte. One bit at a time is all we need
today.)

We'll wrap the test in a tiny function so the active-low twist is written
down in exactly one place:

**`src/player.zig`** (add at the end of the file)

```zig
/// Read joystick 1 and move the player one pixel in each direction held.
pub fn steer(m: *Machine) void {
    const stick = m.peek(hw.joy1);
    var x = m.peek(map.player_x);
    var y = m.peek(map.player_y);

    if (held(stick, joy.left) and x > min_x) x -= 1;
    if (held(stick, joy.right) and x < max_x) x += 1;
    if (held(stick, joy.up) and y > min_y) y -= 1;
    if (held(stick, joy.down) and y < max_y) y += 1;

    m.poke(map.player_x, x);
    m.poke(map.player_y, y);
    m.work(40); // the tests, sums and branches above
}

/// Is this switch held? Joystick switches read 0 while they're pressed.
fn held(stick: u8, switch_bit: u8) bool {
    return stick & switch_bit == 0;
}
```

`steer` reads the port once, into a local. Then it reads the player's
position, moves it one pixel for each direction held, as long as that
doesn't cross a limit, and writes it back. Holding two directions moves
diagonally, for free.

Notice `x` and `y` are `var` locals, which is fine. The rule is about
state that has to *survive* between frames. A local lives only while
`steer` runs, like a scratch register on the processor, and it's gone
when the function returns. Whatever needs to be remembered goes back to
`$0200` before we leave.

The `m.work(40)` is us being honest with the meter. `peek` and `poke`
charge for themselves, but the comparisons, the additions and the
decisions between them would cost the processor real time too. We
estimate it and charge it. The meter is only as truthful as we make it,
and later chapters will rely on it to tell us when a design is too
slow.

:::pro-tip `&` binds tighter than `==` in Zig
In JavaScript, C and many of their relatives, `stick & LEFT == 0` means
`stick & (LEFT == 0)`, a classic bug that has eaten many afternoons. Zig
puts the bitwise operators *above* comparison, so `stick & switch_bit
== 0` means what it looks like it means: `(stick & switch_bit) == 0`.
Python happens to agree with Zig; JavaScript and C don't. If your
fingers learned on JavaScript, the parentheses are free: `zig fmt`
keeps them.
:::

One more line in `frame`, after `show`:

**`src/main.zig`** (replace `frame`)

```zig
pub fn frame(m: *Machine) void {
    // Hardware first. The beam reaches the top of the display 3,213
    // cycles into the frame; registers written before then can't tear.
    player.show(m);

    // Then the game itself. What it decides shows up next frame.
    player.steer(m);
}
```

The order matters, and it's the beam rule at work. `show` copies the
position that `steer` worked out *last* frame into the chip, safely
before the beam reaches the display. Then `steer` works out the next
position, which `show` will copy at the start of the next frame. The
picture is always one frame (a fiftieth of a second) behind the
joystick, and no player alive can feel it.

Build, reload, click the screen and push the arrow keys. **He moves!**

Walk him right. He stops about three quarters of the way across the
screen, in the middle of nowhere. There's the wall made of arithmetic:
X is a byte, and a byte stops at 255. If you'd left out the `x < max_x`
check, `x += 1` at 255 would try to make 256, and Zig would stop the game
right there with `panic: integer overflow`. Chapter 4 digs into exactly
what happens when numbers outgrow their bytes, and how the 1984 game
fits its coordinates into a byte without losing the edge of the screen.

## Fire!

The fire button is bit 4 of the same byte, and we already have
`held(stick, joy.fire)`. So making fire change the explorer's colour
should be one line, right?

```
if fire is held: pick the next colour
```

Try thinking it through frame by frame. A quick tap of the fire button
lasts about a tenth of a second. That's five frames. Each of those five
frames, `steer` runs, sees fire held, and changes the colour: five
colours per tap. Hold the button and the explorer strobes through the
palette fifty times a second. The joystick tells you whether the button
*is down*, and what we want to know is whether it *went down*.

The fix is to remember what the stick looked like last frame. A press is
"held now, and not held last frame". That's what the fourth player byte,
`player_last_stick` at `$0203`, is for: at the end of every `steer`, we store
the port byte we read, and at the start of the next one, we read it back
as `before`.

:::power-up The Edge Detector Power-Up
Keep last frame's input byte, and a press is `held(now) and
!held(before)`. One byte of memory and a few cycles of work turn "is the
button down?" into "was the button pressed *this frame*?", for all five
switches at once, since the whole port byte is saved. The same trick
tells you when a button is *released* (`!held(now) and held(before)`).
Doorbells in Chapter 5 and the ray-gun control panel in Chapter 7 both
want presses, not holds, and the same byte will serve them.
:::

Here's `steer` with fire added: one new line at the top, the fire check
after the moves, and one more poke at the end.

**`src/player.zig`** (replace `steer`)

```zig
/// Read joystick 1 and move the player one pixel in each direction held.
/// A fresh press of fire picks the next colour.
pub fn steer(m: *Machine) void {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    var x = m.peek(map.player_x);
    var y = m.peek(map.player_y);

    if (held(stick, joy.left) and x > min_x) x -= 1;
    if (held(stick, joy.right) and x < max_x) x += 1;
    if (held(stick, joy.up) and y > min_y) y -= 1;
    if (held(stick, joy.down) and y < max_y) y += 1;

    // Held now but not last frame: that's a press. Without this check,
    // holding fire would change colour fifty times a second.
    if (held(stick, joy.fire) and !held(before, joy.fire)) {
        const c = m.peek(map.player_color);
        m.poke(map.player_color, if (c == 15) 1 else c + 1); // 0 is black, like the background
    }

    m.poke(map.player_x, x);
    m.poke(map.player_y, y);
    m.poke(map.player_last_stick, stick);
    m.work(40); // the tests, sums and branches above
}
```

The next colour is the current one plus one, except that after 15
(light grey) we wrap round to 1 (white), skipping 0, which is black and
would make the explorer vanish against the background. In Zig, `if` is
an expression, so `if (c == 15) 1 else c + 1` produces a value, like
JavaScript's `c === 15 ? 1 : c + 1`.

Remember that `start` set `player_last_stick` to `$FF`? Memory powers
on as zeros, and to a joystick byte, zero means *every switch is held*.
Left alone, the first frame would think all five switches had been held
a moment ago: a fire button held at power-on would be swallowed, and a
release check would see five releases that never happened. `$FF` is what
the port itself reads when nobody's touching it, so the first frame
compares against an idle stick.

Build and reload. Tap Space: white, red, cyan, purple, one colour per
tap, however long you hold it.

:::secret-passage Make it tear
Now that he moves and changes colour, you can break him on purpose.
Suppose the game does a lot of work before it gets round to the sprite:
in `frame`, put `m.work(6000);` on the line before `player.show(m);`.
That's 6,000 cycles, so the beam is 95 lines down, about 44 rows into the
display, when the registers get written.

The tear lasts only for the one frame on which his colour changes, a
20 ms blip that's hard to catch by eye, so let the headless runner catch
it for you:

```
zig build run -- --frames 152 --press 0:u:134 --press 150:f:5
```

That walks him 134 pixels up the screen, until his hat is in the beam's
way, and presses fire on frame 150. `steer` picks the new colour on frame
150, and `show` writes it on frame 151, after the beam has already drawn
the top of him. So `frames/frame_00151.ppm` looks like this:

![The explorer torn across the middle: a white hat and face, and a red body below them](images/01-tear.png)

His hat and face are still white; the rest of him is already red. On a
colour change it's one torn frame. In a game whose sprites move every
frame and whose logic runs long, it's a constant shimmer. Move the
`m.work(6000);` below `player.show(m);`, run the same command, and frame
151 is clean, even though the frame does exactly the same amount of
work. Take the line out again when you're done; the checkpoint doesn't
have it.
:::

## A test that plays the game

`zig build test` already boots your game and plays 100 frames to check
it doesn't crash. Let's add a test of our own that checks it does what we
said: that the stick moves the sprite, and that fire changes the colour
once per press, not once per frame.

**`src/main.zig`** (add `std` at the top of the imports, and the
`map` import after `hw`)

```zig
const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const room = @import("room.zig");
const player = @import("player.zig");
```

**`src/main.zig`** (add at the end of the file)

```zig
test "the stick steers the sprite and fire changes its colour" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    const x = m.ram[map.player_x];
    const color = m.ram[map.player_color];

    m.input = .{ .joy1 = machine.joy.left | machine.joy.fire };
    _ = m.runFrame(@This());
    try std.testing.expectEqual(x - 1, m.ram[map.player_x]);
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);

    // Still holding fire: same colour. The sprite registers caught up.
    _ = m.runFrame(@This());
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);
    try std.testing.expectEqual(x - 1, m.ram[hw.spriteX(0)]);
}
```

The test powers on a whole Comet 64, holds joystick 1 left and fire for
one frame, and checks the player's bytes in memory. Then it holds them
for another frame and checks that the colour *didn't* change again, and
that `show` has caught the chip's X register up with where `steer` put
the player. Because all the game's state lives in `m.ram`, a test can
read it straight out of memory, with no special hooks.

`m.input` is how a test (or the browser, or the headless runner) works
the joysticks: it holds the switches that are pressed, using the same
`joy` masks, and the machine turns that into the active-low port byte
before each frame.

:::pro-tip Three Zig things in that test
- **`@This()`** is the type of the file you're in. In Zig every file is
  a struct, and `main.zig` *is* the game, so `m.boot(@This())` boots the
  file the test lives in.
- **The `Machine` goes on the heap.** With everything the machine
  keeps, it's about half a megabyte, too big to sit comfortably on a
  test's stack. `std.testing.allocator.create` makes one, and `defer
  ... destroy(m)` frees it when the test ends. (And `testing.allocator`
  fails the test if you forget.) Allocating in a *test* is fine; the
  game itself never allocates.
- **`try`** is Zig's way of saying "if this fails, return the error".
  A failed `expectEqual` returns an error, so the test stops and reports
  the line.
:::

Here's the whole of `main.zig` as it stands, to check yours against:

**`src/main.zig`** (complete)

```zig
//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const room = @import("room.zig");
const player = @import("player.zig");

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    room.paint(m);
    player.start(m);
}

pub fn frame(m: *Machine) void {
    // Hardware first. The beam reaches the top of the display 3,213
    // cycles into the frame; registers written before then can't tear.
    player.show(m);

    // Then the game itself. What it decides shows up next frame.
    player.steer(m);
}

test "the stick steers the sprite and fire changes its colour" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    const x = m.ram[map.player_x];
    const color = m.ram[map.player_color];

    m.input = .{ .joy1 = machine.joy.left | machine.joy.fire };
    _ = m.runFrame(@This());
    try std.testing.expectEqual(x - 1, m.ram[map.player_x]);
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);

    // Still holding fire: same colour. The sprite registers caught up.
    _ = m.runFrame(@This());
    try std.testing.expectEqual(color + 1, m.ram[map.player_color]);
    try std.testing.expectEqual(x - 1, m.ram[hw.spriteX(0)]);
}
```

:::byte-budget Chapter 1
**Memory.** The game's own state is 4 bytes, at `$0200–$0203`. The
explorer's picture is 63 bytes of the program image, copied into one
64-byte sprite block at `$C000` (of 32). The floor is 320 bytes of
bitmap and 40 of colour RAM, which are the hardware's planes, not new
memory. That's 4 bytes of the 64 KB that are actually ours. Plenty of
room left.

**Time.** A frame where the stick is idle costs 92 cycles: `show` is 3
peeks and 3 pokes (24), and `steer` is 4 peeks, 3 pokes and our
estimated 40 (68). A fire press adds one more peek and poke, for 100.
Out of 19,656, that's half of one percent. The work meter is a sliver
of green at the left of the bar. Enjoy the elbow room. Chapter 2 starts
drawing whole rooms, and the meter will finally have something to say.
:::

:::game-over Common mistakes
- **Forgetting active-low.** Write `stick & joy.left != 0` for "left is
  held" and you've got it backwards: with nothing pressed, every bit is
  1, so the explorer runs left on his own the moment the game starts and
  stops when you *press* left. Keep the test in `held` and use it
  everywhere.
- **Writing registers late.** Put `player.show(m)` after the game logic
  and it works today, because the logic is tiny. As the game grows, the
  logic pushes `show` past the 3,213-cycle mark and the sprite starts
  tearing. Hardware first, always.
- **Fire strobes through the colours.** You tested `held(stick,
  joy.fire)` without `!held(before, joy.fire)`, or forgot
  `m.poke(map.player_last_stick, stick)` at the end of `steer`, so every frame
  looks like a fresh press.
- **The explorer never appears.** `start` set up the picture but nothing
  writes his position into the chip: check that `frame` calls
  `player.show(m)`. If he's still missing, check `$D015`: if the enable
  bit for sprite 0 isn't set, the chip doesn't draw him at all.
- **`panic: integer overflow`.** A limit check went missing, and `x += 1`
  or `y -= 1` tried to leave the 0–255 range of a `u8`. Put the `x <
  max_x`-style check back.
- **A Zig `var` at the top of a file.** It compiles, and it even works,
  but it hides a byte inside the program image where the memory map, the
  widgets and your tests can't see it. Give it an address in `map.zig`
  instead.
:::

:::boss-battle Bring him to life
From your project folder:

```
zig build
zig build test
zig build run -- --frames 250 --press 10:l:60 --press 80:u:80 --press 170:f:5 --press 200:rf:40 --dump-every 50
```

`zig build` and `zig build test` print nothing when they pass. The
headless run holds left for 60 frames, then up for 80, taps fire, then
holds right and fire together for 40. It prints:

```
ran 250 frames (250 calls to frame)
cycles: max 100 (0%), avg 92 (0%) of 19656
  bucket 0: max 100, avg 92
overruns: 0, loading pauses: 0
last frame: frames/frame_00249.ppm
```

and saves six pictures in `frames/`. In `frame_00000.ppm` the explorer
stands on the grey floor, white, a little left of centre. By
`frame_00100.ppm` he's walked left and is on his way up. In
`frame_00249.ppm` he's floating near the middle of the screen, cyan,
after two presses of fire (white, red, cyan): the second press held
fire for 40 frames and still changed the colour only once.

Then play it:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000>, click the screen, and steer with the
arrow keys or W A S D. Space changes his colour. The meter in the
bottom border is a tiny green sliver.

**Your Comet 64 has a player.** Everything else in the castle, every
door and monster and trapdoor, will be built the same way: bytes at
addresses you chose, read and written a little at a time, fifty times a
second.
:::

:::warp-zone
The finished checkpoint is [`code/ch01/`](../code/ch01/), also as a
download, [`ch01.zip`](downloads/ch01.zip), which unzips into the same
`code/` folder as the starter kit. To start Chapter 2 from a known-good
game, replace your project with it:

```
cd code
rm -rf my-creep
cp -r ch01 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```

The last line matters. A project's `.zig-cache` remembers where its own
source files live, so a copied cache can make `zig build` quietly reuse
the *original's* game and ignore everything you type in the copy. If you
ever copy a project and your changes don't show up, delete its
`.zig-cache` and build again.
:::

:::bonus-stage
- **Draw your own explorer.** Change the 1s in `picture`, keeping it at
  63 bytes. A different hat? A cape? Make sure the bottom row still has
  his boots, or adjust `max_y`.
- **Make him bigger.** Set bit 0 of `$D017` (`hw.sprite_double_height`)
  and `$D01D` (`hw.sprite_double_width`) in `start`, and he's 48 × 42.
  The limits will need adjusting to match.
- **Cross the wall.** Bit 0 of `$D010` (`hw.sprite_x_msb`) is the ninth
  bit of sprite 0's X. Find a way to let the explorer reach the right
  edge. You'll need to remember a little more state, and the memory map
  will need to know about it.
- **Player 2.** Joystick 2 is at `$DC00` (`hw.joy2`), and in the browser
  it's I J K L and Return. Sprite 1 is waiting. It'll need its own bytes
  in the memory map, and the overlap check will tell you if they land
  on player 1's.
:::
