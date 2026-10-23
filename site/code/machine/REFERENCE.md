# COMET 64 — Programmer's Reference Card

*Keep this card next to your keyboard. Everything your game can touch on
the Comet 64 is on it.*

The Comet 64 is a home computer with **64 KB of memory**, a **1 MHz**
processor, a **50 Hz** colour display, a VIDEO chip with **eight hardware
sprites**, a three-voice SOUND chip and **two joystick ports**. You program
it in Zig. Your program is a game module with two functions, and the
machine does the rest.

---

## 1. Your program

```zig
const machine = @import("machine");
const Machine = machine.Machine;

pub fn boot(m: *Machine) void { ... }   // once, at power-on
pub fn frame(m: *Machine) void { ... }  // 50 times a second
```

- **`boot`** runs once when the machine powers on. Set up the screen,
  copy your tables into place, and so on. Boot time is free: the meter
  isn't running yet.
- **`frame`** is the frame interrupt. It runs fifty times a second, for as
  long as the machine is on. Each call is one frame of your game.

**All of your game's changing state lives in memory, in `m.ram`.** A
`const` table in your program is fine (it's part of the program image),
but there are no `var` globals and no allocator. If your game needs to
remember something from one frame to the next, give it an address.

Every frame goes like this:

1. The machine latches the joysticks and keyboard into the input ports.
2. It resets the work meter and calls your `frame`.
3. When `frame` returns, the VIDEO chip draws the picture from what's in
   memory right then and records any sprite collisions.

---

## 2. Memory map

| Address | Size | What lives there |
|---|---|---|
| `$0000–$00FF` | 256 | Zero page. Plain memory, free for your use. |
| `$0100–$01FF` | 256 | **Reserved:** the processor's stack. Don't use. |
| `$0200–$07FF` | 1.5 KB | Free memory. |
| `$0800–$77FF` | 28 KB | **Program image.** Your game's code lives here. Large built-in tables are copied into the top of it at boot. |
| `$7800–$BFFF` | 18 KB | Free memory for your game's data. |
| `$C000–$C7FF` | 2 KB | Sprite frames: 32 blocks of 64 bytes. |
| `$C800–$CBFF` | 1 KB | Free memory. |
| `$CC00–$CFE7` | 1000 | Screen plane: one byte per 8×8 cell (two colours). |
| `$CFF8–$CFFF` | 8 | Sprite pointers: which block each sprite shows. |
| `$D000–$D3FF` | | VIDEO chip registers. |
| `$D400–$D7FF` | | SOUND chip registers (`$D400–$D418`). |
| `$D800–$DBE7` | 1000 | Colour plane: one byte per cell (low 4 bits used). |
| `$DC00–$DCFF` | | Input ports. |
| `$E000–$FF3F` | 8000 | The bitmap: 320×200 pixels. |

Addresses are written in hexadecimal: `$D020` on this card is `0xD020` in
Zig. The hardware addresses are also available by name as `machine.hw`
(for example `machine.hw.border`).

The chips' registers, the planes and the bitmap are ordinary memory. You
write them whenever you like during a frame; the VIDEO chip reads them
once, when your frame is done. The machine writes the input ports and the
collision registers between frames.

---

## 3. The display

The screen is **320 pixels wide and 200 tall**, inside a coloured border.
It is always a multicolour bitmap. Each pixel is a pair of bits, so
pixels come out twice as wide as they are tall: 160 fat pixels across,
200 down.

The screen is split into **40 × 25 cells** of 8×8 (that's 4 fat pixels
by 8 lines). Each cell may use **four colours**: the shared background
colour plus three of its own.

### How a cell is stored

A cell is 8 bytes of bitmap, one per line, top line first. Cells run left
to right, then top to bottom: cell (column `c`, row `r`) starts at

    $E000 + (r × 40 + c) × 8

Each byte is one line of four fat pixels, leftmost in the top bits:

```
  bit:     7   6     5   4     3   2     1   0
         ┌───────┬───────┬───────┬───────┐
  byte:  │ 0   1 │ 1   0 │ 1   1 │ 0   0 │   = $6C
         └───────┴───────┴───────┴───────┘
          pixel 0 pixel 1 pixel 2 pixel 3
           code 01 code 10 code 11 code 00
```

The 2-bit code picks the colour:

| Code | Colour comes from |
|---|---|
| `00` | Background colour, `$D021` (shared by the whole screen) |
| `01` | Screen plane byte for this cell, **high** 4 bits (`$CC00 + cell`) |
| `10` | Screen plane byte for this cell, **low** 4 bits |
| `11` | Colour plane byte for this cell, low 4 bits (`$D800 + cell`) |

where `cell = r × 40 + c`. Codes `00` and `01` are **background** pixels;
codes `10` and `11` are **foreground** pixels. Sprites can hide behind
foreground pixels, and bump into them (see section 5).

To find fat pixel (`x`, `y`), with `x` from 0 to 159:

    byte = $E000 + (y / 8) × 320 + (x / 4) × 8 + (y mod 8)
    bits = 7−6 for x mod 4 = 0, 5−4 for 1, 3−2 for 2, 1−0 for 3

---

## 4. VIDEO chip registers

| Address | Name | What it does |
|---|---|---|
| `$D000 + 2n` | Sprite *n* X | Low 8 bits of sprite *n*'s X position (n = 0–7) |
| `$D001 + 2n` | Sprite *n* Y | Sprite *n*'s Y position |
| `$D010` | X high bits | Bit *n* is the 9th bit of sprite *n*'s X |
| `$D015` | Sprite enable | Bit *n* on = sprite *n* is shown |
| `$D017` | Double height | Bit *n* on = sprite *n* is twice as tall |
| `$D01B` | Behind | Bit *n* on = sprite *n* goes behind foreground pixels |
| `$D01C` | Multicolour | Bit *n* on = sprite *n* is a multicolour sprite |
| `$D01D` | Double width | Bit *n* on = sprite *n* is twice as wide |
| `$D01E` | Sprite hits | Collision report: sprites touching sprites |
| `$D01F` | Bitmap hits | Collision report: sprites touching foreground pixels |
| `$D020` | Border | Border colour (0–15) |
| `$D021` | Background | Background colour, pixel code `00` |
| `$D025` | Sprite colour A | Shared colour for multicolour sprite code `01` |
| `$D026` | Sprite colour B | Shared colour for multicolour sprite code `11` |
| `$D027 + n` | Sprite *n* colour | Sprite *n*'s own colour |

Colours are palette numbers 0–15 (section 9). Only the low four bits of a
colour register count.

---

## 5. Sprites

The VIDEO chip draws up to **eight sprites** over the bitmap. They move
anywhere without disturbing what's underneath: just change their
registers.

**Frames.** A sprite frame is **24 × 21** pixels stored in **63 bytes**:
21 rows of 3 bytes, top row first, leftmost pixel in bit 7 of the first
byte of each row. Frames live in 64-byte blocks from `$C000`: block *N*
is at `$C000 + N × 64`. There's room for 32 blocks (0–31) in the sprite
area. To pick sprite *n*'s frame, write the block number to `$CFF8 + n`.
Changing that one byte is how you animate.

**Hires and multicolour.** A hires sprite has one bit per pixel: `1` is
the sprite's own colour, `0` is see-through. A multicolour sprite
(`$D01C`) uses pairs of bits, like the bitmap, giving 12 fat pixels
across:

| Code | Colour |
|---|---|
| `00` | see-through |
| `01` | sprite colour A, `$D025` |
| `10` | the sprite's own colour, `$D027 + n` |
| `11` | sprite colour B, `$D026` |

**Position.** Sprite coordinates count from a point above and to the left
of the display, so a sprite can slide in from off-screen. **X = 24,
Y = 50** puts a sprite's top-left pixel on the display's top-left pixel.
X needs 9 bits to reach the right-hand side, so its top bit lives in
`$D010`. Sprites are only seen inside the display window, not over the
border.

**Size.** `$D01D` and `$D017` double a sprite's width and height (48 × 42).

**Who's in front.** Sprite 0 is in front of sprite 1, which is in front of
sprite 2, and so on. A sprite with its bit set in `$D01B` goes behind
foreground pixels (codes `10` and `11`) and in front of background ones.

**Collisions.** While drawing, the VIDEO chip watches for a visible
sprite pixel landing on another sprite's visible pixel (sets both
sprites' bits in `$D01E`), or on a foreground bitmap pixel (sets the
sprite's bit in `$D01F`). It checks every pixel, inside the display
window. The bits **stay set** until you clear them by writing `0` to the
register. A collision drawn at the end of frame *F* is waiting for you
when frame *F + 1* begins.

---

## 6. Character ROM

The Comet 64 has a **2 KB character ROM** holding 256 glyphs of 8 × 8
pixels in the Comet's own chunky typeface. Codes `$20–$5F` follow ASCII:
space, punctuation, digits, `@`, `A–Z` and `[\]^_`. Lowercase codes
`$61–$7A` print as capitals. Codes `$01–$0B` hold picture glyphs:

| Code | Glyph | Code | Glyph |
|---|---|---|---|
| `$01` | skull | `$07` | arrow left |
| `$02` | ankh | `$08` | arrow right |
| `$03` | key | `$09` | solid block |
| `$04` | heart | `$0A` | checkerboard |
| `$05` | arrow up | `$0B` | castle tower |
| `$06` | arrow down | | |

The rest are blank. Each glyph is 8 bytes, top row first, leftmost pixel
in bit 7. One bit per pixel: you decide how to turn that into bitmap
pixels.

The ROM isn't in the 64 KB memory map. Read it with `m.charRom(code)`,
which returns a pointer to the glyph's 8 bytes. Reading the ROM is free.

---

## 7. Input ports

| Address | What you read |
|---|---|
| `$DC00` | Joystick 2 |
| `$DC01` | Joystick 1 |
| `$DC02` | Keyboard: last key pressed, as an uppercase ASCII code; `0` = none |

A joystick port packs five switches into one byte. A switch reads **0
while it's pressed** and 1 when it's not. Bits 5–7 always read 1.

```
  bit:   7   6   5    4     3     2    1    0
       ┌───┬───┬───┬──────┬─────┬────┬────┬────┐
       │ 1 │ 1 │ 1 │ fire │right│left│down│ up │
       └───┴───┴───┴──────┴─────┴────┴────┴────┘
```

With nothing pressed a port reads `$FF`. Holding up and fire reads
`$EE`. The bits are also available as `machine.joy.up`, `.down`, `.left`,
`.right` and `.fire`.

The keyboard port holds the last key pressed until **you** clear it by
writing `0`. Write `0` once you've handled a key, and you'll see each
press exactly once.

**Keys.** In the browser, joystick 1 is the arrow keys or **W A S D**,
with **Space** to fire. Joystick 2 is **I J K L**, with **Enter** to fire.
Those keys belong to the joysticks; every other key goes to the keyboard
port. **Esc** is 27, **Backspace** is 8, **Tab** is 9.

---

## 8. The work meter

The processor runs **19,656 cycles per frame** (312 lines of 63 cycles).
That's your budget: everything your `frame` does has to fit.

The machine counts what you spend. Its memory routines charge as they go,
and you charge for your own computation with `m.work`:

| Call | What it does | Cost (cycles) |
|---|---|---|
| `m.peek(addr) u8` | read a byte | 4 |
| `m.poke(addr, value)` | write a byte | 4 |
| `m.peek16(addr) u16` | read 2 bytes, low byte first | 8 |
| `m.poke16(addr, value)` | write 2 bytes, low byte first | 8 |
| `m.copy(dst, src, n)` | copy `n` bytes (overlap is fine) | 8 per byte |
| `m.fill(dst, n, value)` | set `n` bytes to `value` | 8 per byte |
| `m.mul8(a, b) u16` | multiply two bytes (there's no multiply instruction; this is a routine) | 120 |
| `m.work(n)` | charge `n` cycles for your own work | n |
| `m.view(T, addr)` | a typed pointer into memory (see below) | 0 |
| `m.charRom(code)` | a glyph from the character ROM | 0 |
| `m.meter() u32` | cycles the **previous** frame used | 0 |

`m.ram` is the memory itself and can be read directly. The meter is an
honest estimate, not a stopwatch, so play fair: if a loop does work
outside these calls, charge for it, for example `m.work(2)` per pass for
the loop's own counting and branching.

**`m.view(T, addr)`** gives you a `*align(1) T` pointing straight into
memory at `addr`, so you can treat a run of bytes as a record. `T` must
have a fixed byte layout: an `extern struct`, a `packed struct`, a
whole-byte integer, or an array of those. The view itself costs nothing;
charge `m.work` for what you do with it.

**The meter on screen.** A bar in the bottom border shows how much of
the budget the last frame used, across the width of the display:

- **green**: under 75%. Comfortable.
- **yellow**: 75% to 100%. Getting tight.
- **red, with a red stripe across the border**: over budget.

A frame that goes over budget still finishes (the Comet 64 is
forgiving), but the machine counts it as an **overrun**.

---

## 9. The palette

| No. | Colour | Hex | No. | Colour | Hex |
|---|---|---|---|---|---|
| 0 | black | `#000000` | 8 | orange | `#6F4F25` |
| 1 | white | `#FFFFFF` | 9 | brown | `#433900` |
| 2 | red | `#68372B` | 10 | pink | `#9A6759` |
| 3 | cyan | `#70A4B2` | 11 | dark grey | `#444444` |
| 4 | purple | `#6F3D86` | 12 | grey | `#6C6C6C` |
| 5 | green | `#588D43` | 13 | light green | `#9AD284` |
| 6 | blue | `#352879` | 14 | light blue | `#6C5EB5` |
| 7 | yellow | `#B8C76F` | 15 | light grey | `#959595` |

The names are also an enum, `machine.Color`: `@intFromEnum(machine.Color.purple)` is 4.

---

## 10. The SOUND chip

The SOUND chip's registers sit at `$D400–$D418`: three voices of seven
registers each, then the filter and volume. You can already write them,
and they hold what you write, but the speaker isn't connected yet. The
full SOUND chip description is in its own supplement.

<!-- TODO(author): audio output and this section's register table arrive with the music chapter. -->

---

## 11. Running your game

**In the browser:**

```
zig build wasm
python3 -m http.server -d web
```

then open <http://localhost:8000> and click the screen.

**Headless** (no screen: runs the game and saves pictures):

```
zig build run -- --frames 250 --press 50:rf:20 --dump frames --dump-every 50
```

| Option | Meaning |
|---|---|
| `--frames N` | run N frames (default 250, five seconds) |
| `--press FRAME:KEYS[:DUR][@2]` | hold joystick directions from FRAME for DUR frames (default 10). KEYS is any of `u d l r f`. Add `@2` for joystick 2. Repeat as needed. |
| `--key FRAME:C` | type the character C at FRAME |
| `--dump DIR` | where to save pictures (default `frames`) |
| `--dump-every K` | also save every Kth frame (the last frame is always saved) |

Frames are counted from 0, the first frame after `boot`. Pictures are
saved as `DIR/frame_NNNNN.ppm`, border and meter included, 384 × 272.
When the run ends you get a summary: frames run, the most and average
cycles per frame, and how many frames overran.

**Testing:** `zig build test` runs your game's own `test` blocks, then
powers the machine on with your game and runs 100 frames.
