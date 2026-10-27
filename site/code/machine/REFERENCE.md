# COMET 64 — Programmer's Reference Card

*Keep this card next to your keyboard. Everything your game can touch on
the Comet 64 is on it.*

The Comet 64 is a home computer with **64 KB of memory**, a **1 MHz**
processor, a **50 Hz** colour display, a VIDEO chip with **eight hardware
sprites**, a three-voice SOUND chip, **two joystick ports** and a **disk
drive**. You program
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
- **`disk`** (optional): `pub const disk: machine.drive.Image` is the disk
  that comes with your game. At power-on the machine puts it in the
  drive (section 13).

**All of your game's changing state lives in memory, in `m.ram`.** A
`const` table in your program is fine (it's part of the program image),
but there are no `var` globals and no allocator. If your game needs to
remember something from one frame to the next, give it an address.

Every frame goes like this:

1. The machine latches the joysticks and keyboard into the input ports.
2. The beam goes back to the top of the screen, the work meter resets to
   zero, and the machine calls your `frame`.
3. As your code spends cycles, the beam sweeps down the screen and the
   VIDEO chip draws each line it passes (section 6). When `frame`
   returns, the beam finishes the picture from what's in memory then.
4. The SOUND chip reads its registers and plays them until the next
   frame (section 11).

---

## 2. Memory map

| Address | Size | What lives there | Zig name |
|---|---|---|---|
| `$0000–$00FF` | 256 | Zero page. Plain memory, free for your use. | |
| `$0100–$01FF` | 256 | **Reserved:** the processor's stack. Don't use. | `hw.stack` |
| `$0200–$07FF` | 1.5 KB | Free memory. | |
| `$0800–$77FF` | 28 KB | **Program image.** Your game's code lives here. Large built-in tables are copied into the top of it at boot. | `hw.program` … `hw.program_end` |
| `$7800–$BFFF` | 18 KB | Free memory for your game's data. | |
| `$C000–$C7FF` | 2 KB | Sprite frames: 32 blocks of 64 bytes. | `hw.sprite_data` |
| `$C800–$CBFF` | 1 KB | Free memory. | |
| `$CC00–$CFE7` | 1000 | Screen plane: one byte per 8×8 cell (two colours). | `hw.screen` |
| `$CFE8–$CFF7` | 16 | Free memory. | |
| `$CFF8–$CFFF` | 8 | Sprite pointers: which block each sprite shows. | `hw.sprite_pointers` |
| `$D000–$D02E` | 47 | VIDEO chip registers (section 4). | `hw.video_chip` |
| `$D400–$D418` | 25 | SOUND chip registers (section 11). | `hw.sound_chip` |
| `$D800–$DBE7` | 1000 | Colour RAM: one byte per cell (low 4 bits used). | `hw.color_ram` |
| `$DC00–$DC02` | 3 | Input ports (section 8). | `hw.joy2`, `hw.joy1`, `hw.key` |
| `$DD00–$DD2F` | 48 | Disk drive registers (section 13). | `hw.drive_command` … `hw.drive_name` |
| `$E000–$FF3F` | 8000 | The bitmap: 320×200 pixels. | `hw.bitmap` |
| `$FF40–$FFFF` | 192 | Free memory. | |

The rest of `$D000–$DFFF` (`$D02F–$D3FF`, `$D419–$D7FF`, `$DBE8–$DBFF`,
`$DC03–$DCFF`, `$DD30–$DFFF`) is **reserved** for expansion hardware.
Don't keep anything there.

Addresses are written in hexadecimal: `$D020` on this card is `0xD020` in
Zig. The Zig names live in `machine.hw` (for example `machine.hw.border`).

The chips' registers, the planes and the bitmap are ordinary memory, and
you can write them at any time. The VIDEO chip reads them as the beam
passes (section 6). The machine writes the input ports between frames,
and the VIDEO chip sets the collision and raster registers as it draws.

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
| `11` | Colour RAM byte for this cell, low 4 bits (`$D800 + cell`) |

where `cell = r × 40 + c`. Codes `00` and `01` are **background** pixels;
codes `10` and `11` are **foreground** pixels. Sprites can hide behind
foreground pixels, and bump into them (see section 5).

To find fat pixel (`x`, `y`), with `x` from 0 to 159:

    byte = $E000 + (y / 8) × 320 + (x / 4) × 8 + (y mod 8)
    bits = 7−6 for x mod 4 = 0, 5−4 for 1, 3−2 for 2, 1−0 for 3

---

## 4. VIDEO chip registers

| Address | Zig name (`machine.hw.`) | What it does |
|---|---|---|
| `$D000 + 2n` | `spriteX(n)` | Low 8 bits of sprite *n*'s X position (n = 0–7) |
| `$D001 + 2n` | `spriteY(n)` | Sprite *n*'s Y position |
| `$D010` | `sprite_x_msb` | Bit *n* is the 9th bit of sprite *n*'s X |
| `$D011` | `control` | Bit 4: display on (1) or blanked (0). Bit 7: bit 8 of the raster line (read only). Other bits unused. |
| `$D012` | `raster` | The raster line the beam is on, low 8 bits (read only) |
| `$D015` | `sprite_enable` | Bit *n* on = sprite *n* is shown |
| `$D017` | `sprite_double_height` | Bit *n* on = sprite *n* is twice as tall |
| `$D01B` | `sprite_behind` | Bit *n* on = sprite *n* goes behind foreground pixels |
| `$D01C` | `sprite_multicolor` | Bit *n* on = sprite *n* is a multicolour sprite |
| `$D01D` | `sprite_double_width` | Bit *n* on = sprite *n* is twice as wide |
| `$D01E` | `sprite_sprite_hits` | Collision report: sprites touching sprites |
| `$D01F` | `sprite_bitmap_hits` | Collision report: sprites touching foreground pixels |
| `$D020` | `border` | Border colour (0–15) |
| `$D021` | `background` | Background colour, pixel code `00` |
| `$D025` | `sprite_mc0` | Shared colour for multicolour sprite code `01` |
| `$D026` | `sprite_mc1` | Shared colour for multicolour sprite code `11` |
| `$D027 + n` | `spriteColor(n)` | Sprite *n*'s own colour |

`spriteX`, `spriteY` and `spriteColor` are functions: `hw.spriteX(3)` is
`$D006`. `$D011` bit 4 is also `machine.display_on`. Colours are palette
numbers 0–15 (section 10). Only the low four bits of a colour register
count. At power-on every register is 0 except `$D011`, which is `$10`
(display on).

---

## 5. Sprites

The VIDEO chip draws up to **eight sprites** over the bitmap. They move
anywhere without disturbing what's underneath. Change their registers and
they move.

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
Y = 50** puts a sprite's top-left pixel on the display's top-left pixel
(`machine.video.sprite_origin_x` / `sprite_origin_y`). X needs 9 bits to
reach the right-hand side, so its top bit lives in `$D010`. Sprites are
only seen inside the display window, not over the border.

**Size.** `$D01D` and `$D017` double a sprite's width and height (48 × 42).

**Who's in front.** Sprite 0 is in front of sprite 1, which is in front of
sprite 2, and so on. A sprite with its bit set in `$D01B` goes behind
foreground pixels (codes `10` and `11`) and in front of background ones.

**Collisions.** As the beam draws, the VIDEO chip watches for a visible
sprite pixel landing on another sprite's visible pixel (sets both
sprites' bits in `$D01E`), or on a foreground bitmap pixel (sets the
sprite's bit in `$D01F`). It checks every pixel inside the display
window. The bits **stay set** until you clear them by writing `0` to the
register. A collision low on the screen is usually found after your
`frame` has finished, so look for it at the start of the next frame.

---

## 6. Racing the beam

The picture is drawn by a beam that sweeps the tube from top to bottom,
one **raster line** at a time: **312 lines a frame, 63 cycles a line**.
That's where the budget of 19,656 cycles comes from. The work meter *is*
the beam: when your `frame` has spent `c` cycles, the beam is on line
`c / 63`.

| Raster lines | What the beam is doing |
|---|---|
| 0–14 | Off the top of the tube (vertical blank) |
| 15–50 | Top border |
| **51–250** | **The display**: display row `y` is raster line `51 + y` |
| 251–286 | Bottom border (the work meter is down here) |
| 287–311 | Off the bottom of the tube (vertical blank) |

Your `frame` starts with the beam at line 0. The VIDEO chip draws each
line as the beam finishes it, from memory and registers **as they are at
that moment**. So:

- Anything you change in the first **3,213 cycles** (51 lines × 63) is in
  place before the beam reaches the display. Do your sprite and screen
  updates first and they can never tear.
- Change a sprite while the beam is halfway down it, and its top half
  shows the old frame or position and its bottom half shows the new one:
  a **tear**. The same goes for the bitmap and the colours.
- When `frame` returns, the beam finishes the rest of the picture from
  memory as you left it.

`m.rasterLine()` tells you the line the beam is on (0–311), for free.
The same number is in `$D012` (low 8 bits) and `$D011` bit 7 (bit 8).

### Blank the screen for big jobs

Some jobs are too big for one frame, like clearing the whole screen and
drawing a new room. A frame can run as long as it needs to: it takes as
many frame slots as its cycles fill (a 50,000-cycle frame takes three),
and the machine skips calling `frame` for the extra slots. Time passes as
normal while it works.

If the display was on while the beam drew any of that frame, the player
saw it run long: it's an **overrun**, and the meter turns red. If you
switch the display off first (clear bit 4 of `$D011`), the display window
shows plain border colour and nothing in it is drawn, not even sprites,
and no collisions are reported. A long frame that never showed the
display is a **loading pause**, not an overrun. The meter shows a grey
bar instead. Blank it early, before the beam reaches the display (in
the first 3,213 cycles); a display line already drawn with the display
on counts.

Switch the display back on at the start of the **next** frame, before the
beam reaches the display, and the player sees one clean cut from blank to
the finished screen. (A long frame ends partway down a sweep of the beam.
Switch the display on at the end of it instead, and the beam finishes
that sweep with the display on: the bottom of the new screen shows under
a blank top for the rest of the pause.)

```zig
// The long frame:
m.poke(hw.control, 0);                    // blank, in the first 3,213 cycles
drawTheWholeRoom(m);                      // as long as it takes

// The next frame, first thing:
m.poke(hw.control, machine.display_on);   // and reveal
```

---

## 7. Character ROM

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

## 8. Input ports

| Address | Zig name | What you read |
|---|---|---|
| `$DC00` | `hw.joy2` | Joystick 2 |
| `$DC01` | `hw.joy1` | Joystick 1 |
| `$DC02` | `hw.key` | Keyboard: last key pressed, as an uppercase ASCII code; `0` = none |

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
press exactly once. Letters and symbols arrive as uppercase ASCII;
**Return** is 13, **Backspace** is 8 and **Esc** is 27.

**Keys.** In the browser, joystick 1 is the arrow keys or **W A S D**,
with **Space** to fire. Joystick 2 is **I J K L**, with **Return** to
fire. Those keys work the joysticks *and* type into the keyboard port,
like every other key, so a game reads whichever it wants. **Tab** moves
the keyboard away from the Comet.

---

## 9. The work meter

The processor runs **19,656 cycles per frame** (312 lines of 63 cycles,
`machine.frame_budget`). That's your budget: everything your `frame` has
to do should fit.

The machine counts what you spend. Its memory routines charge as they go,
and you charge for your own computation with `m.work`:

| Call | What it does | Cost (cycles) |
|---|---|---|
| `m.peek(addr) u8` | read a byte | 4 |
| `m.poke(addr, value)` | write a byte | 4 |
| `m.peek16(addr) u16` | read 2 bytes, low byte first | 8 |
| `m.poke16(addr, value)` | write 2 bytes, low byte first | 8 |
| `m.copy(dst, src, n)` | copy `n` bytes of memory (overlap is fine) | 8 per byte |
| `m.fill(dst, n, value)` | set `n` bytes to `value` | 8 per byte |
| `m.load(dst, bytes)` | copy a `const` table from your program into memory | 8 per byte |
| `m.mul8(a, b) u16` | multiply two bytes (there's no multiply instruction; this is a routine) | 120 |
| `m.work(n)` | charge `n` cycles for your own work | n |
| `m.view(T, addr)` | a typed pointer into memory (see below) | 0 |
| `m.charRom(code)` | a glyph from the character ROM | 0 |
| `m.meter() u32` | cycles the **previous** frame used | 0 |
| `m.rasterLine() u16` | the line the beam is on | 0 |
| `m.bucket(id)` | send the cycles that follow to meter bucket `id` (0–7) | 0 |

`m.ram` is the memory itself and can be read directly. The meter is an
honest estimate, not a stopwatch, so play fair: if a loop does work
outside these calls, charge for it, for example `m.work(2)` per pass for
the loop's own counting and branching.

**`m.view(T, addr)`** gives you a `*align(1) T` pointing straight into
memory at `addr`, so you can treat a run of bytes as a record. `T` must
have exactly the same bytes in Zig as in memory:

- whole-byte integers: `u8`, `u16`, `u32` (not `usize`);
- an `extern struct` whose fields leave no gaps. Zig lines a `u16` field
  up on an even byte, so `extern struct { color: u8, ptr: u16 }` has a
  hidden padding byte and is refused. Use `ptr: [2]u8` (and `m.peek16`),
  or arrange the fields so every `u16` starts on an even byte and the
  whole record is an even number of bytes;
- a `packed struct(u8)` (or `u16`, `u32`) for a byte of flags;
- an `enum(u8)` with a `_` member, so any byte value is allowed;
- an `extern union` of any of those, every field the same size, so no
  field leaves bytes that mean nothing to it;
- arrays of any of those.

Anything else is a compile error that says what's wrong. The view itself
costs nothing; charge `m.work` for what you do with it.

**Buckets.** Each frame starts in bucket 0. Call `m.bucket(2)` before
drawing and `m.bucket(3)` before moving monsters, say, and the meter
records how much of the frame each part took. `m.last.buckets` holds the
previous frame's eight totals.

**The meter on screen.** A bar in the bottom border shows how much of
the budget the last frame used, across the width of the display:

- **green**: under 75%. Comfortable.
- **yellow**: 75% to 100%. Getting tight.
- **red, with a red stripe across the border**: over budget, with the
  display on. That's an **overrun**.
- **grey**: over budget with the display blanked. A loading pause
  (section 6).

A frame that goes over budget still finishes (the Comet 64 is
forgiving). It takes more than one frame slot instead.

---

## 10. The palette

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

## 11. The SOUND chip

The SOUND chip plays **three voices** at once. Each voice is an
oscillator, which makes a wave at the frequency you ask for, and an
**envelope**, which makes it louder and softer over time. All three go
through one volume control to the speaker.

### Registers

Each voice has seven registers. Voice 0's start at `$D400`, voice 1's at
`$D407` and voice 2's at `$D40E` (`hw.voice(v)`):

| Offset | Zig name (`machine.sound.`) | What it does |
|---|---|---|
| +0, +1 | `freq_lo`, `freq_hi` | Frequency, 16 bits, low byte first (below) |
| +2, +3 | `pulse_lo`, `pulse_hi` | Pulse width, 12 bits (low 4 bits of +3): how much of each wave the pulse is high, out of 4096. 2048 is a square wave. |
| +4 | `control` | Waveform and gate (below) |
| +5 | `attack_decay` | High 4 bits: attack. Low 4 bits: decay. |
| +6 | `sustain_release` | High 4 bits: sustain level, 0–15. Low 4 bits: release. |

Then:

| Address | Zig name | What it does |
|---|---|---|
| `$D415–$D417` | | The filter. This model doesn't have one fitted: these hold what you write and do nothing. |
| `$D418` | `hw.sound_volume` | Low 4 bits: the volume, 0 (silent) to 15. The high bits do nothing. |

At power-on every register is 0, so the chip is silent until you set the
volume.

### The control register

| Bit | Zig name | What it does |
|---|---|---|
| 0 | `sound.gate` | On: the envelope rises and holds (a key held down). Off: it fades away (the key let go). |
| 1 | `sound.sync` | Start this voice's wave again each time the voice before it starts one. |
| 2 | `sound.ring` | With the triangle: flip it over while the voice before it is in the second half of its wave. A bell-like clang. |
| 3 | `sound.testbit` | Hold the oscillator at the start of its wave, silent. |
| 4 | `sound.triangle` | Triangle wave: soft, like a flute. |
| 5 | `sound.sawtooth` | Sawtooth wave: bright and buzzy, like brass. |
| 6 | `sound.pulse` | Pulse wave: hollow and reedy; its width sets how hollow. |
| 7 | `sound.noise` | Noise: a hiss, a crash, a bang. |

The voice before voice 0 is voice 2. With no waveform bit set a voice is
silent. With two or more set, it plays them mixed together.

### Frequency

The oscillator keeps a 24-bit counter. On every cycle of the 1 MHz
clock it adds the frequency register to it, and each time the counter
goes all the way round, the wave has played once. So:

    frequency in Hz = register × 1,000,000 / 16,777,216

or, the other way, **register = Hz × 16.777216**. The A above middle C, 440 Hz, is
7,382 (`$1CD6`). The highest frequency, `$FFFF`, is just over 3,906 Hz.

### The envelope

Turn the gate on, and the voice's loudness climbs from silence to full in
the **attack** time. Then it falls in the **decay** time towards the
**sustain** level, and stays there as long as the gate is on. Turn the
gate off, and it falls to silence in the **release** time. Each time is a
4-bit number:

| Value | Attack | Decay, release | Value | Attack | Decay, release |
|---|---|---|---|---|---|
| 0 | 2 ms | 6 ms | 8 | 100 ms | 300 ms |
| 1 | 8 ms | 24 ms | 9 | 250 ms | 750 ms |
| 2 | 16 ms | 48 ms | 10 | 500 ms | 1.5 s |
| 3 | 24 ms | 72 ms | 11 | 800 ms | 2.4 s |
| 4 | 38 ms | 114 ms | 12 | 1 s | 3 s |
| 5 | 56 ms | 168 ms | 13 | 3 s | 9 s |
| 6 | 68 ms | 204 ms | 14 | 5 s | 15 s |
| 7 | 80 ms | 240 ms | 15 | 8 s | 24 s |

The decay and release times are for the whole fall, from full to
silence; a fall from a lower level is quicker. The sustain level runs
from 0 (silence) to 15 (full). The tables are
`machine.sound.attack_ms` and `machine.sound.fall_ms`.

### The output

The three voices are mixed, scaled by the volume, and sent to the speaker
through a gentle smoothing and a capacitor that lets no steady offset
through: a narrow pulse wave sounds centred, not pushed to one side.
The loudest peaks are rounded off rather than clipped. A
voice whose waveform you switch off fades out over a few milliseconds
instead of clicking.

### When the chip listens

The SOUND chip reads its registers **once a frame, when your `frame`
returns**, and plays what they say until the end of the next frame. So:

- Where in `frame` you write them doesn't matter, and nothing tears.
- A change lasts at least a frame. Turn a gate off and on again in the
  same frame, and the chip never sees it off. Leave it off for a frame.
- During a long frame (section 6) the chip plays the last frame's
  registers for as long as it takes.

The registers are ordinary memory: you can read back what you wrote.

---

## 12. Running your game

**In the browser:**

```
zig build wasm
python3 -m http.server -d web
```

then open <http://localhost:8000> and click the screen. The click lets
the browser make sound, too.

**Headless** (no screen: runs the game and saves pictures):

```
zig build run -- --frames 250 --press 50:rf:20 --dump frames --dump-every 50
```

| Option | Meaning |
|---|---|
| `--frames N` | run N frames (default 250, five seconds) |
| `--press FRAME:KEYS[:DUR][@2]` | hold joystick directions from FRAME for DUR frames (default 10). KEYS is any of `u d l r f`. Add `@2` for joystick 2. Repeat as needed. |
| `--key FRAME:C` | type the character C at FRAME; `--key FRAME:#13` types code 13 (Return) |
| `--dump DIR` | where to save pictures (default `frames`) |
| `--dump-every K` | also save every Kth frame (the last frame is always saved) |
| `--wav FILE` | save the sound to FILE, a WAV file (44,100 samples a second, mono) that any music player opens |
| `--disk FILE` | put the disk image FILE (a `.d64` file) in the drive, instead of your game's own disk |
| `--save-disk FILE` | when the run ends, save the disk in the drive, with everything the game saved on it, to FILE |

Frames are counted from 0, the first frame after `boot`. A long frame
covers several frame numbers, and they all get its picture. Pictures are
saved as `DIR/frame_NNNNN.ppm`, border and meter included, 384 × 272.
When the run ends you get a summary: frames run, the most and average
cycles per call to `frame`, each meter bucket that was used, and how many
frames overran or were loading pauses. With `--wav`, the last line says
how long the sound is and how loud it got at its loudest. With
`--save-disk`, it says how many blocks are free on the disk it saved.

In the browser, a game with a disk drive gets two more controls under the
screen: a file picker that slots a disk image in (and powers on again
with it), and a button that saves the disk in the drive as a file. The
image is read right there in the page; nothing is sent anywhere.

**Testing:** `zig build test` runs your game's own `test` blocks, then
powers the machine on with your game and runs 100 frames.

---

## 13. The disk drive

The drive reads and writes **disk images**: a disk, byte for byte, as a
file (a `.d64` file). A disk is the classic single-sided kind: **35
tracks** of **256-byte sectors**, 683 sectors, 174,848 bytes. Tracks 1–17
have 21 sectors, 18–24 have 19, 25–30 have 18 and 31–35 have 17. The
drive also takes 40-track images and images with a byte of error codes
per sector at the end; it uses the first 35 tracks and ignores the rest.

### How a disk is laid out

- **Track 18 is the disk's own.** Sector 0 is the **BAM** (block
  availability map): four bytes per track, a count of its free sectors
  and a bit for each sector (1 = free), then at `$90` the disk's name
  (16 bytes, padded with `$A0`) and at `$A2` its two-letter ID.
- **The directory** is a chain of sectors starting at 18/1. Each holds
  eight 32-byte entries: a file type at byte 2 (`$82`: a program file,
  closed), its first track and sector at 3–4, its name at 5–20 (padded
  with `$A0`) and its length in sectors at 30–31.
- **A file** is a chain of sectors. Each one starts with the track and
  sector of the next, then 254 bytes of the file. The last has track 0,
  and its second byte is the position of its last byte.
- **A file's first two bytes** are its load address. The drive keeps
  them on the disk but doesn't give them to you: you say where a file
  goes.

### Registers

| Address | Zig name | What it does |
|---|---|---|
| `$DD00` | `hw.drive_command` | Write a command here (below). The drive does it at once: by the time `poke` returns it's done. Reads back 0. |
| `$DD01` | `hw.drive_status` | How the last command went: a `drive.Status`. |
| `$DD02–$DD03` | `hw.drive_address` | Where in RAM, low byte first. |
| `$DD04–$DD05` | `hw.drive_length` | How many bytes: to save, or the most to load. After a load, how many came. |
| `$DD06` | `hw.drive_name_length` | The name's length, up to 32. |
| `$DD10–$DD2F` | `hw.drive_name` | The file's name, as letters. |

Only `m.poke` to `$DD00` starts a command; filling it any other way
(`m.copy`, `m.ram`) writes the byte and nothing happens.

| Command | `drive.Command` | What it does |
|---|---|---|
| 1 | `.load` | Load the named file into RAM at the address, less its two-byte load address, and at most the length. |
| 2 | `.save` | Save `length` bytes from the address as the named file, with the address as its load address. |

| Status | `drive.Status` | Meaning |
|---|---|---|
| 0 | `.ok` | Done. |
| 1 | `.no_disk` | The drive is empty. |
| 2 | `.not_found` | No file by that name. |
| 3 | `.exists` | A save to a name that's taken. Put `@0:` in front to save over it. |
| 4 | `.full` | Not enough free sectors. Nothing was written. |
| 5 | `.too_long` | The file is longer than the length you gave. That much came. |
| 6 | `.bad_name` | Empty, longer than 16 letters, or a pattern where a save needs a name. |
| 7 | `.bad_disk` | The disk's chains lead off the disk, or round in a circle. |

### Names

- A name is up to 16 letters. `0:` in front names the drive (there's
  only one): `0:CASTLE` is `CASTLE`.
- In a load, `*` matches the rest of a name and `?` any one letter.
  The first file in the directory that matches is the one you get.
- `@0:` in front of a save saves over a file of that name if there is
  one.
- **`$` loads the directory**, as a little program listing. `$0:Z*`
  lists only the files that match `Z*`. The listing is lines, one after
  another. Each line is two link bytes (always 1, 1), a 16-bit line
  number, some text and a 0 byte. The first line is the disk's name in
  quotes, line number 0. Then a line for each file: its length in
  sectors as the line number, then its name in quotes and its type.
  The last line is the number of free sectors, then `BLOCKS FREE.`
  Two 0 bytes end the listing. The files are in directory order.

### Time

**Every sector the drive reads or writes costs a frame's worth of
cycles: 19,656.** A command that touches no sector still costs one (the
disk spins round once). Loading a 4,323-byte file reads a directory
sector and 18 sectors of file: 19 frames. Blank the display first
(section 6), so the long frame is a loading pause, not an overrun.
While the drive works, the SOUND chip goes on playing the last frame's
registers.

### Making a disk

`machine.drive` works on a plain `drive.Image` and needs no machine, so
a game can make its disk while it compiles:

```zig
pub const disk: machine.drive.Image = blk: {
    @setEvalBranchQuota(4_000_000);
    var d: machine.drive.Image = undefined;
    machine.drive.format(&d, "MY DISK", "01".*);
    var sectors: u32 = 0;
    machine.drive.save(&d, "HELLO", 0x9800, "HELLO, DISK", &sectors) catch unreachable;
    break :blk d;
};
```

`format`, `save`, `load`, `find` and `blocksFree` count the sectors they
touch in their last argument. A shell slots another disk in with
`m.insert(bytes)` (after `boot`), takes it out with `m.eject()`, and gets
the disk as it is now, saves and all, from `m.diskImage()`. Powering on
again puts the game's own disk back in.
