# Review: Chapter 3 ("Haunted Blueprints")

Reviewer scope: `site/chapters/03-haunted-blueprints.md`, its images
(`images/03-gatehouse.png`, `03-hall.png`, `03-final.png`) and
`site/code/ch03/` (diffed against `site/code/ch02/`). I checked them against
`site/AUTHORING.md` (the bible and its Decision log),
`docs/tutorial/outline.md`, `site/code/machine/REFERENCE.md`,
`machine/src/machine.zig` and `layout.zig`, the Prologue, Chapters 1 and 2,
and `reviews/ch01-review.md` and `ch02-review.md`. For the castle format I
used `reference/segrax-DrCreep/src/creep.cpp` (`roomPrepare` and every
`obj_*_Prepare`, `obj_stringPrint`/`StringPrint`, `obj_Image_Draw`,
`obj_MultiDraw`, `mapRoomDraw`, `mapArrowDraw`, `obj_Door_InFront`,
`obj_Key_Infront`, `Game`), `castle/objects/object.hpp`,
`docs/castle-format.md`, and the 1984 shape table and data bytes read out of
`disasm/object.s`. I could not test real castle files: `extracted/` is not
present in this checkout. Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-ch03/`:
- `fences.py`: extracts the chapter's 42 ```zig fences and compares each,
  label and body, with the writer's `listings.py` steps.
- `tools/` + `rebuild/my-creep/`: my own run of the rebuild, from `ch02/`.
- `rb-A` … `rb-G/`: frames from every intermediate "build and run" stage.
- `tour/`: all 20 rooms and the final room, headless (`sheet_00–05.png`).
- `clean/my-creep/`: a clean copy of `ch03/` for build, test, wasm and Boss
  Battle runs.
- `err/` + `errs.sh`: each quoted compile error, reproduced.
- `stats/`: a test that measures the castle's streams by kind.
- `hallt/`: a test showing that the kit rebuilds the hand-typed hall with
  only two bytes different (finding 11).
- `mem.py`: the 1984 shape directory at `$603B`, decoded from the
  disassembly (used for the sizes in finding 4).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** All 42 ```zig fences
  match the writer's `listings.py` steps, label for label and byte for byte.
  The only difference is one trailing blank line in A3. I checked every
  label's edit against the `ch02` file it applies to:
  - "replace the `text` region's comment and first four lines";
  - "replace the four lines at the top of the loop";
  - "replace `glyph_pixels` and the two lines below it";
  - "in `start`, replace the last two lines";
  - "replace the imports below `machine`, adding two";
  - "in `frame`'s `.title` branch, replace the last line".

  All of them say what the tool does. Applied in order, with `art.zig` and
  `training.zig` copied from the Warp Zone at the two points where the prose
  says so, the result is byte-identical to `ch03/` (all 13 `src` files plus
  `build.zig`/`.zon`). `zig fmt --check` is clean at every stage.
- **Every intermediate stage builds, tests and runs, and says what it shows.**
  - Stage A is Chapter 2's game.
  - Stage B is Chapter 2's hall with castle-coloured bricks ("Everything
    else in the room is still Chapter 2's hand-placed code").
  - Stage C has floors, ladder and pole only, with the torches and windows
    gone.
  - Stage D is pixel-identical to `03-hall.png`.
  - Stage E is pixel-identical to `03-gatehouse.png`.
- **Boss Battle:** `zig build`, `zig build test` (10/10: 9 game + the machine
  boot test) and `zig build wasm` (writes `game.wasm`, `shell.js`,
  `index.html`) succeed from a clean copy. The headless run prints the
  quoted seven lines exactly. Frames 40/80/120 are the Gatehouse, Gallery
  and Ladders rooms, and frames 240 and 299 are pixel-identical to
  `03-final.png`. The title screen is pixel-identical to Chapter 2's at
  frame 19 ("the title is unchanged, byte for byte" is true).
- **Every quoted error is verbatim:**
  - the `m.view(room.Squeezed)` padding error (when declared in
    `room.zig`);
  - `enum 'training.Room' has no member named 'galery'`;
  - `switch must handle all possibilities`;
  - all five `castle: room …` builder messages, each at `src/author.zig:298`
    (`fail`).

  Changing the test stream's lightning end byte to `0x00` does make the
  walker test fail (`expected .ray_gun, found .lightning`).
- **Numbers I recomputed:**
  - `$0154` = 340 = 256 + 9 + 75 (I counted the hall's 75 bytes).
  - The hex trace of the hall is correct, apart from one byte (finding 15).
  - 4,324 = 256 + 161 + 3,907.
  - 31 × 8 + 1 ≤ 256.
  - Text glyph 63 bytes = 3 + 48 + 6 + 6; `text_buffer_size` still 48.
  - 17 map regions.
  - 221,418 / 19,656 → 12 slots; 132,074 → 7.
  - Room frame 108 = 104 + 4.
- **The format is right, all 18 kinds.** I checked each against `creep.cpp`:
  tag codes (`$0803 + 3k`, `object.hpp`), record sizes, framing and end
  tests.
  - Counted: door (8) and bell (3).
  - Ended by 0: walkway, pole, ladder, forcefield, mummy, key, lock,
    pattern (`MultiDraw`: count, shape, x, y, dx, dy).
  - Ended by `& 0x20`: lightning.
  - Ended by `& 0x80`: ray gun, trapdoor, conveyor, frankenstein.
  - Text: records until x = 0, bit-7 strings.
  - Teleport: x, y, target, pads to a 0, one per tag.
  - Image: one per tag; size `3 + w·h + 2·w·ceil(h/8)`, exactly the
    `obj_Image_Draw` arithmetic; places to a 0.

  The header (size word including the header, `$80`, start rooms/doors,
  lives, `$5F` final pointer) and the directory are right: 8 bytes, colour
  low nibble, size bits 0–2 = rows of 8 and 3–5 = columns of 4 (that is how
  `mapRoomDraw` uses them, whatever the port's names say), objects at +6,
  end on bit 6 (`MAP_ROOM_STOP_DRAW`), visited = bit 7. The Walker's choice to test
  the marker before the first record (the 1984 loops for lightning,
  forcefield, mummy, key, ray gun, trapdoor, conveyor and frankenstein are
  do-while) is safe for any data the 1984 engine itself could read.
- **The writer's three corrections to `docs/castle-format.md` are all
  right:**
  1. Door byte 7 is the exit flag, not a door ID. `obj_Door_Prepare` uses it
     only to index the frame table at `$41D1` (`$06` normal, `$96` exit), and
     the same `X` is then overwritten by `object_Create(byte &X)`.
     `obj_Door_InFront` sets the "escaped" flag at `$785D` when it is
     non-zero.
  2. A bell's third byte is the door's index in the room's door group:
     `obj_Door_Button_Prepare` matches it against `objNumber = count`.
  3. Door byte 2 bit 7 is "open" (`if (A & 0x80)` in prepare, and
     `|= 0x80` in `obj_Door_Execute`).

  The lightning end test is `& 0x20` (`LIGHTNING_END_MARKER`), not
  `== 0x20`. On real data, whose states are `$00/$40/$80/$C0`, the two give
  the same answer. The doc is also wrong that `MultiDraw` is "not reverse
  engineered": `obj_MultiDraw` is right there, and the writer found it.
  Someone should fold these into `docs/castle-format.md`, since other
  writers will read it.
- **Lore checks out against the engine:**
  - The jump table at `$0803` (18 × 3 bytes).
  - Room colouring by repainting shape-table colour bytes
    (`roomSetColours`).
  - The open-door panel in the destination room's colour.
  - The bell in its door's destination colour.
  - Images drawn by pointing shape `$16`'s directory entry (`$6067`) into
    the castle.
  - The text style byte: bits 0–1 height, bits 4–5 pick one of four
    character sets at `$2BE8` (`$D000/$D400/$D800/$DC00`), so bit 4 really
    is "reversed" and bit 5 "the letters set".
  - The skip word (`objects + 2`).
  - The tutorial castle is 4,145 bytes in 13 rooms.

  Two lore sentences are wrong, though (findings 3 and 13).
- **Fiction:** no C64, Commodore, VIC, SID, emulator, reverse engineering,
  AI, "pretend", "in-world", real author or publisher. **Banned words:** one
  "obvious" (finding 16), and no just/simple/easy. **Exclamation points:**
  two in prose, both on real milestones ("every piece of it out of the
  castle file!", "You've built a castle!").
- **Chapter 1 and 2 promises honoured:**
  - The castle X conversion and off-left handling (`screenX`).
  - The font/style byte decision.
  - "`draw` straight at text inside the castle file."
  - Little-endian explained ("Chapter 3 says why").
  - Comptime built on Chapter 2 (the star map, `pack`, `@field`/`@tagName`)
    rather than re-taught.
  - The comptime room DSL.
  - `--key` for flipping rooms.

  The new forward promises (ch4 X scale and "the wall made of arithmetic",
  ch5 function-table dispatch and doors, ch9 header scratch and map, ch11
  disk load) match the Decision log.

---

## Findings, ranked

### 1. BLOCKER (trivial fix): "nothing in between" is false, and the Game Over box twenty lines later contradicts it

**Where:** "A struct is a row of bytes", lines 224–227, and the `game-over Why
not objects: u16?` box (237–258).

> A Zig **`extern struct`** is the other thing: its fields, in the order you
> wrote them, with nothing in front and nothing in between.

**Problem:**
- An `extern struct` follows the C layout rules, and those rules *do* put
  padding between fields to align them. The box below says exactly that:
  "Zig keeps every `u16` on an even byte ... so it slips a hidden padding
  byte in after `color`."
- So the chapter teaches a rule and then breaks it, and the correction is
  filed under "common mistakes". This is the same pattern as the Chapter 2
  shift Pro Tip, which was rated a blocker. Struct layout is this chapter's
  ladder row 3 headline.
- The layout lesson (padding, alignment) is the most important idea in the
  section, and it has no byte diagram. The outline makes diagrams "the main
  teaching tool".

**Fix:** correct the sentence. Then move the padding lesson out of the
Game Over box and into the main text, with a diagram. See weakest passage 1
for a full rewrite. Also say "the natural first try" instead of "The
obvious way" (finding 16).

### 2. SHOULD-FIX: the Keys room teaches the wrong mechanic

**Where:** `training.zig`, room 9 (`keys`):

> "SAME COLOUR AND WALK", "OVER IT TO PICK IT", "UP. THEN TRY A LOCK."

**Problem:**
- In 1984 you pick a key up by standing at it and pressing fire.
  `obj_Key_Infront` returns early when `mButtonState == 0`. Locks work the
  same way (`obj_Door_Lock_InFront`).
- The bible requires per-type behaviour to match the 1984 game. So in
  Chapter 7 either the text is wrong or the mechanic is.
- The Decision log says "check room text when the mechanic lands". This one
  is already checkable, and it's cheap to fix now, before readers copy the
  castle.

**Fix:** for example "SOME DOORS HAVE NO / BELL, ONLY A LOCK. / FIND THE KEY
OF THE / SAME COLOUR, STAND AT / IT AND PRESS FIRE. / THEN DO THE SAME AT /
THE LOCK." (7 lines, room has no upper door). I spot-checked the other rooms'
promises against `creep.cpp`, and they're right:
- push up into an open door;
- push down onto a pole, with no climbing back;
- the forcefield button is a timer;
- the transmitter takes fire to pick a pad, then up;
- Frankenstein wakes when you share his floor;
- you can't fight the mummy (trapdoors, lightning and lasers can).

### 3. SHOULD-FIX: "loaded straight to `$7800` and played where it lands" is wrong

**Where:** `inside-the-disk Castles by the kilobyte`, line 2183.

**Problem:** the 1984 game keeps the castle as loaded at `$9800`. `Game()`
(`0D71`) copies `readLEWord($9800)` bytes down to `$7800` at the start of
every game, and plays and scribbles on the copy. That is why every game
starts with all doors shut. The title sequence also tours the pristine copy's rooms
(`mObjectPtr += 0x2000` when `mIntro`). Only a *saved position* loads
straight to `$7800`. The Decision log already relies on this ("the 1984
staging area at `$9800` stays free for ch10/ch11"), so the lore contradicts
our own plan.

**Fix:** see weakest passage 4. It's a better story than the wrong one.

### 4. SHOULD-FIX: three shape footprints differ from the 1984 ones, and two of them will bite real castles

The 1984 shape directory at `$603B` (from `disasm/object.s`) gives:

| shape | 1984 (fat px × rows) | ours |
|---|---|---|
| door frame `$06` / exit `$96` | 20 × 32 | 20 × 32 ✓ |
| door panel `$07`/`$08` at (+4, +16) | 12 × 15 | 12 × 24 at (+4, +8) |
| bell `$09` | 12 × 19 | 8 × 16 |
| ladder `$28` | **4** × 8 | **8** × 8 |
| pole `$24` | 4 × 8 | 4 × 8 ✓ |
| walkway `$1B–$1D` | 4 × 8 | 4 × 7 (ch2 decision) |

None of these touches the file format. The loader and every record are
right, and Chapter 4's navigation grid is built from the records (`x/4 − 4`,
`y/8`, length), not from the art. So nothing here *breaks* loading. But the
bible asks that shape sizes "follow the original's dimensions so real
castles render correctly". My judgement on each:

- **Ladder: fix now (art plus one builder number).**
  - Our 8-wide ladder covers the byte column right of the ladder's x.
  - `drawShape` *copies* colour cells, so in a real castle whatever sits in
    that column gets repainted in the ladder's colours: a walkway end, a
    pole, a door frame's edge, a lightning machine. That is the
    4-colours-per-cell clash the whole series warns about.
  - It also puts the ladder art 2 fat pixels off the column the grid (and
    1984's climbing code, which centres the climber on x) uses, so Chapter 4
    would have to fudge the explorer's climbing x or he'd look off-centre.
  - Four fat pixels is plenty for a ladder in multicolour: `"3..3"` rails
    and a `"3333"` rung.
  - The builder's `if (kind == .ladder) 8 else 4` becomes `4`.
  - Remove the "open question" from the Decision log.
- **Bell: fix now (art plus the builder's `{ 8, 16 }`).**
  - Chapter 5's "standing in front of" test uses the object's rectangle. In
    1984 that rectangle comes from the shape (`Draw_RoomAnimObject`).
  - With an 8 × 16 bell, real castles' bells become narrower targets, and
    they are drawn 2 fat pixels left of their designed centre.
  - Matching 12 × 19 now keeps Chapter 5 behaviour-identical on real
    castles, and the overlap boxes stop baking in the wrong size.
- **Door panel: keep the deviation.**
  - It draws only inside our own 20 × 32 frame, so it can't damage
    neighbours in a real castle.
  - The reason (the 21-row explorer fits the doorway) is a fair design call.
  - Log what Chapter 5 must reconcile:
    - 1984 places the entering player at (door x + 6, door y + 15)
      (`obj_Door_InFront`);
    - its open animation runs 14 steps (`Object_field_2 = 0x0E`, shape
      `$7C`);
    - its "in front of door" rectangle is the panel's (12 × 15 at +4, +16).

  Chapter 5 should take those from named constants, not repeat `+ 4, + 8`
  inline.

The walkway's 7 rows is a Chapter 2 decision. It's harmless, but log it next
to these.

### 5. SHOULD-FIX: the builder leaves half of each door's map position at 0, so Chapter 9's "you are here" arrow will be wrong for right-wall and bottom-wall doors

**Where:** `author.door`, lines 1748–1749:

```zig snippet
.map_x = if (side % 2 == 0) @min(width - 4, (d.x - 16) * width / 160) else 0,
.map_y = if (side % 2 == 1) @min(height - 3, (d.y + 16) * height / 200) else 0,
```

**Problem:**
- `mapRoomDraw` reads only the along-wall byte (byte 5 for top and bottom
  doors, byte 6 for side doors). The builder matches that.
- But `mapArrowDraw` (the per-player arrow, coverage matrix row 21) uses
  **both** bytes for every door. The arrow goes at `(room x + byte5 +
  dx[side], room y + byte6 + dy[side])`, with `dx = {−1, +2, −1, −5}` at
  `$11DA` and `dy = {−10, −2, +6, −2}` at `$11DE`.
- With `map_x = 0`, a right-wall door's arrow lands at the room's *left*
  edge. With `map_y = 0`, a bottom-wall door's arrow lands at its top.
- The disk's own data fills both bytes. The tutorial's room 0 right-wall
  door is `mapX = 10` in a 12-fat-pixel-wide room (width − 2) and
  `mapY = 48` (castle-format.md §5).

The Training Castle is meant to be "in the 1984 castle format, down to the
last byte". Its bytes would play, but they would mean something different
from what a 1984 castle means.

**Fix:**
- Fill the across-wall byte too: `map_x = width − 2` for right-wall doors
  and 0 for left; `map_y = 0` for top and `height − 3` for bottom doors.
  That puts the arrow just outside the wall, and it matches the one disk
  value I can check.
- Prose (1790–1794): "...where it shows on the map: which wall it's in, and
  where along it".
- Decision log: replace "ch9 may refine these" with the arrow formula, so
  Chapter 9 verifies it against the disk rather than rediscovering it.
- Also fix the hand-typed hall to match (finding 11).

### 6. SHOULD-FIX: length and pacing (15,381 words: 7,296 prose, 8,085 code)

**Where:** the whole chapter. Above all, "Comptime, properly this time"
through "The Training Castle" (lines 1376–1970): about 880 prose words and
**2,279 code words** of `author.zig` in four listings, with nothing to run
until the Gatehouse appears.

**Problem:**
- The prose is inside the 4–9k guide. The total is the same size Chapter 2
  was flagged for.
- The chapter opens slowly, with four `map.zig` edits before the reader
  knows what a castle is (lines 68–130, weakest passage 2).
- The middle has the longest stretch in the series so far without a visible
  result: 300 lines of kit, typed blind.

**Fix (concrete; together these move roughly 3,000 code words out of the
reading path and cut about 600 prose words, with the exhaustiveness rule
kept):**
1. **Add a "Type-In Listing" box** (a `:::type-in` directive that the site
   renders collapsed, with a "show listing" button), and log it in the
   Decision log. It's the 1984 magazine convention, so it's on-voice, and
   it keeps every line in the chapter, in typing order.
   - Put these behind it: the 14 later-kind record structs; the walker test;
     the two `main.zig` tests and `walkRoom`; and `author.zig`'s helpers
     (`bell`, `Box`, `onScreen`, `onWalkway`, `le`, `fail`).
   - Leave in the reading path: the prose that explains them, and the code
     that teaches (`Entry`, `Size`, `Kind`/`kindOf`, `Framing`, `Walker`,
     `build`, `stream`, `door`).
2. **"Make it work, then make it strict."** Split `author.zig` into two
   steps.
   - First, `build` and `stream` with no checks. Then rewrite the
     hand-typed hall as a ten-line plan, and add a test that
     `author.build(Hall, hall_plan)` equals the hand-typed bytes. I ran
     this (`scratchpad/.../hallt/`). The kit already reproduces all 340
     bytes except the two door `map_y` bytes, which you typed as 16 and
     the kit computes as 6 and 13. Fix those two bytes in the hand-typed
     listing (and add finding 5's `map_x`), and the test passes.
   - "The compiler just wrote the same 340 bytes you typed by hand" is the
     chapter's best possible aha, and it is a run in the middle of the dry
     stretch.
   - Then add the checks, with the Game Over messages.
3. **Don't re-list `room.zig` whole at stage C** (line 954). It re-types
   `paint`, `roomColors` and `both`, which were typed six listings earlier.
   Use "replace `draw`; add `prepare`, `walkway` and `column` at the end"
   (about −25 lines).
4. **Move each map edit to where it's needed** (weakest passage 2):
   - `castle` next to "Boot copies the castle into its region";
   - the `text` growth to "The text style byte";
   - `room_number` to "Flipping through the castle".

   The `regions` listing appears once, at the first of them. This costs
   nothing and fixes the cold open.
5. **Prose trims:**
   - The `Framing` explanation after the code repeats the doc comments.
   - The "Three things to look at" coordinate paragraph re-explains
     Chapter 2's fat pixel.
   - The Byte Budget's time paragraph can lose its second half.
   - The table of 21 rooms (lines 1943–1965) duplicates the room comments.
     Keep it (it's useful), but cut the paragraph after it to one sentence.

### 7. SHOULD-FIX: a walkway, ladder or line that starts off the left edge vanishes completely

**Where:** `room.walkway`/`column`/`line`/`image`:
`castle.screenX(...) orelse return`.

**Problem:**
- The 1984 blitter clips on the left, so a walkway starting at X = 8 draws
  from the screen edge on. Ours drops the whole walkway.
- The Training Castle can't do this (the builder refuses X < 16), but
  Chapter 11 loads real castles unmodified. A walkway whose hidden left end
  starts at 8 or 12 would disappear, and so would the floor under the player
  (visually; the grid would still have it).
- I can't check the 14 real castles here (no `extracted/`).

**Fix (cheap, and right for real data):** in `walkway`, step the pieces
and skip the ones whose X is below 16, rather than returning. Pieces are
4 fat pixels, exactly one byte column, so there's no partial-piece clipping.
Do the same in `image`'s place loop (it already does, via `continue`). Log
it in the Decision log, and add a Chapter 11 note to check the real castles
for X < 16 and Y ≥ 200.

### 8. SHOULD-FIX: comptime idioms used without a word (`anytype`, `noreturn`, `[0..n].*`)

**Where:** `author.bell(comptime room: anytype, …)`, `onWalkway(comptime
room: anytype, …)`, `fail(…, args: anytype) noreturn`, and
`directory[0..directory.len].*` / `out[0..out.len].*` in `build` and `says`.

**Problem:** Chapter 2's review flagged the slice-to-array `[0..len].*` as
unreadable, and Chapter 3 is "comptime, properly". Yet `anytype` (new),
`noreturn` (new) and `[0..len].*` get no explanation. A JS dev will read
`anytype` as TypeScript's `any`, which is wrong: it's checked per call.

**Fix:** one paragraph after `fail`:

> Three small things in the helpers. `anytype` means "whatever type the
> caller passes": Zig compiles a copy of the function for each type it's
> called with and checks every use, so it's TypeScript generics without
> writing the `<T>`, not `any`. `noreturn` is the type of a function that
> never comes back; `fail` ends the build, so Zig lets you call it where a
> value was expected. And `x[0..x.len].*` turns a compile-time slice into an
> array value, the thing you can freeze with `const` and point at
> (Chapter 2's `const done = ...; &done`).

### 9. SHOULD-FIX: the Byte Budget leaves out the castle's second copy, and its numbers don't add up

**Where:** `byte-budget Chapter 3`, lines 2161–2178.

- **The second copy.** `training.bytes` is a `const`, so all 4,324 bytes
  also sit in the program image, as the table `m.load` copies from. That is
  the same honest-accounting point Chapter 1 makes about `var`s. Add: "For
  now the castle is in memory twice: once in the program image, as the
  table `boot` copies from, and once at `$7800`. Chapter 11's disk drive
  removes the first."
- **Text.** "2,876 bytes, is text: 2,316 letters". That leaves out the final
  room's three lines (41 letters) and every room's text tag and end byte.
  Measured (`scratchpad/.../stats/`): text records come to 2,929 bytes in
  143 lines and 2,357 letters, or 2,992 with tags and end bytes. Either
  quote those, or say "in the twenty rooms". Update the Decision log either
  way.
- **The pause.** "a fifth of a second of blank screen at worst": 12 slots
  is 240 ms, about a quarter of a second.

### 10. SHOULD-FIX (low): small inaccuracies in the format prose

- **Line 696:** "The machines need other markers, because their first byte
  is a state that can be 0". The mummy's first byte is a state too, and it
  ends on 0. Say "...because their state byte can be 0 (a mummy's never
  is, so mummies end on 0 like the rest)".
- **Line 724, `Framing.marked` doc comment:** "a byte with bit `end` set".
  `end` is a mask (`0x20`), not a bit number. Say "a byte with any of
  `end`'s bits set".
- **Line 1158:** "with 0 counting as 1". In 1984 only a whole style byte of
  0 means height 1. `$20` gives height 0 there (`mTextFont & 3`). Ours is
  more forgiving, which is fine, but say "a style of 0 counts as plain".
- **Line 1078:** "castles store shape IDs, so existing IDs mustn't move".
  That's true, but real castles store **1984** shape IDs. Key records carry
  shapes around `$50 + colour`, and `Id` doesn't match the 1984 numbering.
  Add a Decision-log note for Chapters 7 and 11: real Key records need a
  1984-ID → `Id` translation, or reserved IDs.

### 11. SHOULD-FIX (low): the hand-typed hall's door map bytes don't match its own builder

**Where:** `training.zig` (hand-typed), lines 380–381: `…, 0, 16, 0`.

**Problem:**
- The hall's two doors carry `map_y = 16`. The kit computes 6 and 13 for
  the same doors.
- With finding 5, door 1 also wants `map_x = 14`.
- Nothing reads these bytes yet, but if the bytes match, the comparison test
  from finding 6.2 becomes possible.

**Fix:**
- Door 0: `32, 40, 3, 0, 1, 0, 6, 0`.
- Door 1: `152, 96, 1, 0, 0, 14, 13, 0` (with finding 5).
- Update the hex trace at line 535 to match.

### 12. NIT: plain `struct` vs `extern struct` is never contrasted

**Where:** "A struct is a row of bytes".

The reader meets `Walker`, `Record`, `Map`, `Line` and `Box` as plain
`struct`s and `Entry`/`Run` as `extern struct`s, and is never told the
difference. One sentence: "A plain `struct`, like `Walker` below, is
Zig's JS object: the compiler may reorder and pad its fields however it
likes, so it's for working values, never for bytes on a disk. Only
`extern` (or `packed`) promises a layout." Also, line 219 ("its fields in
whatever order the engine likes") is wrong about JS. Engines keep
properties in insertion order. What they hide is the *layout*: "laid out
however the engine likes".

### 13. NIT: two lore sentences that a stickler would catch

- **Line 563:** "`$0821` ... The engine's own title screens use it; no castle
  does." The title data actually carries tag `$160A`, the MultiDraw
  routine's *own* address, not its jump-table slot. The title text uses
  `$2A6D`, the text routine (`mRoomIntroData`). That's better lore: "The
  title screens don't even bother with the table: their tags are the
  routines' own addresses, `$160A` and `$2A6D`. Proof, if you wanted it,
  that a tag is nothing but an address." A related fact, if you want it:
  `roomPrepare` writes each tag into the operand of its own `JSR` at
  `$1600` and calls it.
- **Lines 567–568:** "Our tags can't be addresses in our own program,
  because Zig decides where our code goes". In the fiction, the 1984 game
  is Zig too, and it pinned a table at `$0803`. A better reason is one the
  junior will remember: "Every castle ever written depends on that table
  never moving, so the 1984 engine pinned it at `$0803`. Our functions
  live wherever the compiler puts them, so we turn the tag back into a
  kind."

### 14. NIT: bridges and syntax that would help a JS/Python reader

- **Little-endian (151–173).** The reasoning is good. Add the bridge the
  reader may have seen: "If you've used `DataView`, this is the `true` in
  `view.getUint16(0, true)`".
- **Iterator (776).** "like a Python iterator's `__next__`, handing back
  `null` instead of raising `StopIteration`; `while (w.next(m)) |r|` is
  Zig's `for r in walker`."
- **Sentinels.** The Power-Up has no bridge. "JS arrays carry their
  `.length`; a C string doesn't, it ends on a 0 byte. The castle is the C
  kind."
- **Line 1059–1061:** "`align(1)` says it may sit at any address, odd or
  even (which is why the machine only allows views of types without
  padding)". The "which is why" doesn't follow. Say "...odd or even.
  (Padding is a separate question: the machine refuses any type with
  padding, because the hidden bytes wouldn't match memory.)"

### 15. NIT: the hex trace misses an `L`

**Where:** line 540: `54 48 45 20 ... 48 41 CC  00`.

"HALL" is `48 41 4C CC`, so as printed the string reads "...HAL". Write
`... 48 41 4C CC  00`.

### 16. NIT: wording and small slips

- **Line 238:** "The obvious way". Say "The natural first try".
- **Line 2211:** "N does nothing, or skips two rooms". Without the
  acknowledge, the key stays latched and the game races through a room
  every loading pause. Say "**N races through the rooms.**"
- **A headless `--key` that lands on a skipped loading-pause slot is
  lost** (Decision log), and the chapter never says so. A reader who types
  `--key 60:N --key 65:N` gets one flip. Add a Game Over bullet, or a
  clause in the Boss Battle ("keys are 40 frames apart so each lands after
  the previous room has drawn").
- **The two tests count rooms two ways:**
  `@typeInfo(training.Room).@"enum".fields.len` in one and
  `std.enums.values(training.Room).len` in the other. Use one.
- **"Perhaps the castle editor needed it"** (2189). There's no castle
  editor in the reader's world. "Perhaps the tools that built the castles
  needed it" says the same thing.

### 17. NIT: the Training Castle's text and art (judgement)

- **The text is good:** in the guide's voice, one lesson a room, with some
  real jokes ("GOODNIGHT, FRANKENSTEIN!", "HOW FAST CAN YOU GET HERE?",
  "THERE'S NO CLIMBING BACK UP A POLE, SO LOOK FIRST."). Apart from finding
  2, the rules it states are the 1984 rules.
- **The layout:** body lines start at X = 16, flush against the left edge
  of the display, and 20-letter lines touch the right edge too. With 2-row
  leading, the top half of every room is a dense block. One byte of margin
  (`says` body at X = 20, 19-letter lines) would make every room look more
  designed. It means rewrapping about 20 lines, and the builder enforces
  the new limit for free.
- **The Long Gallery** teaches "THE END OF A WALKWAY IS AS FAR AS YOU GO" in
  a room whose only walkway ends at the walls. Chapter 4 brings rooms 1–3
  alive, so give it a visible end now: for example, door 1 at X = 132, and
  the floor stopping at X = 156 with dark stone beyond. It isn't long,
  either. Its geometry is the Gatehouse's.
- **Sameness:** 9 of the 20 rooms are floor, two arches and a bell. That's
  fine for static geometry (the log says machines will reshape them). But
  the chapter has just shown that a castle can carry *pictures*, and
  "The windows and torches are gone: the castle format has no torches"
  (1071) is a missed opportunity. Make a Bonus Stage: "Bring the torches
  back as Image objects." That decorates the rooms with the chapter's own
  tool.
- **The final room** reads well (trophy, sparkles, two centred lines). The
  sparkles are tiny at 1×.
- **The doors** (stone arch, oak planks, iron bands and ring) and the green
  exit arch with its star are charming. The bells read as bells.
- **Alt text** is accurate for all three images.

### 18. NIT: ladder-row bookkeeping for later chapters

The chapter uses three later-row ideas in passing. None of them is taught
early, which is right. Log them so the later chapters refer back:
- the directory as "room *n* at `$7900 + n × 8`" (row 5, arrays of structs
  as one block);
- bells and doors naming each other by index (row 6, linking by index);
- `-%` (row 4).

Cost accounting is honest overall. Four loops charge no loop overhead
against the card's `m.work(2)` per pass convention: `stringEnd`,
`placesEnd`, `roomCount` and `image`'s place loop. That's a nit, but the
card asks for it.

---

## The weakest passages, with rewrites

1. **"A struct is a row of bytes" plus the padding Game Over box**
   (findings 1, 12). Replace lines 224–235 and fold the box in:

   > A Zig **`extern struct`** is the other thing: a promise about bytes.
   > Its fields sit in the order you wrote them, nothing in front, laid out
   > by the same rules every compiler on every computer agrees on. Declare
   > the entry as one, and `@sizeOf(Entry)` is 8, `@offsetOf(Entry,
   > "objects")` is 6, and the struct *is* the format. (A plain `struct`,
   > like the `Walker` you'll write soon, makes no such promise. Zig may
   > shuffle its fields, which makes it Zig's JS object: fine for working
   > values, useless for a file.)
   >
   > Those agreed rules have one catch. A `u16` likes to start on an even
   > address (its **alignment**), so try the natural first version of a
   > record whose word follows a single byte:
   >
   > ```
   >   extern struct { color: u8, objects: u16 }
   >
   >   byte:    0        1          2        3
   >          ┌───────┬──────────┬────────┬────────┐
   >   Zig:   │ color │ (padding)│ obj lo │ obj hi │   4 bytes
   >          └───────┴──────────┴────────┴────────┘
   >   disk:  │ color │  obj lo  │ obj hi │            3 bytes
   > ```
   >
   > Zig slips in a byte you never asked for, and every field after it
   > reads one byte late. The Comet's processor doesn't care where a word
   > starts, and the castle format packs its bytes tight wherever they fall
   > (the header's final-room word sits at `$5F`, an odd offset). So castle
   > words are `[2]u8` in our structs, read with `m.peek16`, and the
   > machine refuses to `m.view` any type with padding, at compile time,
   > with this message: (error block)

   Keep `game-over` for real mistakes (finding 16's).

2. **The cold open of "Room for a castle"** (lines 68–130; finding 6.4).
   The reader gets four memory-map edits for a castle they haven't met yet.
   Open the section with the castle instead:

   > A castle file starts with a **header**, 256 bytes, and it lives at
   > `$7800`, the first byte of free memory above the program image...

   Put the `castle` region listing where boot first loads the castle ("It
   needs somewhere to land: an 8 KB region from `$7800`, room for any
   castle on the 1984 disk"). Put the `text` growth in "The text style
   byte", where "you'll see why later" becomes "which is why the glyph's
   scratch shape has to grow from 23 bytes to 63". Put `room_number` in
   "Flipping through the castle".

3. **"Loops that change type"** (lines 1418–1426). This is the hardest idea
   in the chapter, and it has no bridge:

   > **Loops that change type.** In JavaScript you'd write
   > `for (const kind of KINDS) writeGroup(room[kind])` and never think
   > about it, because every value is "anything" until it runs. Zig has no
   > "anything" at run time: `room.door` is a list of doors, `room.text` a
   > list of lines, and an ordinary loop's body has one type per variable.
   > So **`inline for`** asks the compiler to write the body out once per
   > kind, eighteen copies, each with its own types. `@field(room,
   > @tagName(kind))` (Chapter 2's trick for finding art by name) picks the
   > room's list for that kind, and a `switch` on a kind the compiler
   > already knows keeps only the branch for it. The loop vanishes before
   > the program runs; what's left is eighteen straight-line blocks.

4. **"Castles by the kilobyte"**, first paragraph (finding 3):

   > The fourteen castles on the 1984 disk run from about 2 KB to about
   > 6 KB each; the disk's own tutorial castle is thirteen rooms in 4,145
   > bytes. A castle file loads to `$9800` and stays there untouched (the
   > title screen tours its rooms from that copy). Each time you start a
   > game, the engine copies it down to `$7800` and plays the copy, because
   > playing *writes* to it: the header's spare bytes fill with your notes,
   > and an open door is a door record with bit 7 set. Start again and
   > you get a fresh copy, every door shut.

5. **The walker walkthrough** (lines 879–890). This is the heart of the
   chapter, explained in one flat paragraph. Replace it with a trace of the
   hall bytes the reader typed:

   > | `at` | reads | does |
   > |---|---|---|
   > | `$7909` | `03 08` | tag: doors, counted |
   > | `$790B` | `02` | two of them |
   > | `$790C` | 8 bytes | → door 1 of 2 |
   > | `$7914` | 8 bytes | → door 2 of 2; count is 0, `continue` |
   > | `$791C` | `06 08` | tag: walkways, marked by 0 |
   > | … | … | … |
   > | `$7952` | `00 00` | end tag → `null` |

   Then the two sentences on `continue` and `orelse` that are already there.

---

## What works well (keep these)

- **The hand-typed castle, then its own downfall.** The reader types 340
  bytes, counts along, and is told "Change the hall by a single byte and that
  size is wrong, and nothing tells you. Hold that thought." The thought is
  paid off by a builder that refuses a door that doesn't lead back. This is
  the outline's "experience before mechanism" done with data. Finding 6.2
  would make it even stronger.
- **"The tag is the address"** is a superb Inside the Disk box: true to the
  byte, and it ends on a line a junior will repeat ("the data carries the
  address of the code that reads it"). Turning it back into a 54-entry
  lookup table is a nice callback to Chapter 2's Power-Up.
- **The format is exact.** Every one of the 18 kinds frames and sizes as
  `creep.cpp` does. The writer caught three real errors in our own research
  doc and verified each against the engine. The walker test is written
  against bytes "nobody generated", including the do-while-sensitive
  lightning group.
- **The reader and the writer share one definition.** The builder writes
  `std.mem.asBytes(&castle.Entry{...})`, the loader views the same struct,
  and `walkRoom` uses the same `inline for` over `Kind`: "If the writer and
  the reader ever disagreed about one byte of the format, this test would be
  the first to say so." That's the right lesson about formats.
- **Compile-time validation with real messages,** quoted verbatim and named
  by room. The anecdote "The last one caught a line in the Training Castle
  while it was being written" is exactly the senior-dev voice.
- **"A pointer doesn't care what it points at"** in the Image section.
  Pointing the spare `image` directory entry into the castle is a lovely
  aha, it's what the 1984 engine does, and it pays off Chapter 2's promise
  that one blitter would serve both.
- **Room colouring by repainting the shape table** is explained from the
  1984 trick, and it's why the walkway art changed. "the room changes the
  pictures instead of the pictures taking orders" is a great line.
- **Comptime done properly, built on Chapter 2.** It has "same language,
  earlier", types as values with a TypeScript bridge, the branch quota
  explained, a misspelled room as the payoff of typed names, and
  `EnumFieldStruct` making "leave a room out and it doesn't build" free.
- **Engineering rigour:**
  - 42 listings rebuild `ch03` byte for byte, and every stage builds,
    tests and runs.
  - Every number in the Boss Battle is verbatim, and all three screenshots
    are pixel-exact.
  - The title is pixel-identical to Chapter 2's after `text.draw` was
    rewritten.
  - The loading-pause pattern from the Chapter 2 review is kept.
  - Bucket ids are stable, and nothing bypasses the memory map.
- **Voice:** warm, quick, and not condescending, with two earned
  exclamation points. The Under the Hood JSON box ("contains no names at
  all: where a byte sits says what it means") is the ladder's JS-bridge
  method at its best.
