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

### Brevity (added after the first read-through: "too much text")

- **Say it once, short.** Prose is there to get the reader to the next
  listing with the idea in their head. Cut scene-setting, recaps,
  previews of later chapters, repeated reassurance, and asides that don't
  teach. Targets: the prologue is about 800 words, and a chapter's prose
  is about 4,000–4,500 words (code listings aren't counted).
- **Introduce things when they arrive.** Don't tour mechanics, boxes or
  tools ahead of time. The prologue says what the game is in a paragraph,
  and the chapters introduce each mechanic when it's built.
- **Calibrate to the reader, both ways.** If an idea gets a careful
  explanation, don't then lean on something just as unfamiliar to them
  without explaining it. For example, "in JavaScript every number is a
  64-bit float" assumes they know what a float is. Either give it a
  clause ("a number with a decimal point, stored in 8 bytes") or drop
  the comparison.
- **Personality is not padding.** After the brevity pass the owner said
  "you lost all the personality; you overcorrected". Cut repetition, not
  voice. These stay:
  - opening a section from the player's experience ("You know that
    moment when…");
  - the senior dev's enthusiasm, said out loud ("this is my favourite
    trick in the whole game");
  - a joke or a vivid image, at most one or two per section;
  - celebrating real milestones;
  - the magazine-guide energy of the boxes;
  - transitions that carry momentum.

  Revised targets: the prologue is about 1,000–1,200 words, and a
  chapter's prose is about 5,000–5,500.
- **Clear beats clever.** The owner flagged this sentence: "a Zig var
  hides at an address only the compiler knows, and on a 64 KB machine a
  byte nobody wrote down is a byte you'll end up spending twice." A reader
  can't tell what "wrote down" refers to (the memory map) or what
  "spending twice" means (using one byte for two things). Rules:
  - Every phrase must have a referent the reader can name. Say "the
    memory map", not "written down".
  - A metaphor may decorate a point that has already been stated
    plainly. It may never carry the point by itself.
  - Avoid compressed, aphoristic sentences that make the reader decode
    them. If a sentence needs a second read, rewrite it as two plain
    ones.
  - The test: could the reader explain the sentence back in their own
    words? If not, rewrite it.
- **Plain words (added after the owner flagged the ch02 opening as
  "what does that even mean?").** The reader is a programmer, not an
  English major. Rules:
  - Short sentences. One idea per sentence. If a sentence has a colon
    *and* a semicolon, split it.
  - Define every term before using it, in plain words: what the thing
    *is* and what it *does*. "A cell is 8 × 8 dots" comes before
    anything about a cell's colours.
  - Build up in small steps, one fact at a time, rather than packing
    three facts into one sentence ("a pixel takes two bits, so each one
    is two dots wide" skips the step that explains the "so").
  - Short, concrete everyday metaphors are welcome (paint-by-numbers,
    a flip-book, a times table, a clock face, a rubber stamp), always
    *after* the plain statement, never instead of it.
  - Keep the playful tone: jokes, enthusiasm and vivid images stay.
- **Keep the collaborative voice.** "We", "let's" and the guide's own
  "I love this one" stay: the tutorial should feel like building the
  game together. (The no-"we"/"I" rule is for the homepage only, not
  the tutorial.)
- **Boxes earn their place.** Keep a box only if it adds something the
  main text doesn't. Merge or drop the ones that repeat the prose.

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
| `$D400–$D7FF` | SOUND chip registers (`$D400–$D418`, SID-like layout; audio since ch10: three voices, ADSR, no filter) |
| `$D800–$DBE7` | colour RAM: 1000 bytes, low nibble = colour for pixel code `11` |
| `$DC00–$DCFF` | input: `$DC00` = joystick 2, `$DC01` = joystick 1 (5-bit active-low: bit0 up, bit1 down, bit2 left, bit3 right, bit4 fire; bits 5–7 read as 1). `$DC02` = last key pressed (ASCII, 0 = none; the game writes 0 to acknowledge) |
| `$DD00–$DD2F` | disk drive (ch11): command, status, address, length, name length, name; card §13 |
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
`bonus-stage` (optional builds), `side-quest` (collapsed by default: a self-contained detour whose code is still part of the checkpoint, so the reader types it in from the box, but the main text doesn't stop to teach it), `inside-the-disk` (lore), `type-in`
(a "Type-In Listing": long bulk code the reader still types, rendered
collapsed with a "show listing" button; every line stays in the chapter,
in typing order, so the exhaustiveness rule holds).

Code listings: fenced ```zig blocks preceded by a line naming the file,
e.g. **`src/video.zig`** (new file) or **`src/main.zig`** (add below
`boot`). Interactive widgets are marked with `:::widget name` placeholders
plus a one-line description (memory-map, budget-meter, toggle,
hex-inspector, byte-diagram). Byte diagrams can be drawn as text tables
or ASCII.

Length guide: 4,000–9,000 words per chapter. Two or three new
under-the-hood ideas per chapter (outline's ladder), each taught where it
is needed.

### Diagrams

Show it instead of telling it wherever a picture is clearer, for example:
memory turning into colours on screen, a sprite's bytes becoming a
picture, bits packed in a byte, regions that overlap, collision boxes,
pointers into a table, or a contiguous table next to scattered objects.

- **ASCII diagrams** in plain fences (or `text`) are fine for small byte
  layouts, and many existing ones are good. Keep them.
- **HTML/SVG diagrams**: write `:::diagram NAME` with an optional
  one-line markdown caption as the body, closed by `:::`. The figure is
  `site/page/diagrams/NAME.html`, which `site/build.py` inlines. Name
  files `chNN-what.html`. Use the shared classes and colour rules in
  `site/page/diagrams.css`:
  - theme tokens (`--ink`, `--ink-soft`, `--rule`, `--sheet`,
    `--accent`, `--code-bg`) for labels, frames and arrows;
  - the fixed Comet palette `--c0`…`--c15` for anything that *is* screen
    colour.
- Diagrams may be **animated** where motion is the point, for example
  the beam sweeping down the screen, a pointer flip, or a door opening.
  Put `data-animate` on any element in the figure file. The page then adds
  Play/Pause/Restart controls, and starts paused for readers who prefer
  reduced motion. Animate with CSS `@keyframes`, or SVG `<animate>`,
  scoped to the figure. The figure must not contain any scripts. It must
  read correctly when paused at any point, and its resting state must
  make sense on its own. Use no colours outside the tokens.
  They must stay legible at 400 px wide, either by wrapping or by
  scrolling sideways inside the figure. Labels must be real text, not
  text drawn as paths.
- A diagram replaces the paragraph that was describing the same thing.
  Don't keep both.

## 6. Training Castle

Original rooms in the 1984 castle format, authored with the comptime
room DSL introduced in chapter 3. Rooms are added as mechanics arrive,
following the outline's coverage matrix. Room text is our own, in the
guide's voice ("This is a doorbell. Stand in front of it and press fire.").
Keep a running list of rooms and their room numbers in the Decision log.
The current list (from chapter 3) is in the Decision log entry "Training
Castle rooms (ch03)".

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
- **SOUND chip:** registers are plain RAM. Until ch10 the card (§11)
  said the model "ships without its speaker board". **Ch10 fitted it**
  (see "The SOUND chip's speaker (ch10, machine)" below): card §11 is the
  full register table; `hw.voice(v)` and `hw.sound_volume` name the
  registers.
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
  re-enable → return" is still a loading pause, **but** (corrected in the
  ch02 review) its picture is the rest of the current lap drawn with the
  display on, so the new screen shows from wherever the beam stopped
  downwards for every slot of the pause. The pattern the chapters teach
  (ch02, and card §6 now): blank in the first 3,213 cycles (before raster
  51) of the long frame, and re-enable at the top of the **next** frame,
  also before raster 51. Card §6 "Racing the beam" /
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
- **Disk drive (planned; built in ch11, see "The disk drive (ch11,
  machine)" below):** a disk drive device is added to
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
- **Sprite slots (ch01 revision).** Prose calls the VIDEO chip's eight
  sprites "sprite slots" 0–7 (each = X, Y, colour, a `$D015` bit, a
  pointer); the limit of eight is stated in ch01 as shaping the whole game.
  Code names: `player_sprite` ("which of the VIDEO chip's eight sprite
  slots (0-7) is the player's", ch01–ch04) and, in ch01 only,
  `player_block` (the block number const; ch02 replaces it with the RAM
  byte `map.player_block`). "Block" = 64-byte unit of sprite memory
  `$C000–$C7FF`, numbered 0–31, explained in ch01 with the
  `ch01-sprite-slots` diagram. The beam is shown by the animated
  `ch01-beam` diagram (generators in `tools/diagrams/ch01/`).
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
  `title: "Ghosts in the Bitmap"` (paid off in the tear Secret Passage:
  "the ghost in the bitmap, half of one frame haunting the next"). Title
  text colours: light blue / light green / white. The tear experiment is
  `m.work(14500);` before `player.steer(m)` plus `^ 8` removed, `--frames
  72 --press 20:f:5 --press 60:r:30`, torn `frame_00071`. Screenshots: `02-title.png` and
  `02-room.png` (full frames at 2×, 768×544) and `02-tear.png` (a zoomed
  two-panel close-up of the explorer, torn vs. double-buffered, 656×256;
  close-ups are fine when a full frame would hide the point). ch02 has no
  closing "complete `main.zig`" listing (cut for length in review; every
  change is still shown as an insertion listing, and the rebuild from
  listings is byte-identical).
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
  shape table `$6800–$77FF` (4 KB region, 1,044 B used); row table
  `$BB00–$BC8F` (200 × u16 LE); new hardware row: screen plane
  `$CC00–$CFE7`.
- **Modes and loading pauses.** `const Mode = enum(u8) { draw_title,
  title, draw_room, room }` in `main.zig`; power-on 0 = `draw_title`.
  Every whole-screen draw is a `draw_*` mode whose branch starts with
  `m.poke(hw.control, 0)`, draws, and sets the next mode; the next mode's
  branch starts with `m.poke(hw.control, machine.display_on)` (4 cycles a
  frame) so the reveal is one clean cut (a loading pause; ch1's "the
  meter will finally have something to say" is paid off here). Title draw
  156,200 cycles (8 slots), room 126,172 (7); `clear` alone is 80,000.
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
  inside the castle file". `draw` stops at the right edge (`left >= 152`):
  letters past it are left out, 20 to a line (no overflow panic).
- **Sprites.** Player = sprite 0, multicolour (`$D01C` bit 0 at boot);
  shared colours set once at boot: `$D025` pink (skin), `$D026` orange
  (hat/belt/boots) — every later multicolour sprite shares them. Double
  buffer: sprite *n* should use blocks *n* and *n*+8, flipped with `^ 8`;
  unpack into the hidden block, then store it in the player's block byte;
  `show` copies it to `$CFF8+n` at the top of the frame. Explorer frames:
  8 fat px × 21 rows, coat = own colour white (flags), four right-facing
  drawings plus `mirror` for left. Walk frame = `(x >> 2) & 0b11`; standing
  = frame 0 of the facing direction (derived from `player_frame`).
  Unpack ≈ 630 cycles; room frame 104 cycles idle, 732 on a frame change;
  title frame 6,698 (stars 6,660). A `comptime` block in `player.zig`
  fails the build unless the eight explorer IDs are consecutive.
- **Player API at ch02.** `start` (boot: multicolour, shared colours,
  `player_last_stick = $FF`, `player_block = 8`), `enter` (room drawn:
  x 160, y on floor, first frame, enable), `show`, `steer` (left/right
  only; up/down and the fire colour cycle removed), `pressedFire` (edge
  detector, now `pub`, used by the title; it also stores the stick, so it
  must be called exactly once a frame), private `held` (still the only
  place active-low is spelled out). `room.floor_top` = 192 (unchanged
  from ch01; the floor walkway fills the bottom cell row). The X wall at
  255 remains (ch4 promise unchanged). **Note for ch5 (doorbells):** in
  room mode nothing updates `player_last_stick` any more. Before a
  doorbell tests for a press only while the explorer stands at it,
  restructure: update `player_last_stick` once per frame (e.g. at the end
  of `steer`) and make the press test a pure function of `stick` and
  `before`, or a fire held across the room counts as a fresh press.
- **Ladder bookkeeping (ch02).** Taught: shifts/masks (plot, packing two
  colours in a screen byte, the flags byte), pointers (row table, shape
  directory, string walking; Zig `*T` = typed address), lookup tables vs
  `mul8` (title stars: 6,660 vs 22,020 cycles/frame, the latter overruns).
  Used in passing with forward pointers: `^` (flip bit 3; "Chapter 8 has a
  lot more to say about `^`"), `+%` wrapping add (ch4 covers overflow),
  a comptime LCG for star positions ("Chapter 8 has the proper story of
  making numbers look random"), `comptime` blocks, `@field`/`@tagName`.
  **ch3 must build on ch2's comptime use, not introduce comptime from
  zero:** ch2 has a Pro Tip "Reading comptime code" ("Chapter 3 takes
  `comptime` apart properly") that already covered top-level `const`s
  being evaluated at compile time, `blk:` as only a label, `comptime`
  parameters, `?T` + `if (x) |v|`, `[_]u8{x} ** n`, `undefined`, and
  freezing a comptime value (`const done = x; ... &done`). ch3 should
  refer back to `shapes.zig`/`pack` and go deeper (branch quota, comptime
  vs runtime, type-returning functions). Also taught early: **several
  flags in one byte** (the sprite-frame flags byte, ladder row 4), so ch4
  should refer back rather than re-teach; **little-endian** was only
  mentioned ("two-byte values on the Comet go low byte first; Chapter 3
  says why"), so ch3 owes that explanation.
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
- **Type-In Listing box (from ch03).** `:::type-in Title` wraps one or
  more labelled ```zig listings that the site renders collapsed ("show
  listing"); it's the 1984 magazine type-in convention. Use it for long
  code that must be typed but needn't be read line by line: record
  tables, encoders and checkers, tests. The label line and fence go
  inside the box unchanged, so listing tooling and the exhaustiveness rule
  are unaffected. ch03 uses five (later-kind records, the walker's tests,
  the stream encoders, the builder's checks, the whole-game tests).
- **Chapter 3 file, title, images.** `site/chapters/03-haunted-blueprints.md`,
  `title: "Haunted Blueprints"`. Screenshots (full frames, 2×, 768×544):
  `03-gatehouse.png` (Mission Briefing: room 0), `03-hall.png` (the
  hand-typed one-room castle drawn from its stream), `03-final.png` (Boss
  Battle: the final room). Built from a template with a listing script
  (writer's scratch `ch3/tools/`: `listings.py`, `rebuild.py`,
  `expand.py`, `errs.py`); 54 listings rebuild `ch03` from `ch02` byte for
  byte, and stages B, C, D, E1 (kit without checks + hall test), E, F, G
  each build, pass `zig fmt --check` and tests, and run. Quoted builder
  errors are regenerated by `errs.py`.
- **Game source layout (from ch03).** Adds `castle.zig` (the format:
  header/directory constants, `Entry`, `Size`, `Kind`, `code`, `kindOf`,
  every record type, `Framing`, `isEnd`, `Record`, `Walker`, `shapeSize`,
  `left_edge`), `author.zig` (the castle-authoring kit, comptime only:
  declarations, `build`, `stream`, `door`, `le`, `fail`, then a separate
  `check` pass: `check`, `checkRoom`, `Box`, `onScreen`, `onWalkway`),
  `hall.zig` (the hand-typed one-room castle from the chapter, kept as a
  test fixture: its plan and the test "the kit writes the castle you typed,
  byte for byte"; `main.zig` has `test { _ = hall; }` because nothing else
  uses it) and `training.zig` (the Training Castle: `Room`, `plan`,
  `bytes`; bulk data, copied from the Warp Zone). `room.zig` draws any room
  from its stream (`start`, `draw`, `prepare`, `paint`, `roomColors`,
  `both`, `place`, per-kind drawers, `door_panel_dx/dy`, `flip`); it keeps
  `floor_top` (192) and its ch2 comment. `screen.zig` adds `drawPart`.
  Whole-game tests stay in `main.zig`.
- **Memory map at ch03.** `room` `$0208` (`room_number`; the final room is
  number `roomCount`). `text` grows to `$0300–$037F`: `text_glyph` `$0310`
  up to 63 bytes (2 × 24 rows + 6 + 6, for triple-height letters),
  `text_buffer` moves to `$0350` (48 bytes). **`castle` `$7800–$97FF`** (8
  KB). 17 regions. In the chapter each map edit appears where it's needed
  (castle before `castle.zig`, text at the style byte, room at flipping).
- **Castle staging (promise for ch9/ch11).** The 1984 game loads a castle
  to `$9800`, never plays that copy (the title tours its rooms), and copies
  it to `$7800` at the start of every game (`Game()` `0D71`), because play
  writes into the castle (header scratch, door-open bits). ch03 boots
  straight into `$7800` (like a saved position) and says in its Inside the
  Disk box: "when Chapter 9 teaches the game to start over, it keeps a
  clean copy the same way." So **ch9** adds a `$9800–$B7FF` staging region
  (fits below the row table at `$BB00`) and the per-game copy (34,584
  cycles at 8/byte for 4,323 bytes: do it in a loading pause); **ch11**'s
  disk load targets `$9800`. Also noted in the ch03 Byte Budget: the castle
  is in memory twice for now (the `const` in the program image and `$7800`);
  ch11 removes the first.
- **Castle format, as implemented (all from the 1984 engine; now also
  corrected in `docs/castle-format.md`, marked "corrected after
  verification against creep.cpp").**
  - Header: size word `$00` (whole file incl. header), magic `$80` at
    `$02`, start rooms `$03/$04`, start doors `$05/$06`, lives `$07/$08`,
    final-room stream pointer word at `$5F` (0 = none). The rest is zero on
    our disk; ch9 uses it as runtime scratch ("Chapter 9 moves in").
  - Directory at `$7900`, `castle.Entry = extern struct { color, map_x,
    map_y, size: Size, skip: [2]u8, objects: [2]u8 }`; `Size = packed
    struct(u8) { height: u3, width: u3, unused: u2 }` (bits 0-2 height in
    8-row map cells, 3-5 width in 4-fat-pixel cells, as `mapRoomDraw` reads
    them). End byte has bit 6 set: `$40` with a final room, `$FF` without.
    Bit 7 of a colour byte = visited (ch9). `skip` = objects + 2 (never
    read). `castle.max_rooms = 31` is **our** rule, not the 1984 game's.
  - Words in records are `[2]u8` read with `peek16`; record structs are
    all `u8` fields. The chapter teaches padding with a byte diagram of
    `extern struct { color: u8, objects: u16 }` and quotes the machine's
    view error; it contrasts plain `struct` (layout not promised) with
    `extern`.
  - `castle.Kind` = 18 kinds in jump-table order (tag = `$0803 + 3k`):
    door, walkway, pole, ladder, bell, lightning, forcefield, mummy, key,
    lock, **pattern** (`$0821`, MultiDraw: count, shape, x, y, step_x,
    step_y, ends on 0; no castle uses it; the title screens' tags are the
    routines' own addresses `$160A`/`$2A6D`), ray_gun, teleport, trapdoor,
    conveyor, frankenstein, text, image. `kindOf` = subtract `$0803` (`-%`)
    and index a 54-entry `?Kind` table. Dispatch is a `switch` in ch3.
    **Promise: ch5 brings back "the 1984 idea properly, with a table of
    functions"** (ladder row 5).
  - Record structs and sizes: Door 8 (`x, y, side, to_room, to_door, map_x,
    map_y, exit`), Run 3 (`length, x, y`), Bell 3 (`x, y, door`), Text 4 +
    string (`x, y, color, style`), Lightning 8 (`state, x, y, length,
    machines[4]`), Forcefield 4 (`button_x, button_y, field_x, field_y`),
    Mummy 7 (`state, ankh_x, ankh_y, tomb_x, tomb_y, runtime[2]`), Key 4
    (`number, shape, x, y`), Lock 5 (`number, shape, door, x, y`), Pattern
    6, RayGun 7 (`state, x, y, length, runtime, control_x, control_y`),
    Trapdoor 5 (`state, x, y, switch_x, switch_y`), Conveyor 5 (`state, x,
    y, control_x, control_y`), Frankenstein 7 (`state, x, y, runtime[4]`).
    **Later kinds' field names are provisional** (sizes are fixed):
    chapters 6-8 check each meaning against `creep.cpp` and may rename.
  - **Shape IDs in real castles (ch7/ch11 note).** Key and Lock byte 1 is a
    **1984** shape ID (around `$50 + colour`), and our `shapes.Id` does not
    follow the 1984 numbering. Real castles' Key/Lock records need a
    1984-ID → `Id` translation table (or reserved IDs) when keys arrive
    (ch7) and real castles load (ch11). The ch3 prose says only "IDs end
    up stored in data, so existing ones mustn't move".
  - Framing (`castle.Framing`, `union(enum)`): counted (door, bell);
    marked with `isEnd(byte, end)` = `byte == 0` if `end` is 0, else
    `byte & end != 0` (lightning `0x20`; ray gun, trapdoor, conveyor,
    frankenstein `0x80`; others 0; mummy state is never 0); text (records
    until x = 0, 4 bytes + bit-7 string); teleport (one per tag: x, y,
    target, pads to 0); image (one per tag: shape-table-format shape,
    places to 0). The 1984 engine loops some marked kinds do-while;
    `Walker` tests the marker first, identical for valid data; the builder
    never writes an empty group and refuses records that start like their
    end marker.
  - Door record: byte 2 bits 0-1 = the wall on the castle map (0 up, 1
    right, 2 down, 3 left), **bit 7 = open**; byte 7 = 1 for the exit
    door, selecting the exit arch (**not** a door ID). A bell's `door` is
    the door's index in the room's door group.
  - **Door map bytes (both filled, for ch9's arrow):** `mapRoomDraw` reads
    only the along-wall byte (byte 5 for top/bottom doors, byte 6 for
    side doors); `mapArrowDraw` uses both for every door: arrow at (room x
    + byte5 + dx[side], room y + byte6 + dy[side]), dx = {−1, +2, −1, −5}
    (`$11DA`), dy = {−10, −2, +6, −2} (`$11DE`). The builder writes: right
    wall `map_x = width − 2` (the tutorial disk's room 0 has 10 in a
    12-wide room), left wall `map_x = 0`, top `map_y = 0`, bottom `map_y =
    height − 3`; along the wall `map_y = min(height − 3, (y + 16) × height
    / 200)` or `map_x = min(width − 4, (x − 16) × width / 160)`, where
    width/height are the room's map size in fat pixels/rows. ch9 should
    verify these against a real castle's map.
- **Drawing semantics (ch03, keep).**
  - `castle.left_edge = 16`. `room.place(m, id, x, y)` is the one place
    object X becomes a fat pixel: `x ≥ 16` → `drawShape(x − 16)`; else
    `screen.drawPart(m, id, 0, y, (16 − x + 3) / 4)`, which leaves out the
    shape's first byte columns (**clipped, not dropped**). Walkways clip
    piece by piece; text (`room.line`) skips whole letters left of the
    edge, as `text.draw` does at the right. No top clipping (the 1984
    blitter treats Y ≥ 220 as negative); the blitter clips at row 200.
    **ch11 note:** check the real castles for X < 16 and Y ≥ 200.
  - Walkway: `length` pieces of 4 fat pixels (1 = left end only).
    Ladder/pole: `length` pieces 8 rows apart from y down. Training Castle
    convention (builder-checked): ladders and poles start on a walkway row
    and end on the walkway row below, top and bottom pieces ORed over the
    bricks. No through-walkway variant shapes yet (1984: pole 0x27, ladder
    0x29/0x2C); ch4 may add them at the end of `Id`.
  - Room colour (1984 `roomSetColours`): `paint` recolours the
    screen-plane bytes (both nibbles) of walkway, walkway_left,
    walkway_right, ladder and pole; colour RAM stays light grey. The final
    room uses `final_color = .yellow`.
  - **Shape footprints vs 1984** (from the `$603B` directory): door frame
    and exit frame 20 × 32 ✓; ladder **4** × 8 ✓ (was 8 wide in the first
    draft; fixed); pole 4 × 8 ✓; bell **12 × 19** ✓ (fixed); walkway 4 × 7
    (1984: 4 × 8; ch2 decision, harmless: the grid comes from records).
  - **Door panel: deliberate deviation.** Ours is 12 × 24 at (+4, +8)
    inside the arch (`room.door_panel_dx/dy`), so the 21-row explorer fits;
    1984's is 12 × 15 at (+4, +16). **ch5 must reconcile:** 1984 places the
    entering player at (door x + 6, door y + 15) (`obj_Door_InFront`); its
    open animation runs 14 steps (`Object_field_2 = 0x0E`, erasing with
    shape `$7C`, 3 × 1, a row at a time); its "in front of the door" box
    is the panel's (12 × 15 at +4, +16). ch5 should take all of these
    from named constants (`door_panel_dx/dy` and new ones), not inline
    `+ 4, + 8`, and pick an entry Y that fits our taller doorway.
  - Open panel `door_open` recoloured to the destination room's colour;
    bells recoloured to the colour of the room their door leads to (both
    1984 behaviour).
  - Text style byte (1984 `StringPrint`): bits 0-1 height ×1-3 (we treat
    any 0 height as 1; 1984 only a whole style of 0), bit 4 reversed
    (XOR `$FF`), bit 5 the letters set (ignored). `text.plain = $21`,
    headings `$22`. `text.draw(m, x, y, color, style, addr) u16` returns
    the address after the string. Still OR only (no AND mask).
  - Images: `shapes.point(m, .image, at)` aims the spare `image` entry
    into the castle (1984: shape `$16`).
- **Shape IDs (ch03, appended):** 20 `door_frame`, 21 `exit_frame`, 22
  `door_shut`, 23 `door_open`, 24 `bell`, 25 `image` (no picture). Shape
  table 1,716 bytes. `shapes.pack` is `pub`; `shapes.recolor`,
  `shapes.point` added. `art.zig`: walkway pieces redrawn for room
  colouring (bricks 01, mortar 00, edges 11), ladder 4 wide, bell 12 × 19,
  plus `trophy` (16 × 24) and `sparkle` (4 × 8) castle pictures (not
  `Id`s).
- **Castle-authoring kit (`author.zig`).** `build(Name, Castle(Name))
  []const u8` at comptime; its first line after the quota is
  `check(Name, c)`. Taught in two steps: layout only (then the hall test
  shows the kit reproduces the hand-typed 340 bytes), then the strict
  `check` pass. `Castle(Name)` = `start {room, door}`, `lives` (3),
  `rooms: std.enums.EnumFieldStruct(Name, Room(Name), null)`, `final:
  ?Room(Name)`. `Room(Name)` has `color`, `map: Map {x, y, width: u3,
  height: u3}` and one list per kind named after its `Kind` tag; later
  kinds are written as their `castle.*` records (chapters 6-8 add records
  to `training.zig`; helpers optional, e.g. lightning switch machine
  indices are stored × 8). `Door(Name)` `{x, y, to, to_door = 0, open =
  false, exit = false}`; `Line {x, y, color = .white, height: u2 = 1,
  words}` (style `$20 | height`); `Teleport {x, y, target, pads}`; `Image
  {art, at}`. Streams in tag order. Computed: pointers, skip words, size,
  end byte, final pointer, door side and both map bytes. Checks (all
  `@compileError("castle: room NAME: ...")`): ≤ 31 rooms, start door
  exists, map place and non-black colour, on screen and on byte
  boundaries, doors on cell rows, door pairs lead back (exit doors
  exempt), bells name existing doors, run length ≠ 0, ladders/poles start
  and end on walkways, no overlaps among doors (20 × 32), bells (12 × 19),
  text lines and image placements, later-kind records don't start with
  their end marker, total ≤ castle region.
- **Training Castle rooms (ch03).** Map: a 5 × 4 snake (rows alternate
  right/left), each room 4 × 3 map cells at `x = 56 + 16·col`, `y = 48 +
  24·row`. Every room: a floor walkway at y 192 (40 pieces; the Long
  Gallery's is 35, stopping short of the right wall, with its door 1 at x
  132 and bell at x 112), door 0 = back (to the previous room's door 1),
  door 1 = forward, a bell for door 1 beside it (x 140 for a right door at
  156, x 44 for a left door at 16); upper walkways at y 128 (`upper_left`
  x 16, `upper_right` x 96, 20 pieces) with 4-wide ladders (x 56 / 112;
  two_players: x 56 and 136 on 14-piece walkways) or a pole; doors at y
  160 (floor) or 96 (upper). Text: centred yellow heading (height 2) at y
  8; light-grey body at **x 20** from y 32 every 10 rows, **≤ 19
  letters**, ≤ 6 lines in rooms with an upper door. Start: gatehouse door
  0. Room text states mechanics checked against `creep.cpp` (doors: push
  up; poles: no climbing back; forcefield button: a timer; transmitter:
  fire to pick, then up; Frankenstein wakes when you share his floor; you
  can't fight the mummy; **keys and locks: stand at it and press fire**).
  | # | `Room` tag | Heading | Mechanic | Alive in |
  |---|---|---|---|---|
  | 0 | gatehouse | THE GATEHOUSE | doors and doorbells | ch5 |
  | 1 | gallery | THE LONG GALLERY | walkways | ch4 |
  | 2 | ladders | LADDERS | ladders | ch4 |
  | 3 | poles | SLIDING POLES | sliding poles | ch4 |
  | 4 | lightning | LIGHTNING | lightning + switch | ch6 |
  | 5 | forcefields | FORCEFIELDS | forcefield + timer | ch6 |
  | 6 | trapdoors | TRAPDOORS | trapdoor + switch | ch6 |
  | 7 | conveyors | CONVEYORS | conveyor + control | ch6 |
  | 8 | transmitter | THE TRANSMITTER | matter transmitter | ch6 |
  | 9 | keys | KEYS AND LOCKS | key + lock | ch7 |
  | 10 | ray_guns | RAY GUNS | ray gun + panel | ch7 |
  | 11 | mummy | THE MUMMY | mummy + ankh | ch8 |
  | 12 | frankenstein | FRANKENSTEIN | Frankenstein | ch8 |
  | 13 | frank_trap | A TRAP FOR FRANK | Frankenstein + trapdoor | ch8 |
  | 14 | frank_ride | FRANK'S RIDE | Frankenstein + conveyor | ch8 |
  | 15 | under_fire | UNDER FIRE | ray gun + forcefield | ch7 |
  | 16 | mummy_storm | MUMMY IN A STORM | mummy + lightning | ch8 |
  | 17 | locked_away | LOCKED AWAY | key behind a teleport | ch7 |
  | 18 | two_players | TWO'S COMPANY | two players, one switch | ch9 |
  | 19 | way_out | THE WAY OUT | exit door (door 1, `exit`) | ch9 |
  | final | (`plan.final`) | YOU ESCAPED! | image room: `trophy` ×1, `sparkle` ×6, floor, 2 text lines | ch9 |
  Later chapters may change a room's geometry and text to fit its
  machines (e.g. remove the ladder in `transmitter`) but keep room
  numbers; new rooms go at the end of `Room`. Castle 4,323 bytes (header
  256, directory 161, streams 3,906; text 2,991 bytes in 147 lines, 2,340
  letters, tags and end bytes included).
- **Main loop at ch03.** Title fire → `room.start` (header start room) →
  `draw_room`. Room mode: after `player.steer`, `m.bucket(0)` and
  `room.flip` (N/P via `$DC02`, any key acknowledged with 0; past the last
  room comes the final room, then room 0) → `draw_room`. The explorer is
  unchanged from ch02. Headless: a `--key` landing on a skipped slot of a
  loading pause is lost (said in the chapter's Game Over box and Boss
  Battle; keys 40 frames apart).
- **Costs at ch03.** Room draws 132,586 (final room) to 219,278 cycles (7-12
  slots, ≈ ¼ s at worst); `clear` 80,000; a plain letter ≈ 670 cycles, a
  tall one ≈ 1,160. Loops in `roomCount`, `stringEnd`, `placesEnd`, `line`
  and `image` charge `m.work(2)`-style loop overhead. Title draw 157,316
  (ch02 156,200). Room frame 108 idle (ch02 104 + the key peek), ≈ 360 on
  a key frame. Boss Battle: `--frames 300 --press 20:f:5 --key 60:N --key
  100:N --key 140:P --key 180:P --key 220:P --dump-every 20`, 7 loading
  pauses, final room from frame 240.
- **Tests at ch03 (12 with the machine's).** `castle.zig`: tag codes ↔
  kinds; the walker over a hand-written stream. `hall.zig`: the kit
  reproduces the hand-typed castle byte for byte. `main.zig`: `test { _ =
  hall; }`; N/P flipping with a loading pause and wrap to the final room;
  the Training Castle read back (header, room count, each stream's address
  and per-kind counts against the plan, streams end to end, size).
- **Ladder bookkeeping (ch03).** Taught: `extern struct` layout, padding
  and alignment (byte diagram + the machine's view error), plain vs
  `extern` struct, `packed struct(u8)` (ch4 refers back for flag bytes),
  little-endian (ch2's promise paid; `DataView` bridge), sentinels (the
  Sentinel Power-Up; C-string bridge), comptime properly (same language
  earlier; type-returning functions with a TypeScript bridge; `inline for`
  + `@field` with a JS bridge; `EnumFieldStruct`; the 1,000-branch quota;
  `@compileError` validation; `anytype`, `noreturn`, `x[0..x.len].*`),
  tagged unions, iterators (Python `__next__` bridge), `orelse`. In
  passing (later chapters refer back, don't re-teach from zero): `-%`
  (row 4, overflow), `+|` saturating add (row 4), the directory as "room n
  at `$7900 + n × 8`" (row 5, arrays of structs as one block), bells and
  doors naming each other by index (row 6, linking by index), `@max`,
  destructuring, `align(1)`. Prose promises: ch4 puts the explorer on the
  object-X scale ("past the wall made of arithmetic") and "teaches him the
  castle"; ch5 opens doors (the open-door look is already drawn) and
  brings function-table dispatch; ch9 moves into the header's spare bytes,
  draws the map from map x/y/size and the doors' map bytes, sets the
  visited bit, and keeps a clean `$9800` copy for each new game; ch11's
  disk drive replaces `m.load` and removes the program-image copy.
- **Chapter 4 file, title, images.** `site/chapters/04-creaky-floorboards.md`,
  `title: "Creaky Floorboards"`. Screenshots (full frames, 2×, 768×544):
  `04-ladders.png` (Mission Briefing: mid-climb in the Ladders room, Boss
  Battle `frame_00330`), `04-grid.png` (the G grid view of the Ladders room),
  `04-poles.png` (Boss Battle: mid-slide, `frame_00690`). Built from
  `site/tools/ch04/ch04.tmpl.md` with `listings.py`, `rebuild.py`,
  `expand.py`, `errs.py`, `wc.py` (scratch output goes to `$WORK`, default
  the writer's scratchpad; set `WORK=` to rerun). 47 labelled listings
  (plus the `art.zig` copy and one prose-only deletion) rebuild `ch04` from
  `ch03` byte for byte; stages A, B0, B, C, D, E, F each pass `zig fmt
  --check`, build, test and run. Prose ≈ 6,000 words, code ≈ 4,400.
- **Game source layout (from ch04).** Adds `grid.zig` (the navigation grid:
  `columns`, `rows`, the four direction masks, `clear`, `column`, `cell`,
  `at`, private `piece`, `add`, and the slow `search`) and `debug.zig` (the
  G and S switches: `keys`, `overlay`). `sprites.zig` adds `place` (castle
  point → sprite registers). `room.zig` adds `objects(m, n)` (stream address,
  final-room aware; `prepare` now uses it) and `firstDoor`. `player.zig` is
  rewritten around the grid (below).
- **Memory map at ch04.** `player` `$0200–$0206` (adds `player_way` `$0206`:
  direction of the last step, `player.still` = `$80`); **`game` moved to
  `$0207–$0208` and `room` to `$0209`** (the chapter shows the overlap
  error, then moves them); `debug` `$020A–$020B` (`debug_grid`,
  `debug_search`, 0/1); **`grid` `$C800–$CBE7`** (1,000 bytes, in the free
  KB between sprite frames and the screen plane). 19 regions.
- **Castle coordinates for the explorer (ch1 promise paid).** `player_x` =
  castle X of his left edge (fat pixel + 16), `player_y` = pixel row of his
  top. `sprites.place(m, n, x, y)`: sprite X = `@as(u16, x) * 2 - 8` (valid
  for x ≥ 4), low byte to `$D000+2n` via `@truncate`, bit 8 into `$D010`
  bit n (other bits kept), Y = y + 50. The wall at 255 is gone; the Gatehouse
  spawn is sprite X 316. **Feet point** = (x + 3, y + 21): 1984 reads the
  grid at (x + 3, y + 17) for its 17-row explorer; ours is 21 rows, boots on
  row 20. Real-castle positions that the 1984 engine derives from the feet
  must use our `feet_y` (21), not 17.
- **Navigation grid format (ch04; ch6/ch8/ch9 build on it).** One byte per
  screen cell, 40 × 25, cell (col, row) at `$C800 + row*40 + col` (the same
  numbering as the screen plane and colour RAM; `row*40` as `(row << 5) +
  (row << 3)`, `cell` charges 16). Bit d = direction d open, d clockwise
  from up (0 up `$01`, 2 right `$04`, 4 down `$10`, 6 left `$40`; odd bits
  are diagonals, never set: exactly 1984's bits). Built in `room.draw`:
  `grid.clear` (8,000 cycles) then `grid.add(m, r)` for every record, which
  ignores all but walkway/ladder/pole. Rules (1984 `obj_*_Prepare`):
  walkway piece 1 right, last left, middle both (length 1: right only);
  ladder up unless top piece, down unless bottom piece (length 1: nothing);
  pole down on every piece. Column = `x / 4 - 4`, `null` for x outside
  16..175 (off-screen pieces are skipped, so X < 16 objects can't underflow);
  rows ≥ 25 skipped. `grid.at(m, x, y)` (castle point) = 20 cycles.
  `grid.search(m, objects, x, y)` computes the same byte from the stream
  (1,118–1,646 cycles per question including `room.objects`, as `waysAt`
  calls it; Ladders room 1,442; corrected after the ch04 review); a test proves `at == search` for every cell of every
  room. **Deviation:** 1984 uses `$C000`, 2 bytes per cell (the second never
  read) and 32 rows (2,560 bytes); we use 1 byte, 25 rows. **Note for ch6
  (trapdoors):** 1984 opening a trapdoor clears the right bit of the
  trapdoor's cell and the left bit of the cell two to its right (`+4` bytes
  in its 2-byte grid), and sets them again when it shuts (`$36F6`, `$3734`,
  `$5220`); translate to our 1-byte cells (`+2`).
- **Movement rules (1984 `obj_Player_Execute`; the movement is kept
  exactly, the picture choice deviates, see "Shape IDs (ch04)").** One step every
  other frame (`steer` returns when `game_tick & 1 != 0`; 25 steps/s; 1984:
  the engine loop waits 2 frames and the player's countdown is 1). Stick →
  direction by a 16-entry comptime table built from `held` (compass
  `[3][3]u8`; up+down or left+right held = still; 1984 `$5F59`). `way` =
  wanted direction if its bit is open; else the last direction if it's open
  and the wanted one is adjacent (±1 mod 8, so diagonals continue the
  current move); else still. Moving up/down first sets `x = x - fx%4 + 1`
  (feet at fat pixel 1 of the cell: "snaps onto the ladder"); moving
  left/right first sets `y -= fy%8` (steps up onto the row). Step tables
  `step_x = {0,1,1,1,0,FF,FF,FF}`, `step_y = {FE,FE,0,2,2,2,0,FE}` added with
  `+%` (1984 `$34D7`/`$34DF`). Consequence taught in prose: a climb stops
  with his feet 6 rows into the top rung's cell (that cell has no up); push
  left/right to step off. No falling (1984 has none). Not implemented because
  nothing can trigger them: 1984's masking when the feet are mid-row in a
  cell with neither up nor down, and its diagonal reads of the up-left/
  up-right cell at cell edges. **Note for ch9:** 1984 player–player
  collision masks the other player's step (`Sprite_field_18` = `$EF` no
  down / `$FE` no up, `$3534`); our `steer` has no mask input yet.
- **Pole rule changed (ch04).** A pole's every piece opens down, so a pole
  must end one row **above** a walkway (else he slides through the floor).
  The builder now checks ladders end on a walkway and poles just above one
  (message: `castle: room poles: pole 0 must start on a walkway and end just
  above one (top piece row 128, bottom piece row 192)`; the check loops over
  a small array of `{ runs, kind, short }` structs). **ch11 note:** verify on
  a real castle file that 1984 poles end one row above a walkway (derived
  from the code: the last pole piece also opens down and there's no floor
  test; not yet confirmed on data). Training Castle `poles` pole length 9 → 8;
  `hall.zig` pole 16 → 15 (bytes and plan). Castle still 4,323 bytes.
  Supersedes ch03's "ladders and poles start on a walkway row and end on the
  walkway row below" for poles.
- **Spawn until ch5.** `player.enter` puts him in the room's **first door**
  record (`room.firstDoor`; doors are first in a stream): x = door x + 6
  (1984 `obj_Player_Add`), y = door y + 11 (1984 +15 for its 17-row
  explorer; ours puts his boots on the sill at door y + 32). Constants
  `door_x`, `door_y` in `player.zig`. Faces right if x < 96 (screen middle),
  else left. No doors (final room): x 96, y `room.floor_top - feet_y` = 171.
  **Promise to ch5:** the real arrival door replaces the first door ("Chapter
  5 brings the door he really walked through"); 1984 arriving through an
  *open* door starts at (door x + 11, door y + 12) and plays a walk-out
  animation; reuse `door_x`/`door_y` for the shut-door case.
- **Shape IDs (ch04, appended):** 26 `explorer_climb_0`, 27 `explorer_climb_1`,
  28 `explorer_climb_2` (= mirror of 0), 29 `explorer_climb_3` (= mirror of
  1), 30 `explorer_slide`. Shape table 1,951 bytes. Walk frame now
  `(x >> 1) & 3` on castle X (still every 4 screen pixels); climb frame
  `climb_0 + ((y >> 2) & 3)`; going up/down shows climbing if the feet cell
  **or the cell below** has the up bit (a ladder's top rung has no up), else
  `explorer_slide`. **Deliberate deviation:** 1984 (`$3421`) tests only the
  feet cell's up bit *before* the step, so its explorer shows the pole frame
  `$26` for his first steps down from a ladder top; ours looks one cell
  further (said in the Inside the Disk box); ch8 monsters copying 1984's
  picture rules should decide consciously. Stopped on a ladder/pole keeps
  the picture (he lands from a pole still in his slide pose, as in 1984; the
  prose says so); stopped walking stands. Art (revised after review):
  `climb_1` is asymmetric so the four climb frames are distinct, hands sit
  on the rails (sprite columns 2 and 5), the slide grips the pole above the
  hat with knees out. A second `comptime` check requires the climb frames
  to be consecutive.
- **ch2 promise paid (ch04).** ch2's "Chapter 4 has the story of what
  happens when a byte like `left` overflows" is answered in ch4's overflow
  section (ch2's `draw` stops before `left += 8` passes 255; ch3's walks on
  in a `u16`). `player.still` is now private (map comment says `$80`).
- **Debug switches (ch04, keep).** `debug.keys` (called before `room.flip`
  as `debug.keys(m) or room.flip(m)`): **G** toggles `debug_grid` and redraws
  the room (the explorer re-enters at the door), **S** toggles
  `debug_search` (steer's `waysAt` uses `grid.search`). `debug.overlay` runs
  after `room.draw` in `.draw_room`: each open cell is cleared and redrawn
  as a code-11 pipe map (centre block + arms), colour RAM yellow. Later
  chapters may add keys here; N and P stay `room.flip`'s.
- **Costs at ch04 (re-measured after the review).** Grid build 9,400–11,440
  cycles (clear 8,000 + marking); room draw is ch03's +9,650–11,010, from
  141,776 (final room) to 228,268 (`room.draw` alone; 229,244 for the whole
  draw frame, still 12 slots). Room frames: 88 between steps; step 196
  (standing) / 204 (walking) / 228 (climbing), +628 on a picture change.
  With S: 1,618 / 1,626 / 3,072, and 3,700 climbing with a picture change.
  The chapter's table (Ladders room): one lookup 20 vs ≈ 1,440; walking step
  204 vs 1,626; climbing step with picture 856 vs 3,700. Like-for-like in
  prose: eight climbers' lookups (2 a step each) 8 × 2 × 1,442 ≈ 23,000 vs
  8 × 2 × 20 = 320. Boss
  Battle: `--frames 1000 --press 20:f:5 --key 60:N --key 100:N --press
  120:r:176 --press 300:u:80 --press 390:r:130 --key 530:N --press 560:r:96
  --press 660:d:80 --press 750:r:220 --dump-every 10` → 950 calls, max
  229,244, 5 loading pauses, 0 overruns.
- **Tests at ch04 (18 with the machine's).** `sprites.zig`: castle X →
  sprite X incl. the ninth bit and other sprites' bits kept. `main.zig`:
  the walk test replaced ("explorer walks in": Gatehouse doorway at 162/171,
  `$D010` bit set, 8 frames left → x 158, `explorer_left_3`); the Ladders
  room's grid bits; `at == search` everywhere; the Long Gallery's walkway
  end (x 149 / 16); ladder line-up, diagonal climb, step-off, descent;
  pole down only. Helpers `inRoom(m, n)` (pokes `room_number` before the
  draw frame) and `hold(m, stick, frames)`.
- **Build modes, as taught in ch04.** Debug (`zig build`, `run`, `test`) and
  ReleaseSafe (`zig build wasm`, the browser) both panic on `+`/`-`/`*`
  overflow; ReleaseFast/ReleaseSmall leave the check out and overflow is
  undefined. (The brief said the browser build was ReleaseSmall; it's
  ReleaseSafe, per "Game project layout".)
- **Ladder bookkeeping (ch04).** Taught: fixed-width integers (`u8`, `u16`,
  `u3`, `i8`), overflow and the build modes, `+%`/`+|` (with `-%`, `*%`,
  `-|`, `*|` named), `@as`/`@intCast`/`@truncate`, two's complement (`0xFF`
  = −1, step tables added with `+%`; `@bitCast` named), 2D grids as one
  flat run (row × 40 + col, ×40 by shifts, JS `grid[y][x]` vs `Uint8Array`
  bridge, Zig `[3][3]u8` is contiguous), flags in a byte (refers back to
  ch2's flags byte and ch3's `packed struct`; masks because bits are picked
  by number). In passing: `or` short-circuits; shift amounts need `u3`
  (refers to ch2's Pro Tip, with `@intCast`). Prose promises: ch5 doors
  and the real arrival door; ch6 trapdoors rewrite grid bits ("Chapter 6
  does the same"); later chapters bring up to eight sprites that read the
  grid (a second explorer, mummies, Frankenstein's monsters).
- **Chapter 5 file, title, images.** `site/chapters/05-ding-dong.md`,
  `title: "Ding Dong, You're Dead"`. Screenshots (full frames, 2×, 768×544,
  all from the Boss Battle run): `05-bell.png` (Mission Briefing: Gatehouse
  door half wiped, explorer at the bell, `frame_00120`), `05-doorway.png`
  (walking into the open Gatehouse door, `frame_00230`), `05-flicker.png`
  (white hires flash in the Lightning room, `frame_02170`). Built from
  `site/tools/ch05/ch05.tmpl.md` with `listings.py`, `rebuild.py`,
  `expand.py`, `errs.py`, `wc.py`, plus `runs.py` (the stage runs; `{{A F}}`
  in the template expands to the Boss Battle arguments). `rebuild.py` gained
  a `replace_all` op (a search-and-replace table in prose, used once for the
  tests' `m.ram[map.player_*]` → `explorer(m).*`). 94 labelled listings plus
  three prose-only deletions (`player.sprite`, `player.setFrame`,
  `room.start`) and the replace table rebuild `ch05` from `ch04` byte for
  byte; stages A (actors), B (preparer table), C (objects + bell), D (doors),
  E (death), F (C switch) each pass `zig fmt --check`, build, test and run.
  Prose ≈ 6,750 words, code ≈ 7,250 (most of it in type-ins).
- **Game source layout (from ch05).** Adds `actors.zig` (`Box`, `Actor`,
  `State`, `Kind`, `Behaviour`, `kinds`, `slots`, `table`, `slot`, `clear`,
  `add`, `show`, `step`, `flicker`, `setFrame`), `objects.zig` (`Object`,
  `Flags`, `Kind`, `Handlers`, `kinds`, `slots`, `slot`, `clear`, `add`,
  `step`, `touching`, `overlap`) and `doors.zig` (`ring`, `find`, `open`,
  `enter`, `bell_reach` 12, `into_door` 1). `player.zig` is the explorer as
  actor kind `player` (`Status`, `feet_x` now `pub`, `doorway` walk table,
  `start`, `newGame`, `add`, `playing`, `turn`, `read`, `steer`, `walkIn`,
  `walk`, `kill`, `roomOver`, `nextRoom`, `pressedFire`, `pressed`, `held`);
  `player.show`, `player.enter`, `player.setFrame` and `room.start` are gone.
  `room.zig`: `objects(m, n)` renamed **`stream(m, n)`** (clashed with the
  `objects` import; "object stream" = castle data, "object table" = live
  slots), `firstDoor` replaced by `doorAt(m, room, i) ?u16` (any room; null
  if the stream doesn't start with doors or `i` ≥ count), per-kind preparers
  `door/walkway/pole/ladder/bell/line/image/later` all `fn (m, castle.Record)
  void`, `panel(m, door_at)`, `wipe(m, x, y)`, constants `door_panel_dx 4`,
  `door_panel_dy 8`, `door_panel_width 12`, `door_panel_height 24`.
- **Memory map at ch05.** `player` `$0200–$0204`: `player_actor` (slot),
  `player_status` (`player.Status`), `player_lives`, `player_last_stick`
  (kept at `$0203`), `player_door` (the door he enters the room by; 1984
  `$780B`). x/y/colour/block/frame/way moved into his actor slot; `$0205–
  $0206` are free. `game` `$0207–$0208`, `room` `$0209` unchanged. `debug`
  `$020A–$020C` (adds `debug_scan`, C). `engine` `$020D–$020E`
  (`engine_objects` = object slots in use, `engine_ending` = steps until the
  room is over, 0 = not ending). **`actors` `$BD00–$BD7F`** (8 × 16), **`objects`
  `$BE00–$BFFF`** (32 × 16): 1984's addresses (its tables are `$BD00` 8 × 32
  bytes, `$BE00`/`$BF00` two 32 × 8 tables). comptime checks in both files
  that slots × size fills the region. 22 regions.
- **Actor slot layout (16 bytes, `extern struct`, ch6+ must keep offsets):**
  0 `kind` (`actors.Kind = enum(u8) { player, _ }`), 1 `state`, 2–5 `box`
  (`Box = extern struct { x, y, width, height }`: castle top-left, picture
  size in fat px/rows; `setFrame` writes width = frame bytes × 4, height =
  rows, as 1984 `hw_SpritePrepare`), 6 `frame` (shape ID), 7 `block` (n or
  n + 8; `add` sets n + 8 so the first picture lands in block n), 8 `color`,
  9 `countdown`, 10 `pace` (1984 `Sprite_field_5/6`), 11 `flashes` (field_8),
  12 `way` (field_1F), 13 `stick` (direction this turn, field_1E), 14 `fire`
  (1 = pressed this turn, field_1D), 15 `walk` (doorway table index,
  field_1B). Bytes 12–15 are the player's; later kinds may reuse them their
  own way (1984 does) or ch6+ may rename them generically. **Slot n is
  sprite n** (1984 too). `State = packed struct(u8)` with 1984's bits: 0
  unused, 1 hit_sprite, 2 hit_bitmap, 3 free, 4 destroy, 5 dying, 6 flash,
  7 created.
- **Object slot layout (16 bytes):** 0 `kind` (`objects.Kind = enum(u8) {
  door, bell, _ }`; ch6+ append kinds), 1 `flags` (`Flags = packed
  struct(u8) { own: u5, picked (bit 5), execute (bit 6), disable (bit 7) }`,
  1984's `ITM_*`), 2–5 `box`, 6–7 `record: u16` (castle record address; the
  first `u16` in our own structs, at an even offset), 8 `number` (door: index
  in the room's door group; bell: its door's index), 9 `open` (door, 1984
  `Object_field_1`), 10 `step` (door wipe row, field_2), 11–15 `spare`.
  Objects are created enabled (1984 creates them disabled until drawn; same
  effect). `add` returns `?u8`, null when 32 are used (object drawn but
  inert, 1984 behaviour). `picked` is defined but nothing handles it yet:
  **ch7 (keys)** implements 1984's removal (swap the last object into the
  slot, `object_Execute` `$3F96`).
- **Handler tables (ladder row 5: dispatch tables).** Built with
  `std.enums.directEnumArray(Kind, T, 0, .{...})`, so a missing kind is a
  compile error (`missing struct field: image`, quoted in the chapter) and
  the table is a plain `[N]T` indexed by `@intFromEnum`. Three tables:
  `room.prepares` (castle `Kind` → `*const fn (m, castle.Record) void`; 11
  kinds are `later`, a no-op; ch3's promise paid), `actors.kinds`
  (`Behaviour { turn: *const fn (m, n: u3) void, flickers: bool }`; 1984's
  `$088F` records also have hit-sprite and hit-object handlers: **ch6/ch7 add
  `hit` (sprite–sprite) and `touch` (sprite–object, e.g. trapdoor kills,
  1984 `obj_Player_Collision`) fields when lightning/trapdoors arrive**), and
  `objects.kinds` (`Handlers { execute, in_front: ?*const fn }`, optional =
  1984's zero address). Non-exhaustive kind enums are required by `m.view`;
  an unnamed kind indexes out of bounds and panics.
- **Engine step (1984 `events_Execute`).** One step every other frame
  (`game_tick & 1 == 0`, moved out of `steer`), in `main`'s `.room` branch
  after `actors.show`: `actors.step` (bucket 3) then `objects.step`
  (bucket 4), then `player.roomOver`. `actors.step`: read `$D01E/$D01F`,
  write 0 to both, copy each in-use actor's bit to `hit_sprite`/`hit_bitmap`;
  then per slot: `destroy` → turn immediately; `flash` or `dying` →
  `flicker`; else countdown −1, at 0: if `hit_bitmap` (or `debug_scan`)
  `objects.touching`, then turn unless `flash` got set; `free` → `unused`;
  countdown = pace. `objects.step`: for each slot, if `execute`, call
  `execute` (or clear the flag if null). No event queue: **the outline's
  "event queue" was dropped**: 1984 has none (`EventAdd`/`mEvents` in the
  reference port are its SDL input queue; `events_Execute` is the engine
  loop). The execute flag is the to-do list. `actors.show` (bucket 2) runs
  every frame: place/colour/pointer for every in-use, non-`destroy` slot;
  `$D015` from in-use slots, `$D01C` multicolour unless `dying`. `clear`
  also zeroes `$D01E/$D01F`.
- **Collision approach.** Hardware first pass, then boxes: only an actor
  whose `$D01F` bit was set (sprite pixel on a foreground bitmap pixel,
  codes 10/11) runs `objects.touching`, which box-tests every non-disabled
  object (`overlap`: inclusive edges, sums in `u16`, 40 cycles) and calls its
  `in_front`. Doors (arch, panel), bells (outline) are foreground enough;
  verified in the Gatehouse and on every door in the Boss run. `hit_sprite` is
  recorded but **unused until ch6** (lightning is the first second actor):
  ch6 adds 1984's `Sprite_Collision_Check` (actor box vs every other actor
  with `hit_sprite`, per-kind hit-data mask at `$0895`, both directions'
  handlers). Measured: Gatehouse standing step 246 cycles (bucket 3), 374
  with C (2 objects ≈ 64 each); prose extrapolates 8 × 32 × 64 = 16,384.
- **Doors and doorbells, as implemented.** Bell `in_front` (`doors.ring`):
  actor kind player, `a.fire` (a *press* this turn; 1984 accepts fire held,
  said in an Inside the Disk box), player status playing, `a.x + feet_x −
  bell.x < 12` with wrapping (1984 `$41D8` uses `mWidth = 3`), door found by
  searching objects for kind door with the bell's number (1984 too), and if
  the door's `open` is 0, set its `execute`. Door `execute` (`doors.open`):
  first call sets `open`, `step = door_panel_height − 1` (23), and bit 7 of
  byte 2 of **this door and the door it leads to** in the castle (1984
  `obj_Door_Execute`); each step `room.wipe` zeroes the 3 bitmap bytes of
  panel row `step` (bottom up, colour cells untouched); at step 0, wipes row
  0, clears `execute`, `room.panel` draws `door_open` recoloured to the
  destination. **Deviation:** 24 rows / 23 steps (≈ 0.96 s) vs 1984's 15
  rows / 14 steps; 1984 erases with shape `$7C` (3 × 1). Door object box =
  the panel (12 × 24 at +4, +8; 1984 12 × 15 at +4, +16). Bell box = the bell
  shape's size (12 × 19). Persistence is the castle bit, so doors stay open
  across rooms, deaths and (until ch9's clean copy) games.
- **Entering a door: stick up-and-right (direction 1), 1984-exact.**
  `obj_Door_InFront` (`$4085`: `lda $bd1e,x; cmp #$01`) requires the
  stored stick direction to be 1 (up+right via the `$5F59` table), on every
  door; teleports and switches use 0 (up). The Gatehouse sign changed to
  "PUSH UP AND RIGHT." (castle 4,333 bytes). This **supersedes** ch3's log
  line "doors: push up". Door `in_front` (`doors.enter`): door `open`, actor
  kind player, `a.stick == 1`, status playing → `player.walkIn`: status
  `doorway`, `walk = 0`, `pace = 3`, snap to (door x + 6, door y + 11),
  `room_number = to_room`, `player_door = to_door` at once (1984 sets
  `$7809/$780B` at once too).
- **Doorway walk and arrival geometry (ch4 promise paid).** `player.doorway`
  table, 14 entries `{dx, dy, frame, then: ?Status}`: in = entries 0–6
  (frame only, then 5 moves +1 x, −1/0/−1/0/−1 y, then `.gone`), out = 7–13
  (frame, 5 moves −1 x, +1/0/+1/0/+1 y, then `.playing`); one entry per turn
  at pace 3 (≈ 0.84 s). Same timing and displacement as 1984's 12 × 4-byte
  table at `$34A1` (walk out starts at offset `$18`). Frames are our walk
  frames (right going in, left coming out); 1984 has six dedicated images
  `$1E–$23` (a Bonus Stage suggests back-view art). Arrival through an
  **open** door: (door x + 11, door y + door_y − 3) = (+11, +8) — 1984's
  (+11, +12) is its +15 less 3 — status `doorway`, `walk = 7`, pace 3; walks
  out to (+6, +11). Shut door: (+6, +11), standing, facing right if x < 96.
  No doors (final room): middle of the floor. Facing after walk-out is
  left (1984 too).
- **Room end and lives (1984 `roomMain`/`Game`).** `player.roomOver`: while
  status is playing/doorway, false; otherwise `engine_ending` counts 30
  steps (1984 runs 30 more engine ticks) and then true. `player.nextRoom`:
  through a door → true (room/door already set); dead → lives `-|` 1; 0 →
  false → `.draw_title` (minimal game over); else room/door = castle
  header start room/door (**1984 respawns at the castle's start**, not the
  room's entry door; `$7809 = $7803`). `player.newGame` (title fire) sets
  room/door from the header and lives from header `$07`. **ch9 must:** show
  "GAME OVER", keep the clean `$9800` copy so a new game's doors are shut
  again (now a new game after game over keeps the open doors), show the map
  between rooms (1984 `mapDisplay` after every room), move lives/room/door
  into the header scratch if it wants 1984's layout (`$7807/$7809/$780B/
  $780D`), add the escape when the exit door's walk-in ends (1984 sets
  `$785D` in `obj_Door_InFront` when byte 7 ≠ 0; in ch5 The Way Out's exit
  door leads back into its own door 0, said in prose), and a second
  player (`player_actor` already decouples player from slot).
- **Death lifecycle (coverage row 20), in the engine now.** K (`debug.keys`;
  1984's equivalent is the kill key it offers for being stuck) →
  `player.kill`: only if playing; status `dead`, actor `flash`. `flicker`
  (1984 `Sprite_FlashOnOff`): `flash` → clear, if the kind `flickers`:
  `dying`, `flashes = 8`, `pace = 1`, else `destroy` at once; each dying step
  on even engine steps (`game_tick & 2 == 0`) colour white and `flashes −1`,
  odd steps black; hires while dying (`$D01C` bit off); at 0 → `destroy` →
  the kind's turn (player: `free`) → `unused`. **ch6 wires real hazards**
  (lightning touch, trapdoor fall) by setting `player_status = dead` and the
  actor's `flash` (1984 sets status 2 and returns true from the collision
  handler); **ch10** adds the flash sound (1984 `SOUND_SPRITE_FLASH`, pitch
  from `flashes << 3`) and the door sound (`SOUND_DOOR_OPEN` each opening
  step, pitch `$10 − step`).
- **Pure fire-press rule (ch2 caveat resolved).** `player.pressed(stick,
  before) bool` is pure. In a room, `player.read` (every turn, every status)
  is the only writer of `player_last_stick` and records `a.stick` (direction)
  and `a.fire` (press) in the slot; handlers read the slot. The title still
  uses `pressedFire` (per frame). Consequence: a press is per *turn* (every
  other frame), so a one-frame tap on an odd frame is missed (fine for
  humans; tests hold fire ≥ 2 frames).
- **N/P kept** as a debug aid: `room.flip` also sets `player_door = 0`, so
  he enters by door 0 (walking out if it's open). G/S unchanged; **C**
  (`debug_scan`) makes every actor run `touching` every turn; K kills.
- **Costs at ch05 (measured).** Room frames: 170 cycles without an engine
  step (146 of it `actors.show` over 8 slots), 448 with one standing still
  (bucket 3 246, bucket 4 28), ≈ 1,096 with a picture change; ch04 was 88 /
  196. Door opening: bucket 4 440 on the first step, 102 per wipe step, 2,112
  on the final draw. Room preparation 143,106–236,478 cycles (12 slots at
  worst; ch04 236 k incl. grid). Boss Battle (`runs.py` F, 2,300 frames):
  2,227 calls, max 236,824, 7 loading pauses, 0 overruns.
- **Tests at ch05 (28 with the machine's).** `actors.zig`: slot add/free/
  capacity; the table is one block (offsets, state bits). `objects.zig`:
  `overlap` edges and no wrap; handlers cover every kind and `add` stops at
  32. `room.zig`: a preparer for every castle kind. `player.zig`: the press
  rule. `main.zig`: ch04 tests on `explorer(m)` (helper returns the
  player's slot); bell opens the door on both sides; fire held across the
  room doesn't ring; through the Gatehouse door into the Gallery's door 0
  and back (door still open; up alone doesn't enter); K → flicker
  (multicolour off) → 2 lives at the start → game over → title.
- **Ladder bookkeeping (ch05).** Taught: arrays of structs as one block
  (JS heap/pointer diagram vs `[8]Actor` view; slot address arithmetic),
  fixed-capacity slot tables (Slot Table Power-Up), function pointers and
  dispatch tables (Jump Table Power-Up; `*const fn`, optional `?*const fn`
  with `if (f) |call|`, `directEnumArray`), non-exhaustive enums, hardware
  collision as a first pass and execute flags (Only-If-Asked Power-Up). In
  passing: `.?` (unwrap or panic), shadowing is an error, struct field
  defaults in a `const` table (`Walk`). Linking by index is still ch6's
  (doors/bells name each other by number, used lightly). Prose promises:
  ch6 brings the machines into the `later` entries, the second actor kinds
  and sprite–sprite collision, and real deaths; ch7 transient actors (lasers)
  and keys (`picked`); ch9 the escape, game over words, clean castle per
  game, the map; ch10 sound.
- **Reserved keys (rule, from the ch05 review).** Debug and game keys must
  never be joystick keys: **W A S D, I J K L, the arrows, Space, Return**
  (the browser shell drives the sticks with them, and they also reach
  `$DC02`). Keys in use: N, P (room flip), G (grid view), **Q** (search
  instead of the grid; was S in ch04, renamed in ch04's code, chapter and
  tools), C (scan every object), **X** (give up a life; was K in the ch05
  draft). Chapter 9's second player and Chapter 11's menus must keep to
  this too.
- **Search-and-replace table (convention, from the ch05 review).** A
  listing may be replaced by a table of `| Replace | With |` pairs only for
  a purely mechanical rename inside one named file, applied to every
  occurrence, with no other edits on those lines, and where a missed
  occurrence fails to compile. The prose says "with your editor's find and
  replace" and names the compile-error safety net. Never for a change that
  needs judgement. `rebuild.py`'s `replace_all` op implements it (used once,
  ch05 stage A, `m.ram[map.player_*]` → `explorer(m).*`).
- **ch05 review fixes (supersede the numbers above where they differ).**
  C switch on bare floor: 246 → **354** cycles (54 an object; full room 8 ×
  32 × 54 = 13,824, ≈ 70 %). Room preparation peaks at 236,478 = **13
  slots** (the Gatehouse's longer sign). Walking step with a picture change
  ≈ 1,216. Door opening is **24 steps** (rows 23..0 wiped, drawn open on the
  24th; 1984 15 steps, ≈ 0.6 s). **Shape IDs 31 `explorer_back_0`, 32
  `explorer_back_1`** (back views drawn in the left 5 fat-pixel columns, so
  at door x + 6..11 he stays inside the panel's +4..+15 and never over the
  pillar): the doorway walk uses them both ways, the walk out's last step
  turns to `explorer_left_0`. Shape table 2,045 bytes. `player.walk_across =
  5`, `walk_up = 3` (comptime-checked against the `doorway` table) and
  `player.middle` replace magic numbers. The chapter now owns the push-up
  mistake ("Chapter 3's sign … was wrong"); ch3's text and screenshot stay.
  Listing blank-line padding is hidden in the shown fence; labels say
  "after a blank line".
- **Note for ch7 (ladder row 7).** Ch05 already taught free-slot reuse (the
  Slot Table Power-Up, `actors.add` finding the first `unused` slot, a test
  that frees slot 3 and reuses it) and a lifecycle state machine in one flag
  byte (`actors.State`: created → flash → dying → destroy → free → unused).
  Ch7's lasers must refer back to both and build on them (a transient actor
  that spawns into a free slot and frees itself), not re-teach them; its new
  material is the ray gun's own flag byte (`RAYGUN_*`) and spawning under
  the 8-sprite cap.
- **Chapter 6 file, title, images.** `site/chapters/06-flip-the-switch.md`,
  `title: "Flip the Switch"`, generated from `tools/ch06/ch06.tmpl.md` by
  `expand.py` (109 listings, prose ≈ 5,430 words by `wc.py`). Screenshots
  (768×544): `06-lightning.png` (Mission Briefing; run A frame 200, bolts
  crackling, explorer on the ladder), `06-switch.png` (A 330, lever down,
  poles dull), `06-zapped.png` (B 260, walking into a bolt),
  `06-forcefield.png` (C 350, field down, gauge relighting),
  `06-conveyor.png` (a room-7 run frame 320, carried on the belt),
  `06-transmitter.png` (F 2520, in the booth, lamp red). Diagrams:
  `ch06-links` (switch record → machine records → object table → sprite
  slot), `ch06-wall` (animated; `grid.wall` on five cells),
  `ch06-belt` (animated; 8 cells recoloured, with the three costs). Quoted
  error: `'place' is not marked 'pub'` (`errs.py` case `private`).
- **Source layout (ch06).** New files `lightning.zig`, `forcefields.zig`,
  `trapdoors.zig`, `conveyors.zig`, `transmitter.zig` (each: constants,
  `prepare`, the handlers). Changed: `castle.zig` (named state bits:
  `lightning_switch $80`, `lightning_on $40`, `trapdoor_open 1`,
  `conveyor_on 1`, `conveyor_left 2`, `conveyor_pressed 4`, `conveyor_held
  $10`, `conveyor_players $3C`; `Teleport{x, y, target}` + pads), `objects.zig`
  (`find(m, kind, number)` generalised from `doors.find`, which is deleted;
  `clock` = `game_tick >> 1`; `none = $FF`; `touching` calls
  `actors.touch` before `in_front`), `actors.zig` (`none = $FF`,
  `hitting`, `hit`, `touch`), `room.zig` (`place` now pub; `unplace`,
  `swap`, `tint`, `boxOf`, `first`), `screen.zig` (`erase`), `grid.zig`
  (`wall`), `player.zig` (`die`, `hit`, `touch`, `tread`; `feet_y` pub;
  `underfoot = 4`), `main.zig` (`actors.clear` moved before `room.draw`,
  because forcefields add their actor in `prepare`; so the explorer is not
  always slot 0, `player_actor` pays off). `room.prepares`: lightning,
  forcefield, trapdoor, conveyor, teleport are real; `later` remains for
  mummy, key, lock, raygun, frankenstein (ch3 promise fully paid in ch8).
  Shape IDs appended after `explorer_back_1`: `machine_pole, machine_tip,
  bolt_0..3, lever_plate, lever_up, lever_down, button_frame, button_lit,
  field_top, field_on_0, field_on_1, field_off, trapdoor_shut,
  trapdoor_tilt, trapdoor_open, plate, belt, control, control_knob, booth,
  lamp, pad` (25; bolts comptime-checked consecutive).
- **Memory map (ch06).** `player` region grows to `$0200–$0206`:
  `player_plate` (+5, plate object under his feet this turn or `$FF`) and
  `player_last_plate` (+6). No other region changes. Shape table 3,265
  bytes (was 2,045); training castle 4,438 bytes (was 4,333).
- **Slot layouts (ch06; keep offsets).** Actor `Kind = { player,
  lightning, forcefield, _ }` (1984 numbering 0, 1, 2; later chapters keep
  1984's: mummy 3, laser 4, frankenstein 5, so ch7 must add `mummy` before
  `laser` or give the enum explicit values). Object `Kind = { door, bell,
  machine, lever, button, trapdoor, plate, belt, control, booth, _ }`.
  Object bytes 8 `number` (generic link number), 9 `open`, 10 `step`, **11
  `actor`** (slot or `actors.none`), **12 `timer`**, 13–15 `spare[3]`.
  `Behaviour` gains `hit: ?fn(m, n, other) bool`, `touch: ?fn(m, n,
  object) bool`, `group: u8` (1984 `$0895` hit masks: player 0, lightning
  `0b100`, forcefield `0b011`).
- **Links (ladder row 6), as implemented.** Three kinds of index, no
  addresses: (1) switch → machines: the castle's 1984 format, byte offsets
  from the room's first lightning record (`room.first`), `$FF` ends the
  list; a machine object's `number` = its offset. (2) object ↔ object by
  `(kind, number)` via `objects.find` (bell→door, switch→machine,
  plate→trapdoor; trapdoor and plate share the record's offset in the
  trapdoor group). (3) object → actor by slot in `o.actor` (machine →
  bolt, button → field).
- **Sprite–sprite collision (ch5 promise paid).** In `actors.step`, before
  the countdown, an actor with `hit_sprite` runs `hitting(m, n, hits)`:
  every other actor whose bit is in `$D01E`, not dying, not sharing group
  bits, with overlapping boxes; both `hit` handlers are called (n, other
  and other, n), true sets `flash`. `player.hit`: forcefield → false,
  anything else → `die` (status dead; true). Runs every step (not only on
  turns). `actors.touch` (actor's own object handler, 1984
  `obj_Player_Collision`) is called from `objects.touching` before the
  object's `in_front`; `player.touch`: feet within `underfoot` of the
  object's x: trapdoor → `die`, plate → `player_plate`.
- **Mechanics, as implemented.** *Lightning:* machine object box = emitter;
  `execute` set if on; first step adds the bolt (x = tip x, y = tip y + 8,
  `bolt_0`), each 4th step tints the pole (3 colour pairs); off → tint
  dull, bolt `destroy`, execute off. Bolt turn: pace 1–4, picture 1–3 on
  (never the same), fake random from `clock ^ slot*$5B`. Switch
  `in_front`: player, playing, feet within lever width, stick up (0) =
  on / down (4) = off, flips own bit and each listed machine's bit, sets
  its `execute`, `swap`s the lever. *Forcefield:* `prepare` draws
  button/gauge/emitter, adds the button object and the field actor
  (`field_x`, `field_y + 2`, pace 4) and raises: `grid.wall(column(field_x
  + 2), (field_y + 27) / 8)` (1984's cell). Button `in_front` on a fire
  press: lower if up, gauge rows all 0, `step = 8`, `timer = 30`; `execute`
  each step: every 30 relight one gauge row (one bitmap byte, bottom up),
  at 0 raise. 240 steps ≈ 9.6 s (1984 same 8 × 30). Field turn alternates
  `field_on_0/1` while up. *Trapdoor:* `prepare` erases the walkway piece
  at (x + 4, y), draws the picture at (x + 4, y − 8), panel object 4 × 16
  (disabled while shut), wall `grid.wall(column(x) + 1, y / 8)` when open
  (1984's two-cell rule from the ch4 note), plate object + tint (red open,
  green shut). `tread` (on his turn, after `read`): plate ≠ none and ≠
  last → `trapdoors.flip` (castle bit, wall at once, tint, panel
  `execute`; shutting disables at once, opening enables at the end).
  `swing`: one picture a step. *Conveyor:* `prepare` clears bits 2–5,
  belt always executes. Control `in_front` on a fire press sets `pressed`.
  Belt `execute`: fresh press (pressed, not held) → on: `^= on|left`
  (stop and reverse), off: `|= on`; arrows tinted; held = pressed; if on,
  every other step shift the 3 shades across 8 cells (tint 224 cycles).
  `carry` (belt `in_front`): player only, walking frames only, feet on the
  32-px belt, ±1 per step and ±1 more when `clock & 7 == 0` (1984 exact
  for the player). *Transmitter:* `prepare` draws booth, lamp (tinted pad
  `target`'s colour, colour i + 2), pads; booth object (x + 4, y + 8, 8,
  24). `in_front`: ignored while flashing; fire → x = pad x, y = pad y + 8
  − `feet_y`, `step = 32`, execute; up (0) and `clock & 15 == 0` → next
  pad (wrap at the 0 terminator), lamp tint. `flash`: 32 steps, pad white
  / lamp black when `step & 2`.
- **Training Castle rooms 4–8 (ch06; numbers unchanged).** 4 Lightning:
  machines `{on, 104, 112, len 6}`, `{on, 124, 112, len 6}`, switch
  `{switch|on, 28, 104, machines 0, 8, $FF, $FF}`; new text "TOUCH
  LIGHTNING AND / YOU'RE TOAST…". 5 Forcefields: `{button 120,160; field
  80,168}`; text "…ONLY UNTIL / ITS GAUGE FILLS UP…". 6 Trapdoors: `{open,
  72, 192, switch 112, 184}`; text "A TRAPDOOR IS OPEN…". 7 Conveyors:
  trapdoor `{open, 52, 192, switch 124, 184}` + belt `{on|left, 60, 184,
  control 96, 160}` (the belt runs into the hole); text "…THIS ONE / RUNS
  TO A TRAPDOOR!". 8 Transmitter: the ladder is replaced by a pole `{8, 72,
  128}` (booth up, pole down), teleport `{112, 160, target 1, pads (60,
  120) red, (136, 184) cyan}`; text fixed to "PUSH UP … PRESS FIRE AND
  YOU'RE THERE" (**ch3's sign had up and fire reversed**; 1984 `$4EA8`
  up changes, fire sends; owned in an Inside the Disk box). Floor gadgets
  (plate, belt, trapdoor) have foreground pixels at rows 184–191 so the
  hardware first pass sees his legs.
- **Deviations (ch06).** (1) Bolt link: we keep the bolt's slot in the
  machine object; 1984 stores the machine number in the bolt (field_1F)
  and searches the sprites (box). (2) Forcefield: the button sets the
  field's picture; 1984's field polls a flag table at `$4750` each turn
  (box). (3) Recolour instead of redraw: pole (1984 redraws six pieces
  with patched colour bytes), belt (1984 draws frames `$7E–$81`), lamp and
  pads (1984 redraws shape `$71/$72`); trapdoor has 3 pictures, 1984 six
  (`$73–$78`) (box). (4) `conveyor_left` is 1984's `CONVEYOR_MOVING_RIGHT`
  bit, which moves things left; same bit (box). (5) Presses, not held fire,
  for button/control/booth (1984 tests the button state; its conveyor has
  the same edge rule). (6) Bolt randomness is clock-based until ch8. (7)
  Field sprite 21 rows vs 1984's 25. (8) Switch reach: feet within the
  lever's width; 1984 tests `x + width − switch x < 4`. (9) Teleport
  arrival y = pad y + 8 − 21 (1984 pad y + 7 in its sprite coordinates).
  (10) Flash: 32 steps, 2 on / 2 off; 1984 8 flashes on `ticks & 3`.
  (11) The search test drops the final room (no plan entry) and expects 2
  differing cells per raised forcefield / open trapdoor.
- **Costs at ch06 (measured).** Tint one cell 28 cycles; belt tint 224 vs
  draw 1,320 vs swap 2,972; pole tint 88 vs draw 1,704; `objects.find` 76;
  `room.first(.lightning)` 576. Step maxima (actors / objects buckets):
  room 4 2,218 / 300, room 5 1,208 / 52, room 6 566 / 64, room 7 670 / 336,
  room 8 514 / 52. Boss Battle (`runs.py` F, 2,900 frames, rooms 4→8 via
  N×4, ending in the Keys room): 2,786 calls, bucket 3 max 2,750, bucket 4
  max 2,192, 11 loading pauses, 0 overruns.
- **Tests at ch06 (34 in `zig build test`).** `main.zig`: lightning
  (walk into a bolt → dead; climb to the switch, down → 0 bolts, up → 2);
  forcefield (stopped at feet 87; press; through; back up after 240
  steps; stopped at 76 from the other side); trapdoor (switch flips once
  per step-on, both ways); conveyor (carried into the hole → dead; control
  stops+reverses, restarts right, carries right); transmitter (up moves
  the lamp within 17 steps, fire lands on pad 0); search test rewritten
  (`inline for` over `training.Room`, `@field` + `@tagName`). `screen.zig`:
  `erase` removes only the shape's pixels.
- **Ladder bookkeeping (ch06).** Taught: linking by index (under-the-hood
  box: JS references vs ids, `JSON.stringify` copies; the Index Link
  Power-Up; diagram), toggling a bit with `^=` (one sentence; XOR proper is
  ch8's), colour cycling via the screen plane (the Recolour Power-Up),
  patching the navigation grid at runtime (`grid.wall` diagram; "the grid
  isn't the castle any more"), edge detection "now and not last time"
  (refers back to ch2's press rule), erase masks (`b | b>>1 & $55 | b<<1 &
  $AA`). In passing: `inline for`, `@field`, `@tagName`, comptime block
  checking enum order. Shared state machines: trapdoor's open/step and the
  conveyor's bits. ch5's "linking by index used lightly" is now paid.
- **Promises (ch06 → later).** ch7: lasers are actor kind 4 with their own
  group (1984 `$0895`), keys use `picked`; ray gun + forcefield combo room
  will need laser vs field groups. ch8: real pseudo-random (replace
  `crackle`'s clock roll), monsters ride belts (`carry` is player-only,
  1984 also carries mummies/Frankensteins at 2 px every step) and fall in
  trapdoors (`touch` for monsters), Frankenstein/mummy `hit`/`group`. ch9:
  player 2 (conveyor P2 bits `$08/$20` already reserved by
  `conveyor_players`, player-vs-player groups, `player_plate` per player),
  the final room back in the search test. ch10: sounds (switch, forcefield
  tick, trapdoor swing, conveyor switch, teleport change/send).
- **ch06 review fixes (supersede the ch06 entries above where they
  differ).** *Rooms 6 and 7 re-laid so the reader meets the open hole in
  normal play* (with one plate between entry and hole, 1984's step-on rule
  makes every crossing flip, so a hole met open can only be crossed by
  turning round *on* the plate; hence:) 6 Trapdoors: trapdoor `{0 (shut),
  72, 192, switch 32, 184}`, switch beyond the hole: it opens behind him on
  the way to door 1, and walking back the hole stops him at feet 72; sign
  "THIS TRAPDOOR IS / SHUT. STEP ON ITS / SWITCH AND IT OPENS / BEHIND YOU.
  STEP ON / IT AGAIN AND IT / SHUTS." 7 Conveyors: trapdoor `{open, 52,
  192, switch 28, 184}` (beyond the hole), belt unchanged (runs left into
  the hole: walking in along the floor kills him), plus a high walkway
  `{22, 32, 128}`, `ladder_right` (x 112) and a pole `{8, 36, 128}`: the
  way on is up, along and down the pole; last line of the sign "RUNS INTO A
  HOLE!". Tests rewritten without setting `box.x`: trapdoor (shut → step on
  switch → open behind → walk back, stopped alive at 72 → step on again →
  shut); conveyor (walk in → carried into the hole → dead; control stops
  and reverses; walking left against the right-running belt he gets no
  further than 90; ladder, high walkway, pole, onto the switch → shut, then
  carried right past 100). Search test: room 7's open trapdoor is the only
  trapdoor wall now. Castle 4,435 bytes (was 4,438 before the review; ch05 4,333). *Runs:* E = straight along the floor
  into the hole (500 frames); `ROOM7` takes the high road; Boss F is 3,120
  frames (room 8 from 2,610): 3,006 calls, bucket 3 max 2,750 (the switch
  throw, frame 318; 3,042 with bucket 4), bucket 4 max 2,420, 11 loading
  pauses, 0 overruns; named frames 330, 1010, 1760, 2200, 2350, 2770, 3119.
  *Images:* `06-switch.png` = A 370 (he has stepped away; lever visible),
  `06-conveyor.png` = E 320 (walking left on the running belt towards the
  open hole), new `06-trapdoor.png` = F 1760 (trapdoor open behind him at
  the door), `06-transmitter.png` = F 2740 (same picture as before). Every
  image now comes from a `runs.py` run. *Listings:* stage B's lightning test
  is two edits (B6 the name line, B6b the death block replacing the
  `// Up the ladder` comment), 110 listings; labels A31/A35/D24 corrected.
  *Diagrams:* `ch06-wall` rests on "wall up" and its hole marker is
  `--ink-soft`; `ch06-belt` delays −0.17 s/−0.33 s so the paused figure
  shows three shades; `ch06-links` caption dropped (its small print stays).
  *Prose:* `find` costs 52–64 cycles (76 was a miss); the forcefield
  press-vs-held difference is told (1984 re-arms while fire is held, so a
  second player can hold a field down; ch9 may restore it); the conveyor's
  `held` bit is explained (1984 reads the held button; room for P2), and
  the Game Over symptom is now "keeps reversing: clear `pressed`"; the
  Inside the Disk box no longer quotes a name for the direction bit; ch3's
  transmitter-sign mistake is owned in the prose, not the lore box; ch1's
  Edge Detector and ch3's `inline for` are referred back to. Prose ≈ 5,570
  words.
- **Note for ch11 (from the ch06 review).** `room.tint`, `room.unplace` and
  `screen.erase` compute `x − castle.left_edge` and `x / 4` with no
  off-left handling: a machine at castle X < 16 overflows (panics in Debug
  and ReleaseSafe). Add them to the "check the real castles for X < 16"
  list when real castles load.
- **Chapter 7 file, title, images.** `site/chapters/07-lock-and-load.md`,
  `title: "Lock and Load"`, generated from `tools/ch07/ch07.tmpl.md` by
  `expand.py` (65 listings, prose ≈ 5,030 words by `wc.py`). Screenshots
  (768×544, every one from a `tools/ch07/runs.py` run): `07-under-fire.png`
  (Mission Briefing; E 470, a laser stopping on the field with the explorer
  behind it), `07-keys.png` (A 740, at the green key upstairs),
  `07-locked.png` (B 390, just arrived on the pad), `07-panel.png` (C 480,
  at the panel, gun climbing), `07-shot.png` (D 340, the laser reaching him
  on the floor), `07-escape.png` (E 1380, gun at the top, field down, running
  for the door). Diagrams: `ch07-swap` (animated; the key's slot taken by
  the last object, count 4 → 3), `ch07-gun-byte` (static; the `Gun` bits,
  castle-set vs game-set), `ch07-slots` (animated; one laser's life in
  slot 2, plus the full table where `add` says null). Quoted error:
  `Cannot create a direct enum array for actors.Kind. It would have 1
  unused slots, but only 0 are allowed.` (`errs.py` case `gap`). Quoted test
  failure: the first Under Fire test before the `share` fix (`expected 0,
  found 3`).
- **Source layout (ch07).** New files `locks.zig` (`prepareKey`, `take`,
  `carrying`, `prepareLock`, `unlock`) and `guns.zig` (`gunX`, `picture`,
  `lowest`, `prepare`, `lamps`, `run`, `move`, `shoot`, `fly`, `gunOf`,
  `blocked`, `strike`, `steer`; comptime check that each way's 4 gun
  pictures are consecutive). Changed: `castle.zig` (header `keys_count`
  `+$13`, `keys_held` `+$15`, `pocket = 32`; documented `Key`, `Lock`;
  `RayGun.runtime` renamed **`gun_y`** and `state` typed **`Gun`**, a
  `packed struct(u8)`: bit 0 `left`, 1 `down`, 2 `up`, 3 `fire`, 4
  `no_gun`, 5 `steered`, 6 `shot`, 7 `end` = 1984 `RAYGUN_*` TRACK_TO_LEFT,
  MOVE_DOWN, MOVE_UP, FIRED_BY_PLAYER, TRACK_ONLY, PLAYER_CONTROLLING,
  DONT_FIRE, END), `objects.zig` (kinds `key, lock, gun, panel`; `step`
  re-reads the count and removes `picked` objects; `remove`), `actors.zig`
  (`Kind.laser = 4`, `directEnumArray(..., 1, ...)` leaving the mummy's gap;
  laser `{turn fly, flickers false, hit blocked, touch strike, group
  0b100}`; **`share`**, a strict box test for sprite pairs, replaces
  `objects.overlap` in `hitting`), `room.zig` (key/lock/ray_gun preparers;
  `later` now only mummy, pattern, frankenstein), `author.zig` (keys 8×16
  and locks 12×24 on screen and in the overlap check; a lock's door must
  exist), `training.zig` (`key(color, x, y)` / `lock(color, door, x, y)`
  helpers writing `$50 + colour` / `$57 + colour`), `shapes.zig` (Ids
  appended after `pad`: `key, lock, track, gun_right_0..3, gun_left_0..3,
  panel, laser`), `art.zig` (sections "keys and locks", "ray guns"),
  `main.zig` (`feet` helper, 7 new tests). `map.zig` unchanged.
- **Memory (ch07).** Inventories live in the **castle header, as in 1984**:
  `$7813` P1 count, `$7814` P2 count, `$7815–$7834` P1 keys, `$7835–$7854`
  P2 keys (1984 `obj_Key_Infront`/`obj_Key_NotFound`). So a saved castle
  carries them and ch9's clean castle copy per game resets them; until
  then a new game keeps the old pockets *and* the taken keys (consistent).
  This is a first use of the header as runtime state (ch9 teaches it).
  Shape table 3,774 bytes (was 3,265); castle 4,496 (was 4,435).
- **Mechanics, as implemented.** *Key:* prepare skips `shape == 0`, recolours
  `.key` (`white << 4 | number`), places, adds object. `take` (in_front):
  player, fire *press*, playing, pocket not full → append number, count+1,
  record `shape = 0`, erase picture, `picked` + `disable`. *Removal:*
  `objects.step`, for a `picked` object: count−1, copy the last 16-byte slot
  over it (`m.copy`), `continue` so the moved object skips this step (1984
  `object_Execute`). *Lock:* prepare recolours `.lock`, places, adds;
  `unlock`: player, press, playing, `carrying(number)` → find `.door` with
  `number == lock.door`, set `execute` if shut; key kept. *Gun prepare:*
  clear `shot`, draw `length` track pieces 8 rows apart, draw gun at (x+4 or
  x−8, gun_y) unless `no_gun`, gun object (8×11) with `execute`; panel
  (8×24) drawn, lamps grey, panel object. *Gun run* (every step, acts on
  `clock & 3 == 0`): not steered → clear up/down, if playing: `near =
  |his top − gun_y|`, up if his top < gun_y else down. `move`: one row if
  track remains (gun_y between y and y + 8·length − 11), erase/draw picture
  `gun_*_0 + (gun_y & 3)`, box follows, lamps (up green / down red / grey,
  tinting the 2×1 cells at control_y and control_y + 16). Then steered →
  clear `steered`, need `fire`, clear it; else need `near < 5`; then not
  `shot` → `shoot`. *Shoot:* `actors.add(.laser) orelse return`, at (gun x
  ± 8, gun_y + 5), way 2/6, `setFrame(.laser)`, `shot`, `o.actor = slot`.
  *Fly* (pace 1): ±4 a step; x < 8 or ≥ 176 → `destroy`; last turn → `free`,
  `gunOf` (gun object whose `actor` is n) → `actor = none`, `shot = false`.
  *blocked* (hit): always true (no flicker → gone next step). *strike*
  (touch): machine → true, a gun other than its own → true. *Panel steer*:
  player, playing, feet within panel width; stick 0 → up, 4 → down, `0x80` →
  neither, else return; `steered`; a fire press → `fire`.
- **Training Castle rooms 9, 10, 15, 17 (ch07).** 9 Keys and Locks: bell
  removed; key green (168, 112) at the upper walkway's end; lock green door
  1 (44, 168). 10 Ray Guns: gun `{left, x 132, y 96, length 12, gun_y 152,
  control 40, 104}` (gun at 124–131, panel beside the ladder top); walking
  the floor gets him shot before x 124; standing in the doorway, shot in ≈ 3
  s. 15 Under Fire: walkways floor + `upper_right`, `ladder_right`; field
  `{button 136,160; field 88,168}`; gun `{right, x 60, y 96, length 12,
  gun_y 171, control 120, 104}` (lasers from 72 die on the field); new sign
  "THE FORCEFIELD IS / YOUR SHIELD. TAKE / IT DOWN AND THE / GUN CAN HIT
  YOU. SO / SEND THE GUN UP / FIRST, THEN RUN!". 17 Locked Away: bell
  removed; pole `{8, 100, 128}`; teleport `{128, 160, target 0, one pad
  (136, 120)}`; key light_blue (168, 112); lock light_blue door 1 (44, 168).
  The panels sit next to ladder tops on purpose: a gun steered to the top
  reaches the upper walkway's row in ≈ 7 rows (28 steps).
- **Deviations (ch07).** (1) Key/lock/panel react to a fire *press*; 1984
  reads the held button (its panel copies held fire into FIRED every turn,
  so holding fire keeps shooting; box). (2) One key picture recoloured;
  1984 draws the record's picture `$51–$57`. The record's `shape` byte is
  only "0 = taken" for us, so **no 1984-ID → `Id` table is needed for keys**
  (pays the ch3/ch11 note for keys; locks' byte is unused in 1984 too).
  (3) Lock has a white glint (code 01). (4) Laser 2 rows tall (1984 1).
  (5) The key erases its own picture in `take`; 1984 erases picked objects
  in `object_Execute`. (6) The gun is drawn in `prepare`; 1984 on its first
  execute. (7) Gun→laser link is `o.actor`, with `gunOf` searching back;
  1984 stores the gun in the laser (`field_1E`). (8) **Full sprite table:**
  ours holds fire; 1984's `$3A98` ignores the finder's carry and takes slot
  0 (box). (9) Tracking reads player 1 only (ch9 adds the nearest of two);
  1984's "y ≥ 200 counts as above" and signed-distance wrap are dropped.
  (10) Track is one symmetric piece; 1984 has left/right track pictures.
  (11) Pocket full (32) refuses the key; 1984 would overflow into P2's list.
  (12) **Sprite–sprite boxes are strict** (`share`, `>`); 1984 uses `>=`
  (`Sprite_Collision_Check`), which kills an explorer leaning on a field
  when a laser dies on its far side (field box 88–95, explorer 92, laser
  84–91: edges meet at 92). Found by the Under Fire test; told in the
  chapter and a box. Object touching keeps `overlap` (inclusive).
- **Costs at ch07 (measured).** Removal 120 cycles (`objects.step` 68 → 188
  with one removal). Gun moving a row ≈ 1,430; idle turn 4; firing turn ≈
  2,086 (+≈ 650 for the laser's unpack). Laser turn 16, last turn 52.
  Boss Battle (`runs.py` F, 4,760 frames: rooms 9 → 10, N×4 → 15, N → 17,
  ending in room 18): 4,555 calls, bucket 3 max 2,138, bucket 4 max 3,622
  (room 10, a gun row + the door opening), 20 loading pauses, 0 overruns.
  Named frames 740, 1720, 2740, 3680, 4110.
- **Tests at ch07 (41 in `zig build test`).** All room tests play through
  the stick: keys (lock refuses empty-handed; ladder, key, slot-2 swap check,
  record shape 0; back to the lock; through door 1 to room 10); locked away
  (booth fire → upstairs, key, pole, lock opens); ray guns death (floor walk,
  one laser at a time, dies before x 124); ray guns steering (gun holds still
  at the panel, steered to the top, a laser fired over his head comes and
  goes, then down and out to room 11); under fire shield (alive leaning on
  the field for 400 frames with lasers dying, button → dead); under fire
  solution (panel, gun up, button, run, out to room 16). One unit-style test
  sets gun flags directly: sprite cap (room 10, slots 1–7 filled, steered +
  fire → no shot, fire consumed; free slot 5 → laser in 5, `o.actor` 5).
- **Ladder bookkeeping (ch07).** Taught: fixed list + count instead of a
  growable array (under-the-hood box, `push`/`includes`); swap-with-last
  removal (diagram; the Last-One-In Power-Up); a whole device's state in one
  flag byte shared by castle and game (`Gun`, diagram); spawning under a
  hard cap, null = wait (diagram, the Spawn-and-Free Power-Up); explicit enum
  values (`laser = 4`) and `directEnumArray`'s gap count; strict vs inclusive
  box tests. Built on, not re-taught: ch05's free-slot reuse and the
  `State` lifecycle (`destroy` last turn → `free` → `unused`), ch06's links
  by number (`o.actor`, `objects.find`). Outline "you can shoot another
  player" is ch9's (lasers already kill any `player` actor).
- **Promises (ch07 → later).** ch8: mummy is actor kind 3 (fill the gap,
  then `directEnumArray(..., 0)` again or keep 1 for none); lasers kill
  Frankensteins (1984 laser `touch` on a Frankenstein object; `strike`
  needs the case) and monsters need laser `hit`s; mummy/frank groups vs
  `0b100`. ch9: player 2's pocket (`keys_count + 1`, `keys_held + 32`),
  keys/locks/panels for either player, guns track the nearest playing
  player, per-player `player_plate` (stale after a swap-removal; box in
  ch7), the clean castle copy resets pockets and taken keys, the header as
  scratch state. ch10: sounds (key pickup, gun fire, lock). ch11: real
  castles' gun records with `no_gun`, panels at X < 16 (the ch06 tint
  note applies to `lamps`).
- **ch07 review fixes (supersede the ch07 entries above where they
  differ).** *Room 10 re-laid so it stays winnable from door 0 after a
  death on the floor* (the gun's row is in the castle, so a gun parked on
  the floor's row in front of door 0 shot him as he came in, and nothing
  resets it until ch9): gun `{right, x 56, y 96, length 12, gun_y 171,
  control 40, 168}` (gun at 60–67, lasers from 68 run right along the
  floor); door 0 (16, 160) → keys door 1, door 1 (156, 160); floor walkway
  only, no ladder; bell (140, 168) for door 1. He arrives at x 22 behind the
  muzzle with the panel between him and the track. Walking the floor past
  the muzzle gets him shot between feet 68 and 140. Solution: panel, push
  up to the top (96), fire (the laser goes high over the room), walk right
  to the bell and out. Timings: from the top the gun reaches the floor's
  firing range in 70 rows × 8 frames ≈ 11 s; panel → bell → doorway ≈ 280
  frames ≈ 6 s ("about eleven seconds … about six"). The first-visit
  "shot in ≈ 3 s in the doorway" is gone (behind the gun it can't hit him).
  *One-way rooms, accepted:* coming back into room 10 by door 1, or room 15
  by door 1, puts him in front of the muzzle; with the gun low he's shot
  walking back. 1984 castles have one-way rooms too; the chapter's routes
  never come back that way (Writer response in the review). *Tests (42 in
  `zig build test`):* death test is "past the muzzle" (one laser, dies at
  68 < feet < 140); the steering test is `inRoom` + a new helper
  `escapeRayGuns` (walk to the panel, gun holds still 40 frames, up to the
  top, fire, laser comes and goes, walk to the bell, out to room 11); new
  regression test "shot once, the room can still be won from its door"
  (die on the floor, back at room 0, N×10 through the stick, `gun_y > 166`
  on arrival, then `escapeRayGuns`). *Listings (67):* C19 adds
  `escapeRayGuns` (without the firing lines, which D15 adds). The lasers
  section is reordered so every intermediate build compiles except the
  one the chapter means to fail: D1–D4 (actors comment, `guns` import,
  laser Id, picture), D5–D9 (AIM, `run`, `shoot`, `fly`/`gunOf`,
  `blocked`/`strike`), then D10 `Kind`, D11 the entry, "Build now" and the
  error, D12 the gap of 1, then tests D13–D17. `rebuild.py` keeps a copy
  of the project right after D11 (`SNAP` in `listings.py`); `errs.py`
  builds that copy as-is and requires exactly one error, so the quoted
  `directEnumArray` message comes from the reader's project at that
  point. *Runs:* `ROOM10` rewritten; Boss F is 4,745 frames (room 10 from
  1,326, N×4 from 2,498, room 15 from 2,578, N at 3,978, room 17 from
  4,013): 4,541 calls, max 236,486, buckets 326 / 235,206 / 1,274 / 2,002
  / 2,204 (bucket 4 max in room 15, a gun turn that fires at the field), 20
  loading pauses, 0 overruns; named frames 740, 1720, 2740, 3680, 4110
  (re-checked on the new run), last frame room 18. *Images:* `07-shot.png`
  = D 312 (the laser touching him past the muzzle), `07-panel.png` = C 500
  (at the floor panel, gun climbing; now used after "Run it and play").
  *Diagrams:* `ch07-swap` rests on the result (animation-delay −3.6 s:
  lock in slot 2, count 3); `ch07-gun-byte` bit 5 reads `steered`.
  *Prose:* "overlaps by four fat pixels" in the box story; a lost panel
  press when the table is full (box, `shoot` comment, Power-Up); plainer
  slot-zero and plain-words rewrites; "could die the same way"; removal
  "adds 120 cycles to that step"; castle size without the list; "two
  locks, two keys and two guns"; `later` keeps the monsters and the title
  pattern; wheel marks not white; "Two of them, plus `end`"; Bonus Stage
  "Two guns, two panels"; stale-plate box without the ch9 clause; escape
  caption; Boss invitation no longer suggests standing in the doorway.
  Prose ≈ 5,220 words.
- **Chapter 8 file, title, images.** `site/chapters/08-monster-mash.md`,
  `title: "Monster Mash"`, generated from `tools/ch08/ch08.tmpl.md` by
  `expand.py` (84 listings; 3 deletions told in prose: `gunOf`, the
  explorer's `underfoot` and `tread`; prose ≈ 5,530 words by `wc.py`).
  Screenshots (768×544, nearest-neighbour, made by `tools/ch08/shots.py`
  from the `rebuild.py` stage runs): `08-storm.png` (Mission Briefing; C
  490, the switched-on machine's bolt on the mummy under the explorer),
  `08-rise.png` (B 420, ankh white, mummy climbing out of the opened
  tomb), `08-frank.png` (D 560, Frank stepping out of his alcove),
  `08-trap.png` (E 640, Frank on the ladder above the open trapdoor),
  `08-ride.png` (E 1620, Frank walking on the spot at the reversed belt's
  end). Diagrams: `ch08-dice` (animated highlight down the four rows of
  the first roll: `$57 $C6` → rotr → `$E3`; `$57^$E3 = $B4`; `$C6^$B4 =
  $72`), `ch08-choose` (static; room 13's junction: down 64 rows beats
  left 28 fat pixels; the corridor rule table), `ch08-ride` (animated;
  belt with him +3 a turn, against him on the spot). Quoted error: `the
  shape table doesn't fit in its region` (`errs.py` case `full`, the
  snapshot right after listing B3, the mummy's art).
- **Source layout (ch08).** New files `dice.zig` (`start`, `roll`, 2
  tests), `mummy.zig` (`prepare`, `open`, `release`, `glow`, `wake`,
  `walk`, `hit`, `touch`; comptime checks: the rise table drops 8 rows,
  walking pictures consecutive), `frankenstein.zig` (`prepare`, `turn`,
  `wakes`, `choose`, `bit`, `move`, `hit`, `touch`; comptime check on
  picture order). Changed: `map.zig` (region `dice` `$020F–$0210`
  between `engine` and `text`; **star map `$5F00`, shape table
  `$6000–$77FF`** (6,144 bytes), forced by the mummy's art overflowing
  4,096; the program-image reservation shrinks to `$5EFF`), `castle.zig`
  (`Mummy{state, ankh_x, ankh_y, tomb_x, tomb_y, x, y}` with
  `mummy_tomb/out/dead` = 1/2/3; `Frankenstein{state: Frank, x, y,
  frank_x, frank_y, frame, way}`; `Frank` packed: bit 0 `left`, 1
  `awake`, 2 `dead`, 7 `end`; Pattern's comment points at ch11),
  `objects.zig` (kinds `ankh {glow, release}`, `alcove {null, null}`;
  slot bytes `plate`, `last_plate` replace two of the three spares, set
  to `none` in `add`; **`owner(kind, n)`**, the object whose `actor ==
  n`, generalising ch07's `gunOf`), `trapdoors.zig` (`underfoot` moved
  here; `Under {nothing, hole, plate}`, `under(n, object)`,
  `tread(plate*, last*)` shared by the explorer and monsters),
  `player.zig` (own `tread`/`underfoot` removed; `touch` switches on
  `under`), `actors.zig` (`Kind {player, lightning, forcefield, mummy,
  laser, frankenstein}` = 1984 0–5; `directEnumArray(..., 0, ...)`;
  mummy `{walk, flickers, hit, touch, group 0b010}`, frankenstein
  `{turn, flickers, hit, touch, group 0}`), `lightning.zig` (`crackle`
  rolls the dice), `guns.zig` (`fly` uses `owner`; `strike` stops on
  `.alcove`), `conveyors.zig` (`carry` takes mummies and Frankensteins:
  2 px a turn, any frame), `room.zig` (mummy/frankenstein preparers;
  `later` is the pattern only, "Chapter 11"), `author.zig` (tomb 20×24,
  ankh 8×16, alcove at x−4 16×24 on screen and in the overlap check),
  `shapes.zig` (Ids after `laser`: `brick, tomb_open, ankh,
  mummy_rise_0..2, mummy_right_0..2, mummy_left_0..2, alcove_right,
  alcove_left, frank_asleep, frank_right_0..2, frank_left_0..2,
  frank_climb_0..3, frank_slide`), `art.zig` (sections "the mummy",
  "Frankenstein's monster"), `training.zig` (imports `shapes`; rooms 11,
  12, 13, 14, 16), `main.zig` (boot calls `dice.start`; search test
  allows 3 cells per alcove; helpers `monster`, `distance`, `back`,
  `escapeMummy`, `stormOut`, `trapFrank`, `rideOut`).
- **Mechanics, as implemented (ch08).** *Dice* (1984 `$5ED5`): turned =
  low byte of rotr16(high:low, 1); high ^= turned; low = (low & $FE) ^
  high; return low. Seeds `$C6 $57` at boot only (never reset per game).
  First rolls 72 FF 8C B8 D0 D0 B8 8C; the seed pair has a tail of 1, then
  a cycle of 32,767; low two bits ≈ uniform. *Bolt:* pace = 1 + (roll &
  3); picture = roll & 3, the next one if it equals the current (1984).
  *Mummy prepare:* 5×3 bricks (4×8 each) from (tomb_x, tomb_y); not in
  the tomb → middle three of the middle row unplaced, `tomb_open` drawn;
  ankh drawn + object; state out → actor at record (x, y), climb done,
  pace 2. *release* (ankh in_front): player, playing, feet − ankh.x < 8,
  state tomb → out, record x/y = tomb + (6, 3), ankh `execute` with step
  8, open, actor at tomb + (6, 3 − 8), pace 4, `mummy_rise_0`. *glow:*
  every 4th step, tint 2×2 white/white or orange/yellow, 8 times.
  *walk:* destroy → free, clear `o.actor`; tread plates; rise entries
  (dy 0,0,0,2,2,2,2; pictures rise 0,0,1,1,2,2,2) at pace 4 then pace 2;
  then (player playing) toward player 1's x unless |dx| < 2, needing the
  grid's right/left bit at the feet, never changing y, walking frames
  cycle, record x/y updated. *hit:* lightning or laser → state dead,
  flicker; anything else nothing. *touch:* open trapdoor → dead; plate →
  `o.plate`. *Frankenstein prepare:* grid patch at row (y+24)/8: facing
  right cells col..col+2 lose `left`; facing left col−1..col+1 lose
  `right` (1984); alcove picture at (x−4, y) + object; not dead → actor:
  awake → record (frank_x, frank_y, way, frame); asleep → (x, y+3),
  `frank_asleep`, way still. Pace 2. *turn:* destroy handling; asleep →
  `wakes` (playing, |his top − Frank's top| < 4, in front: left-facing
  him.x ≤ x, right-facing him.x > x) → awake, way still; tread; `choose`;
  `move`; record x/y/frame/way. *choose:* no ways → still; one → it; two
  opposite and the current way open → keep; else far[up,right,down,left]
  from player 1 (dx ≥ 0 → right, dy < 0 → up; others 0xFF) and pick the
  farthest open, each retry only strictly shorter distances, ties to the
  lower index (1984's quirk kept). *move:* along: y −= feet_y % 8, x ±1,
  walk frames cycle; up/down: x = x − feet_x % 4 + 1; rungs (feet cell or
  cell below has `up`) → y ∓ 2, climb frame `climb_0 + ((y>>1)&3)`; else
  slide y += 2, `frank_slide`. *hit:* awake only; lightning or laser →
  dead. *touch:* open trapdoor → dead (even asleep); plate → `o.plate`.
  *Belts:* `carry` runs on the actor's turn (touching), monsters +2 any
  frame; against him, he walks on the spot at the belt's end (feet 54–57
  in room 14's test). *Laser:* alcove object stops it (`strike`);
  an awake Frank or a mummy dies by its `hit`.
- **Training Castle rooms 11–14, 16 (ch08).** Design rule: every monster
  room's door 0 is upstairs, unreachable by its monster (poles only go
  down; mummies never climb), so a death never leaves the monster at the
  door until ch9's clean castle. 11 The Mummy: doors (16, 96) → ray_guns
  door 1 and (156, 160) → frankenstein; walkways floor + {30 @ 16,128};
  pole {8 @ 128,128}; bell (140, 168); mummy {tomb, ankh 48,112, tomb
  28,168}; sign "A MUMMY SLEEPS IN / HIS TOMB. PASS THE / ANKH AND HE
  WAKES. / HE KEEPS TO HIS / FLOOR: LEAD HIM ONE / WAY, RUN THE OTHER."
  12 Frankenstein: doors (16, 96), (156, 160); floor + `upper_left`;
  pole {8 @ 88,128}; bell 140; frank {right, 24, 168}. 13 A Trap for
  Frank: doors (16, 96), (156, 96) → frank_ride; floor, `upper_left`,
  `upper_right`; pole {8 @ 80,128}; ladder {9 @ 124,128}; bell (140,
  104); trapdoor {shut, 120, 192, **switch 96**, 184}; frank awake at
  (100, 104), frank (100, 107), frame `frank_right_0`, way still. *The
  switch moved from 64 to 96 during testing:* with the explorer at feet
  ≈ 66 Frank dithered at the ladder top for ever (down 64 vs left ≈ 59
  at the walkway cell; one step down, still in that cell, down 58 < left
  59 → left, back up, repeat). Told in the chapter. 14 Frank's Ride:
  doors (16, 96), (156, 160) → under_fire; floor + {25 @ 16,128}; pole
  {8 @ 104,128}; bell 140; conveyor {on, right, 56, 184, control 116,
  160}; frank {right, 24, 168}. 16 Mummy in a Storm: doors (156, 96) →
  under_fire door 1, (16, 160) → locked_away; floor + `upper_right`;
  ladder {9 @ 100,128}; bell (44, 168); lightning: machine 0 {off, 124,
  136, length 3}, machine 1 {on, 64, 112, length 6}, switch {120, 104,
  machines 0 and 8}; mummy {out, ankh 104,176, tomb 72,168, at 78,171}.
- **Deviations (ch08).** (1) Mummy rise: dy is 1984's, dx is 0 (1984
  slides him sideways out of its own tomb shape); tomb, rise and walk
  pictures and the out position (tomb + (6, 3)) are ours (box). (2) Ankh
  flash colours ours (white / orange-yellow). (3) Alcove picture is ours,
  drawn at x−4; 1984's extra shape `$1C` under it is not drawn (box).
  (4) Frank's vertical picture uses our explorer's rungs rule (feet cell
  **or cell below** has up), a conscious choice paying the ch04 note;
  1984 copies its explorer's feet-cell-only test (box). (5) An awake
  Frank's record `frame` byte holds **our shape Id**, not 1984's sprite
  frame; ch11 needs a translation when real castles have awake Franks
  (box). (6) Frank–Frank avoidance masks (1984 blocks ways another Frank
  occupies) skipped; no room has two on one floor (box; ch11). (7)
  Monsters chase player 1 only; 1984 the nearest playing explorer (ch9;
  box). (8) The dice are never re-seeded; same as
  1984 as far as the disassembly shows.
- **Costs at ch08.** Roll 24 cycles (2 per bolt turn). Mummy turn ≈ 90,
  Frankenstein ≈ 136 in a corridor, +40 per extra try at a junction; a
  picture change adds ≈ 650 (sprite unpack). `owner` 12 per object
  searched. Boss Battle (`runs.py` F, 4,060 frames: room 11 from 215, 12
  by door at 1,021, 13 at 1,535, 14 at 2,334, N at 3,515 in Under Fire,
  16 from 3,548, ending in room 16's doorway to Locked Away): 3,881 calls,
  bucket maxima 348 / 241,532 (room draws) / 1,278 / 4,248 (actors, room
  11) / 2,432, 17 loading pauses, 0 overruns. Named frames 500, 1380,
  2040, 2950, 3780. Shape table 5,106 bytes (was 3,774); castle 4,652
  (was 4,496).
- **Tests at ch08 (56 in `zig build test`).** Dice: 1984's first eight
  rolls; cycle 32,767 after the first roll with low-two-bit counts in
  8,100–8,300. All room tests play through the stick (`inRoom` pokes
  only the room number; `back` presses N): mummy (sleeps 200 frames,
  wakes past the ankh, under you on the floor, record x matches, escape
  to room 12); mummy revisit after a death at the pole (still out, by
  the pole, escape works); storm (lever under the mummy kills him, count
  0, state 3, down and out to room 17) and its revisit after a death on
  the ladder; Frank (asleep 200 frames, awake on landing, run out to room
  13 with him on his way) and revisit (wait upstairs until he passes
  under the pole going left, out); Frank vs a stray bolt (asleep immune,
  awake dies; a `hit` unit test that places a bolt actor directly); trap
  (switch, he comes down into the hole and dies, switch shut again, up
  his ladder, out to room 14); trap without the switch (he reaches the
  floor alive); trap revisit (caught on the floor, back, lead him up his
  ladder, the trap works again); ride (2 turns on the belt = 6 px; two
  presses → running left, he holds at feet 54–57 for 100 checks; out to
  room 15) and its revisit (he's past the belt on your side; wait until
  he's held at the belt's near end walking left; slide down; same
  escape). Runs are recorded from these helpers (scratch recorder:
  the test helpers driven from a headless-like start, printing presses
  with headless frame numbers) and checked by eye.
- **Ladder bookkeeping (ch08).** Taught: XOR as "flip where the other
  has 1s" (ch2's `^` promise paid), bit rotation (`std.math.rotr`),
  pseudo-random numbers with a seed, determinism for tests and replays
  (under-the-hood box; ch2's "making numbers look random" paid, with the
  star LCG as the multiply-add contrast), cycle length and fairness of
  the low bits (tests), following a link backwards by search (`owner`;
  the Follow-It-Back Power-Up), sharing per-actor state through pointers
  (`tread`), grid patching as one-way doors, a chaser that only thinks at
  junctions (diagram). Built on: ch05 groups and `hit`/`touch`, ch06
  trapdoors/belts/lightning, ch07 `directEnumArray` gap (paid: back to
  0), `packed struct(u8)` flag bytes. ch3's `later` preparers: only the
  pattern remains (ch11).
- **Promises (ch08 → later).** ch9 (corrected by the ch08 review): the
  mummy chases player 1 while P1 is playing, else player 2 (1984 `$3846`,
  no distance); Frankenstein takes each direction's distance as the
  smaller of the two playing explorers' (`$3C15`) and wakes for either;
  ankhs and panels serve either explorer; ankh/alcove plate bytes are
  per-monster already, the explorer's `player_plate` still needs a P2
  copy; the clean castle copy resets mummies (state, x/y), Frankenstein
  records and belts; second explorer as a target for `wakes`/`choose`.
  ch10: sounds (ankh, tomb opening, Frank's steps, deaths). ch11: real
  castles' mummy/Frankenstein records (1984 frame numbers in awake Franks'
  `frame` byte → our Ids); Frank–Frank avoidance masks; tombs and alcoves
  at X < 16 (the ch06 tint note applies to `glow`); the pattern preparer.
- **ch08 review fixes (supersede the ch08 entries above where they
  differ).** *Must-fix:* "A 6510" → "The Comet's CPU" (fiction). *Prose:*
  both monsters walk at **half the explorer's speed** (pace 2, 1 px; the
  mummy line said "as fast as you"); Frankenstein is "no faster than the
  mummy"; the nearest-explorer box now says 1984's mummy chases P1 then
  P2 and Frankenstein uses the nearer explorer per direction (and the ch9
  promise above is corrected); the grid claim says forcefields already
  change the grid ("as a forcefield's wall does, but only one way"); the
  program-image sentence no longer says our code isn't in the Comet's
  memory ("the room we keep for the game's code … nearly 22 KB"); the
  dice are "a quarter each" but **consecutive rolls are linked** (the
  second's bit 0 follows from the first; 8 of 16 pairs), said in the
  prose and the Power-Up ("fine for small choices like a bolt's
  flicker"); Bonus "Loaded dice" names `first_low = 0x01, first_high =
  0x00` (which falls to the stuck (0, 0) pair) and asks why almost every
  other pair gives 32,767; tie box: "rare, because the two numbers have
  to match exactly"; rungs box drops "we said then"; "three things";
  "carry on", "like the ankh", "rule is short"; frame 500 wording;
  D25's label names its span. *Costs (measured by the reviewer):* roll
  40 cycles, mummy turn ≈ 120 (+≈ 650 picture), Frankenstein ≈ 200 in a
  corridor; a Frankenstein's position is four record bytes. *Sizes logged
  (deviation, ch11 risk):* our ankh is 8×16, 1984's `$44` is 8×23 (a real
  castle's `ankh_y` would float ours 7 rows high and shorten its
  in_front box); our alcove is 16×24 at (x−4, y), above the walkway,
  1984's `$90/$91` is 8×32 at (x, y) standing on it; 1984 erases shape
  `$92` (8×6) at (x, y+24) and, for a right-facing alcove only, redraws
  walkway piece `$1C` at (x+4, y+24). The box says this; ch11 must place
  both pictures (and the alcove object box / author overlap check) for
  real castles. *Room 13:* its upper-left walkway is now its own
  `{18 @ 16,128}` (16–87), leaving a visible gap before Frank's walkway
  (96–175) instead of an invisible end in a seemingly continuous floor;
  the revisit test walks to the walkway's end (feet 84). *Room 12 sign:*
  "… THEN HE PACES / IT. HE'S SLOW: RUN / FOR THE BELL!" (the old "go
  down behind him" fitted only a revisit). *Art:* the alcove's inside is
  filled with code 1 (dark grey), so it no longer reads as a doorway.
  Runs unchanged (same frames work); screenshots re-shot from the new
  stage runs (`08-frank`, `08-trap`, `08-ride` changed). Not done: renaming
  the old search test (Writer response in the review). Prose ≈ 5,540
  words.
- **Chapter 9 file, title, images.** `site/chapters/09-the-great-escape.md`,
  `title: "The Great Escape"`, generated from `tools/ch09/ch09.tmpl.md` by
  `expand.py` (116 listings; told in prose instead: deleting the old
  `player` region, its `regions` entry, `newGame`, three `map` imports,
  the final room's "YOU ESCAPED!" line; two `| Replace | With |` tables,
  the walker test's `room` → `bytes` and the tests' `map.player_*` →
  `castle.*`; prose ≈ 5,460 words by `wc.py`). Stage runs A (two in the
  Gatehouse), B (Two's Company for two), C (two through Gatehouse and
  Gallery, the map), D (N to the Way Out, two escapes, GAME OVER), E
  (Boss: room 18 for two, P1 alone after, the map, the Way Out, both
  escapes, GAME OVER, title; 3,500 frames). Screenshots (768×544, by
  `tools/ch09/shots.py`): `09-escape` (Mission Briefing; D 1150, P1
  cheering under the built final room), `09-two` (A 170), `09-company`
  (B 620, P1 holding the button, P2 past the field), `09-map` (C 800,
  three rooms, one white arrow), `09-over` (D 2000, GAME OVER for both).
  Diagrams: `ch09-header` (static list, file bytes vs game bytes),
  `ch09-union` (animated: the three overlays of `$0200–$0206` lit in
  turn), `ch09-bcd` (animated rows: `$09`+1 = `$0A`, +6 = `$10`; `$59` →
  `$60` → `$00` carry). Quoted errors (`errs.py`): `shadow` (at-A4:
  "local constant shadows declaration of 'room'", castle.room vs the
  walker test's local) and `union` (at-D21: "m.view(game.Between):
  game.Between.over is smaller than the union; every field must be the
  same size", `Over` before its `unused: [6]u8`).
- **Source layout (ch09).** New files `game.zig` (`Between` extern
  union {chart, escape, over} + size check, `between`, `Over{wait,
  unused[6]}`, `chosen` (stick 2 wins), `start` (copy staging → castle,
  room/door from start, `in_game`, `two`), `next`, `Then {map, escape,
  over}`, `after`, `escaper`, `drawOver`, `over` (210 frames)),
  `clock.zig` (`Time{frames, seconds, minutes, hours}` at header `$55`
  + 4p, `tick`, `advance`, `up(digits, limit)`, `print`; 2 tests),
  `chart.zig` (`Chart{blink[2], lit[2], ready[2], steady}`, `draw`,
  `sketch`, `gap`, `label`, `wait`), `escape.zig` (`Escape{who, shown,
  spot, wait, walk, leg, left}`, `draw`, `run`, `piece`, `step`,
  `picture`). Changed: `map.zig` (`between $0200–$0206` replaces
  `player`; `players $0211–$021A`; `staging $9800–$B7FF`), `castle.zig`
  (header names, below; `visited = $80` in a colour byte), `player.zig`
  (`Number = u1`, `Player extern struct{actor, last_stick, plate,
  last_plate, mask}` ×2, `ports`, `coats {white, yellow}`, `records`,
  `record`, `number`, `here`, `arrive`, `coat`, `picture`, `setStatus`,
  `walking`, `nearest`, `holding`, `jostle`; `newGame`/`nextRoom` gone),
  `room.zig` (`build` split out of `draw`, `prepare` pub, `flip` sets
  both players), `text.zig` (`shout`, style | 2), `shapes.zig`/`art.zig`
  (`map_floor/top/bottom/left/right`, `arrow_down/up/right/left`,
  `explorer_cheer_0/1`), the handlers (`playing(m, who)`; locks pockets,
  conveyor per-player bits, forcefield `holding`, guns `nearest`, mummy
  P1-then-P2, Frankenstein both), `title.zig` ("STICK 2 FOR TWO"),
  `training.zig` (room 18 rebuilt: floor field at 88 with its button up
  the ladder; final room loses "YOU ESCAPED!"), `main.zig` (modes
  `draw_map, map, draw_escape, escape, draw_over, over`; boot loads to
  staging; `clock.tick` each room frame).
- **Memory (ch09): the header as game state, 1984's layout.** `$7803/4`
  start room, `$7805/6` start door, `$7807/8` lives (decremented in play,
  as 1984), `$7809/A` room, `$780B/C` door, `$780D/E` status (our
  `player.Status` numbering), `$780F/10` in game, `$7811` last, `$7812`
  two, `$7813/4` key counts, `$7815+32p` pockets, `$7855+4p` time,
  `$785D/E` escaped, `$785F` final room. A new game copies 4,644 bytes
  from `$9800` (37,244 cycles, loading pause), which also zeroes all of
  this. Bit 7 of a directory colour byte = visited (set when the map is
  drawn for that room).
- **Mechanics, as implemented (ch09).** *Next room* (1984 `Game()`):
  both in game and in one room → it; two rooms → player `last ^ 1`; one
  in game → his. `roomOver` scans P2 then P1, `last` = the last one
  still playing; the room goes on while anyone present is playing or in
  a doorway. *After a room:* dead → lives −1, 0 → `in_game = 0`
  (→ GAME OVER), else start room/door; through an `exit` door →
  `escaped` → escape screens, each escaper `in_game = 0` at the end;
  then GAME OVER (two-player games say "FOR PLAYER n" for those out),
  then `next`: map for anyone left, else title. *Map:* arrow at (room x +
  door map_x + dx[side], room y + map_y + dy[side]), dx {−1, +2, −1, −5},
  dy {−10, −2, +6, −2}; blink P1 12, P2 30 frames; both at one door →
  steady white; ONE UP/TWO UP coloured by lives (1 pink, 2 yellow, 3+
  light green) with the time below; fire (fresh press) from everyone
  here. *Escape:* "PLAYER n ESCAPES" (16,0 light green, double height),
  "TIME:" (40,24 yellow), time at 88; a final-room record (or one image
  place) every 10 frames; then 1984's legs, a step every other frame:
  {128 right, 25 cheer, 45 right}, or when `dice & 0x0E == 0` {172
  right, 44 left, 25 cheer, 45 right}. *Players:* jostle (1984 `$3534`):
  other climbing/sliding or same y → nothing; other below → my mask
  `~down`, above → `~up`, applied to my next step only. Guns: nearest
  |dy|, P2 checked first, tie → P2. Mummy: P1 while playing, else P2.
  Frankenstein: wakes for either; per-direction distance = min of both.
  Forcefield button re-arms every step fire is held (1984). Conveyor:
  pressed bits 2/3, held bits 4/5, works on pressed & ~held.
- **Deviations (ch09).** Timer counts frames (50 = 1 s) in software;
  1984 runs a chip's time-of-day clock (BCD tenths) per room and saves
  it at `$7855` (seconds/minutes/hours bytes are the same BCD). Status
  numbers ours. Map: fire needs a fresh press, both sticks polled every
  frame (1984 waits for release); arrows in coat colours until shared
  (1984 white); P2 coat yellow, P1 white (1984 P1 yellow, P2 orange).
  Escape: words drawn before the reveal, reveal 10 frames a piece, cheer
  2 frames (1984 4), walk on our floor (y = floor_top − 21). Door map
  bytes come from our builder and are still unverified against a real
  castle (no `extracted/` here): ch11. Times aren't shown in rooms (as
  1984).
- **Costs at ch09 (measured).** Castle copy 37,244; first map draw
  111,890 (one room); map frame 136; `clock.print` 5,472; `tick` 72 with
  two explorers; `up` 14; escape screen draw 118,902; busiest escape
  frame (a piece) 14,238; GAME OVER draw 98,708. Draws are loading
  pauses; no overruns in any stage run.
- **Tests at ch09 (67 in `zig build test`).** Clock (BCD carry; an hour
  a minute a second, printed); title → map → room; map waits for both;
  N/P on the map; X → GAME OVER → title; search test includes the final
  room; **the whole Training Castle through the stick, for one and for
  two** (every room in at door 0, out by door 1, escape, GAME OVER);
  Two's Company coop; ladder jostle; nearer gun / mummy P1; Frankenstein
  wakes for P2; P2 out of lives while P1 plays on; both escape. Test
  helpers: `hold` mirrors P2 in two-player games, `hold2`, `onward`,
  `inRoom2`, `second`, `ringAndGo`, `teleport`, `arrived`,
  `twosCompany`; `trapFrank` lets P2 tread the switch's second time.
- **Ladder bookkeeping (ch09).** Taught: one region two jobs (the header
  over time; `extern union` for the screens between rooms, and the
  machine's same-size rule for viewed unions); BCD (nibbles, +1/+6,
  printing with shift and mask, no divide). `u1` as a player number.
- **Promises (ch09 → later).** ch10: sounds (map blink, escape, GAME
  OVER, bells). ch11: real castles' door map bytes checked against the
  map; saving a castle saves the game (header carries it all); disk load
  to `$9800` (staging); high scores from `time`; title/menu choosing
  one or two players (ours: which stick fires).
- **ch09 review fixes (supersede the ch09 entries above where they
  differ).** *Code:* GAME OVER's "FOR PLAYER n" lines are in
  `player.coat(p)` (white, yellow), not 1984's yellow/orange (logged in
  the "What's ours" box); `castle.zig`'s header comment names
  `final_room` as file-set; the two-player whole-castle test also asserts
  player 2 escaped, out of the game, 3 lives. *Prose:* Game Over bullet is
  "the one up the ladder climbs down through the other's head" (two
  explorers both on a ladder do pass, as 1984 `$353F`); jostle text in
  "he", and "touching an explorer who is on a ladder or pole himself
  changes nothing"; "Whose turn" box says apart they take strict turns;
  the clock box no longer compares hardware ("1984 timed each room in
  tenths … same four BCD bytes at `$55`"); both replace tables have the
  find-and-replace lead-in and the compile-error safety net, and the
  `, m.ram[map.room_number])` → `castle.room` change (17 test checks) is
  told separately as a change of meaning, with the reason and a search to
  confirm (listings: A51 = three `player_*` rows, A51r = the room checks);
  "big idea under the hood" replaces "ladder rung"; "harmless" without
  "for now"; copy 37,152 for the bytes, 37,244 in all; header state 86
  bytes; GAME OVER 98,708 / 106,856 with both lines; busiest escape frame
  ≈ 14,400; Boss: N keys land in rooms after fire on the map; `inRoom`'s
  8 frames keep the engine's step phase; hours' limit `$A0`; map cells'
  counts (not sizes) in the entry; Mission Briefing "and then you cheer";
  the escape-order sentence no longer invents a dead escaper; map caption
  says where the steady arrow's tip is (on the neighbour's wall, 1984's
  nudge); "What's ours" box (was "… in the escape") adds 1984's cheer
  changing every step and rewords the door map bytes; labels A30, A33,
  C18 say what they replace; union diagram cells no longer split
  "steady"; JS bridge "one `ArrayBuffer` read through different typed
  views". Screenshot `09-over.png` re-shot (new colours).
  *Deviation for ch11 (1984 turn-order quirk):* 1984's `roomMain`
  (`$1594`) counts an absent player's header status if it is 0 (playing),
  true only before he has ever been added; so in a two-player game whose
  **start rooms differ**, player 2 keeps playing until he reaches player
  1's room or leaves the game. Ours skips absent players (`actor ==
  none`) and alternates strictly. The Training Castle starts both in the
  Gatehouse, so it never shows; ch11's real castles may need a decision.
- **The SOUND chip's speaker (ch10, machine).** `machine/src/sound.zig`
  is a forgiving software synth: `base = $D400`, 25 registers, voice
  offsets `freq_lo … sustain_release`, `volume = $18`; control bits
  `gate, sync, ring, testbit, triangle, sawtooth, pulse, noise`. Per
  voice: a phase accumulator (register × 1 MHz / 2^24 Hz, so register =
  Hz × 16.777216; 440 Hz = 7,382 = `$1CD6`; max ≈ 3,906 Hz); triangle,
  sawtooth, pulse (12-bit width), noise (23-bit LFSR clocked 16× a lap);
  several waveform bits are averaged (not ANDed); sync and ring use the
  voice before (2 → 0 → 1); test bit holds silent. ADSR is straight ramps
  from `attack_ms`/`fall_ms` (fall times are full scale → 0); gate edges
  are seen once per `render` call. No filter (`$D415–$D417` are plain
  RAM), `$D418` low nibble is volume; mix = sum / 3 × volume / 15, then
  a one-pole 12 kHz low-pass and a ≈30 Hz DC blocker (ch10 review; the
  first version's smoother was inert). **Latching:** `Machine.runFrame` copies
  `$D400–$D418` into `sound_regs` *before* calling `frame`, i.e. the
  previous frame's end state, and `Machine.listen(out, rate)` renders from
  it; a long frame's extra slots replay the same registers (the shells
  call `listen` once per slot). Card §1 step 4 and §11 ("When the chip
  listens": once a frame when `frame` returns; a gate must stay off a
  frame to be seen). Machine test "the SOUND chip plays what the last
  frame left, all through this one"; `sound.zig` has 4 tests (silence and
  volume 0, 440 Hz → 438–442 zero crossings, attack/release timing, noise
  and no-waveform). **Headless:** `--wav FILE` (44,100 Hz mono 16-bit),
  summary gains a last line `sound: FILE, S.ss seconds, loudest N%` only
  with `--wav` (all earlier stage outputs unchanged). **Wasm:**
  `comet_listen(rate, count)` returns a pointer to ≤4,096 f32 samples
  (was 1,000 before the ch10 review).
  **Browser:** `shell.js` `makeSpeaker` (AudioContext; schedules one
  AudioBufferSource per slot, `rate/50` samples with a fractional carry,
  0.06 s lead, ≤0.25 s ahead); `startComet(canvas, {wasm, status,
  audio})`; the canvas wakes the speaker on pointerdown/keydown; pause,
  resume and crash sleep/wake it (only a context the shell made itself is
  suspended). The tutorial page's Power-on click makes one shared
  `window.cometAudio` and resumes it *before* the `await import` (the
  user-gesture rule), passing it as `audio`. Standalone `web/index.html`
  says "click the screen to play (and to hear it)". `site/build.py` copies
  `chapters/images/*.mp3` too; `template.html` styles `.prose audio`.
  Every checkpoint ch01–ch10 passes `check-all.sh` with this machine.
- **Chapter 10 file, title, images.** `site/chapters/10-things-that-go-bump.md`,
  `title: "Things That Go Bump"`, generated from `tools/ch10/ch10.tmpl.md`
  by `expand.py` (58 listings; told in prose instead: the same import
  lines in 12 more files, as a table after listing E1). Stage runs (all
  with `--wav creep.wav`, kept as `rb-<tag>.wav`): A and B (the title,
  150 frames, the experiment's held A4), C (the waltz, 1,200 frames), D
  (fire at 300 and 330: the map's chime), E (Boss: ch09's BOSS shifted by
  280 frames, 3,780 frames). `tools/ch10/shots.py` makes `10-waltz.png`
  (log-frequency spectrogram, A1–A6, of the waltz's first 4 bars from
  rb-C; 8,192-point FFT per frame, top 48 dB) and MP3 clips (`10-note`
  A 0–3 s, `10-waltz` C 0–24 s, `10-chime` D 5–8 s, `10-boss` E all,
  ≈ 445 KB) shown with `<audio controls preload="none">`. Diagrams:
  `ch10-envelope` (ADSR with gate trace), `ch10-command` (command byte
  bits; the forcefield's 16 bytes decoded, byte 9 highlighted),
  `ch10-weave` (two parts at unit 2 → one stream, the composer test),
  `ch10-interrupt` (animated playhead: 7 slots, driver first, a 3-slot
  loading pause, the chip holding its registers), `ch10-beat` (animated:
  tempo `$B0` over 8 frames). Quoted error (`errs.py`): `b7` (at-A5,
  `note_count = 96`: "note 95 needs a frequency register of 66288, and
  the register has 16 bits"). Prose ≈ 5,550 words by `wc.py`.
- **Source layout (ch10).** New `tunes.zig`: `note_count = 95` (C0–A#7),
  `frequencies` (comptime `@exp2`, compileError past 16 bits), `note(name)`
  (comptime; `#`/`b`; octave 0–7), composer (`Instrument{wave, width =
  0x800, attack, decay, sustain = 15, release}`, `Part{sound, notes}`,
  `Tune{tempo, unit, parts}`, `gap = 1`, `events`, `wait` in ≤255 pieces,
  `compose` = `comptime weave`), `Song {title, escape, over}`, `music`
  (frequency table then songs, fit check), `frequency(n)`, `placed`,
  `Effect` (1984's 13, in 1984's order), `effects`, `effect_at` (checks
  byte 8 is a voice-0 note-on), `pitch = 9`, `effect_tempo = $EA`,
  `sounds`, six instruments, `songs`. New `sound.zig`: `Op` (1984 numbers:
  note_on, note_off, wait, long_wait, instrument, filter, transpose,
  volume, tempo, end ≥ 9), `lengths {2,1,2,2,6,5,2,2,2}`, `command(op,
  voice) = op<<2 | voice`, `tune = $FE`, `nothing = $FF`, `start`, `step`,
  `run`, `silence`, `begin`, `music`, `effect`, `effectAt`, `stop`.
  `main.zig`: `bucket_sound = 5`; `frame` steps the driver first, in
  bucket 5; the title starts `.title`, choosing a game calls `stop`.
  Call sites: listed in "as implemented" below.
- **Memory (ch10).** `sound` `$021B–$0225` (at+0 2 bytes, loop+2 2,
  wait+4, tempo+5, beat+6, playing+7, transpose+8 3 bytes); `effects`
  `$0380–$04FF` (RAM so callers patch byte 9; 267 bytes used); `music`
  `$5A00–$5EFF` (1,029 used: 190 table, title 482, escape 263, over 94);
  program image now ends `$59FF`; hardware row `sound_chip` =
  `$D400–$D418`.
- **Mechanics, as implemented (ch10).** Tick = carry of `beat +%= tempo`
  each frame (50 × tempo / 256 Hz): waltz `$B0`, unit 8 (768 ticks ≈
  22.3 s, loops), escape `$E0`, unit 4 (256 ticks, 5.85 s), over `$80`,
  unit 4 (96 ticks, 3.84 s, inside GAME OVER's 210 frames); effects `$EA`
  (≈ 45.7 ticks/s). Composer: gate off one tick before each note's end;
  offs before ons; instrument for each part at tick 0 just before its
  first note, so every effect is tempo(2) + instrument(6) + note-on at 8,
  note at **9**. `begin`: silence all, volume 15, transpose 0, run the
  first commands at once. **Rules (1984's):** music always plays;
  `effect`/`effectAt` are dropped unless `sound_playing == nothing`
  (first come, first served; music never interrupted by an effect).
  Call sites and notes: door each opening row `C3 + 24 − step` (C3+1 …
  C5); flash each white step `C4 + flashes × 4` (C4+28 … C4); lightning
  switch C6 on / C4 off; forcefield press C3 every held step (a
  continuous buzz that drops other effects), count tick `C4 + (8 −
  step) × 2`; trapdoor swing `C2 + next × 3`; conveyor box press;
  transmitter `teleport_change` `C4 + target × 2`, send `teleport` on even
  flash steps `C4 + (dice & $1F)` (uses the dice); key pickup; gun shot
  (fixed); mummy rising `C2 + walk × 3`; Frankenstein waking; map close
  (`chart.wait` when all ready); escape → `music(.escape)` after the
  clock; GAME OVER → `music(.over)`.
- **Deviations (ch10).** (1) Tempo is a frame accumulator in the
  frame interrupt; 1984 runs music from a separate timer interrupt
  (≈ 45.8 Hz) with its own tempo byte meaning. (2) Our note table is
  C0-based, equal-tempered from 16.3516 Hz. **1984 uses the same note
  numbers** (C0 = 0 … our table stops at A#7 = 94; 1984's has B7 = 95);
  its registers are tuned for a 1.0227 MHz NTSC clock, so on PAL its
  music sounds about two-thirds of a semitone flat (corrected after the
  ch10 review). (3) Effect
  timbres, lengths and pitch formulas are ours; the shapes (door up,
  flash down, random teleport) follow 1984. 1984's laser pitch depends on
  the gun; ours is fixed. (4) Music on escape and GAME OVER is ours (1984:
  title only); the waltz and both other tunes are original. (5) No sound
  for bell (the door follows), map blink, lock (its door creaks),
  escape, ankh or Frankenstein's steps, as in 1984 (closes ch08's
  "ankh … Frank's steps" promise; the tomb opening is the mummy's rise,
  deaths are the flash). (6) The filter command is a no-op; the
  `long_wait` command is decoded but unused.
- **Costs at ch10 (measured).** Driver step: 14 cycles silent, ~30–40 no
  tick; bucket 5 max 424 / avg 46 (stage C, waltz), max 228 / avg 34
  (Boss). `music` ≈ 420 cycles, `effect(At)` ≈ 250, dropped effect 10.
  Boot loads are free.
- **Tests at ch10 (78 in `zig build test`).** tunes: A4 = 440 Hz (7,382;
  C0 = 274; A#7 last; C#4 = Db4); composer exact bytes. sound (Lab
  game): a note's registers and tick timing; tempo `$80` = 50 ticks /
  100 frames; interrupt rules; the waltz loops for a minute. main: title
  on three voices + `m.listen` non-silent + fire stops it + map chime;
  door creak rising to ≥ 3× its first frequency; every machine through
  the stick (rooms 4–12); a death in Lightning (walk right into it)
  with ≥ 4 falling beeps; escape fanfare → over → waltz (room 19).
- **Ladder bookkeeping (ch10).** Taught: interrupts properly (signal,
  handler, return; `frame` is the frame interrupt's handler, no main
  loop; no re-entry, so long frames swallow slots); fixed-rate timing by
  a fractional accumulator and its carry; frequency tables built at
  comptime (`@exp2`). Also: bytecode and an interpreter, comptime
  composing with `++` and `@setEvalBranchQuota`, `@addWithOverflow`.
- **Promises (ch10 → later).** ch11: 1984's MUSICn tunes (same opcodes
  and lengths; 1984's note bytes play as they are, plus the voice's
  transpose, which effects reset to `$18` on all three voices; a note
  landing on 95 (B7) needs handling). Tempo: 1984's tick rate is
  985,248 / (1,024 × (tempo + 1)) ≈ 962 / (tempo + 1) Hz; every tempo byte
  below `$13` is faster than 50 Hz, beyond our accumulator's 49.8 Hz, so
  ch11 must scale waits or let the accumulator carry more than once a
  frame. 1984's title tune also pauses 512 ticks (≈ 11 s) between loops
  (`$208B`: rewind to `$7802`, `$20DD = 2`). For the title's music; menu/high-score screens may want sounds; priorities left
  as a Bonus Stage. Epilogue: resource retrospective has the sound
  numbers above.
- **ch10 review fixes (supersede the ch10 entries above where they
  differ).** *Machine:* wasm `sound_buf` is 4,096 samples; `shell.js`
  clamps a slot to `SLOT_MAX = 4096`, asks for a 48 kHz AudioContext
  (`makeAudioContext`, falling back to the device rate), wakes on any
  state but running/closed (iOS "interrupted"), runs silent if a stale
  wasm lacks `comet_listen`, and comments the frame/audio clock drift;
  `template.html`'s Power-on makes `window.cometAudio` at 48 kHz with the
  same fallback. The reviewer's harness at 44.1/48/96 kHz: 882/960/1,920
  sample buffers, max 0.717, no non-finite samples. The output stage is
  a real one-pole 12 kHz low-pass (`k = 1 − e^(−2π·fc·dt)`) plus a 30 Hz DC
  blocker, then a soft knee above 0.9 so peaks never clip (the Boss's
  fanfare reached 1.0); a voice whose waveform (or test bit) goes to none fades over
  ≈4 ms instead of stepping to 0 (the start click). New machine test "a
  narrow pulse carries no steady offset to the speaker" (26 machine
  tests); the two silence tests wait one frame more for the fade. Card
  §11: sustain "0 (silence) to 15 (full)", "the A above middle C", a new
  "The output" paragraph. *Docs:* `docs/music-format.md` corrected (op 5
  keeps `$D418`'s low nibble and ORs in; the intro loop's 512-tick pause
  and `$7802`; effects reset all three transposes; the tempo formula and
  the >50 Hz limit; table index = our note numbers, NTSC tuning).
  *Chapter:* fourteen call sites in the "Whose notes?" box; ten commands
  numbered 0–9; Fraction Power-Up "every frame"; `compose` "ordinary code
  that runs later"; effects "in free memory rather than among the
  built-in tables"; "`sound_at`, its stream pointer"; gap mistake "notes
  run together"; "at its loudest a third of full volume"; quoted error
  keeps `error: `. Diagrams: command labels spaced, "highlighted byte";
  envelope caption 0–15; interrupt SVG keeps 560 px and scrolls inside
  its figure at 400 px. Spectrogram starts at the waltz's first sounding
  frame (9). Prologue's "3 voices" row: "for music and sound effects
  alike". Stage outputs, WAVs, MP3s and the spectrogram regenerated.
  *Declined (Writer response in the review):* PolyBLEP anti-aliasing.
- **The disk drive (ch11, machine; supersedes "Disk drive (planned, not
  built)").** `machine/src/drive.zig`: plain functions on `Image =
  [174_848]u8`, all comptime-capable: `sectorsOn` (21/19/18/17),
  `offset(t, s)`, `format(img, name, id)` (BAM at 18/0: 4 bytes a track,
  name `$90`, ID `$A2`, "2A" `$A5`; empty directory at 18/1), `blocksFree`
  (664 on a fresh disk), `parse(raw)` (`$`/`$0:pattern` listing, `@0:`
  replace, `0:` drive prefix, ≤16 letters), `matches` (`*` rest, `?` one),
  `find`, `load(img, raw, out, *touched)` (returns the length less the
  2-byte load address; `out` gets a prefix if short), `save(img, raw,
  address, data, *touched)` (allocation nearest track 18, interleave 10;
  a new directory sector 3 on). Listing: BASIC-style lines (links 1,1,
  line number, text, 0): line 0 = `$12` + quoted disk name + ID, a line
  per matching file in directory order (blocks, quoted name, `PRG`),
  then `N BLOCKS FREE.`, then 0,0. `Command {load = 1, save = 2}`,
  `Status {ok, no_disk, not_found, exists, full, too_long, bad_name,
  bad_disk}`. **Registers** `$DD00` command (a `poke` runs it at once,
  reads back 0), `$DD01` status, `$DD02/3` address, `$DD04/5` length
  (after a load: bytes that came), `$DD06` name length, `$DD10–$DD2F`
  name (32). **Time:** `sector_cycles = frame_budget` (19,656) per sector
  touched, at least one per command, charged by `driveCommand`; the SOUND
  chip holds its registers meanwhile. `Machine.drive {image, present}`,
  `insert(bytes)` (35/40 tracks, ± error bytes: 174,848 / 175,531 /
  196,608 / 197,376), `eject`, `diskImage`; `boot` ejects, then inserts
  `Game.disk` if declared (`checkGame` checks its type). Headless
  `--disk FILE` (after boot; a bad image exits 2) and `--save-disk FILE`
  (prints `disk: PATH, N blocks free`). Wasm: `disk_buf[197_376]`,
  `comet_disk_buffer(_size)`, `comet_insert(len)` (0 ok), `comet_disk(_size)`.
  `shell.js`: `insertDisk(bytes)` (boot, insert), `disk()`, `reset()`
  keeps the disk, `wireDisk` for `input[data-comet-disk]` and
  `button[data-comet-save-disk]` (downloads `comet-disk.d64`);
  `build.py`'s play section has a hidden `.play-disk` row shown when the
  wasm has a drive. Card: memory-map row `$DD00–$DD2F`, reserved
  `$DC03–$DCFF` and `$DD30–$DFFF`, §12 flags, new §13. Tests: 6 in
  `drive.zig`, 1 in `machine.zig` (33 machine tests). Every checkpoint
  starter–ch11 passes `check-all.sh` with it.
- **Chapter 11 file, title, images.** `site/chapters/11-the-castle-keeper.md`,
  `title: "The Castle Keeper"`, generated from `tools/ch11/ch11.tmpl.md`
  by `expand.py` (76 listings; none told in prose instead; no quoted
  compile errors, so no `errs.py`). Prose ≈ 5,550 words by `wc.py`. Stage
  runs: A (10 frames, `--save-disk creep.d64`: 643 blocks free), B (power
  on, 60), C (Esc, five downs, the Entrance Hall, 320), D (N ×19 to the
  Way Out, ACE, then the menu's BEST TIMES, 2,050), E (Gatehouse, save
  MY GAME, three X to GAME OVER, resume, 1,700), F (Boss: ch10's BOSS
  without the WAV, shifted 24 frames for the disk, ACE and DUO, BEST
  TIMES, 3,800). Screenshots (768×544, `tools/ch11/shots.py`):
  `11-title` (B 59), `11-menu` (C 130), `11-signing` (D 1610), `11-times`
  (D 2049), `11-save` (E 430). Diagrams: `ch11-disk` (generated by
  `tools/ch11/diagrams.py` from stage A's disk image: every sector, the
  BAM and directory, ZTRAINING's 19-sector chain on track 17 and the
  Hall's 2, animated read head stepping the chain; scrolls sideways at
  400 px), `ch11-listing` (static: the `$0:Z*` listing bytes in staging,
  the two catalog names with bit-7 ends, the castle loading over the
  listing).
- **Source layout (ch11).** New `master.zig` (`image`: comptime
  `format("CASTLES OF CREEP", "84")`, `save` ZTRAINING and ZENTRANCE
  HALL at `$9800`; `@compileError` if they don't fit), `files.zig`
  (`load`, `save`, `command`, `name`, `nameFrom` (prefix + bit-7-ended
  stored name), `max_castles = 16`, `entry`, `length`, `Disk {unread,
  ready, none}`, `powerOn`, `catalog`, `next`, `pick`, `ready`,
  `saveScores`), `scores.zig` (`Best` extern {initials[3], seconds,
  minutes, hours}, `places = 10`, `File` {size[2], tables[2][10]}, 122
  bytes with a comptime region check, `file`, `address`, `fresh`, `order`,
  `earned`, `colors`, `draw`, `rowOf`, `line`, `run`), `typing.zig`
  (`max_letters = 16`, `placeholder '-'`, keys Return 13, Backspace 8, Esc
  27, `begin`, `Typing {typing, done, cancelled}`, `run` (A–Z, 0–9, space,
  '.'), `finish`, `letter`), `menu.zig` (`Item`, `Choice`, `asked`,
  `rowOf`, `draw`, `lives`, `clear`, `pointer`, `pushed`, `run`),
  `position.zig` (`asked` (Esc only), `draw`, `run`, `Problem`,
  `problemOf`, `save`, `load`). Changed: `main.zig` (`pub const disk =
  master.image`; boot no longer loads staging, pokes `shell_signing =
  0xFF`; `Mode` adds `draw_menu, menu, draw_times, times, draw_name,
  name`; `draw_title` calls `files.powerOn` while `shell_disk ==
  unread`; Esc on title → menu, on map → save), `game.zig` (`chosen`
  needs `files.ready`; `after` loses no life when unlimited), `title.zig`
  (castle name centred at y 72, or NO CASTLE DISK; ESC FOR THE MENU at
  y 88; stars avoid rows 9 and 11), `clock.zig` (`write` split out of
  `print`), `castle.zig` (`restored = 0x01`), `screen.zig` (`erasePart`),
  `room.zig` (`unplace`/`tint` clip at the left edge; `later` replaced by
  `pattern`, the MultiDraw preparer), `frankenstein.zig`
  (1984 frame numbers), `training.zig` (Frank `.frame = 0x84`).
- **Memory (ch11).** `scores` `$B800–$B879` (the score file less its
  load address), `shell` `$B880–$B89F` (+0 disk, +1 castles, +2 castle,
  +3 pointer, +4 stick, +5 unlimited, +6 signing (0xFF none), +7 place,
  +8 saving, +9 x, +10 y, +11 max, +12 typed, +16 line[16] with bit 7 on
  the last letter), `catalog` `$B900–$B9FF` (16 × 16-byte names, bit 7 on
  the last letter), hardware row `disk_drive` `$DD00–$DD2F`. The `$0:Z*`
  listing (126 bytes on the master disk) is loaded into staging and
  overwritten by the first castle (ladder row 11's overlay).
- **Mechanics, as implemented (ch11).** *Power-on:* first `draw_title`
  frame, display blanked, catalog then `pick(0)`. *Catalog:* names in
  quotes starting Z from the listing after line 0, less the Z, max 15
  letters kept, up to 16 castles, directory order. *Pick:* Z+name into
  staging (≤ 8 KB), magic `& ~restored` must be `$80`, Y+name into
  `scores` (122 bytes, size word must be 122) else `fresh` (size 122,
  120 × `$FF`). *Menu:* Esc on title (any other key swallowed); four
  items at rows 0/16/32/48, heading at 64, castles from 72 (8 apart);
  stick 1 edges, wraps; fire on a castle blanks and picks; unlimited
  toggles (reversed text). *Best times:* `earned` after each escape
  (not with unlimited lives, not `restored`); table `castle.two`; first
  place whose time is ≥ his (a tie goes above); slower places shift with
  `m.copy`; initials typed (3), Esc leaves them blank; then `@0:Y`+name
  saved (122 bytes); signing returns to the escape/GAME OVER flow;
  viewing (menu) returns to the menu on stick-1 fire or Esc. *Typing:*
  Return needs ≥ 1 letter; `finish` reads both sticks' fire edges (Return
  is stick 2's fire, Space stick 1's). *Save:* Esc on the map; names
  starting Z or Y refused; `@0:`+name, `castle.size` bytes from `$7800`;
  back to the map either way (Esc too). *Resume:* menu → name → load into
  `$7800`, magic and `in_game` checked, `restored` set, `sound.stop`,
  `game.next`, map; errors shown at y 96, retry; Esc → menu.
  *Left edge:* `unplace` → `erasePart(skip = (16 − x + 3) / 4)`; `tint`
  drops off-screen columns. *Frank:* record frame byte = 1984's `$84–$86`
  right, `$87–$89` left, `$8A` slide, `$8B–$8E` climb, `$8F` asleep
  (`fromRecord`/`toRecord`; unknown → asleep). *Pattern* (1984
  `obj_MultiDraw`): `count` × `place(shape, x, y)`, stepping `x +%= step_x`,
  `y +%= step_y`; shape numbers are ours (≥ the Id count skipped): a real
  castle's MultiDraw would need 1984's image numbers translated (none
  known to use it; the intro screens use the `$160A` variant).
- **Deviations (ch11).** (1) Saves are allowed on any disk, including
  the game's own; 1984 refused to save a game to the master disk. We
  refuse Z/Y names instead. (2) The drive costs a frame per sector
  (~12,700 bytes/s), far faster than 1984's. (3) No room tour on the
  title. (4) Menu: bitmap text, one column, 16 castles (1984 24), picked
  castle white (1984 reversed), Esc instead of RUN/STOP. (5) One or two
  players still chosen by which stick fires (1984 `$7812` = `castle.two`,
  meeting the ch09 promise). (6) The SOUND chip holds the last frame's
  registers during disk I/O (1984's behaviour here is unchecked). (7)
  Best-times screen layout and colours are ours; the file and rules are
  1984's.
- **Promises kept or checked (ch11).** Disk load to staging (ch3/ch9);
  saving a castle saves the game (ch9); high scores from `time` (ch9);
  title/menu choosing players (ch9: by stick, logged above); X < 16
  (ch06 review note: `unplace`, `tint`, `screen.erase` now clip; `place`
  already did; lamps and glow go through these); Frank's frame byte
  translated to 1984's numbers; real castles' `no_gun` records already
  handled in `guns.zig`; the pattern preparer (ch03/ch08's "comes alive
  in Chapter 11").
- **Promises left for the Epilogue (unverified here: no real disk in
  this tree).** Door map bytes vs a real castle's map (ch09);
  Frankenstein–Frankenstein avoidance masks (ch08); ankh and alcove size
  differences (ch08); the 1984 turn-order quirk for different start rooms
  (ch09; we keep strict turns); MUSICn loading and 1984 tempo bytes below
  `$13` (> 50 Hz; ch10), B7 notes, the title's 512-tick pause. All are
  listed for readers in the chapter's "Still to check" box.
- **Costs at ch11 (measured).** Sector 19,656. Power-on frame 638,586
  cycles (33 slots): bucket 0 454,404 (23 sectors: listing 2, ZTRAINING
  20, missing Y 1) + title 184,168. Menu draw 139,728 (8 slots), idle
  102, pointer move 1,086; pick Training 414,074 (21 sectors), pick Hall
  4 sectors; best-times draw 174,466 signing / 157,712 viewing; score
  save 78,946 (4 sectors, new or replacing); name screen 133,958; a letter
  ≈ 920; save game 435,218 (22 sectors, 23 slots); resume 20 sectors.
  No overruns in any stage run. Wasm 950,746 → 1,181,300 bytes (the
  disk image).
- **Tests at ch11 (88 in `zig build test`, plus 33 machine).** main:
  power-on catalog (order, bit 7, staging = training, fresh scores, a
  loading frame); no disk (title stays); menu → Entrance Hall played;
  unlimited lives (5 deaths, lives 3); best time signed, on the disk,
  kept across a power cycle, viewed from the menu; save on the map (with
  Backspace), three deaths, a missing name, resume (room, lives, time,
  `restored`, no best time, onward into room 1); a disk of your own (22
  castles → 16, directory order, a non-castle file ignored). room: left
  edge clipping; a pattern of three panels. frankenstein: frame byte round trip. Old tests sign
  their escapes (`sign`: ACE/DUO, ONE/TWO, WIN). Helpers `typeIn`,
  `sign`, `push`.
- **Ladder bookkeeping (ch11).** Taught: devices (registers, a command,
  a status), blocks and slow storage (tracks, sectors, BAM, directory,
  chained files, interleave, a frame per sector, blank before I/O);
  overlaying memory (the listing in staging under the castle). Also:
  comptime disk building, insertion into a sorted table with an
  overlapping copy.
- **ch11 review fixes (supersede the ch11 entries above where they
  differ).** *Machine:* `wasm.zig` exports `comet_has_disk()` (1 iff the
  game declares `disk`) and `comet_is_disk_size(len)`; `shell.js`
  `hasDrive` uses the first (starter–ch10 pages no longer show the disk
  row) and `insertDisk` checks the second before rebooting (a wrong file
  leaves the game running); the picker's `value` is reset after each pick.
  `drive.nextFree` steps 10 on and one back on each wrap, as real drives
  (track 17: 0, 10, 20, 8, 18, 6 …); new drive test (34 machine tests).
  REFERENCE §12 (slot only for games with a disk; bad files refused) and
  §13 (a saved disk is 35 tracks). `build.py`'s play note adds the Esc keys
  for chapters ≥ 11. *Game:* `typing.begin` clears `$DC02`; a failed score
  save shows TIME NOT SAVED (red, row 1) and waits for stick-1 fire or Esc
  (`shell_signing = 0xFE`, `scores.not_saved`); `master.zig`'s comment no
  longer claims 1984's castles carry `$9800` (they carry `$7800`; the
  loader ignores it). Tests 90 (two new in main: a key during the fanfare,
  a full disk). Listings 77 (D20 split out). *Chapters:* ch08's alcove
  sentence and ch09's door-bytes sentence now point at the Epilogue
  (regenerated; ch08/ch09 rebuilds byte-identical). ch11 prose: load
  address, "17/0, 17/10, 17/20, 17/8", Mode sentence, "Chapter 9 set this
  up", 638,586 note, TIME NOT SAVED, the key clear, Bonus Stage "A bad
  first castle"; diagram legend "(pale until read)"; prose 5,499 words. *Kept:* menu spacing
  (16 castles) and PRESS FIRE under NO CASTLE DISK (Writer response).
