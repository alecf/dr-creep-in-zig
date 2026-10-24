# Tutorial outline — "The Castles of Dr. Creep, written in Zig"

*Draft 5: voice and tone, with the reader persona pinned down. Decisions
from earlier reviews are at the end. Chapter-level detail comes once the
flow is approved.*

This document is for us, the authors. The reader never sees it, and none
of its behind-the-scenes framing (reverse engineering, "pretend",
copyright, this repo's emulator) appears anywhere on the site. See
"Voice and tone".

## The premise (author-facing)

We pretend that in 1984 Ed Hobbs wrote *The Castles of Dr. Creep* in Zig
rather than 6502 assembly, for a machine with the C64's limits: 64 KB of
RAM, a ~1 MHz CPU, a 50 Hz frame, a 320×200 screen with four colours per
8×8 cell, eight hardware sprites, and a three-voice synth. The tutorial
builds that game from an empty directory to a working copy, and the
machine's limits shape every design decision along the way.

Because this repo reverse-engineered the real binary, every design choice
in the tutorial is one the original actually made (the real addresses,
table sizes and data formats are documented in `docs/` and `disasm/`). The
tutorial presents them as decisions a designer would make. The
disassembly is our research source, not reader-facing material. Facts
taken from it appear on the site as in-world "how the 1984 disk does it"
lore, with no links to assembly.

## Voice and tone

**The model is a 1980s game magazine strategy guide, but for code.** The
reader is a player on a quest, and we are the friendly, excitable guide
who has played through it already and can't wait to show them the secret
rooms. Every page should feel like a fun project we're doing together.

- **Talk straight to the reader.** Use "you" and "we", short punchy
  sentences, exclamation points where they're earned (a few per chapter,
  not per paragraph). Mark real milestones ("Your hero just climbed his
  first ladder!") and don't cheer for routine steps.
- **Senior dev to a promising junior.** We're the senior developer who
  loves this stuff and wants to share it. The reader is a junior developer
  we believe in: clearly capable, just new to the low-level world. We
  never doubt they can follow along. We also never assume they've already
  seen what's under the hood.
- **A shared love of retro games.** Both of us grew up on (or fell for)
  games like this one, and that common ground is the hook. The reader
  already knows what's great about these games from the *player's* side:
  how a ladder feels, why that sprite flickers, the joy of a secret room.
  Only the senior knows how they work inside. So we go from the
  experience to the mechanism: "you know that flicker when too many
  enemies are on screen? Here's the 8-sprite limit causing it, and here's
  how we dodge it." The reader brings the nostalgia; we bring the
  internals.
- **Who the reader is:**
  - Comfortable in JavaScript or Python: functions, loops, objects,
    arrays, classes, maybe a framework or two.
  - Kind of understands pointers but has never really used them.
  - Knows what "an array of objects" is, but not how it's laid out in
    memory. They don't know that a JS object is a pointer to a heap
    allocation somewhere, or that an array of structs is one contiguous
    run of bytes.
  - Hasn't had to think about bytes, bits, hex, integer sizes,
    overflow, or what a CPU actually does with each line.
  - New to Zig.
  - Loves retro games and knows them well as a player, but has never
    seen how one is built.
- **Explain from first principles, bridging from what they know.**
  Low-level ideas (memory as one big byte array, addresses, pointers,
  struct layout, bit masks, hex, fixed-width integers and wrapping,
  lookup tables) get a real explanation the first time they appear,
  anchored to a JS/Python equivalent: "in JS you'd write
  `rooms.push({x, y})`; here's what that actually becomes in memory, and
  here's what we do instead." Diagrams of bytes in memory are the main
  teaching tool. Don't re-explain general programming they already know
  (loops, functions, what a variable is).
- **Just in time, never up front.** Each low-level idea arrives in the
  chapter where the game first *needs* it, and is taught through that
  need. Nobody learns bit masks in the abstract; they learn them because
  the joystick hands them a byte with five directions packed into it. No
  chapter opens with a theory section. See the "Under-the-hood ladder" at
  the top of "Chapters" for where each idea lands.
- **Respect without condescension.** In practice:
  - No quizzes, "can you guess?" prompts, or gold stars. Exercises are
    offered as fun things to build, not homework to check.
  - No "easy!", "simple!", "just", or "obviously". If something is hard,
    say so, say why it's worth it, and break it down until it isn't.
  - No baby talk, no mascot narrating to the reader, no "great job!" after
    every listing.
  - Do name the "aha" moments, the way a senior dev would lean over and
    say "okay, this next bit is my favourite trick in the whole game."
  - The test: would a sharp JS developer finish the page feeling smarter
    and excited to keep going, without having felt talked down to or
    lost?
- **Never break the fiction or get meta.** In the site's world, Dr. Creep
  is a Zig game for a 64 KB home computer, and you're building it from
  scratch. No mentions of reverse engineering, disassembly, emulators,
  "pretending", AI, or how the tutorial was made. Off-world needs (legal
  credits, licence) go on one plain colophon page linked from the footer,
  and nothing else on the site refers to it.
- **The constraints are the game's rules, not complaints.** 64 KB, 8
  sprites and the frame budget are the challenge, like a level's time
  limit. Squeezing under them is the fun part.
- **Real rigour underneath.** The jokes never stand in for explanation:
  every listing compiles, every number is right, and every technique gets
  explained properly.
- **Invented, generic magazine trappings only.** No real magazine,
  console, company or character names, and no writing in the voice of the
  game's real author.

### Recurring features (boxes that appear across chapters)

| Box | What it holds |
|---|---|
| **Mission Briefing** | Chapter opener: what you'll build and the screenshot you'll have at the end. |
| **Power-Up!** | A resource-saving technique, named and explained (e.g. "the Lookup Table Power-Up"). |
| **Byte Budget** | A running tally of the memory and frame-time each new piece costs, tied to the memory map and budget meter. |
| **Pro Tip** | Short Zig-specific advice, including 0.16 gotchas. |
| **Under the Hood** | The JS/Python-to-metal bridge: a familiar snippet, what it really costs in memory and time, and the low-level version we're writing instead. |
| **Secret Passage** | An optional deep dive for readers who want more (e.g. how the colour cells really pack). |
| **Game Over?** | Common mistakes and the bug each one produces, with the fix. |
| **Warp Zone** | Jump straight to a chapter's finished checkpoint. |
| **Boss Battle** | The chapter's final stretch: bring the pieces together and get the checkpoint running. Ends on a screenshot of what now works. |
| **Bonus Stage** | Optional open-ended builds, e.g. design a room using what you just built. No answer keys, no grading. |
| **Inside the Disk** | In-world lore on how the 1984 game handles a problem, with real table sizes and tricks. Replaces the "what the original did" sidebars. |

Chapter titles should read like level names: punchy and a little
spooky, matching the haunted-castle setting. The current titles are
working titles and get a pass during chapter detailing.

## Key structural idea: the engine is a bytecode interpreter

The level-coverage problem mostly solves itself. A castle is **data**: a
header, a room directory, and per-room streams of tagged object records
(door, walkway, pole, ladder, doorbell, lightning, forcefield, mummy, key,
lock, ray gun, teleport, trapdoor, conveyor, Frankenstein, text, image).
The engine is a set of per-type handlers. **Implement all 17 object types
and every castle plays**, including all 14 on the original disk, loaded
from the reader's own D64 image.

The original disk already has a castle built for this: **Tutorial**, which
teaches one mechanic per room (doors and doorbells, ladders, poles,
lightning, forcefields, mummy, key and lock, ray gun, matter transmitter,
trapdoor, conveyor, Frankenstein, and a final room). We can't ship it
(copyrighted), so the tutorial ships its own **Training Castle**: about 16
rooms authored for this tutorial in the same file format. Each chapter
brings more of those rooms to life, and a few extra "combination" rooms
test how the mechanics interact. Building the rest of the castles is left
to the reader as an exercise, in three tiers:

1. Load your own disk and play the 13 real castles: no new code needed,
   which is the payoff.
2. Recreate a real castle room by room from map screenshots.
3. Design your own castle with the room-authoring DSL from chapter 3.

### Mechanic coverage matrix (what the Training Castle must contain)

| # | Mechanic | Data object(s) | Runtime pieces | Chapter |
|---|---|---|---|---|
| 1 | Walkways / floors | Walkway | navigation grid | 4 |
| 2 | Ladders | Ladder | grid + climb anim | 4 |
| 3 | Sliding poles | Sliding pole | grid + slide anim | 4 |
| 4 | Doors (in-room, between rooms) | Door | open/close anim, room transition | 5 |
| 5 | Doorbells | Doorbell | "in front of" + fire | 5 |
| 6 | Exit door / escaping the castle | Door (exit flag) | escape sequence | 9 |
| 7 | Lightning machines + switches | Lightning | sprite actor, switch→machine links | 6 |
| 8 | Forcefields + timer button | Forcefield | countdown timer object | 6 |
| 9 | Trapdoors + switch | Trap door | floor removal, grid update | 6 |
| 10 | Conveyors + control | Conveyor | belt moves actors, direction state | 6 |
| 11 | Matter transmitter | Teleport | colour-cycled destination pads | 6 |
| 12 | Keys | Key | per-player inventory | 7 |
| 13 | Locks | Lock | key colour → door id | 7 |
| 14 | Ray guns + control panel | Ray gun | tracking AI, laser actor, player control | 7 |
| 15 | Mummy + ankh trigger | Mummy | tomb release, pursuit AI | 8 |
| 16 | Frankenstein | Frankenstein | wake, chase, die (trapdoor/lightning/ray) | 8 |
| 17 | On-screen text | Text | bit-7-terminated strings | 2/3 |
| 18 | Images / final room | Image | multi-placement blit, ending reveal | 9 |
| 19 | Two players at once | — | per-player state, shared room | 9 |
| 20 | Lives, death, respawn | — | flash/die lifecycle | 5 |
| 21 | Castle map | room directory | reveal-as-visited, "you are here" arrows | 9 |
| 22 | Timer & high scores | — | BCD time, initials entry | 9/11 |
| 23 | Save/load position | — | save files, disk I/O | 11 |

Combination rooms to include (each one stress-tests an interaction):
Frankenstein + trapdoor, Frankenstein + conveyor, ray gun + forcefield,
mummy + lightning, key behind a teleport, and two players needing to
cooperate on a switch.

## The machine we target

The reader writes the game in ordinary Zig against a small **"fantasy
C64"** module, provided ready-made as the in-world **Comet 64** computer
(see `site/AUTHORING.md` §3). The reader writes the game, not the
hardware. `hw` is a **deliberately forgiving emulator**: it does not model
cycle timing, bus quirks or chip bugs. It models only the hard limits, and
it makes those impossible to ignore. Breaking a limit fails loudly: a
compile error where possible, otherwise a red overlay and a log line.
The limits:

- `ram: [65536]u8`: the *only* memory there is. No allocator anywhere in
  the game. The memory map is a comptime table, and the build fails if two
  regions overlap.
- A VIC-like video chip: multicolour bitmap + screen/colour planes, 8
  sprites with shadow registers, sprite collision registers, border and
  background colour.
- A SID-like 3-voice synth (pulse/saw/triangle/noise, ADSR).
- A joystick port (5-bit active-low) and a minimal keyboard.
- A 50 Hz frame interrupt, plus a **work meter**: a frame has a fixed
  budget (modelled on ~19,700 cycles/frame) and game code charges against
  it, so the reader can see when a design is too expensive for the machine.
  This is how the "limited resources" theme becomes concrete instead of
  hand-waved.
- Graphics assets must fit the same hardware formats: 2-bit multicolour
  shapes, 24×21 sprite frames, the fixed 16-colour palette, and at most
  four colours per 8×8 cell. Art that breaks a format won't build.
- Shells: native window (sokol, as in `src/app.zig`) and wasm32-freestanding
  (as in `src/wasm.zig`) for the website.

We don't compile for a real 6502. The limits are self-imposed, and the
point is to practise the 1984 discipline, not to reproduce 1984 toolchains.
This repo's 6502 emulator stays behind the scenes as an author research
tool. It never appears on the site.

## Website shape (the "semi-interactive" part)

- One page per chapter: prose + code listings + an embedded wasm build of
  **that chapter's checkpoint** running in the page.
- Every chapter ends at a runnable checkpoint (a complete project under
  `site/code/ch04/`, etc.), so readers can diff against it or skip ahead.
- Interactive widgets, reused across chapters:
  - **Memory map viewer**: live 64 KB map coloured by region, filling as
    the game boots.
  - **Frame budget meter**: per-frame work, broken down by subsystem.
  - **Toggles** that turn off an optimisation to show why it's there
    (e.g. disable sprite double-buffering → tearing; disable the
    navigation grid → the budget meter goes red).
  - **Hex inspector**: hover over castle bytes to see them decoded.
  - **Room editor** (final chapter): edit a Training Castle room in the
    browser and play it.
- "Inside the Disk" lore boxes (see "Voice and tone"), with no links to
  assembly.

### Deployment: GitHub Pages

- The site is static: HTML/CSS/JS plus one `.wasm` per chapter checkpoint.
  No server is needed.
- A GitHub Actions workflow (`.github/workflows/pages.yml`) installs Zig
  0.16, builds each checkpoint with `zig build wasm`, builds the site, and
  publishes it with `actions/deploy-pages`. Every push to the default branch
  redeploys the site.
- **Nothing copyrighted gets deployed.** The checkpoints that Pages hosts
  use only the Training Castle and the tutorial's own art and font. Anything
  from the disk can't be served from a public site, which is one more
  reason the tutorial ships its own art.
- Loading a real castle disk in the browser uses a file picker. On the
  site, it's an in-world "Bonus Stage: got a castle disk? Slot it in!"
  feature, and the plain copyright explanation lives on the colophon page. The D64 is parsed
  client-side in the wasm build and never leaves the reader's machine, so
  the real castles are playable on the hosted site without the site
  distributing them.
- The site uses relative URLs so it works under the project path
  (`<user>.github.io/dr-creep-in-zig/`).

---

## Chapters

### Under-the-hood ladder

Each low-level idea gets taught where the game first needs it, and later
chapters build on it. Keep any one chapter to two or three genuinely new
ideas.

| Ch | New under the hood | What makes it necessary |
|---|---|---|
| 1 | Bytes and `u8`; memory as one big array; addresses; hex notation; a single bit as an on/off flag | Putting a colour on screen means writing a byte at an address. The joystick's fire button is one bit. |
| 2 | Packing several values into a byte (shifts and masks); pointers as addresses you can do arithmetic on; lookup tables vs computing (what a multiply costs) | Four pixels share a byte. Finding a pixel's byte is the hot path. |
| 3 | Structs and how their fields lay out as bytes (vs a JS object); little-endian 16-bit values; variable-length data with sentinel bytes; comptime | A castle file is raw bytes you have to read as records. |
| 4 | Fixed-width integers, overflow and wrapping; a 2D grid stored as a 1D array (index math); several flags packed in one byte | Coordinates are bytes. The navigation grid is one flat table. |
| 5 | Arrays of structs as one contiguous block (vs an array of pointers to objects); fixed-capacity slot tables; dispatch tables of function pointers | 8 actors and a room's objects, every frame, with no allocator. |
| 6 | Linking things by index instead of by pointer | A switch has to point at "lightning machine #2", and the data must stay valid on disk. |
| 7 | Reusing free slots; a whole state machine in one flag byte | Lasers come and go under a hard 8-sprite cap. |
| 8 | XOR and bit rotation; deterministic pseudo-randomness | Monsters need cheap, repeatable randomness. |
| 9 | Overlaying memory (one region, two jobs, like a Zig `union`); BCD numbers | Runtime state lives inside the castle buffer. The timer prints every frame. |
| 10 | Interrupts, explained properly: what the frame interrupt has been doing since chapter 1; fixed-rate timing; frequency tables | Music must keep time while the game runs. |
| 11 | Devices, blocks and slow storage; loading into memory you just freed | Castles load from disk into a tight memory map. |

Frame cost works the same way. Chapter 1 just says "everything costs
work units, and a frame has a fixed amount". Each later chapter adds one
concrete cost lesson (a multiply in chapter 2, a per-frame search in
chapter 4, scanning idle objects in chapter 5) using the budget meter.

### Prologue — The rules of the game
Mission briefing for the whole quest: meet Dr. Creep's castles and the
machine you're building them for. A tour of the finished game. The budget: 64 KB, 50 Hz, 8 sprites, 4 colours per cell, 3 voices.
How to read the site and use the checkpoints. Zig 0.16 setup.

### 1. A machine in 64 KB
Short and hands-on: get something on screen fast. The reader starts from
a starter kit with the native and wasm shells already wired up (their
internals get a Secret Passage, not a lesson). Meet the machine: memory
is one 64 KB array of bytes, and a colour on screen is a byte at an
address (hex shows up here, because addresses read better that way).
Then write the frame loop at 50 Hz, a tiny memory map (just the regions
this chapter uses; it grows each chapter), and read the joystick's fire
button as one bit.
**Techniques:** no allocator, ever; the frame budget as the game's time
limit; writing hardware registers once per frame.
**Checkpoint:** a coloured screen with one sprite you can steer.

### 2. Pixels on a budget
Multicolour bitmap encoding (2 bits/pixel, colours per cell), the
**shape table** (one table shared by room graphics, text and sprite
frames), the blitter (`screenDraw`), scanline row-address lookup tables,
text from a borrowed 8×8 font with bit-7 string terminators, and hardware
sprites with double-buffered frame pointers.
**Techniques:** lookup tables instead of multiplies; packed 2bpp data;
reusing a font that is already in ROM; decoding sprite frames on demand
into a small scratch area instead of storing every frame pre-expanded.
**Checkpoint:** a static title screen and a hand-placed room drawn from
shapes.

### 3. Data is the program: the castle format
Design the castle file: header, 8-byte room directory, tagged object
streams, the three framing schemes (count-prefixed, end-marker loops,
per-instance tags), and why the tag *is* the handler address. Write the
loader/dispatcher and a **comptime room-authoring DSL** that emits the
bytes, then author the Training Castle's static parts with it.
**Techniques:** variable-length records with sentinels; dispatch tables;
a whole castle in 2–6 KB; validating level data at compile time.
**Checkpoint:** every Training Castle room's static geometry and text
renders; flip between rooms with a key.

### 4. Walking the floors
Build the **navigation grid** (4×8-pixel cells, direction bits) while the
room is drawn, so movement each frame is a single table lookup. Then the
player actor: input, walking, climbing ladders, sliding down poles,
animation frames, and mapping sprite coordinates to grid cells.
**Techniques:** precomputing at load time instead of every frame; bitfield
cells; 8-bit coordinates and wrapping arithmetic; the
`positionCalculate`-style address trick.
**Checkpoint:** walk the floors, ladders and poles of rooms 1–3.

### 5. Actors, objects, and the main loop
The engine's core: fixed tables for 8 actors and N room objects, state
bitflags (created / dying / destroy / free / collided), the per-frame
execute loop that skips idle objects (execute flag), collision (sprite vs
sprite, sprite vs object, "standing in front of"), an event queue, and the
death → flash → respawn lifecycle. First mechanics: **doors and
doorbells**, and walking through a door into the next room.
**Techniques:** fixed-capacity slot tables instead of lists; flags instead
of virtual dispatch; only executing objects that asked to run; using
hardware collision as a cheap first pass.
**Checkpoint:** open a door with a bell and walk room to room through the
Training Castle.

### 6. Switches and machines
One pattern, five uses: a *control* linked to a *device*. Lightning
machines and switches (one switch → up to 4 machines), forcefields with
countdown buttons, trapdoors (patching the navigation grid at runtime),
conveyors (moving whatever stands on them), and the matter transmitter
(cycling destinations).
**Techniques:** linking objects by index instead of pointers; shared state
machines; toggling single bits; cheap colour cycling instead of redrawing.
**Checkpoint:** the Training Castle's machine rooms all work.

### 7. Keys and guns
Per-player key inventory, and locks matched by colour to door id. Ray guns
that track the player up and down, plus the control panel that lets the
player take over a gun and fire it. The laser is the first short-lived
actor: spawned into a free slot, it travels, collides, and frees its slot
again.
**Techniques:** inventories as small fixed lists; a whole gun's state in
one flag byte (move up/down, tracking, fired-by-player); finding and
recycling free actor slots; transient actors under an 8-sprite cap.
**Checkpoint:** the key, lock and ray-gun rooms work; you can shoot
another player.

### 8. Monsters
Mummies released by walking past the ankh, then pursuing along the
floors. Frankenstein waking when you share his level, chasing, getting
carried by conveyors, and dying in trapdoors, lightning and ray fire. A
tiny LFSR random number generator.
**Techniques:** AI as a handful of bytes of state; pursuit without
pathfinding, reading the navigation grid; monster-vs-mechanism rules as
table lookups; deterministic randomness for replays and tests.
**Checkpoint:** every mechanic in the coverage matrix works, plus the
combination rooms.

### 9. The whole castle
Turn rooms into a game: the **castle map** (drawn from the room directory,
revealed as you visit, arrows per player), two simultaneous players with
per-player state, lives and game over, a running BCD timer, the exit door
and escape sequence, and the final Image room's piece-by-piece reveal.
**Techniques:** reusing the castle buffer as runtime state (the header's
scratch area); BCD for cheap display; drawing the map from data the game
already has.
**Checkpoint:** play the Training Castle from start to escape, alone or
with two players.

### 10. Three voices
A SID-style synth, then the **music bytecode** (notes, waits, tempo,
voice control) and its interpreter, driven from the frame interrupt. Sound
effects reuse the same interpreter by taking over its stream pointer.
**Techniques:** one interpreter for music and SFX; note frequency tables;
streaming commands instead of storing samples; deciding what a sound is
allowed to interrupt.
**Checkpoint:** title music and gameplay sound effects.

### 11. The shell: title, menus, disk, scores
Everything around the castles: the title and intro screen, the castle
select menu (order taken from the disk directory), the options menu,
high-score tables with initials entry, saving and loading position, and a
small **1541 disk filesystem** in Zig so the game loads castles exactly as
the original did. This also unlocks loading **your own D64**.
**Techniques:** overlaying memory (reusing title-only code space once the
game starts); loading from a slow device; small fixed save formats
(124-byte score file).
**Checkpoint:** the complete game. Boot, pick a castle, play, save, set a
high score.

### Epilogue — All the castles
Load the real disk and play all 14 castles on the engine you wrote. The
room editor. Exercises: recreate a real castle, design your own, add a
new object type. A retrospective on the resource budget (where the bytes
and cycles went).

---

## Decisions (from review of draft 1)

1. **Target:** ordinary Zig with self-imposed limits, packaged as the
   fantasy-C64 `hw` module. The purpose is to teach working inside tight
   constraints the way 1984 developers had to, so the constraints matter
   more than authenticity.
2. **Art:** the tutorial ships its own replacement art, and that art obeys
   the same hardware formats and limits as everything else. The real
   graphics appear only when a reader loads their own disk.
3. **Chapters:** the old chapter 7 is split into "Keys and guns" (7) and
   "Monsters" (8), giving 11 chapters plus a prologue and epilogue.
4. **Emulator:** `hw` is a very forgiving emulator. It isn't accurate; its
   job is to make the hard limits visible (memory, sprites, colours per
   cell, voices, frame budget). This repo's 6502 core is not part of the
   tutorial.
5. **Site:** lives in `site/` in this repo, with checkpoints under
   `site/code/chNN/`, deployed to GitHub Pages by this repo's Actions
   workflow.
