# Review: Chapter 4 ("Creaky Floorboards")

Reviewer scope: `site/chapters/04-creaky-floorboards.md`, its images
(`images/04-ladders.png`, `04-grid.png`, `04-poles.png`) and `site/code/ch04/`
(against `site/code/ch03/`). I checked them against `site/AUTHORING.md` (the
bible and the Decision log, including the writer's new ch04 entries),
`docs/tutorial/outline.md`, `site/code/machine/REFERENCE.md` and
`machine/src/machine.zig`, the Prologue, Chapters 1–3, and the ch01–ch03
reviews. For 1984 behaviour I used `reference/segrax-DrCreep/src/creep.cpp`
(`obj_Walkway_Prepare`, `obj_SlidingPole_Prepare`, `obj_Ladder_Prepare`,
`positionCalculate`, `word_3C_Calculate`, `obj_Player_Execute`,
`KeyboardJoystickMonitor`, `obj_Player_Add`) and the data bytes in
`disasm/object.s` (`$2F82`, `$34D7`, `$34DF`, `$5F59`). I could not test real
castle files: `extracted/` is not in this checkout. Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-ch04/`:
- `cmp.py`: pulls the chapter's 47 labelled ```zig fences and compares each one,
  label and body, with the writer's `listings.py` steps.
- `rebuild/`, `rb-A` … `rb-F/`: my run of the writer's `rebuild.py` (`WORK=` set
  to this folder).
- `code/ch04/`: a clean copy for build, test, wasm and the Boss Battle. Its
  `src/main.zig` has two extra review-only tests: "REVIEW explore" (an
  exhaustive search of every room, below) and "REVIEW costs" (the meter numbers).
- `boss/`, `grid/`: fresh headless frames. `cmpimg.py` diffs them with the
  chapter's PNGs.
- `pan/`: the `x * 2 - 8` panic, reproduced in Debug and ReleaseFast.
- `errs/`: the quoted compile errors (writer's `errs.py`, rerun).
- `frames.png`, `zoom.png`, `sheet.png`: the new art and in-game close-ups.

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py` finds 47 fences, all
  matching `listings.py` in label and body, in order. There is one prose-only
  deletion ("Delete `min_x` and `max_x` and the comment above them") and the
  `art.zig` copy. The rebuild is **byte-identical** to `ch04/`. Stages A, B0,
  B, C, D, E and F each pass `zig fmt --check`, `zig build` and
  `zig build test`, and each one runs. What the prose says each stage shows is
  true: in stage A he walks edge to edge and in mid-air in Sliding Poles; in
  stage C he climbs in his walking pose; in stage D he has his climbing pictures.
- **The checkpoint is green.** On a clean copy, `zig build`, `zig build test`
  (18/18: 17 game + the machine's), `zig build wasm` (writes all three `web/`
  files, ReleaseSafe) and `zig fmt --check src` all pass. The Boss Battle prints
  the quoted block exactly: `950 calls`, `max 229244 (1166%)`, buckets
  318/228272/956, `loading pauses: 5`.
- **The screenshots match fresh runs pixel for pixel.** `04-ladders.png` is
  `frame_00330`, `04-poles.png` is `frame_00690`, and `04-grid.png` is frame 199
  of `--frames 200 --press 20:f:5 --key 60:N --key 100:N --key 140:G`, all at 2×
  nearest. Frame 520 does show him at the upper right door, as the Boss Battle
  says.
- **The quoted errors are verbatim.** They are `memory map: player overlaps
  game`, the pole message, and `expected type 'u3', found 'u8'`. The
  `x * 2 - 8` snippet compiles and panics with `panic: integer overflow`, caret
  under the `*`, in `place` (column 29). In ReleaseFast the same build runs on
  and wraps silently, as the prose says.
- **The navigation grid matches 1984 bit for bit.**
  - Walkway: piece 1 is right (`$04`), the last is left (`$40`), the middle is
    both, and length 1 is right only. That's `obj_Walkway_Prepare` with a 1-byte
    piece.
  - Ladder: up unless it's the top piece, down unless it's the bottom, and
    nothing for length 1 (`obj_Ladder_Prepare`: `Height != first` → `|1`;
    `--Height != 0` → `|0x10`).
  - Pole: `|0x10` on every piece (`obj_SlidingPole_Prepare`).
  - Column `x/4 − 4` and row `y/8` are `word_3C_Calculate`.
  - The direction bits are `$2F82`'s `1 << d`.
- **The movement is faithful.**
  - The stick table equals `$5F59` entry for entry. I checked all 16, including
    up+down and left+right giving `$80`.
  - The step tables equal `$34D7`/`$34DF` (`00 01 01 01 00 FF FF FF` /
    `FE FE 00 02 02 02 00 FE`).
  - The want/last/adjacent rule matches `$33A3–$33D6`, and so do the snaps:
    `x −= fx&3; x++` going up/down and `y −= fy&7` going sideways.
  - The feet are `mWidth = 3`, and 1984's `mHeight = 17` is correctly scaled to
    21.
  - The doorway offsets are `+6` and `+15 → +11`, so the boots land at door
    y + 32 in both games.
  - The 1984 mid-row and edge masking only touches diagonal bits, plus
    left/right in cells with no up/down that the feet can't be mid-row in, so
    leaving it out changes nothing. The Decision log's reasoning holds.
- **The pole data-rule change is right, and honestly told.** In 1984 the pole's
  last piece also gets `|0x10`. Walkways come first in tag order, so a pole
  ending on the floor would open "down" out of the floor cell. There is no
  falling or floor test in `obj_Player_Execute`, so he would slide into the
  empty row under it and stay there with no ways out. The 1984 drawing code
  agrees: a pole piece on a walkway cell (`& 0x44`) is drawn with the
  through-floor shape `$27`, which only makes sense where a pole crosses a
  floor, not where it ends. Real castles must end poles one row above the
  walkway, so the new builder rule is what real data needs. The prose states it
  as the 1984 rule and says plainly that Chapter 3's rule was wrong ("Fix the
  rule"). The picture doesn't suffer: the 8-row bottom piece still meets the
  floor's top edge (`04-poles.png`). I couldn't confirm it against a real
  castle file. Add a ch11 Decision-log note: "verify poles end one row above a
  walkway in the real castles."
- **The exhaustive play-test is clean.** "REVIEW explore" runs a breadth-first
  search over every (x, y, last-way) state reachable from each room's spawn,
  under all nine stick positions, calling the real `player.steer`. It covers
  all 20 rooms and the final room (400–940 states per room). It found:
  - No state with his feet over an empty cell (never in mid-air, never through
    a floor).
  - No feet below row 200, and X never below 16.
  - No state on a ladder or pole with his feet off the rung column
    (`fx % 4 == 1` always).
  - Walkway ends exactly where the rule says: Long Gallery x 16–149; upper
    walkways stop at x 89 (20 pieces from 16) or run 96–169; full floors run
    16–169.
  - The only ladder and pole columns visited are x 54, 70, 110 and 134, which
    are the four rung columns.

  Every ladder can be climbed both ways, every pole only down, and you can
  step off at every top. The only oddity is cosmetic (finding 8).
- **The cycle numbers I re-measured are right, except where finding 1 says
  otherwise.** A frame between steps is 88 cycles. A standing step is 196, a
  walking step 204, a climbing step 228. A picture change adds 628. Walking with
  S is 1,626 and climbing with S is 3,700. `grid.at` is 20. The worst room
  draws in 229,244 cycles (12 slots). I didn't re-measure the 141,776 low end. The shape table goes from 1,716 to 1,951 bytes
  (5 × 45 + 5 × 2).
- **The fiction holds.** I grepped for C64/Commodore/VIC/SID/emulat/reverse/
  disassembl/pretend/AI/repo/6502/author names and found nothing. The "1984
  game" lore all checks out.
- **No banned words.** Every "just" in the chapter means "just above" (a
  position). There are two exclamation points in the prose, both earned ("He
  climbs!", "He knows the castle!").
- **Chapter 1's promise is kept.** The wall at 255 is gone via fat pixel + 16,
  the overflow story is told, and the "three quarters of the way across" setup
  comes back as the opening hook. Chapter 3's promises are kept too ("teaches
  him the castle", past the wall). Ch2's flags byte and ch3's `packed struct`
  are referred back to, not re-taught. `@intCast`, used without a word since
  ch2, finally gets explained. That's a debt paid.
- **Scope matches the outline's ch4** (grid built at load time, bitfield cells,
  8-bit coordinates and wrapping, the per-frame search cost lesson, rooms 1–3
  playable). It has two genuinely new ladder ideas (fixed-width integers with
  overflow/wrapping and two's complement; the 2D grid in 1D). Nothing comes in
  early from later rows.
- **Length is fine:** 6,037 prose words + 4,442 code (`wc.py`). That's well
  inside the guide and much leaner than ch03.

## Findings, ranked

No blockers.

### 1. SHOULD-FIX: the search cost in the table and the text is wrong

Location: "What the grid saved": the table row "finding the way out of one
cell | 20 cycles | about 1,170", and the paragraph that follows it, "A search
costs between 850 and 1,380 cycles depending on the room". The Decision log
repeats both.

Evidence: I timed `grid.search` directly on the `m.cycles` counter, for every
room, from a drawn room. It costs **1,114 (room 17) to 1,642 (room 0)**. The
Ladders room is **1,438**, and the final room is 1,308. The chapter's own
measured step costs agree with this, not with 1,170:
- Walking with S is 1,626 = 204 − 20 + 1,442.
- Climbing with S (two lookups) is 3,700 = 856 − 40 + 2 × 1,442.

The outline says "every number is right", and this is the chapter's headline
number.

Fix:
- Table: "about 1,440".
- Paragraph: "A search costs between 1,100 and 1,650 cycles depending on the
  room".
- Correct the Decision log ("Costs at ch04" and "Navigation grid format").

### 2. SHOULD-FIX: "eight searchers vs eight grid readers" compares a whole step with a lookup

Location: "Eight searchers climbing would cost 30,000 cycles a step, a frame and
a half, before anything has been drawn. Eight grid readers cost 320."

Problem: 30,000 is 8 × 3,700, the whole climbing step with its picture change.
320 is 8 × 2 × 20, only the lookups. The like-for-like figures are:
- Whole climbing steps: 8 × 856 ≈ 6,850 against 8 × 3,700 ≈ 29,600.
- Lookups only: 8 × 2 × 1,440 ≈ 23,000 against 320.

Either pair makes the point, and a sharp reader will check this sentence
against the table above it.

Fix (lookups version): "Eight searchers climbing would spend 23,000 cycles a
step just asking the question, more than a whole frame, before anything has
been drawn. Eight grid readers spend 320."

### 3. SHOULD-FIX (low): G sends the explorer back to the doorway, and the prose doesn't say so

Location: "Seeing the grid" ("Press **G** and the room is drawn again with the
grid over it") and the Boss Battle's "G for the grid".

Problem: `debug.keys` returns true for G, so the game goes to `.draw_room`,
which calls `player.enter`. A reader who presses G halfway up a ladder to see
why he stopped is teleported back to the first door. That's surprising, and it
looks like a bug they caused. The Decision log knows about it ("the explorer
re-enters at the door"); the reader doesn't.

Fix: add one clause: "Press **G** and the room is drawn again with the grid
over it (drawing a room puts the explorer back in its doorway, so look first,
then walk)." Alternatively, don't call `enter` after a G redraw. That costs code
and a new mode, so the prose fix is better.

### 4. SHOULD-FIX (low): the climbing-picture rule deviates from 1984, and the landing pose isn't mentioned

Two related gaps.

(a) Location: Decision log, "Movement rules (1984 `obj_Player_Execute`, kept
exactly)" and "Shape IDs (ch04)". In 1984 the ladder-or-pole picture choice is
`byte_34D5 & 1`: the up bit of the feet cell *before* the step, and nothing
else (`$3421`). The top rung's cell has no up bit, so a 1984 explorer climbing
down from a walkway shows the **pole frame `$26` for his first four steps**.
Then the `$2E–$31` clamp snaps him to `$31`. Ours also looks at the cell below,
which removes that flicker. It's a good change and the prose never claims it's
1984's. But the log calls movement "kept exactly", and ch8's monsters or
ch11's fidelity checks could trip on it. Record it in the log as a deliberate
deviation. It would also make a nice optional half-sentence in the Inside the
Disk box ("the 1984 explorer briefly takes his pole pose when he starts down a
ladder; ours looks one cell further").

(b) Location: "Climbing and sliding", "When he stops on a ladder or a pole he
holds on and keeps his picture". He also keeps the **slide pose after landing
on the floor**, hands over his head, until he walks (see `sheet.png`, frame
740). The `pole` test even asserts this. It's 1984's behaviour too (`$33D6`
leaves the picture alone), but a reader will see it and wonder.

Fix: add "He lands still in his sliding pose and stands that way until you
walk him off, which is what the 1984 explorer does too."

### 5. NIT: "where all we have is bytes" undersells `m.view`

Location: after `compass`: "We still index the grid by hand, because the grid
lives in the Comet's memory at an address, where all we have is bytes."

Problem: Chapter 3 taught `m.view`, and the machine allows array views:
`m.view([25][40]u8, map.grid.first)` is legal. The honest reason we index by
hand is the cost convention: `peek`/`poke` charge the meter, and a view would
hide the work.

Rewrite: "We could even ask the machine for the grid as a `[25][40]u8` with
Chapter 3's `m.view`. We index it by hand instead, with `peek` and `poke`,
because those charge the meter for every read, and the meter is the point of
this chapter."

### 6. NIT: "The builder has paid for itself" is a little spun

Location: "The pole that went through the floor".

Problem: the builder caught data that broke a rule the chapter had just fixed
in the builder. The rule was the bug, not the castle. The prose is honest
elsewhere, so the cheer reads oddly.

Rewrite: "The new rule catches the Training Castle straight away: Chapter 3
drew the Sliding Poles pole one piece too long, and the Entrance Hall's too.
On screen you'd never know, because the last piece just disappears into the
floor's bricks. In the grid, it's a hole."

### 7. NIT: build-mode and panic details

- "the game stops on the spot with `panic: integer overflow` and the line that
  did it": the line comes only in native builds. In the browser (ReleaseSafe,
  wasm) the machine's panic handler logs the message, and the shell says
  "Details are in the console". There's no source line. Fix: "...and, in a
  native build, the line that did it".
- The quoted trace's `thread 14449` and `0x11ee151` vary from run to run, and
  `45:29` is the line only in a file shaped like the reader's. Add "(your
  thread number and addresses will differ)" once.
- "the first time the explorer stands at castle X 128 or more, the game stops":
  he spawns at 162 in the Gatehouse, so the game stops the moment the room
  appears. Say so; it's more vivid.

### 8. NIT: right-edge arithmetic

- "sprite X is `2x − 8`: as much as 344" (and the doc comment "up to 344"): the
  last fat pixel is X 175, which is sprite X 342. 344 is X 176, off the screen.
- Stage A's `max_x = castle.left_edge + 160 - 8` (168) is described as "the
  right edge, less his own 8 fat pixels". Under the grid he reaches **169** on
  any full-width walkway: feet at 172, the first fat pixel of column 39. That's
  the 1984 rule, so it's correct. But at x 169 the two walk frames whose
  drawing uses column 7 (`explorer_right_1/_2` and their mirrors) lose one fat
  pixel of boot to the display edge. It's invisible in practice. Either let it
  be, or say "about his own width" instead of the exact claim.

### 9. NIT: the JS grid bridge has one inaccurate detail

Location: Under the Hood "`grid[y][x]` versus one flat buffer": "Reading a cell
follows one pointer to the row and another to the number".

Problem: engines store small integers inline in arrays (V8's "Smi" elements).
There's no second pointer for a byte-sized number.

Fix: "Reading a cell follows a pointer to the row first, and each row carries
its own header and spare capacity."

### 10. NIT: `way & 3 == 2` will be misread by a JS reader

Location: `steer`: `if (way & 3 == 2)`, `ways & bit(want) != 0`,
`(... ) & grid.up != 0`.

Problem: in JS and C, `==` binds tighter than `&`, so `way & 3 == 2` means
`way & false`. In Zig, `&` binds tighter, so it reads as intended. Ch2's Pro
Tip covered `&`/`|`/`^` sharing a level, not `&` against `==`. Readers who
port this habit back to JS get a silent bug.

Fix: add one line, in the "Which way is open?" paragraph or as a sentence in
the shift Pro Tip: "Zig binds `&` tighter than `==`, so `way & 3 == 2` means
what it says; in JavaScript you'd need `(way & 3) === 2`."

### 11. NIT: the art (climb and slide frames)

The writer's own verdict was "functional but plain". I agree it's functional:
the back view with the hat brim reads as "climbing" at game scale
(`zoom.png`), and the slide's hands sit exactly on the pole column (sprite x
70 → fat 54; hands at columns 3–4 = fat 57–58).

Specifics (`frames.png`):
- **`explorer_climb_1` is left–right symmetric, so `climb_3 = mirror(climb_1)`
  is identical to it.** The four-frame cycle is really A, B, A′, B. The prose's
  "two drawings and their mirror images" implies four distinct pictures. Either
  make `climb_1` asymmetric (one hand higher, one knee raised) or say "a
  reaching frame, its mirror, and a hands-level frame between them".
- **The climbing hands sit outside the rails.** They're at columns 1 and 6,
  i.e. fat 95 and 100, against rails at 96 and 99. Moving each hand in one
  column would put them *on* the rails, which reads better.
- **The slide frame's head is hard to read.** The white sleeves flank an orange
  block, and the pink face sits below it inside white edges, so at 1× it looks
  like a bonnet. The hands are a single row of pink. Try: hat brim (orange)
  directly above the face; two rows of pink hands gripping at columns 3–4; the
  sleeves narrowing to the hands; knees splayed out (`.2....2.`) round the pole
  instead of the X-shaped legs.

### 12. NIT: Byte Budget and small numbers

- "The three tables in `player.zig`, 32 bytes": there are four tables. `compass`
  (9 bytes) exists only at compile time to build `stick_way`. Say so ("three
  tables, 32 bytes; `compass` only exists while the compiler fills
  `stick_way`"). It's a nice, true point about comptime.
- "Building the grid adds about 9,000 cycles": it measures 9,190 (final room)
  to 9,966 (worst room). "About 9,000 to 10,000" is closer.

### 13. NIT: small code and readability points for a junior

- The `checkRoom` loop zips three parallel arrays (`runs`, `kind`, `short`).
  An array of small structs, `.{ .runs = room.pole, .name = "pole", .gap = 8 }`,
  would read more easily.
- The pole error "end just above one (rows 128 and 192)" doesn't say which
  rows those are. Make it "(top row 128, bottom row 192)".
- `debug.overlay`'s local `const rows` sits next to `grid.rows`. Rename it to
  `pattern`.
- `player.still` is `pub` but used outside only in a comment. Make it private.
- "no grid, just the castle" in `search`'s doc comment is fine as "only", but
  you could drop it to keep the chapter's "just" count at zero outside
  positions.

### 14. NIT: continuity and bookkeeping

- Ch2 promised "Chapter 4 has the story of what happens when a byte like `left`
  overflows" (the text right-edge stop). One clause would close it, e.g. in the
  operator table's paragraph: "(that's why `text.draw` stops at `left >= 152`
  instead of adding 8 past 255)".
- `@as` and `@truncate` were used and briefly explained in ch2. The "three
  tools" paragraph presents them as new. Add "you've used `@as` and `@truncate`
  since Chapter 2" so it reads as a round-up, not a re-teach.
- Decision log: add the ch11 pole check (Baseline), the climbing-picture
  deviation (4a), and the corrected search costs (1).

## The weakest passages, with rewrites

1. **"What the grid saved", closing paragraph** (findings 1 and 2). Rewrite:

   > A search costs 1,100 to 1,650 cycles depending on the room, and most of
   > that is stepping over the room's text, letter by letter. The grid costs 20
   > in every room, however full the room is. One explorer can afford to
   > search: 3,700 cycles is a fifth of a frame. But everything that walks the
   > castle asks the same question every step, and later chapters fill a room
   > with up to eight sprites: a second explorer, mummies, Frankenstein's
   > monsters. Eight searchers climbing would spend 23,000 cycles a step just
   > asking, more than a whole frame, before anything has been drawn. Eight
   > grid readers spend 320.

2. **The `compass` paragraph** (finding 5). Rewrite as in finding 5.

3. **"The builder has paid for itself"** (finding 6). Rewrite as in finding 6.

4. **"Seeing the grid", first paragraph** (finding 3):

   > The grid is invisible, which makes it hard to trust. So let's give the
   > game a switch that draws it. Press **G** and the room is drawn again with
   > the grid over it. Drawing a room puts the explorer back in its doorway, so
   > look first, then walk. A second switch, **S**, waits for the end of the
   > chapter.

5. **The end of the picture explanation in "Climbing and sliding"** (finding
   4b):

   > When he stops on a ladder or a pole he holds on and keeps his picture.
   > That includes the bottom of a pole: he lands in his sliding pose and
   > stays in it until you walk him off, as the 1984 explorer does. When he
   > stops walking he stands.

## What works well (keep these)

- **The opening hook.** "The wall made of arithmetic" picks up Chapter 1's
  promise in the first paragraph and pays it off with real code within a page.
  The panic-then-fix sequence for `x * 2 - 8` (a compiling first try, the real
  trace, the byte diagram of 330, then `place`) is the outline's method at its
  best.
- **The operator table** (`+`, `+%`, `+|`, each tied to where the reader
  already met it) is compact, and it builds on what came before instead of
  re-teaching.
- **"255 is minus one".** Two's complement taught through the step tables the
  reader is about to type, with an odometer-style sum. It never leaves the
  game.
- **"The pole that went through the floor"** turns a real data-format subtlety
  into a story with a reproducible builder error. It also leaves the castle
  format 1984-correct for Chapter 11.
- **The G switch.** A debug view that makes an invisible data structure
  visible, built with Chapter 2's packing. `04-grid.png` is the best teaching
  image in the series so far.
- **"What the grid saved"** (once the numbers are fixed) lets the reader feel
  the Precompute Power-Up on the meter with the S switch, instead of being told.
  The `at == search` test over every cell of every room proves the fast path
  and the slow path agree. That's exactly the rigour the series promises.
- **Fidelity where it matters.** The stick table, step tables, snaps, diagonal
  rule and grid bits are all 1984's, byte for byte. The deviations (1-byte
  cells, 25 rows, the taller explorer's offsets) are deliberate, small, and
  logged.
- **The tests.** The ladder test's comments (`// feet at 113, between the
  rails`, `// the top rung's cell`) double as documentation of the movement
  rules.
- **Tone.** Warm, direct and playful without baby talk ("There's the castle as
  the explorer will feel it", "Then decide why 1984 chose 25"), with two earned
  exclamation points. It never breaks the fiction.
