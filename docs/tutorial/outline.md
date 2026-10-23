# Tutorial outline — "The Castles of Dr. Creep, written in Zig"

*Draft 1 — high-level flow for review. Chapter-level detail comes once the
flow is approved.*

## The premise

We pretend that in 1984 Ed Hobbs wrote *The Castles of Dr. Creep* in Zig
rather than 6502 assembly, for a machine with the C64's limits: 64 KB of
RAM, a ~1 MHz CPU, a 50 Hz frame, a 320×200 screen with four colours per
8×8 cell, eight hardware sprites, and a three-voice synth. The tutorial
builds that game from an empty directory to a working copy, and the
machine's limits shape every design decision along the way.

Because this repo reverse-engineered the real binary, every design choice
in the tutorial is one the original actually made (the real addresses,
table sizes and data formats are documented in `docs/` and `disasm/`). The
tutorial presents them as decisions a designer would make, and adds
"what the original did" sidebars that link back to the disassembly.

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
| 6 | Exit door / escaping the castle | Door (exit flag) | escape sequence | 8 |
| 7 | Lightning machines + switches | Lightning | sprite actor, switch→machine links | 6 |
| 8 | Forcefields + timer button | Forcefield | countdown timer object | 6 |
| 9 | Trapdoors + switch | Trap door | floor removal, grid update | 6 |
| 10 | Conveyors + control | Conveyor | belt moves actors, direction state | 6 |
| 11 | Matter transmitter | Teleport | colour-cycled destination pads | 6 |
| 12 | Keys | Key | per-player inventory | 7 |
| 13 | Locks | Lock | key colour → door id | 7 |
| 14 | Ray guns + control panel | Ray gun | tracking AI, laser actor, player control | 7 |
| 15 | Mummy + ankh trigger | Mummy | tomb release, pursuit AI | 7 |
| 16 | Frankenstein | Frankenstein | wake, chase, die (trapdoor/lightning/ray) | 7 |
| 17 | On-screen text | Text | bit-7-terminated strings | 2/3 |
| 18 | Images / final room | Image | multi-placement blit, ending reveal | 8 |
| 19 | Two players at once | — | per-player state, shared room | 8 |
| 20 | Lives, death, respawn | — | flash/die lifecycle | 5 |
| 21 | Castle map | room directory | reveal-as-visited, "you are here" arrows | 8 |
| 22 | Timer & high scores | — | BCD time, initials entry | 8/10 |
| 23 | Save/load position | — | save files, disk I/O | 10 |

Combination rooms to include (each one stress-tests an interaction):
Frankenstein + trapdoor, Frankenstein + conveyor, ray gun + forcefield,
mummy + lightning, key behind a teleport, and two players needing to
cooperate on a switch.

## The machine we target

The reader writes the game against a small **"fantasy C64"** module,
`hw`, written in chapter 1 and provided as a package after that:

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
- Shells: native window (sokol, as in `src/app.zig`) and wasm32-freestanding
  (as in `src/wasm.zig`) for the website.

Stretch appendix: compile the same game for a real 6502 via the llvm-mos
Zig fork (see open questions).

## Website shape (the "semi-interactive" part)

- One page per chapter: prose + code listings + an embedded wasm build of
  **that chapter's checkpoint** running in the page.
- Every chapter ends at a runnable checkpoint (a git tag in a companion
  repo, e.g. `ch04-done`), so readers can diff against it or skip ahead.
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
- "What the original did" sidebars linking into `disasm/object.s`.

---

## Chapters

### Prologue — The rules of the game
What we're building and the fiction around it. A tour of the finished
game. The budget: 64 KB, 50 Hz, 8 sprites, 4 colours per cell, 3 voices.
How to read the site and use the checkpoints. Zig 0.16 setup.

### 1. A machine in 64 KB
Build `hw`: the RAM array, the comptime memory map, the frame loop and its
interrupt, the work meter, joystick input, and the native and wasm shells.
**Techniques:** no allocator; comptime layout checks; shadow registers
written once per frame; why a fixed frame budget beats "as fast as
possible".
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

### 7. Keys, guns, and monsters
Per-player key inventory, and locks matched by colour to door id. Ray guns
that track the player, plus the control panel that lets the player drive
them; the laser as a short-lived actor. Mummies released by the ankh, and
Frankenstein waking, chasing, and dying in trapdoors, lightning and ray
fire. A tiny LFSR random number generator.
**Techniques:** AI as a handful of bytes of state; pursuit without
pathfinding (using the nav grid); recycling actor slots; deterministic
randomness for replays and tests.
**Checkpoint:** every mechanic in the coverage matrix works, plus the
combination rooms.

### 8. The whole castle
Turn rooms into a game: the **castle map** (drawn from the room directory,
revealed as you visit, arrows per player), two simultaneous players with
per-player state, lives and game over, a running BCD timer, the exit door
and escape sequence, and the final Image room's piece-by-piece reveal.
**Techniques:** reusing the castle buffer as runtime state (the header's
scratch area); BCD for cheap display; drawing the map from data the game
already has.
**Checkpoint:** play the Training Castle from start to escape, alone or
with two players.

### 9. Three voices
A SID-style synth, then the **music bytecode** (notes, waits, tempo,
voice control) and its interpreter, driven from the frame interrupt. Sound
effects reuse the same interpreter by taking over its stream pointer.
**Techniques:** one interpreter for music and SFX; note frequency tables;
streaming commands instead of storing samples; deciding what a sound is
allowed to interrupt.
**Checkpoint:** title music and gameplay sound effects.

### 10. The shell: title, menus, disk, scores
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
and cycles went). Appendix: running on real 6502 hardware.

---

## Open questions for you

1. **Target machine:** is the fantasy-C64 `hw` module with a work meter
   the right level? The alternatives are (a) plain modern Zig with
   self-imposed limits (simpler, less authentic), or (b) actually
   compiling for the 6502 via llvm-mos (most authentic, but toolchain
   maturity is a real risk and it would dominate the tutorial).
2. **Art assets:** the sprites and room shapes live inside the copyrighted
   binary. Options: ship original replacement art for the tutorial,
   with the real graphics appearing when you load your own disk
   (recommended); or require the disk from chapter 2 onward.
3. **Chapter split:** chapter 7 is heavy (keys + ray guns + two monsters).
   It could split into "Keys and guns" and "Monsters", with 9 and 10
   merged into one chapter. That keeps the count at 10.
4. **Relationship to this repo:** the tutorial's game is a clean-room
   native Zig implementation, separate from this repo's emulator/lift
   approach. Should the emulator appear in the tutorial (e.g. as a
   differential tester: "your handler vs the original"), or stay purely
   behind-the-scenes in the sidebars?
5. **Where the site lives:** a `site/` directory in this repo with its own
   build step, or a separate repo for the tutorial plus companion code?
