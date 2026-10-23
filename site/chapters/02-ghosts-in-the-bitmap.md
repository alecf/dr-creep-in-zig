---
chapter: 2
title: "Ghosts in the Bitmap"
checkpoint: ch02
---

:::mission-briefing
By the end of this chapter the Comet 64 boots to a title screen: a
castle by moonlight under a sky of twinkling stars. Press fire, the
screen goes dark for a moment, and you're standing in the **Entrance
Hall**: stone walkways, a ladder, a sliding pole, two doors, torches on
the walls, and the explorer, now in full colour, walking the floor with
a proper walk cycle.

![The Chapter 2 title screen: a starry sky, a full moon, the words THE CASTLES OF DR. CREEP and PRESS FIRE, and a grey castle with two towers and a wooden door](images/02-title.png)

Everything on that screen is drawn from one table of pictures, the
**shape table**, the same way the 1984 disk does it: room pieces,
letters and every frame of the explorer's walk. You'll build the table at
compile time from pictures drawn as text, write the routine that stamps
shapes into the bitmap, borrow the character ROM's font for the words,
and animate the sprite without ever letting the beam catch it half
drawn.

New under the hood: **packing several values into a byte** (shifts and
masks), **pointers as addresses you can do arithmetic on**, and
**lookup tables versus computing** (and what a multiply really costs).
:::

## Four pixels to a byte

Remember Chapter 1's floor? We filled 320 bitmap bytes with `$FF`, and
the comment said "four pixels, code 11". Time to find out what that
meant, because every picture in the game depends on it.

You know the look from the player's side: on machines like this one, the
pixels are wide. Characters have chunky, double-width dots, and a colour
never quite ends where you'd like it to. That look is the multicolour
bitmap at work, and the card's section 3 has the full story. Here's the
short version.

The display is 320 × 200, but a pixel takes **two bits**, so each one is
two dots wide: 160 **fat pixels** across, 200 down. A byte has eight
bits, so a byte holds **four fat pixels**, leftmost in the top two bits:

```
  bit:     7   6     5   4     3   2     1   0
         ┌───────┬───────┬───────┬───────┐
  byte:  │ 0   1 │ 1   0 │ 1   1 │ 0   0 │   = $6C
         └───────┴───────┴───────┴───────┘
          pixel 0 pixel 1 pixel 2 pixel 3
          code 01 code 10 code 11 code 00
```

Two bits make four values, and a pixel's two bits aren't a colour. They're
a **code** that says where to *find* its colour:

| Code | Colour comes from |
|---|---|
| `00` | the background colour, `$D021`, shared by the whole screen |
| `01` | this cell's screen-plane byte (`$CC00` + cell), **high** four bits |
| `10` | this cell's screen-plane byte, **low** four bits |
| `11` | this cell's colour-RAM byte (`$D800` + cell) |

A **cell** is 8 × 8 dots: 4 fat pixels across, 8 rows down, 40 cells by
25. Each cell owns one screen-plane byte and one colour-RAM byte, so
inside one cell you get four colours: the shared background plus three of
the cell's own. That's the "4 colours per 8×8 cell" rule from the
Prologue's table, and now you can see why it's there. It's what makes a
whole screen of colour fit in 8,000 + 1,000 + 1,000 bytes.

So the floor: `$FF` is `11 11 11 11`, four fat pixels of code 11, and
code 11 is "whatever colour RAM says", and we'd put grey in colour RAM.
**One byte held four pixels; a second byte coloured the whole cell.**
That's the trick behind every picture on this machine.

Notice something else in that diagram: the screen-plane byte holds *two*
colours, one in each half. A palette number is 0–15, which is four bits,
and a byte has room for two. That's the first new idea of the chapter,
**packing several values into one byte**, and once you start looking for
it you'll see it everywhere on this machine.

:::widget byte-diagram
A bitmap byte as four fat pixels. Click a pixel to cycle its code, and
watch the byte's bits and hex change; set the cell's three colours and
see the pixels repaint.
:::

:::under-the-hood A pixel in JavaScript
On a canvas you'd write

```js
ctx.fillStyle = "#6C5EB5";
ctx.fillRect(x, y, 1, 1);
```

and the browser stores that pixel as four bytes: red, green, blue and
alpha. A 320 × 200 canvas is 256,000 bytes of pixels, and every one of
them can be any of sixteen million colours.

The Comet 64 has 64 KB *in total*. Its whole screen, pixels and colours,
is 10,000 bytes, a twenty-fifth of that canvas, and it pays for the
saving by sharing: four pixels to a byte, and three colours to a cell.
There's no `fillRect`. Setting one pixel means finding the right byte,
changing two of its bits and leaving the other six alone, and that's
what we'll write first.
:::

## Claiming the memory

This chapter needs a lot more memory than the last one: tables, a text
buffer, a home for the pictures. Here's the plan, new rows in bold:

| Address | Bytes | What |
|---|---|---|
| `$0100–$01FF` | 256 | the processor's stack (reserved) |
| `$0200–$0205` | 6 | the player (**two new bytes**) |
| **`$0206–$0207`** | **2** | **the game: which screen we're on, and a clock** |
| **`$0300–$035F`** | **96** | **text: a lookup table, one letter's shape, a string buffer** |
| `$0800–$66FF` | 24 KB | the program image (reserved) |
| **`$6700–$67FF`** | **256** | **the star map** |
| **`$6800–$77FF`** | **4 KB** | **the shape table** |
| **`$BB00–$BC8F`** | **400** | **the row table** |
| `$C000–$C7FF` | 2 KB | sprite frames |
| **`$CC00–$CFE7`** | **1,000** | **the screen plane** |
| `$CFF8–$CFFF` | 8 | sprite pointers |
| `$D000–$D02E` | 47 | the VIDEO chip |
| `$D800–$DBE7` | 1,000 | colour RAM |
| `$DC00–$DC02` | 3 | input ports |
| `$E000–$FF3F` | 8,000 | the bitmap |

The star map and the shape table are **built-in tables**: data that's
part of the program, like the explorer's picture was in Chapter 1. Boot
copies them to the top of the program image, so the program image row
shrinks to make room and the map still accounts for every byte. The
screen plane is hardware, but the game is about to start writing it, so
it goes in the map too. You'll meet each new row properly as we use it.

**`src/map.zig`** (replace the whole file)

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

/// Everything the game knows about the player, six bytes in a row.
pub const player = Region{ .name = "player", .first = 0x0200, .last = 0x0205 };
pub const player_x = player.first + 0; // sprite X, 24 (left edge) to 255
pub const player_y = player.first + 1; // sprite Y, 50 (top edge) and down
pub const player_color = player.first + 2; // palette number, 1-15
pub const player_last_stick = player.first + 3; // joystick 1 as it read last frame
pub const player_block = player.first + 4; // sprite block the VIDEO chip shows: 0 or 8
pub const player_frame = player.first + 5; // shape ID of the picture in that block

/// Which screen the game is on, and a clock.
pub const game = Region{ .name = "game", .first = 0x0206, .last = 0x0207 };
pub const game_mode = game.first + 0; // a main.Mode
pub const game_tick = game.first + 1; // goes up by one every frame, and wraps

/// Text: a lookup table, the shape each letter is built in, and a string.
pub const text = Region{ .name = "text", .first = 0x0300, .last = 0x035F };
pub const text_widen = text.first + 0x00; // 16 bytes: 4 glyph bits -> 4 fat pixels
pub const text_glyph = text.first + 0x10; // one letter as a 2x8 shape: 23 bytes
pub const text_buffer = text.first + 0x30; // a string to print
pub const text_buffer_size = text.last - text_buffer + 1; // 48 letters

/// Built-in tables, copied to the top of the program image at boot.
pub const stars = Region{ .name = "star map", .first = 0x6700, .last = 0x67FF };
pub const shape_table = Region{ .name = "shape table", .first = 0x6800, .last = hw.program_end - 1 };

/// Where each of the 200 bitmap rows starts: two bytes per row.
pub const row_table = Region{ .name = "row table", .first = 0xBB00, .last = 0xBB00 + 200 * 2 - 1 };

// ---- memory the hardware gives us ---------------------------------------

const stack = Region{ .name = "stack (reserved)", .first = hw.stack, .last = hw.stack + 256 - 1 };
const program = Region{ .name = "program image", .first = hw.program, .last = stars.first - 1 };
const sprite_frames = Region{ .name = "sprite frames", .first = hw.sprite_data, .last = hw.sprite_data + 32 * 64 - 1 };
const screen_plane = Region{ .name = "screen plane", .first = hw.screen, .last = hw.screen + 1000 - 1 };
const sprite_pointers = Region{ .name = "sprite pointers", .first = hw.sprite_pointers, .last = hw.sprite_pointers + 8 - 1 };
const video_chip = Region{ .name = "VIDEO chip", .first = hw.video_chip, .last = hw.spriteColor(7) };
const color_ram = Region{ .name = "colour RAM", .first = hw.color_ram, .last = hw.color_ram + 1000 - 1 };
const input_ports = Region{ .name = "input ports", .first = hw.joy2, .last = hw.key };
const bitmap = Region{ .name = "bitmap", .first = hw.bitmap, .last = hw.bitmap + 8000 - 1 };

/// The whole map, in address order.
pub const regions = [_]Region{
    stack,
    player,
    game,
    text,
    program,
    stars,
    shape_table,
    row_table,
    sprite_frames,
    screen_plane,
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

The overlap check from Chapter 1 now guards fifteen regions. Notice the
program image's last byte is `stars.first - 1`: if the built-in tables
ever grow downwards, the program image shrinks with them, automatically.
Run `zig build`: the Chapter 1 game still builds, because nothing it
used has moved.

## One fat pixel

Let's set a pixel. The card gives the formula for the byte that holds
fat pixel (`x`, `y`):

```
byte = $E000 + (y / 8) × 320 + (x / 4) × 8 + (y mod 8)
```

Read it right to left and it's the cell layout from Chapter 1: `y mod 8`
is the line inside the cell, `(x / 4) × 8` skips the cells to the left
(4 fat pixels per cell, 8 bytes per cell), and `(y / 8) × 320` skips the
rows of cells above (40 cells × 8 bytes). We'll split it in two: the
start of row `y`, and then the step across.

Here's the first version, straight from the card. The machine has no
multiply instruction, so the `× 320` has to be a call to `m.mul8`, the
multiply routine in the card's price list, and it costs **120 cycles**.
(It multiplies `y / 8` by 40, and the `× 8` is cheap, as you'll see in a
moment.) Keep an eye on that number.

**`src/screen.zig`** (new file)

```zig
//! The bitmap: finding a pixel's byte, setting one fat pixel, and drawing
//! shapes from the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const map = @import("map.zig");

/// The address of the first byte of bitmap row `y` (0-199), worked out
/// the way the reference card writes it.
pub fn rowAddress(m: *Machine, y: u8) u16 {
    m.work(12); // y / 8, y % 8, the * 8 and the adds
    return hw.bitmap + m.mul8(y / 8, 40) * 8 + y % 8;
}

/// The bitmap byte that holds fat pixel (x, y). x runs 0-159.
fn pixelByte(m: *Machine, x: u8, y: u8) u16 {
    m.work(6); // x / 4 * 8: three shifts
    return rowAddress(m, y) + @as(u16, x / 4) * 8;
}

/// How far fat pixel x's two bits sit from the right of its byte: 6 for
/// the leftmost pixel of the four, then 4, 2 and 0.
fn pixelShift(x: u8) u3 {
    return @intCast(6 - (x % 4) * 2);
}

/// Set fat pixel (x, y) to colour code 0-3, leaving the other three
/// pixels in its byte alone.
pub fn plot(m: *Machine, x: u8, y: u8, code: u2) void {
    const addr = pixelByte(m, x, y);
    const shift = pixelShift(x);
    const mask = @as(u8, 0b11) << shift;
    const old = m.peek(addr);
    m.poke(addr, (old & ~mask) | @as(u8, code) << shift);
    m.work(12); // the shifts, the mask and the OR
}

/// The colour code (0-3) of fat pixel (x, y).
pub fn codeAt(m: *Machine, x: u8, y: u8) u2 {
    const addr = pixelByte(m, x, y);
    m.work(8); // the shift
    return @truncate(m.peek(addr) >> pixelShift(x));
}

/// Wipe the screen: every pixel code 00, every cell's colours 0.
pub fn clear(m: *Machine) void {
    m.fill(hw.bitmap, 8000, 0);
    m.fill(hw.screen, 1000, 0);
    m.fill(hw.color_ram, 1000, 0);
}

// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "plot sets one fat pixel and leaves its neighbours alone" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    m.ram[hw.bitmap + 8 + 3] = 0b11_11_11_11; // row 3 of cell 1: fat pixels 4-7
    plot(m, 6, 3, 0b01);
    try std.testing.expectEqual(0b11_11_01_11, m.ram[hw.bitmap + 8 + 3]);
    try std.testing.expectEqual(0b01, codeAt(m, 6, 3));
    try std.testing.expectEqual(0b11, codeAt(m, 7, 3));
}
```

`plot` is where the chapter's first new idea lives, so let's take it
slowly.

### Shifts: sliding bits along

**`<<` and `>>` shift a number's bits** left or right, the same in Zig as
in JavaScript. `0b11 << 4` slides the two 1s four places left:
`0b0011_0000`. Bits that fall off the end are gone; the places they leave
fill with 0s. Since each bit is worth twice the one to its right, a shift
left by one doubles a number and a shift right halves it (dropping any
remainder). So `x / 4` is `x >> 2` and `× 8` is `<< 3`: the processor
can do them in a few cycles, with no multiply at all. Zig turns `/ 4`
into a shift for you, so we write whichever reads better and charge a few
cycles for it.

`pixelShift` works out where fat pixel `x`'s two bits sit. `x % 4` says
which of the byte's four pixels it is, 0 to 3, leftmost first; the
leftmost pixel's bits are 6 places from the right of the byte, and each
pixel after it is two places further right. So pixel 2 of its byte (like
`x = 6`) is at shift 2.

### Masks: changing two bits and no others

We can't write a pixel's code into memory on its own: the smallest thing
the machine can write is a byte, and the byte holds three other pixels.
So `plot` reads the byte, changes two bits, and writes it back. For
`plot(m, 6, 3, 0b01)` on a byte that was all 1s:

```
  the byte now         1111 1111
  mask = 0b11 << 2     0000 1100    the two bits that belong to pixel 6
  ~mask                1111 0011    ~ flips every bit
  byte & ~mask         1111 0011    pixel 6 cleared, the others kept
  code << 2            0000 0100    the new code, slid into place
  ... | (code << 2)    1111 0111    = $F7: three 11s and a 01
```

`&` with `~mask` clears exactly the pixel's two bits (AND keeps a bit
only where both sides have a 1, and the mask's 0s are right there).
`|` is **bitwise OR**: each bit of the result is 1 where *either* side
has a 1, so it sets the new code's bits without disturbing anything else.
Clear with AND, set with OR: that's how you change one value packed among
others, on any machine, in any language. `codeAt` goes the other way:
shift the pixel's bits down to the bottom and keep the bottom two.

:::pro-tip Zig sizes your shifts
Why `@as(u8, code) << shift`, and why is `shift` a `u3`? Zig won't let a
shift quietly lose bits. Shifting a `u2` left would push the code straight
out of its two bits, so we widen it to a `u8` first. And the shift amount
of a `u8` must be a `u3` (0 to 7), because shifting eight bits by eight or
more places would empty them. Get it wrong and the compiler tells you,
which beats a pixel silently landing in the wrong place. `@truncate` in
`codeAt` is the other direction: keep the bottom two bits and drop the
rest, on purpose.
:::

`clear` wipes the whole screen: 8,000 bitmap bytes, 1,000 screen-plane
bytes and 1,000 colour-RAM bytes, all zero. Look at its price tag before
you call it: at 8 cycles a byte that's **80,000 cycles**, four whole
frames.

## A sky full of stars

Let's make that pixel routine earn its keep, with something that runs
*every frame*. The title screen needs a night sky, and a night sky needs
stars that twinkle.

The plan: 128 stars, each a single fat pixel. Every frame, each star
moves one step through codes 00, 01, 10 and 11, and we give every cell
the same three colours (dark grey, light grey, white), so a star goes
off, dim, bright, brightest, and round again. Each star starts its cycle
one step behind the last, so they never twinkle in step.

**`src/title.zig`** (new file)

```zig
//! The title screen: the castle by moonlight, and a sky full of stars.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const screen = @import("screen.zig");

pub const star_count = 128;

/// Where the stars are: x then y for each, scattered while the game
/// compiles, keeping clear of the cells the words and the moon use.
pub const star_map: [star_count * 2]u8 = blk: {
    @setEvalBranchQuota(100_000);
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
            (row == 13 and col >= 10 and col < 30) or // PRESS FIRE
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
}

/// Every frame: move each star one step through off, dim, bright and
/// brightest, each star a little out of step with the last.
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
```

`star_map` is worked out while the game compiles: a `blk:` block runs at
compile time, scatters 128 stars with a little arithmetic (Chapter 8 has
the proper story of making numbers look random), throws away any star
that would land in a cell the words or the moon will need, and hands
back 256 bytes of x, y, x, y. The game copies that table to `$6700` at
boot.

Look at the screen-plane fill: `dark_grey << 4 | light_grey`. That's the
packing from the start of the chapter, written in code. Shift one colour
into the high four bits, OR the other into the low four, and one byte
holds both.

In `twinkle`, `phase` is the clock shifted right by three, which is the
clock divided by eight, so the sky takes a new step every eight frames.
`phase +% i` gives each star its own place in the cycle (`+%` is adding
that wraps round past 255 instead of stopping the game), and `@truncate`
keeps the bottom two bits: a code from 0 to 3.

Now `main.zig`. The game has screens now, the title and (soon) the room,
so it needs to remember which one it's on. That's `game_mode`, at
`$0206`: one byte holding a `Mode`. Zig's `enum(u8)` gives each mode a
name and says it's stored as a byte; power-on memory is zero, and zero is
the first mode, `draw_title`, so the game starts by drawing the title
without being told.

**`src/main.zig`** (replace the whole file)

```zig
//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const screen = @import("screen.zig");
const title = @import("title.zig");

/// What the game is doing. Power-on memory is 0, so it starts by drawing
/// the title screen.
const Mode = enum(u8) { draw_title, title, draw_room, room };

/// Meter buckets, so the meter can say where each frame went.
const bucket_drawing = 1;
const bucket_sprites = 2;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    m.load(map.stars.first, &title.star_map);
}

pub fn frame(m: *Machine) void {
    switch (mode(m)) {
        .draw_title => {
            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
            m.bucket(bucket_drawing);
            title.draw(m);
            m.poke(hw.control, machine.display_on);
            setMode(m, .title);
        },
        .title => {
            m.bucket(bucket_drawing);
            title.twinkle(m);
        },
        .draw_room, .room => {}, // later in this chapter
    }
    m.bucket(0);
    m.poke(map.game_tick, m.peek(map.game_tick) +% 1);
}

fn mode(m: *Machine) Mode {
    return @enumFromInt(m.peek(map.game_mode));
}

fn setMode(m: *Machine, new: Mode) void {
    m.poke(map.game_mode, @intFromEnum(new));
}
```

Two things in `frame` deserve a closer look.

**Drawing a screen is a loading pause.** Chapter 1 promised that once we
started drawing rooms, the meter would have something to say. Here it
is. `title.draw` clears 10,000 bytes and fills 2,000 more, which is
nearly five frames of work, so `draw_title` follows the card's advice
(section 6, "Blank the screen for big jobs"): switch the display off
first thing, while the beam is still above the display, do the work, and
switch it back on. The frame runs as long as it needs, the meter shows a
grey bar instead of a red one, and the player sees a blank screen for a
moment and then the finished title. Every room change in the game will
work this way.

**Buckets.** `m.bucket(id)` sends the cycles that follow to one of the
meter's eight buckets, so the headless summary and the meter widget can
say *where* a frame's time went. We'll keep the numbers the same for the
rest of the series: bucket 1 is drawing into the bitmap, bucket 2 is the
sprites, and bucket 0 is everything else. Later chapters fill 3 to 7.

The `switch` has to handle every `Mode`, so the two room modes get an
empty branch for now. Run it:

```
zig build run -- --frames 100
```

```
ran 100 frames (49 calls to frame)
cycles: max 96024 (488%), avg 23542 (119%) of 19656
  bucket 0: max 16, avg 12
  bucket 1: max 96008, avg 23529
overruns: 48, loading pauses: 1
last frame: frames/frame_00099.ppm
```

Look at the last two lines: **48 overruns** and one loading pause. The
loading pause is the title being drawn, and it's fine. The overruns are
every single frame after it. Only 49 calls to `frame` in 100 frames, too:
each one runs into a second frame slot, so the sky twinkles at half
speed. Open it in the browser (`zig build wasm`, then the web server from
the Prologue) and the stars are there, twinkling, and the meter is
**red**, with the red stripe across the border, all the time.

What happened? Add it up for one star: two peeks to read its position,
a peek and a poke in `plot`, and some shifting and looping, about 40
cycles. Then `rowAddress` charges **132**: 12 for the sums and 120 for
the multiply. That's 172 cycles a star, and 128 stars come to 22,020
cycles, more than the whole frame's 19,656. Seven tenths of it is one
`mul8` per star.

## The Lookup Table Power-Up

Here's the thing about `(y / 8) × 320`: there are only 200 possible
values of `y`. The game asks the same 200 questions over and over, and
the answers never change. So ask each one once, at boot, write the
answers down, and from then on, **look them up**.

That's the **row table**: 200 addresses, one per bitmap row, two bytes
each, at `$BB00`. And we can build it without multiplying at all, by
walking down the screen. Inside a cell, the next row down is the next
byte. Below a cell's last row is the top row of the cell underneath,
which is 320 bytes on from the top of this cell, and so 313 bytes on from
its last row. Add 1, add 1, add 1, ..., add 313, and repeat.

**`src/screen.zig`** (add above `rowAddress`)

```zig
/// Build the row table: the address of the first byte of each of the 200
/// bitmap rows. Done once, at boot, without a single multiply.
pub fn start(m: *Machine) void {
    var addr: u16 = hw.bitmap;
    var y: u16 = 0;
    while (y < 200) : (y += 1) {
        m.poke16(map.row_table.first + y * 2, addr);
        // The next line down inside a cell is the next byte. Below a
        // cell's last line comes the top of the cell underneath, 320 bytes
        // on from this cell's top line: 313 on from its last.
        addr += if (y % 8 == 7) 313 else 1;
    }
}
```

**`src/screen.zig`** (replace `rowAddress`)

```zig
/// The address of the first byte of bitmap row `y` (0-199).
pub fn rowAddress(m: *Machine, y: u8) u16 {
    m.work(4); // doubling y: one shift
    return m.peek16(map.row_table.first + @as(u16, y) * 2);
}
```

`peek16` reads the two bytes of an address in one call, 8 cycles, and the
`@as(u16, y) * 2` finds row `y`'s entry: two bytes per entry, so entry
`y` is `y × 2` bytes into the table. A multiply by two is one shift, which
we charge as 4 cycles. So finding a row went from 132 cycles to 12.

Replace the tests at the bottom of the file too: `plot` now needs the
table built, and the table deserves a test of its own, checking all 200
entries against the card's formula.

**`src/screen.zig`** (replace everything from `// ---- tests` down)

```zig
// ---- tests ----------------------------------------------------------------

const std = @import("std");

test "the row table agrees with the reference card's formula" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    for (0..200) |y| {
        const card: u16 = @intCast(hw.bitmap + (y / 8) * 320 + y % 8);
        try std.testing.expectEqual(card, rowAddress(m, @intCast(y)));
    }
}

test "plot sets one fat pixel and leaves its neighbours alone" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    start(m);
    m.ram[hw.bitmap + 8 + 3] = 0b11_11_11_11; // row 3 of cell 1: fat pixels 4-7
    plot(m, 6, 3, 0b01);
    try std.testing.expectEqual(0b11_11_01_11, m.ram[hw.bitmap + 8 + 3]);
    try std.testing.expectEqual(0b01, codeAt(m, 6, 3));
    try std.testing.expectEqual(0b11, codeAt(m, 7, 3));
}
```

Finally, build the table at boot.

**`src/main.zig`** (replace `boot`)

```zig
pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    m.load(map.stars.first, &title.star_map);
}
```

Run the same command:

```
ran 100 frames (96 calls to frame)
cycles: max 96024 (488%), avg 7602 (38%) of 19656
  bucket 0: max 16, avg 12
  bucket 1: max 96008, avg 7590
overruns: 0, loading pauses: 1
last frame: frames/frame_00099.ppm
```

No overruns, 96 calls, and the stars twinkle at full speed. (The
average is pulled up by the long first frame.) A twinkling frame on its
own is now **6,672 cycles, 34% of the budget**: the meter is a
comfortable green, a third of the way across. Same stars, same pixels, same picture. The only difference is that we
stopped working out the same 200 answers fifty times a second.

:::power-up The Lookup Table Power-Up
When a calculation has a small number of possible inputs and the answer
never changes, work out every answer once and store them in a table.
Each lookup is then a read (8 cycles here) instead of the calculation
(132 cycles here). It costs memory, 400 bytes for the row table, and in
exchange the hottest path in the drawing code gets eleven times faster.
On a machine with no multiply instruction, a table of answers is almost
always cheaper than working them out, and the 1984 disk is full of them.
You'll meet a second one in this chapter, for the letters.
:::

:::widget toggle
The title screen running live, with a switch: "row table" on or off.
Off swaps `rowAddress` back to the multiply and the meter goes red;
on, it's green again.
:::

### What a pointer really is

Chapter 1 promised to show what a pointer really is, and you've been
holding a few for a page now. Every entry in the row table is an
**address**, and `pixelByte` takes one and adds to it: start of row `y`,
plus `(x / 4) × 8`. An address you can store in memory, hand to a
function, and do sums on: **that's a pointer.** There's nothing more to
it.

Zig's own pointers are the same idea, built into the language. When
`boot` gets `m: *Machine`, it gets the address where the machine's state
lives, and `m.ram` means "the `ram` field: that address, plus however far
into a `Machine` the field sits". When Chapter 1 wrote `&picture`, it
handed `load` the address of the picture's first byte. The difference is
that a Zig pointer carries a type, so the compiler knows what's at the
other end (`*Machine`, `*const [8]u8`) and checks every use. Our `u16`
addresses are bare numbers, and we keep track of what they point at
ourselves, with the memory map's names.

:::under-the-hood A JavaScript reference vs. an address
In JavaScript, every object you pass around is secretly a pointer:

```js
const room = { x: 3 };
const same = room;   // copies the pointer, not the object
same.x = 4;          // room.x is 4 now too
```

That's why changing `same` changes `room`. But JavaScript never lets you
*see* the address, or add 1 to it, because the engine moves objects
around the heap whenever it likes. On the Comet 64 nothing moves unless
you move it, so an address is a plain number. You can store it in a
table (the row table is 200 of them), add to it (`+ column * 8`), and
step along memory with it (`dst += 8`, next cell across). That's what
makes the tricks in this chapter possible: data that knows where other
data is.
:::

:::inside-the-disk Rows by table
The 1984 disk keeps its row table at `$BB00` and `$BC00`: two
256-byte tables, the high byte of each row's address in one and the low
byte in the other, because its processor reads one byte at a time. It
builds them at start-up the same way we do, stepping 1 byte at a time
and 313 at the bottom of each cell, without a single multiply.

Its shape-drawing routine goes one better. It looks up only a shape's
*top* row in the table, then walks down the screen itself, adding 1, or
313 at a cell boundary, exactly like the loop that built the table. We
look up every row, which is a little slower but easier to read, and at
12 cycles a row it's cheap enough.
:::

## One table for every picture

Think about how a Dr. Creep room looks. Every walkway is the same few
bricks repeated. Every ladder is the same rung, over and over. Doors,
poles, lightning machines, keys: each one is the same picture wherever
it appears, in every room of every castle. You don't store rooms as
pictures. You store **pieces**, once, and a room says where to put them.

The game keeps all its pieces in one place, the **shape table**, and
gives each one a number, its **shape ID**. Room pieces, the frames of
every sprite, and (as you'll see) even letters all go through it. Here's
how it lies in memory:

```
  $6800  ┌────────────────────────────────────────┐
         │ directory: a 2-byte pointer per shape  │  shape 0's address
         │                                        │  shape 1's address ...
         ├────────────────────────────────────────┤
         │ shape: width │ height │ flags │        │  width in bytes (4 fat pixels each)
         │   pixels: width × height bytes         │  row by row, top first
         │   screen plane: width × cells bytes    │  room shapes only:
         │   colour RAM:   width × cells bytes    │  cells = ceil(height / 8) rows
         ├────────────────────────────────────────┤
         │ the next shape ...                     │
```

To find shape `id`, read the pointer at `$6800 + id × 2`, and that's
where the shape starts. A pointer in a table, pointing at more data:
this is pointers doing the job they're for. Shapes are all different
sizes, so you can't find shape 7 by multiplying 7 by a size, but a
directory of addresses finds any of them in one read.

A room shape is its pixels and then its colours, a screen-plane byte and
a colour-RAM byte for every cell it covers. That's the same layout the
castle file's pictures will use in later chapters, so one drawing routine
will serve both.

### Drawing pictures as text

We need art, and we're not going to type pixels in hex. Instead, a
picture is a list of strings, one character per fat pixel, and Zig turns
it into bytes while the game compiles. Here's the top of the art file
and one complete shape, a piece of walkway:

**`src/art.zig`** (new file: the beginning, and the walkway)

```zig snippet
//! The game's pictures, drawn as text. One string per row of fat pixels:
//! '.' is code 00 (the background), '1', '2', '3' are codes 01, 10, 11.
//! For a room shape, the three colours say what those codes look like.
//! For a sprite frame, 10 is the sprite's own colour and 01 and 11 are
//! the two colours every multicolour sprite shares.

const Color = @import("machine").Color;
const shapes = @import("shapes.zig");
const room = shapes.room;
const frame = shapes.frame;
const mirror = shapes.mirror;

// ---- room pieces ------------------------------------------------------------

/// Floors, ladders and poles share colours, so they can cross each other
/// without fighting over a cell.
const stone = [3]Color{ .brown, .pink, .light_grey };

pub const walkway = room(stone, &.{
    "3333",
    "2221",
    "2221",
    "1111",
    "2122",
    "2122",
    "1111",
});
```

`.` is code 00, and `1`, `2` and `3` are codes 01, 10 and 11. `room`
attaches three colours: here code 01 is brown mortar, code 10 is pink
brick and code 11 is the light grey top edge. Squint at the strings and
you can see the brickwork, with a mortar line through the middle and the
bricks offset row to row.

The whole of `art.zig` is bulk data, about 370 lines of pictures: the
walkway's two ends, the ladder, pole, door, window and torch, the moon,
the castle tower and wall, and the explorer's walk. Copy the full file
from the checkpoint in the Warp Zone at the end of the chapter (it's
`code/ch02/src/art.zig`) into your `src/`. We'll look at the explorer's
frames when we animate him.

Now the code that turns those strings into the table.

**`src/shapes.zig`** (new file)

```zig
//! The shape table: every picture in the game (room pieces, letters and
//! sprite frames) in one table, found by ID.
//!
//! In memory the table starts with a directory, a two-byte pointer per
//! shape, and then the shapes themselves. Each shape is
//!
//!   width (bytes)  height (rows)  flags  pixels: width * height bytes
//!
//! and a room shape then carries its colours: one screen-plane byte per
//! cell, then one colour-RAM byte per cell, width * ceil(height / 8) each.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const art = @import("art.zig");

/// Every shape, by ID. Each name except `glyph` has a picture of the same
/// name in art.zig.
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
};

/// A picture as art.zig draws it: one string per row, one character per
/// fat pixel. '.' is code 00, and '1', '2', '3' are codes 01, 10, 11.
pub const Art = struct {
    flags: u8 = 0,
    /// Room shapes: the colours for codes 01, 10 and 11. Sprite frames
    /// have none (their colours are the sprite's).
    colors: ?[3]Color = null,
    rows: []const []const u8,
};

/// A room shape: drawn into the bitmap, with these colours in every cell.
pub fn room(colors: [3]Color, rows: []const []const u8) Art {
    return .{ .colors = colors, .rows = rows };
}

/// A sprite frame: a multicolour sprite picture, at most 12 fat pixels
/// wide and 21 rows tall. Code 10 takes the sprite's own colour.
pub fn frame(color: Color, rows: []const []const u8) Art {
    return .{ .flags = @intFromEnum(color), .rows = rows };
}

/// The same picture facing the other way.
pub fn mirror(comptime a: Art) Art {
    comptime {
        var rows: [a.rows.len][]const u8 = undefined;
        for (a.rows, 0..) |row, r| {
            var flipped: [row.len]u8 = undefined;
            for (row, 0..) |ch, i| flipped[row.len - 1 - i] = ch;
            const done = flipped;
            rows[r] = &done;
        }
        const done = rows;
        return .{ .flags = a.flags, .colors = a.colors, .rows = &done };
    }
}

/// Turn a picture into the bytes the shape table holds. Every mistake in
/// the art is a compile error.
fn pack(comptime name: []const u8, comptime a: Art) []const u8 {
    comptime {
        const height = a.rows.len;
        const pixels = a.rows[0].len;
        if (pixels % 4 != 0)
            @compileError(std.fmt.comptimePrint("shape {s}: {d} fat pixels wide; shapes are whole bytes of 4", .{ name, pixels }));
        const width = pixels / 4;
        if (a.colors == null and (width > 3 or height > 21))
            @compileError("shape " ++ name ++ ": sprite frames are at most 12 fat pixels by 21 rows");

        var out: []const u8 = &.{ width, height, a.flags };
        for (a.rows, 0..) |row, r| {
            if (row.len != pixels)
                @compileError(std.fmt.comptimePrint("shape {s}: row {d} is {d} fat pixels wide, not {d}", .{ name, r, row.len, pixels }));
            for (0..width) |b| {
                var byte: u8 = 0;
                for (row[b * 4 ..][0..4]) |ch| {
                    const code: u8 = switch (ch) {
                        '.' => 0b00,
                        '1' => 0b01,
                        '2' => 0b10,
                        '3' => 0b11,
                        else => @compileError(std.fmt.comptimePrint("shape {s}: row {d} has '{c}'; use . 1 2 3", .{ name, r, ch })),
                    };
                    byte = byte << 2 | code; // leftmost pixel ends up in the top bits
                }
                out = out ++ [_]u8{byte};
            }
        }

        if (a.colors) |c| {
            const cells = width * ((height + 7) / 8);
            const screen_byte = @as(u8, @intFromEnum(c[0])) << 4 | @intFromEnum(c[1]);
            out = out ++ [_]u8{screen_byte} ** cells ++ [_]u8{@intFromEnum(c[2])} ** cells;
        }
        return out;
    }
}

/// The whole table, directory first, built while the game compiles. The
/// pointers in the directory are addresses in the Comet 64's memory:
/// where each shape will be once boot copies the table into place.
pub const table: []const u8 = build();

fn build() []const u8 {
    comptime {
        @setEvalBranchQuota(200_000);
        const ids = std.enums.values(Id);
        var directory: []const u8 = &.{};
        var shapes: []const u8 = &.{};
        var at: u16 = map.shape_table.first + ids.len * 2;
        for (ids) |id| {
            // The glyph is built at run time, in the text region.
            const where = if (id == .glyph) map.text_glyph else at;
            directory = directory ++ [_]u8{ where & 0xFF, where >> 8 }; // low byte first
            if (id == .glyph) continue;
            const bytes = pack(@tagName(id), @field(art, @tagName(id)));
            shapes = shapes ++ bytes;
            at += bytes.len;
        }
        const all = directory ++ shapes;
        if (all.len > map.shape_table.last - map.shape_table.first + 1)
            @compileError("the shape table doesn't fit in its region");
        const done = all[0..all.len].*;
        return &done;
    }
}

/// Where shape `id` lives: follow its pointer in the directory.
pub fn address(m: *Machine, id: Id) u16 {
    m.work(4); // doubling the ID
    return m.peek16(map.shape_table.first + @as(u16, @intFromEnum(id)) * 2);
}

test "a picture packs into width, height, flags, pixels and colours" {
    const bytes = comptime pack("test", room(.{ .red, .green, .blue }, &.{
        "123.....",
        "33333333",
    }));
    try std.testing.expectEqualSlices(u8, &.{
        2, 2, 0, // 2 bytes wide, 2 rows, no flags
        0b01_10_11_00, 0b00_00_00_00, // row 0
        0b11_11_11_11, 0b11_11_11_11, // row 1
        0x25, 0x25, // screen plane, per cell: red (2) high, green (5) low
        0x06, 0x06, // colour RAM, per cell: blue (6)
    }, bytes);
}
```

This file does all its real work while the game compiles.

**`Id`** lists every shape. `enum(u8)` numbers them from 0, and the
number is the shape ID: `walkway` is shape 1, `explorer_left_3` is
shape 19.

**`pack`** turns one picture into bytes. It counts the rows for the
height and the characters of the first row for the width, packs each run
of four characters into a byte (`byte << 2 | code`: shift what you have
left two places, OR the next code into the gap, and after four codes the
first is in the top two bits), and then appends the colours, the same
screen-plane and colour-RAM byte for every cell. A `comptime` block runs
entirely at compile time, so every check in it is a **compile error**,
not a crash: a row that's too wide, a stray character, a sprite frame
that won't fit in a sprite.

**`build`** walks the IDs in order, packs each picture, and writes the
directory. `@field(art, @tagName(id))` is the neat part: `@tagName`
turns the ID `.walkway` into the string `"walkway"`, and `@field` looks
up the declaration of that name in `art.zig`. So the IDs and the
pictures are matched by name, and a shape with no picture is a compile
error too. Each pointer in the directory is a real Comet 64 address,
`$6800` plus the directory plus every shape before it, worked out before
the game ever runs. All the game does at boot is copy the finished bytes
into place.

One entry points somewhere else. Letters are built on the fly, one at a
time, in a little scratch shape in the text region at `$0310`, so the
directory entry for `glyph` points there instead of into the table. A
pointer can point anywhere. The table doesn't care.

`address`, the only part that runs at play time, follows a pointer:
`peek16` the directory entry for `id`, and that's the shape's address.

:::game-over Bad art doesn't build
Give a row of the explorer one fat pixel too many, and the build stops:

```
src/shapes.zig:95:17: error: shape explorer_right_1: row 20 is 9 fat pixels wide, not 8
```

A stray `x` instead of `.` says which shape, which row and which
character. A sprite frame wider than 12 fat pixels or taller than 21 rows
says so. Every one of these would be a garbled picture on a machine that
didn't check; here they never reach the screen.
:::

:::pro-tip Widen before you shift
`@intFromEnum(Color.dark_grey)` is a `u4`, because `Color` is an
`enum(u4)`. Shift a `u4` left by 4 and every bit falls off the end, and
Zig refuses:

```
error: type 'u2' cannot represent integer value '4'
```

(A `u4` can only be shifted by 0 to 3, and the shift amount's type,
`u2`, can't hold a 4.) Widen it first, `@as(u8, @intFromEnum(c)) << 4`,
as `pack` and `title.draw` do.
:::

Copy the table into place at boot. Add the import below `screen`:

**`src/main.zig`** (add below the `screen` import)

```zig
const shapes = @import("shapes.zig");
```

**`src/main.zig`** (replace `boot`)

```zig
pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
}
```

`zig build test` runs `pack`'s test, which checks a tiny two-row shape
byte by byte.

:::byte-budget The shape table
Twenty shapes come to **1,059 bytes**: a 40-byte directory and a
thousand bytes of pictures. The castle tower is the biggest at 243
bytes; a piece of walkway is 12. The region has room for 4,096, so the
table can quadruple before the overlap check complains. Pictures that
repeat cost nothing extra: the room's floor is forty walkway pieces, and
the table holds one.
:::

## The blitter

Now the routine that stamps a shape onto the screen. Old programmers
called this a **blitter**, from "block transfer". Ours takes a shape ID
and a position: **x in fat pixels (0–159), y in pixel rows (0–199)**,
the shape's top-left corner.

There's one rule about x. Shapes are whole bytes wide, and a byte is four
fat pixels, so a shape always starts at the left edge of a byte: x is
rounded down to a multiple of 4. That's how the 1984 game works, and it
makes drawing fast: every byte of the shape lands on exactly one byte of
the screen, with no shifting.

**`src/screen.zig`** (add the import below `map`)

```zig
const shapes = @import("shapes.zig");
```

**`src/screen.zig`** (add below `clear`)

```zig
/// Draw shape `id` with its top-left corner at fat pixel (x, y). x is
/// rounded down to a multiple of 4, because shapes sit on whole bitmap
/// bytes. Anything past the right or bottom edge of the screen is cut off.
pub fn drawShape(m: *Machine, id: shapes.Id, x: u8, y: u8) void {
    var src = shapes.address(m, id);
    const width = m.peek(src);
    const height = m.peek(src + 1);
    src += 3; // past width, height and flags
    const column = x / 4;

    // The pixels, a row at a time, ORed over whatever is already there.
    var row: u16 = 0;
    while (row < height) : (row += 1) {
        const line = y + row;
        if (line < 200) {
            var dst = rowAddress(m, @intCast(line)) + @as(u16, column) * 8;
            var i: u16 = 0;
            while (i < width and column + i < 40) : (i += 1) {
                m.poke(dst, m.peek(dst) | m.peek(src + i));
                dst += 8; // the same line of the next cell along
                m.work(4);
            }
        }
        src += width;
    }

    // The colours: rows of cells, one screen-plane byte and one colour-RAM
    // byte per cell. A shape that doesn't start on a cell's top line
    // reaches one more row of cells, which gets the last row's colours.
    const cell_rows = (height + 7) / 8;
    const reach = cell_rows + @intFromBool(y % 8 != 0);
    const screen_src = src;
    const color_src = src + cell_rows * width;
    // The top line of a cell row is bitmap + row * 320; one eighth of
    // the distance from the bitmap's start is row * 40, the cell number.
    var cell = (rowAddress(m, y & 0b1111_1000) - hw.bitmap) / 8 + column;
    var r: u16 = 0;
    while (r < reach and y / 8 + r < 25) : (r += 1) {
        const from = @min(r, cell_rows - 1) * width;
        var i: u16 = 0;
        while (i < width and column + i < 40) : (i += 1) {
            m.poke(hw.screen + cell + i, m.peek(screen_src + from + i));
            m.poke(hw.color_ram + cell + i, m.peek(color_src + from + i));
            m.work(4);
        }
        cell += 40;
    }
}
```

Walk through it with a pointer in each hand. `src` starts at the shape's
address, reads the width and height, and steps past the three header
bytes. Then, for each row, `dst` is the screen address of that row
(`rowAddress`, plus 8 bytes per column across), and for each byte of the
row we copy a byte from `src` to `dst`, stepping `dst` by 8 to reach the
same line of the next cell. Both pointers only ever move forward through
memory.

The pixels are **ORed** onto the screen, not copied over it. Draw a
ladder through a walkway and the ladder's rails land on top of the
bricks rather than punching holes in them; a 00 pixel in a shape leaves
what's underneath alone. The 1984 game does the same, which is why it
clears the screen before drawing a room.

Then the colours. By now `src` has stepped past every pixel and points
at the shape's screen-plane bytes, with the colour-RAM bytes after those.
These are *copied*, not ORed: a cell can only have one set of colours.

To find the first cell, there's a small trick that saves another
multiply. `y & 0b1111_1000` clears the bottom three bits of `y`, which
rounds it down to the top row of its cell (another mask). The row table's
address for that row is `$E000` plus `cell row × 320`. Subtract `$E000`,
divide by 8, and you have `cell row × 40`: the number of the first cell
in that row, exactly what the screen plane and colour RAM are indexed
by. One table, two jobs.

A shape that starts partway down a cell spills into one extra row of
cells, and that row gets the shape's last row of colours again. And
anything past the right edge (column 40) or the bottom (row 200) is cut
off.

:::secret-passage Where this blitter will be used next
Chapter 3's castle file places its objects with an X that is a fat
pixel **plus 16**, so that an object can sit partly off the left edge of
the screen and still fit in one byte. We'll add a small conversion when
we read the castle; the blitter itself keeps the plain 0–159 fat pixel
you're using here.
:::

Now the castle. Replace `draw` in the title:

**`src/title.zig`** (replace `draw`)

```zig
/// Draw the title screen. Call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    // The stars' colours, in every cell: dark grey, light grey, white.
    m.fill(hw.screen, 1000, @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.light_grey));
    m.fill(hw.color_ram, 1000, @intFromEnum(Color.white));

    screen.drawShape(m, .moon, 124, 4);

    // The castle: two towers, and a wall with a door in it.
    screen.drawShape(m, .tower, 8, 136);
    screen.drawShape(m, .tower, 140, 136);
    var x: u8 = 20;
    while (x < 140) : (x += 4) {
        if (x < 76 or x >= 88) screen.drawShape(m, .wall, x, 168);
    }
    screen.drawShape(m, .door, 76, 168);
}
```

Build and reload. A full moon hangs over the stars, and a grey castle with
lit windows stands along the bottom of the screen, its door set in the
wall. The wall leaves a gap three cells wide for the door, and that's
not only for looks. The wall and the door have different colours, and if
the door were drawn over a piece of wall, the wall's pixels in the
door's cells would take the door's colours. It's the 4-colours-per-cell
rule again, and it's why the room's walkways, ladders and poles all share
one set of colours: they cross each other.

## Words in the bitmap

The title needs a title. There's no text mode on the Comet 64 (the
display is always the bitmap), so letters have to be drawn into the
bitmap like everything else. And we don't need to draw a font: the
machine has one built in.

The card's section 7 describes the **character ROM**: 256 glyphs, 8 × 8,
one bit per pixel, leftmost pixel in bit 7. `m.charRom('A')` returns a
pointer to the eight bytes of the letter A. That's a Zig pointer, `*const
[8]u8`: the address of eight bytes, which we can loop over directly.

The font is one bit per pixel, and the bitmap is two. We follow the 1984
game: **each glyph bit becomes one fat pixel**. A 1 becomes code 01, a 0
becomes code 00, so each 8-pixel row of the glyph becomes 8 fat pixels:
two bitmap bytes. The letters come out 16 dots wide and 8 tall, in a
broad, chunky style the font was designed for.

Expanding bits one at a time would mean eight shifts and tests per row,
64 per letter. But look at it four bits at a time. Four glyph bits
become one bitmap byte, and four bits have only 16 possible values. A
small table, then:

```
  glyph bits   bitmap byte
  0000         00 00 00 00   $00
  0001         00 00 00 01   $01
  0010         00 00 01 00   $04
  ...
  1011         01 00 01 01   $45
  ...
  1111         01 01 01 01   $55
```

That's the **widen table**: 16 bytes at `$0300`. A glyph row's high four
bits (`bits >> 4`) look up its left byte, and its low four bits
(`bits & 0x0F`, a mask) look up its right byte. Two reads per row.

Each letter is drawn *through the shape table*. The text code writes the
letter's 16 pixel bytes into the `glyph` scratch shape at `$0310`, sets
its colours, and calls `drawShape(.glyph, ...)`. So letters get the
same blitter, the same clipping and the same colour handling as every
other picture, for free.

The last thing to decide is how a string ends. JavaScript strings carry
their length; C strings end with a zero byte. The 1984 game does
neither: **the last letter of a string has bit 7 set.** Printable
characters are all below `$80`, so bit 7 is never needed for the letter
itself. Mark the last one with it, and the string needs no length byte
and no terminator byte: its end costs nothing at all. The castle file
stores all its text this way, so our printer reads it the same way.

**`src/text.zig`** (new file)

```zig
//! Text: letters from the character ROM, blown up into the bitmap one
//! glyph bit to one fat pixel, and drawn through the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const map = @import("map.zig");
const screen = @import("screen.zig");

/// The glyph shape's pixels start after its width, height and flags.
const glyph_pixels = map.text_glyph + 3;
const glyph_screen = glyph_pixels + 2 * 8; // then two screen-plane bytes
const glyph_colors = glyph_screen + 2; // and two colour-RAM bytes

/// Build the widen table, and the glyph shape's header.
pub fn start(m: *Machine) void {
    // Entry n is four glyph bits (the bits of n) as four fat pixels: a 1
    // bit becomes code 01, a 0 bit code 00. So 0b1011 becomes 01 00 01 01.
    var n: u8 = 0;
    while (n < 16) : (n += 1) {
        var byte: u8 = 0;
        var bit: u3 = 4;
        while (bit > 0) {
            bit -= 1;
            byte = byte << 2 | ((n >> bit) & 1);
        }
        m.poke(map.text_widen + n, byte);
    }
    m.poke(map.text_glyph + 0, 2); // 2 bytes wide: 8 fat pixels
    m.poke(map.text_glyph + 1, 8); // 8 rows tall
    m.poke(map.text_glyph + 2, 0); // no flags
}

/// Print the string at `addr` with its top-left corner at fat pixel
/// (x, y). Letters are 8 fat pixels wide. The string ends at the first
/// byte with bit 7 set, which is its last letter.
pub fn draw(m: *Machine, x: u8, y: u8, color: Color, addr: u16) void {
    // Glyph pixels are code 01, whose colour is the high half of the
    // screen-plane byte.
    const ink = @as(u8, @intFromEnum(color)) << 4;
    m.poke(glyph_screen, ink);
    m.poke(glyph_screen + 1, ink);
    m.poke(glyph_colors, 0);
    m.poke(glyph_colors + 1, 0);

    var at = addr;
    var left = x;
    while (true) : ({
        at += 1;
        left += 8;
    }) {
        const letter = m.peek(at);
        const glyph = m.charRom(letter & 0x7F);
        var dst: u16 = glyph_pixels;
        for (glyph) |bits| {
            m.poke(dst, m.peek(map.text_widen + (bits >> 4))); // left half
            m.poke(dst + 1, m.peek(map.text_widen + (bits & 0x0F))); // right half
            dst += 2;
            m.work(10); // the shift, the mask, the loop
        }
        screen.drawShape(m, .glyph, left, y);
        if (letter & 0x80 != 0) break;
    }
}

/// Print a string from the program: copy it into the text buffer, then
/// draw it from there.
pub fn say(m: *Machine, x: u8, y: u8, color: Color, comptime words: []const u8) void {
    const bytes = comptime terminated(words);
    m.load(map.text_buffer, &bytes);
    draw(m, x, y, color, map.text_buffer);
}

/// `words` with bit 7 set on its last letter, the way the game stores
/// every string.
pub fn terminated(comptime words: []const u8) [words.len]u8 {
    comptime {
        if (words.len == 0) @compileError("an empty string has no last letter to mark");
        if (words.len > map.text_buffer_size) @compileError("\"" ++ words ++ "\" is too long for the text buffer");
        for (words) |c| {
            if (c >= 0x80) @compileError("\"" ++ words ++ "\" uses bit 7, which marks the end");
        }
    }
    var bytes = words[0..words.len].*;
    bytes[bytes.len - 1] |= 0x80;
    return bytes;
}

test "the last letter carries the end mark" {
    const std = @import("std");
    try std.testing.expectEqualSlices(u8, &.{ 'H', 'I', '!' | 0x80 }, &terminated("HI!"));
}
```

`draw` takes the **address** of a string in memory and walks along it:
peek a letter, draw it, step `at` forward one byte and `left` forward 8
fat pixels, and stop after the letter with bit 7 set. `letter & 0x7F`
masks bit 7 off again before asking the ROM for the glyph. That's
pointer arithmetic doing real work: the string could be anywhere in
memory (Chapter 3 points `draw` straight at text inside the castle file)
and `draw` doesn't care where.

`say` is for strings that are part of the program, like the title.
`terminated` sets bit 7 on the last letter while the game compiles, and
refuses empty strings, strings too long for the buffer, and strings that
already use bit 7. `say` copies the result into the text buffer and draws
it from there, so even the title's words are read from Comet memory and
charged for, the honest way.

:::pro-tip `&` and `|` are equals in Zig
Here's a bug that bit us while writing the widen table. The first
version said

```zig snippet
byte = byte << 2 | (n >> bit) & 1;
```

In C and JavaScript, `&` binds tighter than `|`, so that would mean
"OR in the bottom bit". In Zig, `&`, `^` and `|` all have the *same*
precedence and run left to right, so it meant `(byte << 2 | (n >> bit))
& 1`, which throws away everything but one bit. Every letter came out
as a few stray dots. When you mix `&` and `|`, put in the parentheses;
`zig fmt` keeps them.
:::

Build the table at boot. Add the import below `shapes`:

**`src/main.zig`** (add below the `shapes` import)

```zig
const text = @import("text.zig");
```

**`src/main.zig`** (replace `boot`)

```zig
pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
}
```

And put the words on the title.

**`src/title.zig`** (add the import below `screen`)

```zig
const text = @import("text.zig");
```

**`src/title.zig`** (replace `draw`)

```zig
/// Draw the title screen. Call it with the display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    // The stars' colours, in every cell: dark grey, light grey, white.
    m.fill(hw.screen, 1000, @as(u8, @intFromEnum(Color.dark_grey)) << 4 | @intFromEnum(Color.light_grey));
    m.fill(hw.color_ram, 1000, @intFromEnum(Color.white));

    screen.drawShape(m, .moon, 124, 4);
    text.say(m, 24, 40, .yellow, "THE CASTLES OF");
    text.say(m, 44, 56, .light_green, "DR. CREEP");
    text.say(m, 40, 104, .white, "PRESS FIRE");

    // The castle: two towers, and a wall with a door in it.
    screen.drawShape(m, .tower, 8, 136);
    screen.drawShape(m, .tower, 140, 136);
    var x: u8 = 20;
    while (x < 140) : (x += 4) {
        if (x < 76 or x >= 88) screen.drawShape(m, .wall, x, 168);
    }
    screen.drawShape(m, .door, 76, 168);
}
```

Build and reload. **There's your title screen!** THE CASTLES OF DR. CREEP, in yellow and light green
over the castle, and PRESS FIRE in white. The stars kept clear of the
words: `star_map` steered round their cells from the start. That's the
picture at the top of this chapter.

## Into the Entrance Hall

Fire should take us into the castle. The room is shapes placed by hand,
which is exactly the job the castle file will take over in Chapter 3. A
walkway is a left end, some middle pieces and a right end; a ladder and
a pole are one piece stacked every eight rows.

**`src/room.zig`** (replace the whole file)

```zig
//! The room: floors, a ladder, a pole and doors, placed by hand and drawn
//! from the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const screen = @import("screen.zig");
const text = @import("text.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 184;

/// Draw the whole room. Far too big for one frame: call it with the
/// display blanked.
pub fn draw(m: *Machine) void {
    screen.clear(m);
    text.say(m, 12, 8, .light_grey, "THE ENTRANCE HALL");

    screen.drawShape(m, .window, 64, 32);
    screen.drawShape(m, .window, 116, 64);
    screen.drawShape(m, .torch, 40, 40);
    screen.drawShape(m, .torch, 96, 96);
    screen.drawShape(m, .torch, 24, 144);

    walkway(m, 8, 72, 15); // upper left
    walkway(m, 92, 128, 15); // middle right
    walkway(m, 0, floor_top, 40); // the floor, wall to wall

    screen.drawShape(m, .door, 16, 72 - 32);
    screen.drawShape(m, .door, 136, 128 - 32);

    ladder(m, 104, 128, floor_top);
    pole(m, 48, 72, floor_top);
}

/// A walkway `pieces` bytes long: a left end, a middle, a right end.
fn walkway(m: *Machine, x: u8, y: u8, pieces: u8) void {
    screen.drawShape(m, .walkway_left, x, y);
    var i: u8 = 1;
    while (i < pieces - 1) : (i += 1) screen.drawShape(m, .walkway, x + i * 4, y);
    screen.drawShape(m, .walkway_right, x + (pieces - 1) * 4, y);
}

/// A ladder from `top` down to `bottom`, eight rows at a time.
fn ladder(m: *Machine, x: u8, top: u8, bottom: u8) void {
    var y = top;
    while (y < bottom) : (y += 8) screen.drawShape(m, .ladder, x, y);
}

/// A pole from `top` down to `bottom`.
fn pole(m: *Machine, x: u8, top: u8, bottom: u8) void {
    var y = top;
    while (y < bottom) : (y += 8) screen.drawShape(m, .pole, x, y);
}
```

`floor_top` moved up to row 184, so the floor sits on the bottom of the
screen with the walkway's full brickwork showing. The explorer stands on
it because his limits still come from `room.floor_top`.

The ladder and the pole run down from their walkways to the floor, and
they're drawn last, so their rails are ORed over the bricks where they
pass through. They share the walkway's colours, so there's no clash.

The title needs to notice fire. The press-not-hold test belongs with the
joystick code in `player.zig`, where `held` lives, so add a function there
that the title can call. It's the Edge Detector Power-Up from Chapter 1
again, packaged up: read the stick, compare with last frame's, and store
this frame's for next time.

**`src/player.zig`** (add at the end of the file)

```zig
/// Was fire pressed this frame? (Held now, and not last frame.)
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return held(stick, joy.fire) and !held(before, joy.fire);
}
```

Now `main.zig` gets its room modes. Add the two imports below `title`:

**`src/main.zig`** (add below the `title` import)

```zig
const room = @import("room.zig");
const player = @import("player.zig");
```

**`src/main.zig`** (replace `frame`)

```zig
pub fn frame(m: *Machine) void {
    switch (mode(m)) {
        .draw_title => {
            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
            m.bucket(bucket_drawing);
            title.draw(m);
            m.poke(hw.control, machine.display_on);
            setMode(m, .title);
        },
        .title => {
            m.bucket(bucket_drawing);
            title.twinkle(m);
            m.bucket(0);
            if (player.pressedFire(m)) setMode(m, .draw_room);
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            room.draw(m);
            m.bucket(bucket_sprites);
            player.start(m);
            m.poke(hw.control, machine.display_on);
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.bucket(bucket_sprites);
            player.show(m);

            // Then the game itself. What it decides shows up next frame.
            player.steer(m);
        },
    }
    m.bucket(0);
    m.poke(map.game_tick, m.peek(map.game_tick) +% 1);
}
```

`draw_room` is a loading pause like `draw_title`, and it's also where the
player's sprite gets set up, now that there's a room to stand in. The
`room` branch is Chapter 1's frame, in bucket 2.

Build, reload and press Space. The screen goes blank for a moment, the
meter bar turns grey, and then the Entrance Hall is there, with Chapter
1's explorer standing on its floor. He still floats up and down if you
push the stick, still in one colour, and never moves his legs. Let's fix
that.

## A walk cycle

You know a walk cycle when you see one: four or so frames of legs,
played in turn as a figure moves, and the eye fills in the rest. The
explorer needs one, and he needs to lose that floating.

### Multicolour sprites

First, more colour. Chapter 1's explorer was a **hires** sprite, one bit
per pixel, one colour. A **multicolour** sprite works like the bitmap:
two bits per pixel, so it's 12 fat pixels across, and each code picks a
colour (card section 5). Code 00 is see-through, 10 is the sprite's own
colour, and 01 and 11 are two colours that every multicolour sprite
shares, set once in `$D025` and `$D026`. We'll make the explorer's coat
his own colour (white), and give skin (pink) and his hat, belt and boots
(orange) to the shared colours, which suit any explorer.

The explorer's frames live in the shape table as **sprite frames**:
pictures with no colour cells, at most 12 fat pixels wide and 21 rows
tall. Here's the first of them, standing, facing right:

**`src/art.zig`** (part of the file you copied: the first frame)

```zig snippet
/// The explorer's coat is the sprite's own colour (code 10). Code 01 is
/// skin and code 11 is his hat, belt and boots: the two shared colours.
pub const explorer_right_0 = frame(.white, &.{
    "........",
    "...33...",
    "..3333..",
    ".333333.",
    "..1111..",
    "..11.1..",
    "..11111.",
    "...111..",
    "...22...",
    "..2222..",
    ".222222.",
    ".222222.",
    ".1.22.1.",
    "..3333..",
    "..2222..",
    "..2..2..",
    "..2..2..",
    "..2..2..",
    "..2..2..",
    "..3..3..",
    "..33.33.",
});
```

Frames 1, 2 and 3 have the same head and swing the arms and legs through
a stride. The four left-facing frames aren't drawn at all:
`mirror` reverses every row while the game compiles. Eight frames from
four drawings.

### The flags byte

A sprite frame's third byte, its **flags**, is the most tightly packed
byte in the game so far. It holds five values:

```
  bit:   7      6      5        4        3   2   1   0
       ┌──────┬──────┬────────┬────────┬───────────────┐
       │ wide │ tall │ behind │ hires  │    colour     │
       └──────┴──────┴────────┴────────┴───────────────┘
```

The low four bits are the sprite's own colour, which `frame` puts there
(`.white` is 1). Bits 4 to 7 are four on/off switches: hires instead of
multicolour, behind the background, double height, double width. Ours
are all off. One byte, a colour and four flags, read back with masks:
`flags & 0x0F` is the colour, and `flags & 0x10` is non-zero for a hires
frame. Here are the masks, and the routine that unpacks a frame into a
sprite block:

**`src/sprites.zig`** (new file)

```zig
//! Sprite frames: pictures in the shape table, unpacked into a sprite
//! block when they're needed.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const shapes = @import("shapes.zig");

/// A sprite frame's flags byte.
pub const flag_color: u8 = 0b0000_1111; // the sprite's own colour
pub const flag_hires: u8 = 0b0001_0000; // set: hires; clear: multicolour
pub const flag_behind: u8 = 0b0010_0000; // goes behind foreground pixels
pub const flag_tall: u8 = 0b0100_0000; // double height
pub const flag_wide: u8 = 0b1000_0000; // double width

/// Unpack sprite frame `id` into sprite block `block`: three bytes a row
/// for 21 rows, with see-through filling whatever the frame doesn't
/// cover. Returns the frame's flags.
pub fn unpack(m: *Machine, id: shapes.Id, block: u8) u8 {
    var src = shapes.address(m, id);
    const width = m.peek(src);
    const height = m.peek(src + 1);
    const flags = m.peek(src + 2);
    src += 3;

    var dst = hw.sprite_data + @as(u16, block) * 64;
    var row: u8 = 0;
    while (row < 21) : (row += 1) {
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            m.poke(dst + i, if (i < width and row < height) m.peek(src + i) else 0);
        }
        if (row < height) src += width;
        dst += 3;
        m.work(8); // the tests and the loop
    }
    return flags;
}
```

`unpack` copies the frame into the 63-byte block format the VIDEO chip
wants: three bytes a row, 21 rows. A frame narrower than three bytes, or
shorter than 21 rows, is padded with zeros, which are see-through. The
explorer's frames are two bytes wide, so the third byte of every row is
padding. That's why the table stores frames packed and unpacks them only
when they're needed: each of the eight frames takes 45 bytes in the
table instead of a 64-byte sprite block, and only the frame on screen
needs a block at all.

### The Double Buffer Power-Up

Here's the catch. Unpacking a frame is about 630 cycles of writes into a
sprite block, and the VIDEO chip reads that block every time the beam
passes the explorer. Remember the beam from Chapter 1: anything written
while the beam is drawing it can tear. If we unpack the next frame into
the block on screen, and the beam happens to be crossing the explorer at
that moment, the top of him shows the old frame and the bottom shows the
new one.

Today our frame is short and the unpacking finishes long before the beam
reaches the floor. But a room full of monsters, doors and machines will
push it later and later, and we don't want a sprite that only works
while the game is quiet. So we don't write to the block on screen at
all. Each sprite gets **two blocks**. The VIDEO chip shows one while we
unpack into the other, and when the new frame is complete we flip the
sprite pointer, a single byte, at the top of the next frame, before the
beam reaches the display. The chip only ever sees finished frames.

The explorer uses blocks 0 and 8, and `player_block` at `$0204` remembers
which one the chip is showing. Getting from one to the other is a neat
bit of arithmetic: 0 is `0000_0000` and 8 is `0000_1000`, so the two
differ only in bit 3. `block ^ 8` is **exclusive OR**: it flips the bits
that are set in 8 and leaves the others alone, so it turns 0 into 8 and 8
into 0. (Chapter 8 has a lot more to say about `^`; here it's a light
switch for bit 3.)

Now the new player. Most of it changes, so here's the whole file.

**`src/player.zig`** (replace the whole file)

```zig
//! Player 1: a multicolour sprite who walks the floor with joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const video = machine.video;
const map = @import("map.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");

/// The player is sprite 0. It shows block 0 or block 8, whichever one
/// isn't being rewritten.
const sprite = 0;

/// How far the sprite may go. X stops at 255 because that's the most a
/// byte can hold; the right-hand strip of the screen needs a ninth bit.
const min_x = video.sprite_origin_x;
const max_x = 255;
const floor_y = video.sprite_origin_y + room.floor_top - 21; // boots on the floor

/// The first frame of each walk: four frames facing right, then four left.
const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);

/// Once, at power-on.
pub fn start(m: *Machine) void {
    m.poke(hw.sprite_multicolor, 0b0000_0001); // sprite 0 is multicolour
    m.poke(hw.sprite_mc0, @intFromEnum(Color.pink)); // code 01: skin
    m.poke(hw.sprite_mc1, @intFromEnum(Color.orange)); // code 11: hat, belt, boots
    m.poke(map.player_last_stick, 0xFF); // nothing held
    m.poke(map.player_block, 8); // so the first frame goes into block 0
}

/// Into the room: on the floor, facing right, visible.
pub fn enter(m: *Machine) void {
    m.poke(map.player_x, 160);
    m.poke(map.player_y, floor_y);
    setFrame(m, .explorer_right_0);
    m.poke(hw.sprite_enable, 0b0000_0001); // bit 0 on: sprite 0 is shown
}

/// Copy the player's position, colour and frame into the VIDEO chip.
pub fn show(m: *Machine) void {
    m.poke(hw.spriteX(sprite), m.peek(map.player_x));
    m.poke(hw.spriteY(sprite), m.peek(map.player_y));
    m.poke(hw.spriteColor(sprite), m.peek(map.player_color));
    m.poke(hw.sprite_pointers + sprite, m.peek(map.player_block));
}

/// Walk left or right along the floor, a pixel a frame, stepping through
/// the walk cycle as he goes.
pub fn steer(m: *Machine) void {
    const stick = m.peek(hw.joy1);
    var x = m.peek(map.player_x);
    const now = m.peek(map.player_frame);
    var first: u8 = if (now >= left_0) left_0 else right_0;
    var walking = false;

    if (held(stick, joy.left) and x > min_x) {
        x -= 1;
        first = left_0;
        walking = true;
    } else if (held(stick, joy.right) and x < max_x) {
        x += 1;
        first = right_0;
        walking = true;
    }

    // Bits 2 and 3 of x count 0, 1, 2, 3 as he walks, a new frame every
    // four pixels. Standing still, he stands on frame 0.
    const step = if (walking) (x >> 2) & 0b11 else 0;
    const next = first + step;
    if (next != now) setFrame(m, @enumFromInt(next));

    m.poke(map.player_x, x);
    m.work(40); // the tests, sums and branches above
}

/// Show frame `id` from the next frame on. It's unpacked into the block
/// the VIDEO chip *isn't* showing, so the beam never sees it half done;
/// `show` points the chip at it at the top of the next frame.
fn setFrame(m: *Machine, id: shapes.Id) void {
    const hidden = m.peek(map.player_block) ^ 8; // 0 <-> 8
    const flags = sprites.unpack(m, id, hidden);
    m.poke(map.player_color, flags & sprites.flag_color);
    m.poke(map.player_block, hidden);
    m.poke(map.player_frame, @intFromEnum(id));
}

/// Was fire pressed this frame? (Held now, and not last frame.)
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return held(stick, joy.fire) and !held(before, joy.fire);
}

/// Is this switch held? Joystick switches read 0 while they're pressed.
fn held(stick: u8, switch_bit: u8) bool {
    return stick & switch_bit == 0;
}
```

The joystick code still lives in one place: `held` is exactly as Chapter
1 wrote it, and `pressedFire` is the function you added in the last
section. What's new:

- **`start`** runs once at boot. It makes sprite 0 multicolour, sets the
  two shared colours and sets `player_last_stick` to `$FF` (an idle stick),
  as Chapter 1's `start` did. `player_block` starts at 8, so the first
  frame unpacks into block 0.
- **`enter`** runs when the room has been drawn. It stands the explorer
  on the floor, unpacks his first frame, and switches the sprite on.
- **`show`** now copies one more register: the sprite pointer, from
  `player_block`. That's the flip, done at the top of the frame with the
  other register writes, where the beam can't see it.
- **`steer`** walks left or right only. (Up, down and the ladders are
  Chapter 4.) The walk frame comes straight out of `x`: `(x >> 2) &
  0b11` is bits 2 and 3 of `x`, which count 0, 1, 2, 3, 0, ... as `x`
  goes up by four, so he takes a new step every four pixels and his feet
  keep pace with the floor. Walking left, `x` counts down and the frames
  play in the order 3, 2, 1, 0; the four frames make a loop, and a loop
  of steps looks like walking whichever way round it plays. Standing
  still, he's on frame 0 of whichever way he faces, and `first`
  remembers that from the frame he's showing.
- **`setFrame`** is the double buffer: find the hidden block with `^ 8`,
  unpack into it, take the colour out of the flags, then make the
  hidden block the shown one. Only when the frame changes, about once
  every four frames while he walks.

The fire colour cycle is gone: in the castle, fire is for doorbells and
gun panels, and they're on their way.

Last, `main.zig`. The player's one-time setup moves back to `boot`, and
`draw_room` calls `enter` instead.

**`src/main.zig`** (replace `boot`)

```zig
pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
    player.start(m);
}
```

**`src/main.zig`** (in `frame`, in the `.draw_room` branch, replace `player.start(m);`)

```zig
            player.enter(m);
```

Build and reload, press fire, and walk. **He walks!** Arms swinging, legs
striding, hat on, turning to face whichever way you push.

:::power-up The Double Buffer Power-Up
Never change what the hardware is showing. Build the next picture
somewhere it can't see, then switch to it with one small write at a safe
moment. For a sprite that's two blocks and a pointer flip; it costs one
extra 64-byte block per sprite, and in exchange the frame can be unpacked
at any point in the frame, however late, and never tears. Whole screens
are double-buffered the same way on bigger machines.
:::

:::widget toggle
The room running live, with a busy frame (the beam already crossing the
explorer when his frame is unpacked) and a switch: "double buffer" on or
off. Off, his legs tear every few steps; on, he's whole.
:::

:::secret-passage Make it tear
Try it yourself. Two temporary changes: in `main.zig`'s `.room` branch,
put `m.work(14000);` on the line before `player.steer(m);`, so the frame
is busy and the beam is down by the explorer's knees when a frame gets
unpacked. Then in `setFrame`, take the `^ 8` off, so it unpacks into the
block the chip is showing. Run

```
zig build run -- --frames 72 --press 20:f:5 --press 60:r:30
```

and look at `frames/frame_00071.ppm`:

![Two close-ups of the explorer. Left: torn, his hips in a wide stride and his feet together below them. Right: the same frame with double buffering, whole.](images/02-tear.png)

On the left, his upper legs come from one frame and his feet from the
next: the beam drew him halfway through the unpacking. Put the `^ 8`
back, run it again, and you get the picture on the right, whole, even
though the frame is every bit as busy. (It shows the old frame for one more
fiftieth of a second, which nobody can see.) Take the `m.work(14000);`
out when you're done; the checkpoint doesn't have it.
:::

:::inside-the-disk Two blocks per sprite
The 1984 disk does exactly this for every sprite in the game. Its
shadow copy of the sprite pointers (part of the 30 shadow bytes from
Chapter 1) holds each sprite's current block, and the routine that
prepares a sprite finds the other half of the pair with an exclusive OR
of 8, unpacks the frame from the shape table into it, pads the rows the
frame doesn't cover with a blank row, and only then stores the flipped
pointer. The frame interrupt copies the pointers into the chip at the
top of the next frame.

The shape table itself sits near the top of the program image, about
155 shapes from `$603B`, close to 6 KB: room pieces, monsters, the
explorer, and the scratch shape letters are built in. The disk draws
text exactly the way we do, too, down to the 16-entry widen table, and
one step further: it first stamps a mask over the letter's cells, so
words can be written over a picture without the two ORing together.
The sprite area is cleared on every room change, and only the frames on
screen are ever unpacked.
:::

## A test that walks

The whole game is in place. Let's finish `main.zig` with a test that
plays it: draw the title, press fire, draw the room, and walk four
pixels right, which should be one new frame of the walk, in the other
block.

**`src/main.zig`** (add `std` at the top of the imports)

```zig
const std = @import("std");
```

**`src/main.zig`** (add at the end of the file)

```zig
test "fire on the title screen opens the room, and the explorer walks" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());

    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);

    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This()); // the press
    m.input = .{};
    _ = m.runFrame(@This()); // draws the room
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    const x = m.ram[map.player_x];
    const block = m.ram[map.player_block];

    // Four pixels right is a new frame of the walk, in the other block.
    m.input = .{ .joy1 = machine.joy.right };
    for (0..4) |_| _ = m.runFrame(@This());
    try std.testing.expectEqual(x + 4, m.ram[map.player_x]);
    try std.testing.expect(m.ram[map.player_block] != block);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_right_1), m.ram[map.player_frame]);
}
```

It checks that the title frame was a loading pause, that fire leads to
the room, and that four steps right move the explorer four pixels, onto
frame 1, in the other block. `zig build test` also runs the tests in
`screen.zig`, `shapes.zig` and `text.zig`, since `main.zig` imports them.

Here's the whole of `main.zig`:

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
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const title = @import("title.zig");
const room = @import("room.zig");
const player = @import("player.zig");

/// What the game is doing. Power-on memory is 0, so it starts by drawing
/// the title screen.
const Mode = enum(u8) { draw_title, title, draw_room, room };

/// Meter buckets, so the meter can say where each frame went.
const bucket_drawing = 1;
const bucket_sprites = 2;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
    player.start(m);
}

pub fn frame(m: *Machine) void {
    switch (mode(m)) {
        .draw_title => {
            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
            m.bucket(bucket_drawing);
            title.draw(m);
            m.poke(hw.control, machine.display_on);
            setMode(m, .title);
        },
        .title => {
            m.bucket(bucket_drawing);
            title.twinkle(m);
            m.bucket(0);
            if (player.pressedFire(m)) setMode(m, .draw_room);
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            room.draw(m);
            m.bucket(bucket_sprites);
            player.enter(m);
            m.poke(hw.control, machine.display_on);
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.bucket(bucket_sprites);
            player.show(m);

            // Then the game itself. What it decides shows up next frame.
            player.steer(m);
        },
    }
    m.bucket(0);
    m.poke(map.game_tick, m.peek(map.game_tick) +% 1);
}

fn mode(m: *Machine) Mode {
    return @enumFromInt(m.peek(map.game_mode));
}

fn setMode(m: *Machine, new: Mode) void {
    m.poke(map.game_mode, @intFromEnum(new));
}

test "fire on the title screen opens the room, and the explorer walks" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());

    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);

    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This()); // the press
    m.input = .{};
    _ = m.runFrame(@This()); // draws the room
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    const x = m.ram[map.player_x];
    const block = m.ram[map.player_block];

    // Four pixels right is a new frame of the walk, in the other block.
    m.input = .{ .joy1 = machine.joy.right };
    for (0..4) |_| _ = m.runFrame(@This());
    try std.testing.expectEqual(x + 4, m.ram[map.player_x]);
    try std.testing.expect(m.ram[map.player_block] != block);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_right_1), m.ram[map.player_frame]);
}
```

:::byte-budget Chapter 2
**Memory.** The game's own state is 8 bytes (player and game, at
`$0200–$0207`), plus the 96-byte text region. The built-in tables are
1,059 bytes of shapes and 256 bytes of star map at the top of the program
image, and the row table takes 400 bytes at `$BB00`. The explorer uses
two of the 32 sprite blocks.

**Time.** The title draws in **156,428 cycles**, eight frame slots; the
room in **125,476**, seven. Most of each is `clear`'s 80,000. Both are
loading pauses, a blank screen for an eighth of a second, and the meter
shows them grey. On the title, the stars cost **6,694 cycles a frame**,
34%; with the multiply instead of the row table they cost about 22,000, and
every frame overran. In the room a frame costs **100 cycles**, and 728 on
the one frame in four when the walk changes frame (bucket 2), well under
4% of the budget. The meter has plenty to say now, and it's saying the
room has room for monsters.
:::

:::game-over Common mistakes
- **A cell in the wrong colours.** Two shapes share a cell and the second
  one's colours win, so the first one's pixels turn the wrong colour.
  Give shapes that cross each other the same three colours (as `stone`
  does), or keep them out of each other's cells (as the castle wall does
  around its door).
- **Text that's a few stray dots.** The widen table is wrong, usually
  `&` and `|` without parentheses (see the Pro Tip). Or `say` was handed
  a string with a lowercase letter where you meant a picture glyph: the
  ROM prints lowercase as capitals.
- **A red meter on the title.** Something in the per-frame path is
  doing a multiply, or a table lookup has turned back into a calculation.
  The `bucket 1` line of the headless summary says how much.
- **A red meter when the room is drawn.** The display wasn't blanked, or
  was blanked too late. `m.poke(hw.control, 0)` must be the first thing
  the frame does: once the beam has drawn one display line with the
  display on, the long frame counts as an overrun.
- **The explorer's legs tear.** `setFrame` is unpacking into the block
  on screen: check the `^ 8`, and that `show` copies `player_block` to
  the sprite pointer.
- **The explorer is invisible or a smear of colour.** `start` didn't set
  bit 0 of `$D01C`, so the chip is reading his two-bit frame as a hires
  sprite, or `enter` didn't switch him on in `$D015`.
:::

:::boss-battle Light up the castle
From your project folder:

```
zig build
zig build test
zig build run -- --frames 300 --press 20:f:5 --press 60:r:60 --press 140:l:100 --dump-every 50
```

The headless run waits on the title, presses fire at frame 20, walks
right for 60 frames and left for 100. It prints:

```
ran 300 frames (287 calls to frame)
cycles: max 156428 (795%), avg 1472 (7%) of 19656
  bucket 0: max 38, avg 13
  bucket 1: max 156412, avg 1281
  bucket 2: max 716, avg 177
overruns: 0, loading pauses: 2
last frame: frames/frame_00299.ppm
```

The two loading pauses are the title and the room. `frame_00000.ppm` is
blank: the title is still being drawn. `frame_00050.ppm` shows the
Entrance Hall with the explorer standing in the middle of the floor,
`frame_00100.ppm` has him walking right, mid-stride, and `frame_00150.ppm`
has him walking back the other way, facing left. By `frame_00250.ppm` he's stopped, standing, a little left of
where he started.

![The Entrance Hall: a pink-brick floor, two walkways, a ladder, a sliding pole, two arched doors, windows and torches, and the explorer walking](images/02-room.png)

Then play it:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000>, watch the stars, press Space, and walk the
hall with the arrow keys. The meter is a sliver of green.

**You've drawn a castle.** Every room from here on is built from shapes
in that table, stamped by that blitter, and every monster that walks the
floors will animate the way the explorer does. Next chapter, the rooms
stop being code and become data.
:::

:::warp-zone
The finished checkpoint is [`code/ch02/`](../code/ch02/), also as a
download, [`ch02.zip`](downloads/ch02.zip), which unzips into the same
`code/` folder as the others. The full picture file is
[`code/ch02/src/art.zig`](../code/ch02/src/art.zig). To start Chapter 3
from a known-good game, replace your project with it:

```
cd code
rm -rf my-creep
cp -r ch02 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```
:::

:::bonus-stage
- **Redecorate.** Add a shape to `art.zig` and its name to `Id`: a
  portrait, a suit of armour, a cobweb for the corner. The compiler will
  tell you if the rows don't line up. Mind the cells around it.
- **Design your own room.** Rearrange `room.draw`: more walkways, a
  longer ladder, a door on every floor. Keep the explorer's floor at
  `floor_top`, or move both.
- **Blink PRESS FIRE.** The words' colour is in their cells' screen-plane
  bytes. Changing those 20 bytes every few frames makes the words flash
  without redrawing a single pixel.
- **A shooting star.** One extra pixel that `plot`s its way across the
  sky every frame, erasing behind itself. Watch bucket 1 to see what it
  costs.
:::
