# Authoring guide (the "series bible")

Every chapter writer and reviewer reads this file first, plus
`docs/tutorial/outline.md` (the approved outline). This file is
author-facing only. Nothing in it, and no file outside `site/chapters/`
and `site/code/`, is ever shown to the reader.

When this file and the outline disagree, this file wins (it's newer).
If you have to make a decision this file doesn't cover, make it, record
it in "Decision log" at the bottom, and be consistent with it.

---

## 1. Voice (non-negotiable)

Read "Voice and tone" in the outline in full. A summary:

- **Who's talking:** a senior developer who loves retro games and knows
  how they work inside, showing a junior developer they believe in. The
  tone is a 1980s game-magazine strategy guide, but for code: playful,
  enthusiastic, and warm.
- **The reader:** comfortable in JavaScript or Python, new to Zig. They
  half-understand pointers and have never used them. They know "an array
  of objects" as a concept but not how it sits in memory. They love retro
  games as a player and have never seen how one is built.
- **The method:** start from the player's experience, then show the
  mechanism. Bridge from JS/Python ("in JS you'd write...; here's what
  that really costs; here's what we do instead"). Use byte diagrams.
- **Not condescending:** no quizzes, no "easy/simple/just/obviously", no
  "great job!" after every listing, no baby talk, no mascot. A few
  exclamation points per chapter, not per paragraph. Name the "aha"
  moments.
- **Don't over-explain programming:** loops, functions and variables need
  no introduction. Low-level ideas get a first-principles explanation
  **the first time they appear** (see the "Under-the-hood ladder" in the
  outline). After that, refer back rather than re-teach.
- **Stay in the world:** the game is a Zig game for the Comet 64 home
  computer, and the reader is building it. Never mention reverse
  engineering, disassembly, emulators, "pretend", AI, this repo, the
  C64/Commodore, the real author, Broderbund, or copyright. Real-world
  general knowledge is fine ("8-bit machines of the era",
  "cartridge-era consoles", "JavaScript").
- **Spooky but fun:** chapter titles read like level names.
- **Stay generic:** no real magazine, console, company or character
  names.

## 2. The fiction

- **The machine:** the **Comet 64**, a fictional 1980s home computer.
  It has 64 KB of RAM, a 1 MHz CPU (we count work in "cycles"), and a
  50 Hz display. The video chip is called **the VIDEO chip** in prose and
  the synth chip is **the SOUND chip**. It has two joystick ports and a
  320×200 multicolour bitmap. Its hardware is identical in capability
  to the C64's VIC-II/SID subset described in §3. Don't call them VIC or
  SID.
- **The game:** *The Castles of Dr. Creep*, a 1984 game for the Comet 64
  written in Zig. The tutorial rebuilds it from an empty project.
- **"Inside the Disk" boxes** present real facts about how the 1984 game
  did things (table sizes, tricks) as lore about the shipped disk.
- The reader is given **the Comet 64 itself** (the `machine` package:
  hardware model, browser shell, headless runner), the way a 1984
  developer was given a computer and a programmer's reference guide. The
  reader does **not** write the hardware. The reader writes **the game**.
  Chapter 1 introduces the machine through its reference card,
  `site/code/machine/REFERENCE.md`, which the prose quotes and links to.

## 3. The Comet 64 (the `machine` package)

Location: `site/code/machine/`. It is identical for every chapter. If a
later chapter needs a hardware feature, it has to be added to the
machine (and the reference card), never faked inside game code. The
hardware is **forgiving**: it doesn't model cycle timing or bus quirks.
It does enforce the hard limits.

### Memory map (fixed hardware layout)

| Range | What |
|---|---|
| `$0000–$00FF` | zero page (plain RAM; no speed difference in our model) |
| `$0100–$01FF` | reserved: CPU stack (game must not use) |
| `$0200–$07FF` | free RAM |
| `$0800–$77FF` | **program image**: the game's code lives here. Code is "free" in our model, but this region is reserved so the 64 KB budget is honest. Built-in tables (e.g. the shape table) are copied into the *top* of this region at boot by game code. |
| `$7800–$BFFF` | free RAM for game data (castle buffer, tables, actors…); the game's memory map assigns it |
| `$C000–$C7FF` | sprite frame data (32 blocks × 64 bytes) |
| `$C800–$CBFF` | free RAM |
| `$CC00–$CFE7` | screen plane: 1000 bytes, one per 8×8 cell. High nibble = colour for pixel code `01`, low nibble = colour for code `10` |
| `$CFF8–$CFFF` | sprite pointers: block number (0–31) for sprites 0–7; block N lives at `$C000 + N*64` |
| `$D000–$D3FF` | VIDEO chip registers (see below) |
| `$D400–$D7FF` | SOUND chip registers (`$D400–$D418`, SID-like layout; audio output arrives in a later chapter) |
| `$D800–$DBE7` | colour RAM: 1000 bytes, low nibble = colour for pixel code `11` |
| `$DC00–$DCFF` | input: `$DC00` = joystick 2, `$DC01` = joystick 1 (5-bit active-low: bit0 up, bit1 down, bit2 left, bit3 right, bit4 fire; bits 5–7 read as 1). `$DC02` = last key pressed (ASCII, 0 = none; the game writes 0 to acknowledge) |
| `$E000–$FF3F` | bitmap: 8000 bytes, 320×200 multicolour (160×200 "fat" pixels, 2 bits each), laid out cell by cell (8 bytes per 8×8 cell, cells left to right, rows top to bottom), exactly like the classic hardware |

The memory-mapped I/O regions are plain RAM that the hardware reads
(registers, planes) or writes (input, collision) at frame boundaries.

### VIDEO chip registers (subset of the classic layout)

`$D000+2n / $D001+2n` sprite n X (low 8 bits) / Y. `$D010` X bit 8 for
each sprite. `$D015` sprite enable. `$D017` double height. `$D01B`
sprite-behind-background priority. `$D01C` sprite multicolour enable.
`$D01D` double width. `$D01E` sprite–sprite collision (set by hardware
each frame; the game writes 0 to clear). `$D01F` sprite–background
collision (same). `$D020` border colour. `$D021` background colour
(pixel code `00`). `$D025`/`$D026` sprite multicolours 0/1. `$D027–$D02E`
sprite colours. Sprite coordinates use the classic convention: X=24,
Y=50 puts a sprite's top-left at the display's top-left. Sprites are
24×21 hires or 12×21 multicolour, 63 bytes per frame, at most **8**.
There is no text mode: the display is always the multicolour bitmap.

### Character ROM

There's an 8×8 font in a 2 KB character ROM. It's 256 glyphs; codes
`0x20–0x5F` are ASCII-ordered printable characters, and the rest are
blank or decorative. It is readable through `m.charRom(code)` (the
original-style "bank the ROM in" dance isn't modelled). The font is
**original artwork made for this tutorial**, in a chunky 8-bit style.

### Work meter (the frame budget)

- Budget: **19,656 cycles per frame** (312 lines × 63 cycles).
- Costs: `m.peek`/`m.poke` charge 4 cycles each. `m.peek16`/`m.poke16`
  charge 8. `m.copy(dst, src, n)`/`m.fill(dst, n, v)` charge 8 per byte.
  `m.mul8(a, b)` charges 120 (the machine has no multiply instruction;
  it's a software routine). `m.work(n)` charges n explicitly: game code
  calls it to account for computation, e.g. `m.work(2)` per loop
  iteration for loop overhead.
- Typed views (`m.view(T, addr)`, returning a `*align(1) T` into RAM for
  an `extern struct` or array) are allowed and charge nothing on their
  own. Code that uses them in hot loops should charge `m.work()` by
  convention. The meter is an honest estimate, not an emulation.
- Over budget: the frame still completes. The hardware draws a red
  stripe in the bottom border and counts the overrun. The meter is
  shown as a bar in the bottom border, coloured by fraction used.
  `m.meter()` returns last frame's cycles.

### Game interface

A game is a Zig module exposing:

```zig
pub fn boot(m: *Machine) void   // once, at power-on
pub fn frame(m: *Machine) void  // 50 times a second ("the frame interrupt")
```

All mutable game state lives **in `m.ram`**. Zig `var` globals are not
allowed in game code (`const` tables are fine; they're "part of the
program image"). Mutable state goes at addresses assigned by the game's
own memory map, which is a comptime table with an overlap check that
grows chapter by chapter. Never allocate.

### Shells

- **Browser:** `zig build wasm` produces `web/game.wasm`. `web/index.html`
  and the `machine` package's `shell.js` run it at 50 Hz on a canvas.
  Keyboard: arrows/WASD + Space = joystick 1; IJKL + Enter = joystick 2;
  other keys go to `$DC02`.
- **Headless:** `zig build run -- --frames N --press FRAME:udlrf[:DUR][@2] --dump DIR --dump-every K`
  writes PPM frames and prints the per-frame meter summary. This is how
  writers verify every checkpoint.
- No native window yet (deferred; may come later as a Secret Passage).

## 4. Code layout and checkpoint rules

```
site/
  AUTHORING.md            this file
  chapters/NN-slug.md     chapter prose (Markdown + box directives)
  code/
    machine/              the Comet 64 (shared, provided to the reader)
    starter/              empty game: boot() paints the border; the reader's starting point
    chNN/                 checkpoint at the END of chapter NN (a complete game project)
    check-all.sh          builds, tests and smoke-runs every checkpoint
```

- Each `chNN/` is a standalone project: `build.zig`, `build.zig.zon`
  (path dependency on `../machine`), `src/*.zig`. It starts as a copy of
  `ch(NN-1)/` (or `starter/`).
- **Exhaustiveness rule:** every line that changes between `ch(NN-1)` and
  `chNN` appears in the chapter's prose as a listing, in the order the
  reader types it, with the file name labelled. The one exception is bulk
  data (art, room data). Show a representative excerpt and say "the full
  table is in the Warp Zone checkpoint". A reader who follows the
  chapter must end up with exactly `chNN`.
- **Every checkpoint must pass:** `zig build`, `zig build test`,
  `zig build wasm`, and a headless smoke run (documented in the chapter's
  Boss Battle box, with the expected result). Writers must actually run
  these and inspect the frames: convert a PPM to PNG for viewing with
  Python, or read pixels in a test.
- **Zig 0.16.** See `CLAUDE.md` for gotchas (`.empty` ArrayList, `std.Io`,
  `std.process.Init`). Code style: idiomatic Zig, small files per
  subsystem (`video.zig`, `castle.zig`, `actors.zig`…). Comments explain
  *why*, not what. Hex for addresses (`0xCC00`), with a named constant
  from the memory map, not magic numbers in logic.
- **Data fidelity:** the castle data format, object records, coordinate
  systems and per-type behaviour must match the 1984 game exactly
  (`docs/castle-format.md`, `docs/graphics-format.md`, and
  `reference/segrax-DrCreep/src/creep.cpp` for behaviour, cloned with
  `git clone https://github.com/segrax/DrCreep reference/segrax-DrCreep`
  if missing). That way the real castle files load unmodified in
  chapter 11. **Art and text are ours:** all shapes, sprites, fonts and
  Training Castle text are original. Copy no graphics bytes, text or
  room data from the real disk. Design choices (shape IDs, sizes) may
  follow the original's dimensions so real castles render correctly.
- **Coordinates (the 1984 convention, keep it):** object X is in fat-pixel
  units offset by 16 (`x = fatpixel + 16`; cell column = `x/4 - 4`).
  Object Y is the pixel row (cell row = `y/8`). Sprite registers use the
  hardware convention above. Write the conversion helpers once (chapter
  2 or 3) and reuse them.

## 5. Chapter file format

`site/chapters/NN-slug.md`. Front matter:

```
---
chapter: 1
title: "Power On, Creep On"     (level-name style)
checkpoint: ch01
---
```

Boxes use fenced directives (the site generator will style them):

```
:::mission-briefing
...
:::

:::power-up The Lookup Table Power-Up
...
:::
```

Box types: `mission-briefing` (opens every chapter), `power-up`,
`byte-budget`, `pro-tip`, `under-the-hood`, `secret-passage`,
`game-over` (common mistakes), `warp-zone` (link to `code/chNN`),
`boss-battle` (ends every chapter: build, run, what you should see),
`bonus-stage` (optional builds), `inside-the-disk` (lore).

Code listings: fenced ```zig blocks preceded by a line naming the file,
e.g. **`src/video.zig`** (new file) or **`src/main.zig`** (add below
`boot`). Interactive widgets are marked with `:::widget name` placeholders
plus a one-line description (memory-map, budget-meter, toggle,
hex-inspector, byte-diagram). Byte diagrams can be drawn as text tables
or ASCII.

Length guide: 4,000–9,000 words per chapter. Two or three new
under-the-hood ideas per chapter (outline's ladder), each taught where it
is needed.

## 6. Training Castle

Original rooms in the 1984 castle format, authored with the comptime
room DSL introduced in chapter 3. Rooms are added as mechanics arrive,
following the outline's coverage matrix. Room text is our own, in the
guide's voice ("This is a doorbell. Stand in front of it and press fire.").
Keep a running list of rooms and their room numbers in the Decision log.

---

## Decision log

- **The reader doesn't write the hardware.** The `machine` package is
  provided (the outline's "build `hw`" in chapter 1 became "meet the
  Comet 64"). Reason: the reader is learning to write a game under
  constraints, not to build an emulator.
- **Shells:** browser and headless only for now. The native window is
  deferred because the build container has no GL.
