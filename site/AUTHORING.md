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
It does enforce the hard limits. One timing model exists: the raster
beam, driven by the work meter, so writes made while the beam is on the
display can tear (Decision log, "Beam" and "Display blank"). The
reader-facing spec is `site/code/machine/REFERENCE.md`; where it and
this section differ, the card and the Decision log win.

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
each sprite. `$D011` bit 4 display enable (bit 7 = raster bit 8, read
only). `$D012` raster line (read only). `$D015` sprite enable. `$D017` double height. `$D01B`
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
- **Machine implementation choices (§3 interpretations).**
  - *Frame driver:* `m.boot(Game)` / `m.runFrame(Game)` are methods on
    `Machine`. The shell sets `m.input` (`joy1`, `joy2` as held `joy.*`
    bits, `key` as uppercase ASCII) before each `runFrame`. Boot is not
    metered. `m.meter()` during a frame returns the *previous* frame's
    cycles. `runFrame` returns the frame slots used (see "Beam" below).
    *(Superseded: collisions now latch line by line as the beam draws.)*
  - *Hardware state outside `ram`:* `Machine` also holds the rendered
    screen (`m.screen`, 384×272 RGBA), the input latch, the beam, the
    current bucket, `m.last` (previous frame's `Report`: cycles, buckets,
    kind, slots) and `m.stats` (frames, calls, overruns, loading,
    max/total cycles, per-bucket max/total). These are "the hardware", not
    game state; game code must not use them for game logic.
  - *Picture:* 384×272 with the 320×200 display at (32, 36). Sprites and
    collisions exist only inside the display window (no sprites over the
    border).
  - *Meter bar:* light green (<75%), yellow (75–100%), red + full-width
    red stripe for an overrun, light grey (no stripe) for a loading pause.
    All on a black outline so they read against any border colour.
  - *Sprite pointers:* block N is at `$C000 + N*64` for any byte value
    (no masking); the card tells the reader to use 0–31.
  - *Sprite priority quirk kept:* priority is resolved per pixel by the
    frontmost (lowest-numbered) sprite; if that sprite is "behind" and the
    bitmap pixel is foreground, the bitmap shows (it does not fall
    through to a lower-priority sprite).
  - *`charRom` is free* (0 cycles); the ROM is outside the 64 KB map.
  - *`m.view` types allowed (strict, `src/layout.zig`):* whole-byte ints
    whose size equals their bits (u8/u16/u32/u64; not usize/isize, not
    u24); non-exhaustive enums over those; padding-free `extern struct`
    (every field viewable, `@offsetOf` = running sum, no tail padding);
    `packed struct` with `@bitSizeOf == @sizeOf*8` (i.e. backed by
    u8/u16/u32/u64; bools/odd ints fine inside); `extern union` whose fields
    are all full-size; arrays of those. Rejected with an explanatory
    compile error: bool, pointers, auto layout, exhaustive enums,
    `extern struct {u8, u16}`, `packed struct {u8, u16}`, `[2]u24`. A view
    past `$FFFF` panics. `copy`/`fill` wrap past `$FFFF`; `copy` is
    overlap-safe (memmove).
  - *Keyboard port:* `$DC02` is latched only when a key arrives and
    stays until the game writes 0. Browser: **every** key goes to `$DC02`
    (printable → uppercase ASCII; Return=13, Backspace=8, Esc=27), and the
    joystick keys *also* drive the sticks (Space=32 and Return=13 arrive
    as keys too). Tab is not captured (keyboard users can leave the
    canvas). Ctrl/Cmd/Alt combos are left to the browser. Key repeat
    doesn't retype. One key per frame: a second key in the same 20 ms
    replaces the first (no queue). Keyboard only reaches the game while
    the canvas has focus (so embedded pages still scroll).
  - *Headless extras:* `--key FRAME:C` types a character, `--key
    FRAME:#13` a decimal code (needed from chapter 3, "flip between rooms
    with a key", and for Return/Backspace in chapter 11); `--help`.
    `--press` rejects an empty KEYS and extra fields; huge DUR values
    don't overflow. Defaults:
    250 frames, dump dir `frames`, only the last frame saved unless
    `--dump-every`. Picture names `frame_NNNNN.ppm` (0-based frame
    index).
  - *Font:* 2-px uprights, 1-px bars, letters in the top 7 rows and left
    7 columns. Lowercase slots `0x61–0x7A` copy the capitals. Picture
    glyphs at `0x01–0x0B` (skull, ankh, key, heart, 4 arrows, block,
    checkerboard, castle tower); everything else blank. Designed to look
    right when the game expands each bit to a fat pixel (two cells per
    character, the 1984 game's text style).
  - *Colour names:* index 10 is called "pink" (not "light red"), and the
    enum is `machine.Color`.
- **Game project layout.** Every game's `build.zig` is three lines calling
  `machine.addGame(b, .{ .name = "chNN", .root = b.path("src/main.zig") })`.
  Every `build.zig.zon` is identical (`.name = .game`, same fingerprint,
  path dependency `.machine = .{ .path = "../machine" }`), so copying a
  checkpoint needs no zon edits. `zig build wasm` *writes* `web/`
  (game.wasm, shell.js, index.html from the machine package), so `web/`
  is not checked in (`site/code/.gitignore`). The wasm build is
  ReleaseSafe so panics show in the browser console. `zig build test`
  runs the game's own tests plus a machine-provided 100-frame boot test.
- **SOUND chip:** registers are plain RAM; no audio yet. The reference
  card (§11) says, in-world, that this model "ships without its speaker
  board" and the SOUND supplement comes with it. The music chapter adds
  audio output to the machine, replaces card §11 with the register table,
  and updates the `hw.sound_chip` comment in `machine.zig`. (Author TODO
  lives here, not in reader-visible files.)
- **Beam (racing the raster).** Added so tearing and double-buffering are
  real. 312 raster lines × 63 cycles; the work meter drives the beam
  (line = cycles / 63). `frame()` starts with the beam at line 0. Picture
  line 0 (top of border) = raster 15, display row 0 = raster 51
  (`video.picture_first_raster`, `video.display_first_raster`), display
  rows 0–199 = rasters 51–250, bottom border 251–286, vblank 0–14 and
  287–311. Every charge (`peek/poke/.../work`) checks one compare; when
  the beam finishes a line the VIDEO chip draws that picture line from
  RAM/registers *at that moment* (per-line render, sprite registers
  re-read per line). When `frame` returns, the rest of the current lap is
  drawn from final RAM. A frame that runs several laps keeps only the
  last lap (earlier laps would have been overwritten on the tube).
  `copy`/`fill`/`load` write their bytes first and then charge, so the
  beam sees them as one burst. Collision bits are ORed into `$D01E/$D01F`
  as each line is drawn (a hit high on the screen is visible later in
  the same frame; one low on the screen usually only next frame).
  `m.rasterLine()` (free) and `$D012` (low 8 bits) / `$D011` bit 7
  (bit 8) report the line; the machine rewrites those bits on every line,
  so game writes to them are lost. Boot has no beam.
- **Display blank and multi-frame work.** `$D011` bit 4 = display on
  (`hw.control`, `machine.display_on`); power-up value `$10`. Off: the
  display window is border colour, no bitmap, no sprites, no collisions
  (the border and meter still draw). A frame using `c` cycles takes
  `max(1, ceil(c / 19656))` frame slots; `runFrame` returns that, and the
  shells skip calling `frame` for the extra slots (headless frame numbers
  advance and the skipped frame numbers get the same picture; the
  browser subtracts slots × 20 ms from its accumulator). An over-budget
  frame is an **overrun** if any *display-window* line was drawn by the
  beam during `frame` with the display on; otherwise it's a **loading
  pause** (grey bar, counted in `stats.loading`, not an overrun). Lines
  drawn at end-of-frame completion don't count, so "blank → big job →
  re-enable → return" is a loading pause whose final picture is the
  finished screen. Consequence the chapters must teach: blank in the
  first 3,213 cycles (before raster 51). Card §6 "Racing the beam" /
  "Blank the screen for big jobs".
- **`m.load(dst, bytes)`** copies a Zig slice (a `const` table, the
  program image) into RAM at 8 cycles/byte (free during boot, like
  everything). Wraps past `$FFFF`; panics if longer than 64 KB.
- **Meter buckets.** `m.bucket(id: u3)` (free) sends subsequent charges
  to one of 8 buckets; each frame starts in bucket 0. Previous frame's
  totals: `m.last.buckets`; wasm `comet_bucket(i)`; JS
  `comet.buckets()`; headless prints max/avg for each non-zero bucket.
  Chapters should assign bucket ids in the game's own constants (e.g.
  0 = misc, 1 = input, 2 = drawing, 3 = actors…) and keep them stable
  across chapters for the budget-meter widget.
- **Other wasm exports:** `comet_frame(joy1, joy2) u32` returns slots;
  `comet_loading()`, `comet_kind()` (0 ok, 1 overrun, 2 loading).
- **Memory-map gaps (card §2):** `$CFE8–$CFF7` (16 bytes) and
  `$FF40–$FFFF` (192 bytes) are free RAM. `$D02F–$D3FF`, `$D419–$D7FF`,
  `$DBE8–$DBFF`, `$DC03–$DFFF` are **reserved for expansion hardware**
  (the disk drive will want some). Game memory maps must not place data
  there.
- **Terminology:** "colour RAM" (`hw.color_ram`) everywhere; "screen
  plane" for `$CC00`. The card's register tables now carry a Zig-name
  column.
- **Disk drive (planned, not built):** a disk drive device is added to
  the machine in chapter 11: a file list (directory in disk order), load
  and save of a named file into RAM at a given address (with a cycle /
  slot cost so loading shows as a loading pause), a wasm-side buffer the
  browser fills from a file picker for a real disk image, and `--disk
  FILE` for headless runs. Its registers go in the reserved `$DD00–$DFFF`
  range. Until then, chapters 3–10 load the Training Castle with
  `m.load` from a comptime table at `$7800`; chapter 11 swaps that one
  call for a disk load (same destination), so earlier loader code stays.
- **Browser shell details:** joystick state is rebuilt from the set of
  held keys (two keys on one direction work); falls back from
  `instantiateStreaming` to `instantiate` when the server doesn't send
  `application/wasm`; `reset()` after a panic re-instantiates the module
  (a trapped instance is not reused); the status element is the
  canvas's next sibling if it has `data-comet-status`.
- **check-all.sh** also asserts `web/game.wasm`, `web/shell.js`,
  `web/index.html` were written.
- **Chapter files and titles.** `site/chapters/00-prologue.md` (front
  matter `chapter: 0`, `title: "The Rules of the Game"`, `checkpoint:
  starter`) and `site/chapters/01-its-alive.md` (`title: "It's Alive!"`).
  Box directives may carry a title after the type (`:::power-up The Edge
  Detector Power-Up`); `mission-briefing`, `warp-zone` and `bonus-stage`
  usually don't. Screenshots live in `site/chapters/images/NN-name.png`:
  headless PPMs converted to PNG at 2× scale (768×544), referenced as
  `images/NN-name.png`. Non-Zig pseudo-code goes in a plain ``` fence.
  **Fence markers:** ```zig is code the reader types into the project (a
  whole file or a labelled insertion); site tooling and checkers may
  extract these. ```zig snippet is Zig that is *not* typed into the
  project: quotes of machine source, deliberate compile errors,
  counterexamples, bare statements. Tooling must skip `zig snippet`.
- **The reader's project.** The Prologue has the reader copy `starter/`
  to `code/my-creep/` (a sibling of `machine/`, so `../machine` resolves)
  and work there for the whole series. **Every copy instruction is
  exact commands** (`rm -rf my-creep; cp -r chNN my-creep; rm -rf
  my-creep/.zig-cache my-creep/zig-out my-creep/web`): a copied
  `.zig-cache` makes `zig build` silently reuse the original's binary
  (verified by the ch01 reviewer). The Prologue has a Pro Tip about it.
- **Downloads (site build TODO).** The Prologue links
  `downloads/starter.zip` ("download the starter kit"), and each Warp
  Zone links `downloads/chNN.zip` (relative to the chapter page). The site
  build must produce them from a **clean checkout** (no `.zig-cache`,
  `zig-out`, `web/`, `frames/`). `starter.zip` unzips to `code/machine/` +
  `code/starter/`; `chNN.zip` unzips to `code/machine/` + `code/chNN/`, so
  unzipping several into one place merges them. Chapter 1 renames the runner:
  every checkpoint's `build.zig` uses `.name = "creep"` (supersedes
  "`.name = "chNN"`" above; only `starter/` says `"starter"`). After
  chapter 1, `build.zig` and `build.zig.zon` never change.
- **Checkpoint READMEs.** Each `chNN/` has a short `README.md` (chapter
  name, file list, the Boss Battle commands). It is a Warp Zone note, not
  part of the reader's project, and is outside the exhaustiveness rule,
  which covers `build.zig`, `build.zig.zon` and `src/`.
- **Game source layout (from ch01).** `src/main.zig` holds only imports,
  `boot`, `frame` and whole-game tests. `src/map.zig` is the memory map.
  `src/room.zig` draws the room (ch01: the floor; exports `floor_top`,
  display row 192). `src/player.zig` is player 1 (`start` in boot, `show`
  and `steer` in frame). Later chapters add files per subsystem and keep
  these names.
- **Memory map style (`src/map.zig`).** `pub const Region = struct {
  name: []const u8, first: u16, last: u16 }` with **inclusive** first/last
  (reads like the card's `$0200–$0203`). A game region is a `pub const`
  `Region` named for its contents (`player`); its fields are `u16`
  address constants named `region_field`, computed from the region
  (`pub const player_x = player.first + 0;`), always prefixed with the
  region name (`player_last_stick`, not `last_stick`). Hardware regions
  the game touches are private `Region` constants built from
  `machine.hw` names, with the last byte derived from the card's sizes
  (`hw.bitmap + 8000 - 1`, `hw.spriteColor(7)`), not a literal.
  All go in `pub const regions = [_]Region{...}` **in address order**,
  and a top-level `comptime` block rejects any overlap or inverted range
  with `@compileError("memory map: A overlaps B")`. Chapters add rows;
  they never bypass the map. ch01 rows: stack (reserved), player
  `$0200–$0203`, program image, sprite frames, sprite pointers, VIDEO chip
  `$D000–$D02E`, colour RAM, input ports `$DC00–$DC02`, bitmap.
- **Game state at ch01.** `player` = `$0200 player_x`, `$0201
  player_y`, `$0202 player_color`, `$0203 player_last_stick` (joystick-1
  port byte from last frame, for edge detection; boot sets `$FF` because
  power-on RAM is `$00`, which reads as "every switch held"). Player is sprite 0 showing sprite
  block 0 (`$C000`). X is a plain sprite-X byte clamped to 24–255 (the
  9th bit, `$D010`, is unused; the chapter calls the stop at 255 "the
  wall made of arithmetic"). **Promise to keep: chapter 4 introduces the
  1984 object X coordinate (fat pixel + 16, one byte for the whole
  width), which removes the wall.** ch1 says ch4 shows "how the 1984 game
  fits its coordinates into a byte without losing the edge of the
  screen". Y is
  clamped 50–221 (boots on the floor). ch01 colours: border blue,
  background black, floor grey, player starts white; fire cycles 1→15→1,
  skipping 0.
- **Frame structure.** `frame` writes hardware first (`player.show`: the
  shadow-copy pattern, state in RAM copied to the VIDEO chip before
  raster 51), then runs game logic (`player.steer`), whose results show
  next frame. Later chapters keep "all register writes at the top of
  `frame`". Chapter 1 teaches the 3,213-cycle rule and shows a tear
  (Secret Passage at the end of "Fire!": `m.work(6000)` before `show`,
  `--frames 152 --press 0:u:134 --press 150:f:5`, torn frame 151); the
  Inside the Disk box
  told the 30-byte zero-page shadow-register story, so don't retell it.
- **Joystick idiom.** `fn held(stick: u8, switch_bit: u8) bool { return
  stick & switch_bit == 0; }` (private, in `player.zig`) is the only place
  active-low is spelled out. A press is `held(stick, b) and !held(before,
  b)` ("the Edge Detector Power-Up", named in ch01; ch5 doorbells and ch7
  gun panel are promised to reuse it).
- **Cost convention.** Each logic function charges one `m.work(n)`
  estimate for its non-memory work, with a comment (`steer` charges 40).
  ch01 frame: 92 cycles idle, 100 with a fire press. Buckets are not used
  yet (all bucket 0); ch2 should assign the stable bucket ids.
- **Terms introduced in ch01 prose.** "explorer" for the player sprite;
  "page" (256-byte, the high hex byte of an address); "mask"; "active-low";
  "tear"; "shadow copy". Hex: `$D020` in prose and tables, `0xD020` in
  code. ch01 already told readers: overflow panics are chapter 4,
  bitmap pixel codes and masks/moving bits are chapter 2, "Chapter 2
  shows what a pointer really is", comptime room DSL is chapter 3,
  interrupts / "what happens between frames" are "a later chapter",
  sprite-pointer animation is "a trick we'll lean on hard from Chapter
  2". **Meter promise for ch2:** ch1's Byte Budget says "Chapter 2 starts
  drawing whole rooms, and the meter will finally have something to
  say". Boot is unmetered, so ch2 must draw (or redraw) the room from
  `frame` at least once where the meter sees it (e.g. blank, draw, unblank
  as a loading pause, or redraw on a key), or soften that line in ch1.
- **Shell internals Secret Passage dropped.** The outline's ch1 "shell
  internals get a Secret Passage" is superseded: the shells are part of
  the provided machine (§2), and ch1 doesn't look inside them. Don't flag
  its absence.
- **Chapter 2 file, title, images.** `site/chapters/02-ghosts-in-the-bitmap.md`,
  `title: "Ghosts in the Bitmap"`. Screenshots: `02-title.png` and
  `02-room.png` (full frames at 2×, 768×544) and `02-tear.png` (a zoomed
  two-panel close-up of the explorer, torn vs. double-buffered, 656×256;
  close-ups are fine when a full frame would hide the point).
- **Game source layout (from ch02).** Adds `screen.zig` (row table,
  `plot`/`codeAt`, `clear`, `drawShape`), `shapes.zig` (shape-table
  format, `Id`, comptime packer, `address`), `art.zig` (all pictures, bulk
  data), `text.zig` (widen table, `draw`, `say`, `terminated`),
  `sprites.zig` (`unpack`, flag masks), `title.zig`. `main.zig` keeps only
  imports, `Mode`, bucket ids, `boot`, `frame`, `mode`/`setMode` and
  whole-game tests. Tests in imported files run automatically under `zig
  build test` (no `test { _ = file; }` needed; verified on 0.16).
- **Memory map at ch02.** player `$0200–$0205` (adds `player_block`
  `$0204` = sprite block shown, 0 or 8; `player_frame` `$0205` = shape ID
  in that block); game `$0206–$0207` (`game_mode` = `main.Mode`,
  `game_tick` +1 per frame, wrapping); text `$0300–$035F`
  (`text_widen` 16 B at `$0300`, `text_glyph` scratch shape 23 B at
  `$0310`, `text_buffer` 48 B at `$0330`, `text_buffer_size`); program
  image `$0800–$66FF` (last = `stars.first - 1`); star map `$6700–$67FF`;
  shape table `$6800–$77FF` (4 KB region, 1,059 B used); row table
  `$BB00–$BC8F` (200 × u16 LE); new hardware row: screen plane
  `$CC00–$CFE7`.
- **Modes and loading pauses.** `const Mode = enum(u8) { draw_title,
  title, draw_room, room }` in `main.zig`; power-on 0 = `draw_title`.
  Every whole-screen draw is a `draw_*` mode whose branch starts with
  `m.poke(hw.control, 0)`, draws, re-enables, and sets the next mode (a
  loading pause; ch1's "the meter will finally have something to say" is
  paid off here). Title draw 156,428 cycles (8 slots), room 125,476 (7);
  `clear` alone is 80,000.
- **Meter buckets (stable).** 0 = everything else (frame glue, input),
  1 = drawing into the bitmap/planes, 2 = sprites (player show/steer and
  frame unpacking). Constants `bucket_drawing = 1`, `bucket_sprites = 2`
  in `main.zig`. 3–7 are free for later chapters (suggest 3 = actors,
  4 = room objects, 5 = sound).
- **Shape table format.** At `$6800`: a directory of 2-byte little-endian
  *absolute* Comet addresses, one per `shapes.Id` (enum order = shape
  ID), computed at comptime; then entries `[width bytes][height rows][flags]
  [width*height pixel bytes]`. Room shapes then carry `width*ceil(h/8)`
  screen-plane bytes and `width*ceil(h/8)` colour-RAM bytes (the castle
  Image layout); the `room()` builder fills every cell with one colour
  triple, but the format is per cell. Sprite frames carry no colour data;
  flags low nibble = sprite colour, bit 4 hires (clear = multicolour),
  bit 5 behind, bit 6 double height, bit 7 double width (`sprites.flag_*`);
  at most 3 bytes × 21 rows; `unpack` zero-pads. ID 0 `glyph` points at
  `map.text_glyph` (RAM), not into the table. Art is `art.zig` strings
  (`.`/`1`/`2`/`3` per fat pixel), each `pub const` named exactly like its
  `Id` tag (`@field(art, @tagName(id))`); builders `shapes.room(colors,
  rows)`, `shapes.frame(color, rows)`, `shapes.mirror(art)`. Bad widths,
  stray characters and oversize sprite frames are compile errors. **Add
  new shapes at the end of `Id`** so existing IDs (and the hex inspector)
  stay stable. ch02 IDs: 0 glyph, 1 walkway, 2 walkway_left,
  3 walkway_right, 4 ladder, 5 pole, 6 door, 7 window, 8 torch, 9 moon,
  10 tower, 11 wall, 12–15 explorer_right_0–3, 16–19 explorer_left_0–3.
- **Blitter.** `screen.drawShape(m, id, x, y)`: x = fat pixel 0–159,
  rounded down to a multiple of 4 (x/4 = byte column), y = pixel row
  0–199. Pixels are ORed (the room is cleared first, as in 1984); colour
  cells are copied; a shape starting mid-cell spills one extra cell row
  that repeats its last colour row (the 1984 behaviour); clipped at column
  40 and row 200; no left clipping. Row lookups go through
  `screen.rowAddress` (row table: 12 cycles; the chapter's naive
  `mul8` version: 132). Cell number = `(rowAddress(y & 0xF8) - $E000) / 8`.
  **Promise for ch3:** the castle's object X is fat pixel + 16; ch3 adds
  the conversion (and off-left handling for X < 16) when it reads the
  castle (the ch2 Secret Passage says "We'll add a small conversion when
  we read the castle; the blitter itself keeps the plain 0–159 fat
  pixel"). Room shapes share colour triples when they cross (`stone`:
  brown / pink / light grey).
- **Text.** `text.draw(m, x, y, color, addr)` prints a bit-7-terminated
  string from RAM: each glyph bit → one fat pixel of code 01 (two bytes
  per glyph row via the 16-entry widen table), colour = screen-plane high
  nibble, colour RAM 0, drawn by writing the `glyph` scratch shape and
  calling `drawShape`; 8 fat pixels per letter. `text.say(m, x, y, color,
  comptime words)` copies `terminated(words)` into `text_buffer` and
  draws it. No AND mask (letters OR onto what's there) and no font/size
  byte yet: **ch3** must decide how the castle Text object's font byte is
  handled. ch2 told readers "Chapter 3 points `draw` straight at text
  inside the castle file".
- **Sprites.** Player = sprite 0, multicolour (`$D01C` bit 0 at boot);
  shared colours set once at boot: `$D025` pink (skin), `$D026` orange
  (hat/belt/boots) — every later multicolour sprite shares them. Double
  buffer: sprite *n* should use blocks *n* and *n*+8, flipped with `^ 8`;
  unpack into the hidden block, then store it in the player's block byte;
  `show` copies it to `$CFF8+n` at the top of the frame. Explorer frames:
  8 fat px × 21 rows, coat = own colour white (flags), four right-facing
  drawings plus `mirror` for left. Walk frame = `(x >> 2) & 0b11`; standing
  = frame 0 of the facing direction (derived from `player_frame`).
  Unpack ≈ 630 cycles; room frame 100 cycles idle, 728 on a frame change.
- **Player API at ch02.** `start` (boot: multicolour, shared colours,
  `player_last_stick = $FF`, `player_block = 8`), `enter` (room drawn:
  x 160, y on floor, first frame, enable), `show`, `steer` (left/right
  only; up/down and the fire colour cycle removed), `pressedFire` (edge
  detector, now `pub`, used by the title), private `held` (still the only
  place active-low is spelled out). `room.floor_top` = 184. The X wall at
  255 remains (ch4 promise unchanged).
- **Ladder bookkeeping (ch02).** Taught: shifts/masks (plot, packing two
  colours in a screen byte, the flags byte), pointers (row table, shape
  directory, string walking; Zig `*T` = typed address), lookup tables vs
  `mul8` (title stars: 6,672 vs 22,020 cycles/frame, the latter overruns).
  Used in passing with forward pointers: `^` (flip bit 3; "Chapter 8 has a
  lot more to say about `^`"), `+%` wrapping add (ch4 covers overflow),
  a comptime LCG for star positions ("Chapter 8 has the proper story of
  making numbers look random"), `comptime` blocks, `@field`/`@tagName`
  (ch3 teaches comptime properly; it can refer back to `shapes.zig`).
- **Zig 0.16 gotchas found in ch02.** `&`, `^` and `|` share one
  precedence level (left to right), unlike C/JS: always parenthesise mixed
  bitwise expressions (the chapter has a Pro Tip). A `comptime { ... return
  x; }` block inside a function that may be called at runtime is an error
  ("function called at runtime cannot return value at comptime"); put the
  checks in the comptime block and return outside it. Shifting
  `@intFromEnum(Color.x)` (a `u4`) by 4 fails ("type 'u2' cannot
  represent integer value '4'"): widen with `@as(u8, ...)` first.
- **Bulk-data listings.** Excerpts of `art.zig` are fenced ```zig snippet
  (the reader copies the whole file from the Warp Zone, `code/chNN/src/art.zig`);
  `shapes.zig` (the converter) and at least one complete shape of each kind
  (walkway, `explorer_right_0`) are shown.
