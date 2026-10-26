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
  that really costs; here's what this game does instead"). Use byte
  diagrams.
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
  - the senior dev's enthusiasm, said out loud ("this is the best
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
- **No "we", "I", "my", "our" or "let's".** The guide talks to the
  reader as "you", or about "the game" / "this chapter". Write "the
  best trick in the chapter", not "my favourite trick"; "the game's
  memory map", not "our memory map"; "time to fix that", not "let's fix
  that". This applies to code comments in listings too (and so to the
  checkpoints, which must match).
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
