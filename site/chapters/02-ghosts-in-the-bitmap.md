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

![The Chapter 2 title screen: a starry sky, a round moon, the words THE CASTLES OF DR. CREEP and PRESS FIRE, and a grey castle with two towers and a wooden door](images/02-title.png)

Everything on that screen comes from one table of pictures, the **shape
table**, the way the 1984 disk does it: room pieces, letters and every
frame of the explorer's walk. You'll build the table at compile time from
pictures drawn as text, write the routine that stamps shapes into the
bitmap, borrow the character ROM's font for the words, and animate the
sprite without ever letting the beam catch it half drawn.

New under the hood: **packing several values into a byte** (shifts and
masks), **pointers as addresses you can do arithmetic on**, and
**lookup tables versus computing** (and what a multiply really costs).
:::

## Four pixels to a byte

Remember Chapter 1's floor? We filled 320 bitmap bytes with `$FF`, and
the comment said "four pixels, code 11". Time to find out what that
meant, because every picture in the game depends on it.

You know the look from the player's side: on machines like this one, the
pixels are wide, and a colour never quite ends where you'd like it to.
That's the multicolour bitmap at work (the card's section 3 has the full
story). The display is 320 × 200, but a pixel takes **two bits**, so each
one is two dots wide: 160 **fat pixels** across, 200 down. A byte has
eight bits, so a byte holds **four fat pixels**, leftmost in the top two
bits:

```
  bit:     7   6     5   4     3   2     1   0
         ┌───────┬───────┬───────┬───────┐
  byte:  │ 0   1 │ 1   0 │ 1   1 │ 0   0 │   = $6C
         └───────┴───────┴───────┴───────┘
          pixel 0 pixel 1 pixel 2 pixel 3
          code 01 code 10 code 11 code 00
```

A pixel's two bits aren't a colour. They're a **code** that says where
to *find* its colour:

| Code | Colour comes from |
|---|---|
| `00` | the background colour, `$D021`, shared by the whole screen |
| `01` | this cell's screen-plane byte (`$CC00` + cell), **high** four bits |
| `10` | this cell's screen-plane byte, **low** four bits |
| `11` | this cell's colour-RAM byte (`$D800` + cell) |

A **cell** is 8 × 8 dots: 4 fat pixels across, 8 rows down, 40 cells by
25. Each cell owns one screen-plane byte and one colour-RAM byte, so
inside a cell you get four colours: the shared background plus three of
the cell's own. That's the "4 colours per 8×8 cell" rule from the
Prologue, and it's what squeezes a whole screen of colour into 8,000 +
1,000 + 1,000 bytes.

So the floor: `$FF` is `11 11 11 11`, four fat pixels of code 11, and
code 11 means "whatever colour RAM says", which we'd set to grey. **One
byte held four pixels; a second byte coloured the whole cell.**

And look at the screen-plane byte: it holds *two* colours, one in each
half. A palette number is 0–15, four bits, and a byte has room for two.
That's the chapter's first new idea, **packing several values into one
byte**. Once you start looking for it, it's everywhere on this machine.

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
alpha. A 320 × 200 canvas is 256,000 bytes, and every pixel can be any
of sixteen million colours.

The Comet 64's whole screen is 10,000 bytes, and it pays for the saving
by sharing: four pixels to a byte, three colours to a cell. There's no
`fillRect`. Setting a pixel means finding its byte and changing two bits
without touching the other six.
:::

## Claiming the memory

This chapter needs a lot more memory than the last: tables, a text
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

The star map and the shape table are **built-in tables**, part of the
program like Chapter 1's explorer picture; boot copies them to the top
of the program image. The screen plane is hardware the game is about to
write, so it goes in the map too.

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

The overlap check now guards fifteen regions, and the program image's
last byte is `stars.first - 1`, so it shrinks automatically if the tables
grow. `zig build` still builds the Chapter 1 game: nothing it used has
moved.

## One fat pixel

The card gives the address of the byte holding fat pixel (`x`, `y`):

```
byte = $E000 + (y / 8) × 320 + (x / 4) × 8 + (y mod 8)
```

Read right to left, it's Chapter 1's cell layout: `y mod 8` is the line
inside the cell, `(x / 4) × 8` skips the cells to the left (4 fat pixels
and 8 bytes per cell), and `(y / 8) × 320` skips the rows of cells above.
We'll split it in two: the start of row `y`, then the step across.

Here's the first version, straight from the card. The machine has no
multiply instruction, so the row's `× 40` (then `× 8`) has to be a call
to `m.mul8`, the multiply routine from the card's price list, at **120
cycles**. Keep an eye on that number.

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

`plot` is where the first new idea lives, so let's take it slowly.

### Shifts: sliding bits along

**`<<` and `>>` shift a number's bits** left or right, as in JavaScript.
`0b11 << 4` slides the two 1s four places left: `0b0011_0000`. Bits that
fall off the end are gone, and the places they leave fill with 0s. A shift
left by one doubles a number and a shift right halves it, so `x / 4` is
`x >> 2` and `× 8` is `<< 3`: a few cycles each, no multiply. Zig turns
`/ 4` into a shift for you, so we write whichever reads better.

`pixelShift` works out where fat pixel `x`'s two bits sit. `x % 4` says
which of the byte's four pixels it is; the leftmost pixel's bits are 6
places from the right, and each pixel after it two places further right.
So `x = 6`, pixel 2 of its byte, is at shift 2.

### Masks: changing two bits and no others

The smallest thing the machine can write is a byte, and the byte holds
three other pixels. So `plot` reads the byte, changes two bits, and
writes it back. For `plot(m, 6, 3, 0b01)` on a byte that was all 1s:

```
  the byte now         1111 1111
  mask = 0b11 << 2     0000 1100    the two bits that belong to pixel 6
  ~mask                1111 0011    ~ flips every bit
  byte & ~mask         1111 0011    pixel 6 cleared, the others kept
  code << 2            0000 0100    the new code, slid into place
  ... | (code << 2)    1111 0111    = $F7: three 11s and a 01
```

`&` with `~mask` clears exactly the pixel's two bits (AND keeps a bit
only where both sides have a 1). `|` is **bitwise OR**: each bit of the
result is 1 where *either* side has a 1, so it sets the new code's bits
without disturbing anything else. **Clear with AND, set with OR**: that's
how you change one value packed among others, on any machine, in any
language. `codeAt` goes the other way: shift the pixel's bits down to the
bottom and keep those two.

:::pro-tip Zig sizes your shifts
Why `@as(u8, code) << shift`, and why is `shift` a `u3`? In Zig, the
shift *amount* has a type that depends on what you're shifting: a `u8`
can be shifted by a `u3` (0 to 7; 8 or more would empty it), and a `u2`
only by a `u1`. Shift our `u2` code by a `u3` and the build stops with
`expected type 'u1', found 'u3'`, so we widen the code to a `u8` first.
The same thing bites with colours: `@intFromEnum(Color.dark_grey)` is a
`u4`, and `... << 4` fails with `type 'u2' cannot represent integer value
'4'`. Widen first. What Zig does *not* do is stop you shifting bits off
the top: `0xFF << 4` is quietly `0xF0`, as in JavaScript. And `@truncate`
in `codeAt` drops the high bits on purpose.
:::

`clear` wipes the screen: 8,000 bitmap bytes, 1,000 screen-plane bytes and
1,000 colour-RAM bytes. At 8 cycles a byte that's **80,000 cycles**, four
whole frames. Remember that price tag.

## A sky full of stars

Let's give `plot` something to do *every frame*. The title screen needs a
night sky, and a night sky needs stars that twinkle.

The plan: 128 stars, each a single fat pixel. Every cell gets the same
three colours (dark grey, light grey, white), and every eighth frame each
star steps through codes 00, 01, 10 and 11: off, dim, bright, brightest,
round again. Each star runs one step behind the last, so they never
twinkle in step.

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
    @setEvalBranchQuota(100_000); // compile-time loops are capped; this raises the cap
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

/// Every frame, replot the stars. Every eighth frame each one moves a step
/// through off, dim, bright and brightest, a little out of step with the last.
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

`star_map` is a top-level `const`, and Zig works out every top-level
`const` while it compiles, so this whole block, scattering 128 stars with
a little arithmetic and throwing away any that would land in a cell the
words or the moon will need, costs the Comet 64 nothing. The `blk:` label
is only there so `break :blk out` can hand back the answer. (Chapter 8
has the proper story of making numbers look random.) Boot copies the
finished 256 bytes to `$6700`.

The screen-plane fill, `dark_grey << 4 | light_grey`, is the packing from
the start of the chapter in code: shift one colour into the high four
bits, OR the other into the low four. In `twinkle`, `phase` is the clock
shifted right by three, the clock divided by eight. `phase +% i` gives
each star its own place in the cycle (`+%` is an add that wraps round
past 255 instead of stopping the game), and `@truncate` keeps the bottom
two bits: a code from 0 to 3.

Now `main.zig`. The game has screens now, so it needs to remember which
one it's on: `game_mode`, at `$0206`, one byte holding a `Mode`. Power-on
memory is zero, and zero is the first mode, `draw_title`, so the game
starts by drawing the title without being told. The explorer, his floor
and his test step out for a few sections; they all come back, better.

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
            setMode(m, .title); // the display comes back on next frame
        },
        .title => {
            m.poke(hw.control, machine.display_on); // before the beam reaches the display
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

`@enumFromInt` turns the byte back into a `Mode`. If memory ever held a
4, there's no such mode, and Zig stops the game and says so, where
JavaScript would hand you `undefined` and carry on.

### Drawing a screen is a loading pause

Chapter 1 promised that once we started drawing, the meter would have
something to say. `title.draw` clears 10,000 bytes and fills 2,000 more:
96,000 cycles, nearly five frames. So `draw_title` follows the card's
advice (section 6, "Blank the screen for big jobs"): switch the display
off first thing, while the beam is still above the display, and do the
work. The frame runs as long as it needs, and the meter shows a grey bar
instead of a red one.

Then, the satisfying part: **leave the display off**. A long frame ends
somewhere in the middle of a sweep of the beam. Switch the display back
on at the end of it, and the beam finishes that sweep with the new
screen showing, so the player watches the picture appear from the middle
down. Instead, the next frame switches the display on as its very first
job, before the beam reaches the top of the display, and the player sees
one clean cut from blank to finished. Four cycles a frame buys a perfect
reveal, and every room change in the game will work this way.

**Buckets.** `m.bucket(id)` sends the cycles that follow to one of the
meter's eight buckets, so the summary can say *where* a frame's time
went. For the rest of the series, bucket 1 is drawing, bucket 2 the
sprites, bucket 0 everything else.

The `switch` must handle every `Mode`, so the room modes get an empty
branch for now. Run it:

```
zig build run -- --frames 100
```

```
ran 100 frames (49 calls to frame)
cycles: max 96020 (488%), avg 23545 (119%) of 19656
  bucket 0: max 16, avg 16
  bucket 1: max 96004, avg 23529
overruns: 48, loading pauses: 1
last frame: frames/frame_00099.ppm
```

**48 overruns**: every frame after the loading pause. And only 49 calls to
`frame` in 100 frames, because each one runs into a second frame slot, so
the sky twinkles at half speed. Open it in the browser (`zig build wasm`
and the web server from the Prologue) and there are the stars, twinkling,
over a **red** meter and a red stripe across the border.

Add it up for one star: two peeks for its position, a peek and a poke in
`plot`, some shifting and looping, about 40 cycles. Then `rowAddress`
charges **132**: 12 for the sums and 120 for the multiply. That's 172
cycles a star, and 128 stars come to 22,020 cycles, more than the whole
frame's 19,656. Seven tenths of it is one `mul8` per star.

## The Lookup Table Power-Up

Here's the thing about `(y / 8) × 320`: `y` has only 200 possible values.
The game asks the same 200 questions over and over, and the answers
never change. So ask each one once, at boot, write the answers down, and
from then on **look them up**.

That's the **row table**: 200 addresses, two bytes each, at `$BB00`. We
can build it without multiplying at all, by walking down the screen.
Inside a cell, the next row down is the next byte. Below a cell's last
row is the top of the cell underneath, 320 bytes on from the top of this
cell, so 313 bytes on from its last row. Add 1, add 1, ..., add 313, and
repeat.

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

`peek16` reads the two bytes of an address in one call, 8 cycles. (Two-byte
values on the Comet go low byte first; Chapter 3 says why.) Entry `y` is
`y × 2` bytes into the table, and a multiply by two is one shift, so
finding a row went from 132 cycles to 12.

`plot`'s test now needs the table built, and the table deserves a test of
its own, checking all 200 entries against the card's formula:

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

**`src/main.zig`** (in `boot`, add after the `hw.background` line)

```zig
    screen.start(m);
```

Run the same command:

```
ran 100 frames (96 calls to frame)
cycles: max 96020 (488%), avg 7606 (38%) of 19656
  bucket 0: max 16, avg 16
  bucket 1: max 96004, avg 7590
overruns: 0, loading pauses: 1
last frame: frames/frame_00099.ppm
```

No overruns, 96 calls, full speed. (The average is pulled up by the long
first frame.) A title frame on its own is now **6,676 cycles, 34%**: the
meter is green and a third of the way across. Same stars, same pixels,
same picture. We only stopped working out the same 200 answers fifty
times a second.

:::power-up The Lookup Table Power-Up
When a calculation has a few possible inputs and answers that never
change, work out every answer once and keep them in a table. Here a read
and a shift (12 cycles) replace a calculation (132), eleven times
faster, for 400 bytes. On a machine with no multiply instruction, a
table of answers almost always wins, and the 1984 disk is full of them.
You'll meet another one for the letters.
:::

:::widget toggle
The title screen running live, with a switch: "row table" on or off.
Off swaps `rowAddress` back to the multiply and the meter goes red;
on, it's green again.
:::

:::inside-the-disk Rows by table
The 1984 disk keeps its row table at `$BB00` and `$BC00`: two 256-byte
tables, the high byte of each row's address in one and the low byte in
the other, because its processor reads one byte at a time. It builds
them at start-up the way we do, stepping 1 byte at a time and 313 at the
bottom of each cell, without a single multiply.

Its shape-drawing routine goes one better: it looks up only a shape's
*top* row, then walks down the screen itself, adding 1, or 313 at a cell
boundary. We look up every row, which reads better and costs only
12 cycles.
:::

## One table for every picture

Every Dr. Creep walkway is the same few bricks repeated; every ladder is
the same rung, over and over; every door is the same door, in every
castle. You don't store rooms as pictures. You store **pieces**, once,
and a room says where to put them.

The game keeps all its pieces in the **shape table**, and gives each one
a number, its **shape ID**. Room pieces, every sprite frame and (as
you'll see) even letters go through it:

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

To find shape `id`, read the address stored at `$6800 + id × 2`, and
that's where the shape starts. Shapes are all different sizes, so you
can't find shape 7 by multiplying 7 by a size, but a directory of
addresses finds any of them in one read. A room shape's pixels are
followed by its colours, a screen-plane byte and a colour-RAM byte for
every cell it covers: the same layout the castle file's pictures will
use, so one drawing routine will serve both.

### Drawing pictures as text

We're not going to type pixels in hex. A picture is a list of strings,
one character per fat pixel, and Zig turns it into bytes while the game
compiles. Here's the top of the art file and one complete shape, a piece
of walkway:

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
attaches three colours: code 01 is brown mortar, 10 pink brick, 11 the
light grey top edge. Squint and you can see the brickwork, the bricks
offset row to row.

The rest of `art.zig` is bulk data, about 370 lines of pictures. Copy
the whole file from the checkpoint in
the Warp Zone (`code/ch02/src/art.zig`) into your `src/`. Now the code
that turns those strings into the table:

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
/// name in art.zig. New shapes go at the end: the walk counts on the
/// explorer's frames being in a row, and IDs will be stored in castles.
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
        @setEvalBranchQuota(200_000); // compile-time loops are capped; this raises the cap
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
number is the shape ID: `walkway` is 1, `explorer_left_3` is 19.

**`pack`** turns one picture into bytes. The rows give the height, the
first row's length the width. Each run of four characters becomes a byte
(`byte << 2 | code`: shift what you have left two places and OR the next
code into the gap; after four codes, the first is in the top two bits).
Then come the colours, the same screen-plane and colour-RAM byte for
every cell. A `comptime` block runs entirely at compile time, so every
check in it is a **compile error**, not a crash.

**`build`** walks the IDs in order, packs each picture and writes the
directory. `@field(art, @tagName(id))` is the neat part: `@tagName` turns
`.walkway` into the string `"walkway"`, and `@field` finds the
declaration of that name in `art.zig`. IDs and pictures are matched by
name, and a shape with no picture doesn't build. Each directory entry is
a real Comet 64 address, `$6800` plus the directory plus every shape
before it, worked out before the game ever runs, and stored low byte
first. One entry points somewhere else: letters are built on the fly in a
scratch shape in the text region, at `$0310`, so `glyph`'s entry points
there. The table doesn't care where its pointers point.

`address`, the only part that runs at play time, follows a pointer:
`peek16` the directory entry for `id`, and that's the shape's address.

:::pro-tip Reading comptime code
Chapter 3 takes `comptime` apart properly; for now, a few things make
`shapes.zig` readable. A top-level `const` is always worked out while
compiling, which is why `star_map` and `table` cost the game nothing. A
`comptime` parameter, like `pack`'s `a` or `say`'s `words` later on, must
be known while compiling. `?[3]Color` is "three colours, or `null`" (like
`Optional` in Python), and `if (a.colors) |c|` runs only when there are
some, with `c` the unwrapped value. `[_]u8{x} ** cells` repeats a byte
`cells` times, the way `++` joins. `undefined` means "filled in below".
And `const done = flipped; ... &done` freezes a compile-time value so the
finished table can point at it: every comptime builder you'll write
uses that line.
:::

:::game-over Bad art doesn't build
Give a row of the explorer one fat pixel too many, and the build stops:

```
src/shapes.zig:96:17: error: shape explorer_right_1: row 20 is 9 fat pixels wide, not 8
```

A stray `x` instead of `.` names the shape, the row and the character. A
sprite frame wider than 12 fat pixels or taller than 21 rows says so.
Every one of these would be a garbled picture on a machine that didn't
check.
:::

Copy the table into place at boot:

**`src/main.zig`** (add below the `screen` import)

```zig
const shapes = @import("shapes.zig");
```

**`src/main.zig`** (in `boot`, add before the star map's `m.load`)

```zig
    m.load(map.shape_table.first, shapes.table);
```

## The blitter

Now the routine that stamps a shape onto the screen. Programmers of the
era called this a **blitter**, from "bit-block transfer". Ours takes a
shape ID and a position: **x in fat pixels (0–159), y in pixel rows
(0–199)**, the shape's top-left corner. Shapes are whole bytes wide, so
a shape always starts at the left edge of a byte: x is rounded down to a
multiple of 4. That's how the 1984 game works, and it keeps drawing
fast, since every byte of the shape lands on exactly one byte of the
screen with no shifting. (The castle file in Chapter 3 gives X as a fat
pixel plus 16; the conversion goes in the castle reader, not here.)

**`src/screen.zig`** (add the import below `map`)

```zig
const shapes = @import("shapes.zig");
```

**`src/screen.zig`** (add below `clear`)

```zig
/// Draw room shape (or glyph) `id` with its top-left corner at fat pixel
/// (x, y); sprite frames have no colours, so they don't belong here. x is
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
bytes. For each row, `dst` is the screen address of that row
(`rowAddress`, plus 8 bytes per column across), and for each byte of the
row we copy from `src` to `dst`, stepping `dst` by 8 to the same line of
the next cell. Both pointers only ever move forward through memory.

The pixels are **ORed** onto the screen, not copied over it, so a ladder
drawn through a walkway lands on top of the bricks instead of punching
holes in them; a 00 pixel leaves what's underneath alone. (The 1984 game
does the same, which is why it clears the screen before drawing a room.)
By the time the pixels are done, `src` points at the shape's screen-plane
bytes, with the colour-RAM bytes after them. Those are *copied*: a cell
can only have one set of colours.

To find the first cell there's a trick that saves another multiply.
`y & 0b1111_1000` clears the bottom three bits of `y`, rounding it down
to the top row of its cell. The row table's address for that row is
`$E000 + cell row × 320`. Subtract `$E000`, divide by 8, and you have
`cell row × 40`: the number of the first cell in that row, exactly what
the screen plane and colour RAM are indexed by. **One table, two jobs.**
A shape that starts partway down a cell spills into one extra row of
cells, which gets its last row of colours again, and anything past
column 40 or row 200 is cut off.

### What a pointer really is

Look at what that code did with addresses. It read one out of a
table (the directory), added to it (`src += 3`, `+ column * 8`), and
stepped along memory with it (`dst += 8`). An address you can store in
memory, hand to a function and do sums on: **that's a pointer.** There's
nothing more to it, and Chapter 1's promise is kept.

Zig's own pointers are the same idea, built into the language. When
`boot` gets `m: *Machine`, it gets the address where the machine's state
lives, and `m.ram` means "that address, plus however far into a
`Machine` the `ram` field sits". When Chapter 1 wrote `&picture`, it
handed `load` the address of the picture's first byte. A Zig pointer
carries a type, so the compiler knows what's at the other end and checks
every use. It also won't let you add to a `*Machine`: a pointer to one
thing has no "next". Our `u16` addresses are the kind you do sums on, and
we keep track of what they point at ourselves, with the memory map's
names.

:::under-the-hood A JavaScript reference vs. an address
In JavaScript, every object you pass around is secretly a pointer:

```js
const room = { x: 3 };
const same = room;   // copies the pointer, not the object
same.x = 4;          // room.x is 4 now too
```

But JavaScript never lets you *see* the address, or add 1 to it, because
the engine moves objects around whenever it likes. On the Comet 64
nothing moves unless you move it, so an address is a plain number: data
that knows where other data is.
:::

Now the castle:

**`src/title.zig`** (in `draw`, add after the colour-RAM fill)

```zig

    screen.drawShape(m, .moon, 124, 4);

    // The castle: two towers, and a wall with a door in it.
    screen.drawShape(m, .tower, 8, 136);
    screen.drawShape(m, .tower, 140, 136);
    var x: u8 = 20;
    while (x < 140) : (x += 4) {
        if (x < 76 or x >= 88) screen.drawShape(m, .wall, x, 168);
    }
    screen.drawShape(m, .door, 76, 168);
```

Build and reload. A moon hangs over the stars, and a grey castle with lit
windows stands along the bottom of the screen. The wall leaves a gap three
cells wide for its door, and not only for looks: the wall and the door
have different colours, and if the door were drawn over a piece of wall,
the wall's pixels in the door's cells would take the door's colours. It's
the 4-colours-per-cell rule again, and it's why the room's walkways,
ladders and poles all share one set of colours: they cross each other.

## Words in the bitmap

The title needs a title. The display is always the bitmap, so letters
have to be drawn into it like everything else, and the machine has a
font built in. The card's section 7 describes the **character ROM**: 256
glyphs, 8 × 8, one bit per pixel, leftmost in bit 7. `m.charRom('A')`
returns a `*const [8]u8`, a pointer to the eight bytes of the letter A.

We follow the 1984 game: **each glyph bit becomes one fat pixel**, a 1
becoming code 01 and a 0 code 00, so each glyph row becomes two bitmap
bytes and the letters come out broad and chunky, as the font intends.

Expanding bits one at a time would be 64 shifts and tests a letter. But
four glyph bits become one bitmap byte, and four bits have only 16
possible values. Another table, then:

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

That's the **widen table**, 16 bytes at `$0300`. A glyph row's high four
bits (`bits >> 4`) look up its left byte and its low four (`bits & 0x0F`,
a mask) its right byte. Each letter is then drawn *through the shape
table*: the text code writes the 16 pixel bytes into the `glyph` scratch
shape at `$0310`, sets its colours and calls `drawShape(.glyph, ...)`, so
letters get the same blitter, clipping and colours as every other
picture.

How does a string end? JavaScript strings carry their length; C strings
end with a zero byte. The 1984 game does neither: **the last letter of a
string has bit 7 set.** Printable characters are all below `$80`, so bit 7
is free. Mark the last letter with it and the end of the string costs no
bytes at all. The castle file stores all its text this way.

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
/// byte with bit 7 set, which is its last letter; letters that would run
/// off the right edge of the screen are left out.
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
        if (letter & 0x80 != 0 or left >= 160 - 8) break; // the end, or the edge
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

`draw` takes the **address** of a string and walks along it: peek a
letter, draw it, step `at` forward one byte and `left` forward 8 fat
pixels, and stop after the letter with bit 7 set, or at the right edge of
the screen. (The `: ({ ... })` after `while` is the continue expression,
the step that runs each time the loop goes round again, but not after a
`break`.) `letter & 0x7F` masks bit 7 off before asking the ROM for the
glyph. The string could be anywhere in memory; Chapter 3 points `draw`
straight at text inside the castle file.

`say` is for strings that are part of the program, like the title.
`terminated` sets bit 7 on the last letter at compile time and refuses
empty strings, strings too long for the buffer, and strings that already
use bit 7. `say` copies the result into the text buffer and draws it from
there, so even the title's words are read from Comet memory and paid for.

:::pro-tip `&` and `|` are equals in Zig
Here's a bug that bit us while writing the widen table. The first version
said

```zig snippet
byte = byte << 2 | (n >> bit) & 1;
```

In C and JavaScript, `&` binds tighter than `|`, so that would mean "OR in
the bottom bit". In Zig, `&`, `^` and `|` share one precedence and run
left to right, so it meant `(byte << 2 | (n >> bit)) & 1`, which throws
away all but one bit. Every letter came out as a few stray dots. When
you mix `&` and `|`, put in the parentheses; `zig fmt` keeps them.
:::

Build the widen table at boot, and put the words on the title:

**`src/main.zig`** (add below the `shapes` import)

```zig
const text = @import("text.zig");
```

**`src/main.zig`** (in `boot`, add after `screen.start(m);`)

```zig
    text.start(m);
```

**`src/title.zig`** (add the import below `screen`)

```zig
const text = @import("text.zig");
```

**`src/title.zig`** (in `draw`, add after the moon)

```zig
    text.say(m, 24, 40, .light_blue, "THE CASTLES OF");
    text.say(m, 44, 56, .light_green, "DR. CREEP");
    text.say(m, 40, 104, .white, "PRESS FIRE");
```

Build and reload. **There's your title screen!** The stars keep clear of
the words, because `star_map` steered round their cells from the start.
That's the picture at the top of this chapter.

## Into the Entrance Hall

Fire should take us into the castle. The room is shapes placed by hand,
the job the castle file takes over in Chapter 3. A walkway is a left
end, some middle pieces and a right end; a ladder or a pole is one piece
stacked every eight rows.

**`src/room.zig`** (replace the whole file)

```zig
//! The room: floors, a ladder, a pole and doors, placed by hand and drawn
//! from the shape table.

const machine = @import("machine");
const Machine = machine.Machine;
const screen = @import("screen.zig");
const text = @import("text.zig");

/// Display row (0-199) of the top of the floor the explorer walks on.
pub const floor_top = 192; // the bottom row of cells, as in Chapter 1

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

`floor_top` stays 192, the bottom row of cells, where Chapter 1's floor
was: the walkway's seven rows of brick fill it, and the explorer's limits
still come from it. The ladder and the pole are drawn last, so their rails
are ORed over the bricks where they pass through, and they share the
walkway's colours, so there's no clash.

The title needs to notice fire. The press-not-hold test belongs with the
joystick code in `player.zig`, where `held` lives: it's Chapter 1's Edge
Detector Power-Up, packaged as a function. It also stores this frame's
stick for next time, so call it exactly once a frame.

**`src/player.zig`** (add at the end of the file)

```zig
/// Was fire pressed this frame? (Held now, and not last frame.) It also
/// remembers this frame's stick for next time, so call it once a frame.
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return held(stick, joy.fire) and !held(before, joy.fire);
}
```

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
            setMode(m, .title); // the display comes back on next frame
        },
        .title => {
            m.poke(hw.control, machine.display_on); // before the beam reaches the display
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
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.poke(hw.control, machine.display_on);
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

`draw_room` is a loading pause like `draw_title`, and it sets up the
player's sprite now that there's a room to stand in. The `room` branch
reveals the screen, then runs Chapter 1's frame in bucket 2.

Build, reload and press Space. The screen goes blank for a moment under a
grey meter bar, and then the Entrance Hall is there, all at once, with
Chapter 1's explorer on its floor. He still floats up and down if you
push the stick, still flashes through colours when you press fire, and
never moves his legs. Let's fix all three.

## A walk cycle

### Multicolour sprites

First, more colour. Chapter 1's explorer was a **hires** sprite: one bit
per pixel, one colour. A **multicolour** sprite works like the bitmap,
two bits per pixel, 12 fat pixels across (card section 5). Code 00 is
see-through, 10 is the sprite's own colour, and 01 and 11 are two colours
every multicolour sprite shares, set once in `$D025` and `$D026`. The
explorer's coat is his own colour (white); skin (pink) and his hat, belt
and boots (orange) go to the shared colours, which suit any explorer.

His frames live in the shape table as **sprite frames**: pictures with no
colour cells, at most 12 fat pixels wide and 21 rows tall. Here's the
first, standing, facing right:

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

Frames 1, 2 and 3 keep the head and swing the arms and legs through a
stride. The four left-facing frames aren't drawn at all: `mirror`
reverses every row while the game compiles. Eight frames from four
drawings.

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
are all off. Read it back with masks: `flags & 0x0F` is the colour, and
`flags & 0x10` is non-zero for a hires frame.

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

`unpack` copies a frame into the 63-byte block the VIDEO chip wants,
three bytes a row for 21 rows, padding with see-through zeros wherever
the frame is narrower or shorter. The explorer is two bytes wide, so the
third byte of each row is padding. Each frame takes 45 bytes in the table
instead of a 64-byte block, and only the frame on screen needs a block
at all.

### The Double Buffer Power-Up

Here's the catch. Unpacking a frame is about 630 cycles of writes into a
sprite block, and the VIDEO chip reads that block every time the beam
passes the explorer. If we unpack into the block on screen while the beam
is crossing him, the top of him shows the old frame and the bottom the
new: a tear, like Chapter 1's.

Today our frame is short and the unpacking finishes long before the beam
reaches the floor, but a room full of monsters will push it later and
later. So each sprite gets **two blocks**. The VIDEO chip shows
one while we unpack into the other, and then we flip the sprite pointer,
a single byte, at the top of the next frame, before the beam reaches the
display. The chip only ever sees finished frames.

The explorer uses blocks 0 and 8, and `player_block` at `$0204` says which
one the chip is showing. 0 is `0000_0000` and 8 is `0000_1000`: they
differ only in bit 3. `block ^ 8` is **exclusive OR**, which flips the
bits that are set in 8 and leaves the rest, so it turns 0 into 8 and 8
into 0. (Chapter 8 has a lot more to say about `^`; here it's a light
switch for bit 3.)

Most of `player.zig` changes, so here's the whole file:

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
comptime {
    if (left_0 != right_0 + 4 or @intFromEnum(shapes.Id.explorer_left_3) != left_0 + 3)
        @compileError("the explorer's eight frames must be in a row in shapes.Id");
}

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

/// Was fire pressed this frame? (Held now, and not last frame.) It also
/// remembers this frame's stick for next time, so call it once a frame.
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

`held` is exactly as Chapter 1 wrote it, and `pressedFire` as you added
it. What's new:

- **`start`** (at boot) makes sprite 0 multicolour, sets the shared
  colours, and starts `player_block` at 8, so the first frame unpacks
  into block 0. **`enter`** (when the room is drawn) puts him on the
  floor and switches him on.
- **`show`** copies one more register, the sprite pointer: that's the
  flip, at the top of the frame.
- **`steer`** walks left or right only (up, down and ladders are
  Chapter 4). The walk frame comes straight out of `x`: `(x >> 2) & 0b11`
  is bits 2 and 3 of `x`, which count 0, 1, 2, 3, 0, ... as `x` goes up by
  four, so he takes a step every four pixels and his feet keep pace with
  the floor. Walking left they count down; the four frames make a loop,
  and a loop of steps looks like walking whichever way it plays. Standing
  still, he's on frame 0 of whichever way he faces.
- **`setFrame`** is the double buffer: `^ 8` finds the hidden block,
  `unpack` fills it, and it becomes the shown one.
- The `comptime` block under `left_0` checks that the explorer's eight
  IDs are in a row, which `steer`'s `first + step` counts on.

The fire colour cycle is gone: in the castle, fire is for doorbells and
gun panels. Last, `main.zig`:

**`src/main.zig`** (at the end of `boot`, after the star map's `m.load`)

```zig
    player.start(m);
```

**`src/main.zig`** (in `frame`, in the `.draw_room` branch, replace `player.start(m);`)

```zig
            player.enter(m);
```

Build and reload, press fire, and walk. **He walks!** Arms swinging, legs
striding, turning to face whichever way you push.

:::power-up The Double Buffer Power-Up
Never change what the hardware is showing. Build the next picture where
it can't see, then switch to it with one small write at a safe moment.
For a sprite that's a second 64-byte block and a pointer flip, and in
exchange the frame can be unpacked at any point in the frame, however
late, and never tears.
:::

:::widget toggle
The room running live, with a busy frame (the beam already crossing the
explorer when his frame is unpacked) and a switch: "double buffer" on or
off. Off, his legs tear every few steps; on, he's whole.
:::

:::secret-passage Make it tear
Two temporary changes. In `main.zig`'s `.room` branch, put
`m.work(14500);` on the line before `player.steer(m);`, so the frame is
busy. Then in `setFrame`, take the `^ 8` off, so it unpacks into the block
the chip is showing. Run

```
zig build run -- --frames 72 --press 20:f:5 --press 60:r:30
```

and look at `frames/frame_00071.ppm`:

![Two close-ups of the explorer. Left: torn, his hips in a wide stride and his feet together below them. Right: the same frame with double buffering, whole.](images/02-tear.png)

On the left, the beam is crossing his middle when the unpack starts. The
unpack writes rows faster than the beam draws them, so it overtakes the
beam at his knees: above that, the beam drew the old frame; below, the
new. His hips are mid-stride and his feet are standing. That's the ghost
in the bitmap, half of one frame haunting the next. Put the `^ 8` back
and you get the picture on the right, whole, even though the frame is
every bit as busy. Take the `m.work(14500);` out when you're done.
:::

:::inside-the-disk Two blocks per sprite
The 1984 disk does exactly this for every sprite. Its shadow copy of the
sprite pointers (part of Chapter 1's 30 shadow bytes) holds each
sprite's current block. The routine that prepares a sprite finds the
other half of the pair with an exclusive OR of 8, unpacks the frame from
the shape table into it, pads the rows the frame doesn't cover with a
blank row, and only then stores the flipped pointer for the frame
interrupt to copy into the chip.

The shape table itself sits near the top of the program image: about
155 shapes from `$603B`, close to 6 KB: room pieces, monsters, the
explorer, and the scratch shape that letters are built in. Text is drawn
our way too, down to the 16-entry widen table, and one step further: the
disk first stamps a mask over the letter's cells, so words can sit over
a picture without the two ORing together.
:::

## A test that walks

Let's finish with a test that plays the game: draw the title, press
fire, draw the room, and walk four pixels right, which should be one new
frame of the walk, in the other block.

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

`zig build test` runs it, along with the tests in `screen.zig`,
`shapes.zig` and `text.zig`, since `main.zig` imports them.

:::byte-budget Chapter 2
**Memory.** The game's own state is 8 bytes (`$0200–$0207`) plus the
96-byte text region. The built-in tables at the top of the program image
are 256 bytes of star map and a 1,044-byte shape table: a 40-byte
directory, the castle tower at 243 bytes, a walkway piece at 12, each
explorer frame at 45. The room's floor is forty walkway pieces, and the
table holds one. The 4 KB region lets the table nearly quadruple before
`build` refuses it. The row table is 400 bytes at `$BB00`, and the
explorer uses two of the 32 sprite blocks.

**Time.** The title draws in **156,200 cycles**, eight frame slots, and
the room in **126,172**, seven: about a sixth of a second of blank screen
each, with a grey meter. More than half of each is `clear`'s 80,000. A title frame
costs **6,698 cycles**, 34% (the stars are 6,660 of it); with the
multiply instead of the row table, every one overran. In the room a frame
costs **104 cycles**, and 732 on the one frame in four when the walk
changes frame (bucket 2). The meter has plenty to say now, and what it's
saying is that the room has room for monsters.
:::

:::game-over Common mistakes
- **A cell in the wrong colours.** Two shapes share a cell and the second
  one's colours win. Give shapes that cross the same three colours (as
  `stone` does), or keep them out of each other's cells (as the castle
  wall does around its door).
- **Text that's a few stray dots.** The widen table is wrong, usually `&`
  and `|` without parentheses. **No words at all:** `boot` never called
  `text.start`, so the widen table and the glyph's header are zeros.
- **Words cut short.** Letters that would pass the right edge are left
  out; a line holds 20. (Chapter 4 has the story of what happens when a
  byte like `left` overflows.)
- **A red meter on the title.** Something in the per-frame path is doing
  a multiply. The `bucket 1` line of the headless summary says how much.
- **A red meter while the room is drawn.** The display was blanked too
  late: `m.poke(hw.control, 0)` must land within the first 3,213 cycles.
- **The room appears from the middle down.** The display came back on at
  the end of the long frame. Switch it on at the top of the next one.
- **The explorer's legs tear.** `setFrame` is unpacking into the block on
  screen: check the `^ 8`, and that `show` copies `player_block`.
- **The explorer is a smear, or missing.** `start` didn't set bit 0 of
  `$D01C`, so the chip reads his two-bit frame as hires, or `enter` didn't
  switch him on in `$D015`.
:::

:::boss-battle Light up the castle
From your project folder:

```
zig build
zig build test
zig build run -- --frames 300 --press 20:f:5 --press 60:r:60 --press 140:l:100 --dump-every 50
```

The run waits on the title, presses fire at frame 20, walks right for 60
frames and left for 100. It prints:

```
ran 300 frames (287 calls to frame)
cycles: max 156200 (794%), avg 1477 (7%) of 19656
  bucket 0: max 42, avg 17
  bucket 1: max 156184, avg 1283
  bucket 2: max 716, avg 177
overruns: 0, loading pauses: 2
last frame: frames/frame_00299.ppm
```

The two loading pauses are the title and the room. `frame_00000.ppm` is
blank (the title is being drawn), `frame_00100.ppm` has him walking
right, mid-stride, and `frame_00150.ppm` walking back, facing left.

![The Entrance Hall: a pink-brick floor, two walkways, a ladder, a sliding pole, two arched doors, windows and torches, and the explorer walking](images/02-room.png)

Then play it:

```
zig build wasm
python3 -m http.server -d web
```

Open <http://localhost:8000>, watch the stars, press Space, and walk the
hall with the arrow keys. The meter is a sliver of green.

**You've drawn a castle.** Every room from here on is built from that
table and stamped by that blitter, and every monster will animate the way
the explorer does. Next chapter, the rooms stop being code and become
data.
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
- **Redecorate.** Add a shape to `art.zig` and its name **at the end of**
  `Id`: a portrait, a suit of armour, a cobweb. The compiler will tell
  you if the rows don't line up. (`drawShape` is for room shapes; a
  sprite frame has no colours for it to copy.)
- **Design your own room.** Rearrange `room.draw`: more walkways, a
  longer ladder, a door on every floor.
- **Blink PRESS FIRE.** The words' colour lives in their cells'
  screen-plane bytes. Change those 20 bytes every few frames and the
  words flash without redrawing a pixel.
- **Twinkle for less.** Seven frames in eight, `twinkle` replots the
  stars exactly as they were. Skip it when `phase` hasn't changed and
  watch bucket 1.
- **A shooting star.** One extra pixel that `plot`s its way across the
  sky, erasing behind itself. What does it cost?
:::
