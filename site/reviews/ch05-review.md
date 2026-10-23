# Review: Chapter 5 ("Ding Dong, You're Dead")

Reviewer scope: `site/chapters/05-ding-dong.md`, its images
(`images/05-bell.png`, `05-doorway.png`, `05-flicker.png`) and `site/code/ch05/`
(against `site/code/ch04/`). I checked them against `site/AUTHORING.md` (the
bible and the Decision log, including the writer's new ch05 entries),
`docs/tutorial/outline.md`, `site/code/machine/REFERENCE.md` and
`machine/src/machine.zig`, the Prologue, Chapters 1–4, and the ch01–ch04
reviews. For 1984 behaviour I used `reference/segrax-DrCreep/src/creep.cpp`
(`Sprite_Execute`, `Sprite_Object_Collision_Check`, `Sprite_FlashOnOff`,
`obj_Door_Prepare`, `obj_Door_Execute`, `obj_Door_InFront`,
`obj_Door_Button_Prepare`, `obj_Door_Button_InFront`, `obj_Player_Execute`,
`obj_Player_Add`, `roomMain`, `Game`, `KeyboardJoystickMonitor`), `creep.h`
(`SPR_*`, `ITM_*`, table sizes) and the bytes in `disasm/object.s` (`$0842`,
`$088F`, `$338E–$33A3`, `$34A1`, `$4075–$408A`, `$5F3B`, `$5F59`). Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-ch05/`:
- `cmp.py`: pulls the chapter's 94 labelled ```zig fences and compares each one,
  label and body, with the writer's `listings.py` steps.
- `rebuild/`, `rb-A` … `rb-F/`, `rebuild.log`, `outputs.json`: my run of the
  writer's `rebuild.py` (`WORK=` set to this folder).
- `errs/`: `errs.py` rerun. `shadow/`: the shadowing error from the Game Over box,
  reproduced.
- `code/ch05/`: a clean copy for build, test, wasm and fmt. Its `src/main.zig`
  has review-only tests at the end: "REVIEW every door, both ways", "REVIEW every
  bell, from shut", "REVIEW costs", "REVIEW draw slots", "REVIEW C walking + death
  spots". They print to stderr, so `zig build test` reports a failed step; run
  the test binary directly to see them pass (29/29).
- `c4/`: ch04 run on the stage-A headless script, for the "twice the cost" claim.
- `bellzoom.png`, `walkin.png`, `walk_sheet2.png`, `boss_sheet.png`: close-ups and
  frame sheets.

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py` finds 94 fences, all
  matching `listings.py` in label and body, in order. There are three prose-only
  deletions (`sprite`, `player.setFrame`, `room.start`) and the replace table.
  `rebuild.py` gives **REBUILD BYTE-IDENTICAL**. Stages A–F each pass
  `zig fmt --check`, `zig build` and `zig build test`, and each one runs. I read
  every label against the op `listings.py` applies, and one of them doesn't say
  what the op does (finding 1).
- **The checkpoint is green.** On a clean copy, `zig fmt --check src`,
  `zig build`, `zig build test` (28/28: 27 game + the machine's) and
  `zig build wasm` (writes all three `web/` files) all pass. The Boss Battle
  prints the quoted block exactly: `2227 calls`, `max 236824 (1204%)`, buckets
  78/235548/1260/1074/2124, `loading pauses: 7`.
- **The screenshots match fresh runs pixel for pixel.** `05-bell.png`,
  `05-doorway.png` and `05-flicker.png` are frames 120, 230 and 2170 of the Boss
  run at 2× nearest. Frames 800 (walking out of the Ladders room's left door) and
  2290 (walking out of the Gatehouse door again) show what the text says. One
  caption is wrong, though (finding 4).
- **The quoted errors are verbatim.** `missing struct field: image` (at
  `src/room.zig:28:70`) and `local constant shadows declaration of 'objects'`.
- **The door entry input is right: up-and-right, direction 1. I checked this
  carefully.**
  - `$339A`: `lda $5f56 ; sta $bd1e,x`. Every player turn stores the stick
    direction in actor byte `$1E`. That direction is `$5F59[port & $0F]`
    (`$5F3B`).
  - The table at `$5F59` is `80 80 80 80 80 03 01 02 80 05 07 06 80 04 00 80`.
    Index 6 (`%0110`, up and right held, active low) gives `$01`. Index 14 (up
    alone) gives `$00`.
  - `$4085`: `lda $bd1e,x ; cmp #$01 ; bne`. That is creep.cpp line 5260
    (`Sprite_field_1E != 1`). Nothing between the store and the in-front check
    rewrites `$1E` for a player.
  - So a 1984 door takes direction 1 only, on either wall. Up alone does not
    work. The Gatehouse sign had it wrong, and the fix is correct. Teleports
    (`!= 0 && != 4` at line 5872) take up and down, which matches the
    Transmitter's "PUSH UP".
- **The engine matches 1984 closely, and the chapter says so where it doesn't.**
  - The actor `State` bits are `SPR_*` bit for bit, and `Flags` is `ITM_*`.
  - The tables are 8 × 32-byte actors at `$BD00`, plus two 32 × 8-byte object
    tables at `$BE00` and `$BF00`. Ours repacks them into 8 × 16 and 32 × 16 at
    the same addresses, which is logged.
  - `actors.step` follows `Sprite_Execute`'s order: destroy → action; flash →
    `FlashOnOff`; countdown; at 0, the background hit → object check → then the
    action unless flash got set; free → unused. The only difference is that
    1984 tests dying at countdown 0, but dying sets the pace to 1, so the
    behaviour is the same.
  - `overlap` matches `Sprite_Object_Collision_Check`: inclusive edges, and
    disabled objects are skipped. Ours sums in `u16`. 1984 zeroes the start on
    wrap, which only matters for a box that crosses 255. The chapter states the
    difference honestly.
  - The `$0842` pairs are door `$3FD5`/`$4075` and bell `0`/`$41D8`. That is
    exactly our `.door = {open, enter}` and `.bell = {null, ring}`.
  - `$088F` is six 8-byte records (`$31F6, $3534, $34EF, $00, $01` for the
    explorer). The "Six kinds, eight bytes each" box is accurate.
- **Bell, door, walk, arrival and death all match 1984.**
  - Bell (`$41D8`): player kind, fire state, `x + 3 − bell.x < 12` wrapping,
    status 0, door found by number, `execute` set if shut. Ours does the same
    with a press, and says so.
  - Door open (`$3FD5`): sets the open bit on this door and the far door, then
    wipes bottom-up and draws the open panel in the destination's colour.
  - Walk table (`$34A1`): entries `(0,0,$1E)`, then five `(+1, −1/0/−1/0/−1)`,
    then state 1; the walk out starts at `$18` and mirrors it back to state 0,
    with pace 3 and then 1. The chapter's 14-entry table has the same timing (7
    turns each way) and the same displacement.
  - Arrival (`obj_Player_Add`): open door (+11, +12), shut door (+6, +15). Ours
    is (+11, +8)/(+6, +11), scaled by the ch04 feet rule.
  - `roomMain` runs 30 more ticks once nobody is in states 0/5/6.
  - `Game` (`$7809 = $7803`, `$780B = $7805`): a death means a life lost and a
    respawn at the castle's start.
  - The flicker is `Sprite_FlashOnOff`: 8 flashes, white on even engine ticks,
    hires, pace 1.
- **Play-test: every door both ways, every bell, and death in several places.**
  - "REVIEW every door, both ways" opens every door and starts the explorer in
    each of the castle's **39** door records in turn, so he walks out of it. It
    checks that he ends at (+6, +11) with left or right open in the grid (never
    stuck). Then it pushes up-and-right through the real collision path and
    checks the destination room and door. All 39 pass, including the exit door,
    which leads to The Way Out's own door 0, as the prose says.
  - "REVIEW every bell, from shut" rings all **20** bells from a fresh boot. Each
    one opens its door on both sides.
  - Death on a ladder mid-climb, in the final room (which has no doors), and
    three times in a row (title) all behave as described. K during a doorway walk
    or the 30-step ending does nothing, as it should.
- **Most cycle numbers check out.** I measured these directly:
  - A frame without a step is 170 cycles (`show` is 146). A standing step is
    448, with bucket 3 at 246 and bucket 4 at 28.
  - Door opening, bucket 4: 440 on the first step, 102 per row, 2,112 on the
    last.
  - Preparing a room takes 143,106–236,478 cycles.
  - Idle objects cost 12 each (28 for two, ≈ 388 for 32).
  - Some numbers are wrong: see findings 2, 3 and 5.
- **The fiction holds and the banned words are absent.** I grepped the prose for
  C64/Commodore/VIC/SID/emulat/reverse/disassembl/pretend/AI/repo/6502/
  author/publisher/copyright/tutorial/reader/just/simple/easy/obvious and got no
  hits. There are three exclamation points, all on milestones ("The door
  opens!", "You're in the next room!", "The castle is open!"). The kill key is
  lore without naming RESTORE.
- **Every logged ch5 promise is kept.**
  - Ch3's `switch` became a function table, with 11 `later`s.
  - Doors open, and the look Chapter 3 drew is used.
  - The ch2 `pressedFire` caveat is fixed properly: `read` is the only writer of
    the stick byte in a room, and there's a test with fire held across the room.
  - The door panel is reconciled: four named constants, the box is the panel, and
    the 24-row deviation is explained.
  - Ch4's "the door he really walked through" is paid with `player_door`.
  - Ch1's Edge Detector is reused for the bell.
  - The outline's "event queue" was dropped with a sound reason (logged), and the
    prose says "the flag is the to-do list".
- **Scope and ladder.** The chapter matches outline ch5 (fixed tables, state
  bitflags, execute flag, hardware collision first pass, death lifecycle,
  doors/bells, room to room) and coverage rows 4, 5 and 20. The three row-5 ideas
  each get taught where they're needed. Length is 6,754 prose words and 7,258
  code words (`wc.py`), in line with the plan.

## Findings, ranked

No blockers.

### 1. SHOULD-FIX: one listing label, followed literally, breaks the build

Location: "Ringing the bell", **`src/room.zig`** (replace the first three lines
of `draw`'s body, and the comment above it).

Problem: the listing is the comment, the `pub fn draw` line and three body lines
(`screen.clear`, `grid.clear`, `objects.clear`). At that point the body's first
three lines are `screen.clear(m);`, `grid.clear(m);` and
`var walk = prepare(m, m.peek(map.room_number));`. A reader who replaces those
three deletes `var walk` and gets `use of undeclared identifier 'walk'`. The op
in `listings.py` (C14) really replaces the comment, the signature and the first
**two** body lines. Elsewhere "its first two lines" (the `walkway` listing)
counts the signature, so the two labels also disagree with each other.

Fix: relabel as **`src/room.zig`** (in `draw`, add `objects.clear(m);` below
`grid.clear(m);`, and replace the comment above it), and show only the comment,
the signature and the three clears, as now. Alternatively: "replace the comment
above `draw` and its first three lines".

### 2. SHOULD-FIX: the first-pass numbers are wrong (374, 64, 16,384)

Location: "What the first pass saves": "An engine step costs 246 cycles; press C
and it's 374. ... that's 64 cycles an object ... 8 × 32 × 64 = 16,384 cycles,
more than four fifths of the frame". The Decision log repeats 374 and 64.

Evidence: "REVIEW costs" stands him on bare Gatehouse floor (x 102, `hit_bitmap`
false). Bucket 3 is **246** without C and **354** with C, on every step. That
matches the code: `touching` costs a 4-cycle count peek plus 12 + 40 per object,
which is 4 + 2 × 52 = 108. So the cost is **54 an object**, not 64. Full room:
8 × 32 × 54 = **13,824** cycles (8 × (4 + 32 × 52) = 13,344 if you count exactly),
about **70 %** of 19,656. (If you measure near the door, as I first did at x 152,
`hit_bitmap` is already set by the arch and C changes nothing. Say "a bare
stretch, away from the door", as the text does.)

Fix: "An engine step costs 246 cycles; press C and it's 354. ... that's 54 cycles
an object ... 8 × 32 × 54 = 13,824 cycles, seven tenths of the frame, spent
finding out that nobody is standing in front of anything." Update the log.

### 3. SHOULD-FIX: "still 12 frame slots at worst" is now 13, and the picture-change cost is ≈ 1,200

Location: Byte Budget, "the rooms take 143,106 to 236,478 cycles to prepare,
still 12 frame slots at worst". Also "about 1,100 with a change of picture". The
log says "12 slots at worst" and "≈ 1,096".

Evidence: 12 × 19,656 = 235,872, which is less than 236,478. "REVIEW draw slots"
reports `m.last.slots = 13` for the Gatehouse draw (236,478 cycles). The Boss
Battle's own `max 236824 (1204%)` is 12.04 frames, which is 13 slots. The
Gatehouse is now the most expensive room: its sign gained 10 letters (≈ 6,700
cycles), and every room fills an object table on top. A walking step with a
picture change on open floor is **1,216** cycles (bucket 3 at 1,014).

Fix: "... 143,106 to 236,478 cycles to prepare. That's 13 frame slots at worst,
one more than Chapter 4: the Gatehouse's longer sign tipped it over" (that's also
a nice, honest cost lesson). Change the other number to "about 1,200 with a
change of picture". Update the log.

### 4. SHOULD-FIX: the Mission Briefing image's alt text describes something that isn't in it

Location: the `05-bell.png` alt text: "the door beside it half open, its lower
half already gone to show the orange of the room beyond". In "Ringing the bell":
"Its panel wipes away from the bottom up, and behind it is the orange of the Long
Gallery".

Evidence: `bellzoom.png`. `room.wipe` writes 0 to the panel's bitmap bytes, so
the wiped rows are pixel code `00`, which is the black background. The orange only
appears on the last step, when `panel` draws `door_open`. 1984 does the same: it
wipes with blank shape `$7C`, then draws the open door.

Fix: alt text "...and the door beside it half open, its lower half already wiped
away to black". Prose: "Its panel wipes away from the bottom up, a row a step,
and when it's gone the doorway shows the orange of the Long Gallery, the room it
leads to."

### 5. SHOULD-FIX: the door's step counts are off by one, and the Bonus Stage has 1984's speed backwards

Location: "Ours is 24 rows ... and it takes 23 steps" / "its panel is 15 rows
tall and opens in 14 steps". The Bonus Stage says "Faster doors. Wipe two rows a
step, and decide whether 1984's slower door was more fun." The log says "23
steps".

Evidence: "REVIEW costs" counts **24** engine steps with door work. `open` wipes
rows 23 down to 0, one per call, and draws the open panel in the 24th call. 1984,
counted the same way, takes **15** calls: it wipes rows 14..1 and draws on the
15th (`Object_field_2 = $0E`, decrement while nonzero). Either way, **1984's door
is the faster one**, about 0.6 s against our 0.96 s.

Fix: "its panel is 15 rows tall and opens in 15 steps. Ours is 24 rows ... and
it takes 24 steps: a little under a second". Bonus: "Faster doors. Wipe two rows
a step, which is about 1984's speed, and decide which you like better." (Also, our
last call wipes row 0 and then draws over it straight away. That's harmless, but
the step could stop at row 1, as 1984 does.)

### 6. SHOULD-FIX: the opening crowd scene miscounts its sprites

Location: "A castle full of things": "Two explorers ... a mummy ... A ray gun
slides up and down its track and fires a laser. Lightning crackles between two
machines, and Frankenstein's monster ... That's eight things that move, and every
one of them is a sprite". Also: "Twenty or thirty of those is a normal room."

Problem: the ray gun is an object drawn into the bitmap, not an actor. Only its
laser is a sprite (the chapter's own Inside the Disk box lists the six actor
kinds, and the gun isn't one). "Between two machines" contradicts the Lightning
room's own sign ("CRACKLE BETWEEN CEILING AND FLOOR"). Counted as sprites, the
scene has 2 + 1 + 1 (laser) + 1 + however many bolts, which isn't clearly eight.
"Twenty or thirty" objects for a normal room is generous with a 32-slot cap.

Fix (keep the energy): "Two explorers are working a switch together while a mummy
shuffles after one of them. A ray gun's laser streaks across the room.
Frankenstein's monster is waking up in his alcove, and lightning crackles under
three machines, a sprite for each bolt. That's eight things that move, and every
one is a sprite: the Comet has exactly eight. Around them stand the things they
use ... a busy room can have a couple of dozen."

### 7. SHOULD-FIX: the dispatch-table "aha" has no diagram and misses the obvious JS bridge

Location: "A table of functions" and "The Jump Table Power-Up".

Problem: ladder row 5's first two ideas get strong treatment: the JS
heap-pointer diagram, the `$BD00` slot diagram, the slot-0 byte diagram, and the
Slot Table Power-Up. The third, dispatch tables of function pointers, gets only
prose. Its only bridge is "JavaScript ... looking `update` up on its prototype".
But JS developers already write `handlers[type](...)` with an object of
functions every day. That's the bridge they'll recognise, and the difference is
the lesson: a string key vs. a byte index, a hash lookup vs. one array read, and
"forgot a case" being a runtime `undefined is not a function` vs. a compile
error. There's also no Pro Tip on `fn` vs `*const fn`, the Zig detail this
section stands on and the one readers trip on (a bare `fn (...) void` is a
comptime-only function *type* and can't be stored in a runtime table).

Fix: add a three-line diagram after the `kinds` paragraph, for example:

```
  slot 0:  kind = 0 ──► kinds[0] = { turn: ─────┐ }
                        kinds[1]                 └──► player.turn's code, in the program image
```

Add one bridge sentence: "In JavaScript you'd write
`const kinds = { player: { turn: playerTurn } }` and call
`kinds[a.kind].turn(m, n)`. That's the same idea, looked up by name in a hash
table at run time. Ours is looked up by number in an array, and a missing entry
stops the build instead of the game." Add a short Pro Tip: "`fn` is a type the
compiler knows about; `*const fn` is an address you can store. Tables hold the
second."

### 8. SHOULD-FIX: the up-and-right correction is right, but the chapter should own it, not "disagree" with itself

Location: "Through the door": "The Gatehouse says "push up", and that's the one
place this chapter disagrees with Chapter 3. The 1984 game wants the stick pushed
**up and to the right**, direction 1, and no other. It's not a whim: the
explorer's walk into a doorway goes up and to the right ..."

Evidence: the behaviour is verified (Baseline). Chapter 4 set the precedent for
a correction ("Fix the rule"), owning it plainly in the guide's voice. "Disagrees
with Chapter 3" is coy: the same guide wrote that sign. "It's not a whim" claims
to know the designer's reason. The walk geometry makes a good mnemonic, but it
isn't evidence.

Fix: "How do you go through a door? Chapter 3's sign says "push up", and that
sign was wrong. The 1984 game wants the stick pushed **up and to the right**,
direction 1 on Chapter 4's compass, and nothing else: up alone does nothing, on
either wall. It's easy to remember once you've seen the walk: he steps up and to
the right into the doorway, five fat pixels across and three rows up, as if the
door were set back into the wall." Keep the training.zig fix and the log's
"supersedes" note. Leave Chapter 3 and its screenshot alone: the correction lands
here, where doors start working, as ch4 did with poles.

### 9. SHOULD-FIX: K is joystick 2's "down" in the browser (and S, from ch4, is joystick 1's)

Location: the K key (`debug.keys`, Boss Battle "K to give up a life"). The same
issue exists for S.

Evidence: the reference card, §8: "Joystick 2 is **I J K L** ... Those keys work
the joysticks *and* type into the keyboard port". `shell.js`:
`STICK2 = { KeyI: UP, KeyK: DOWN, ... }`. Today nothing reads joystick 2, so K
works. In Chapter 9, player 2 pressing down would kill player 1. Joystick 1 is
also **W A S D**, so a WASD player who climbs down a ladder with S toggles the
slow search every time (inherited from ch4, never flagged).

Fix: give the kill key a letter that isn't on a stick, for example **X** ("cross
out this life"), and say why in one clause ("not K: that's joystick 2's down").
Log a note for ch9 to revisit S (or move it now and update ch4's mention in ch5's
"N, P, G and S as before").

### 10. NIT: the search-and-replace table (the writer's open question): acceptable, with conditions

Location: "The tests still poke at the old `player` bytes. In `main.zig`'s
tests, replace each of these, everywhere it appears:" and the 4-row table.

Judgement: acceptable under the exhaustiveness rule's spirit. The rule exists so
a reader who follows along ends with exactly `chNN`. These are 25 lines of tests
changed by a pure token substitution in one named file. An editor's
find-and-replace does it unambiguously, and the compiler catches any miss (the
`map.player_*` names no longer exist). Printing 25 near-identical test lines
would only add noise. Conditions:
1. Promote it to a named convention in the Decision log ("a search-and-replace
   table is allowed for a purely mechanical rename inside one named file, every
   occurrence, no other edits on those lines"). Right now it's only a remark
   under the tooling line.
2. Say "with your editor's find and replace", and add the safety net: "any you
   miss won't compile, because `map.player_x` is gone".
3. Never use it for a change that needs judgement.

### 11. NIT: three listings start with a blank line

Location: **`src/player.zig`** (add below `door_y`), (add below `step_y`), and
**`src/doors.zig`** (add below `bell_reach`). The fences open with an empty
line (`pad='\n'` in `listings.py`).

Fix: drop the leading blank line from the shown text and say "(add below
`door_y`, after a blank line)". Or leave it, since the rebuild depends on it,
but keep it consistent with ch04's convention.

### 12. NIT: `read`'s comment overstates what a press is

Location: `player.read`'s doc comment: "whether fire was pressed since his last
turn".

Problem: it tests "fire down now and not at his last turn". A tap that starts
and ends between two turns (one frame on an odd frame) is missed. The log notes
this, but the reader isn't told.

Fix: "and whether fire is down now and wasn't at his last turn". Add a clause in
the prose after `read`: "(a turn is every other frame, so a tap shorter than that
can slip between two looks; no thumb is that quick)".

### 13. NIT: magic numbers in `player.add`

Location: `a.box.x += 5; a.box.y -= 3;` and `castle.left_edge + 80` (twice).

Problem: the log asked ch5 for named door geometry, and the bible says no magic
numbers in logic. The 5 and 3 are the walk-in's displacement and live implicitly
in `doorway`.

Fix: `const walk_across = 5; const walk_up = 3;` beside the table, checked by a
`comptime` sum over `doorway[walk_in..walk_out]`. Also
`const middle = castle.left_edge + 80; // the screen's middle`.

### 14. NIT: small wording and naming issues

- The death section's parenthetical is hard to parse: "(An actor that something
  it touched has set flashing, which Chapter 6's trapdoors will do, doesn't take
  its turn that step either.)" Rewrite: "(If touching an object sets an actor's
  `flash`, as Chapter 6's trapdoors will, it skips its turn that step and starts
  to flicker on the next.)"
- The lifecycle diagram starts at `playing`, which is a `player_status` value, not
  a state flag, after "every step of it is a flag in the actor's state byte". Use
  `(alive) ──K──► flash ...` or say "every step after the first".
- The objects test is named "the table has a turn for every kind, and add stops at
  32". Objects have handlers, not turns.
- `Status` has a `_` with no word of why. One clause would do: "(`_` again: it's
  read back from RAM with `@enumFromInt`)".
- "`room.zig` imports the two tables, and its `objects` function, which has meant
  ... would now clash with the `objects` import, so it becomes `stream`, which is
  what it always found:" runs 45 words. Split it in two.
- Game Over: "**He walks to the door and stands there.** Up alone doesn't open
  it". He doesn't *open* it; up alone doesn't take him *through* it.

### 15. NIT: Bonus Stage "A room of doors" reads like a question with a known answer

Location: "Add a room with three doors and one bell for each, and see which ones
a single bell opens."

Problem: a bell opens exactly its own door. The chapter says so, so "see which
ones" is a quiz.

Fix: "A room of doors. Add a room with three doors, two of them leading to each
other inside the room, and a bell for each. Walk in circles."

### 16. NIT (art): the doorway walk reuses side-on frames, and he overlaps the arch

Location: `doorway` table, `05-doorway.png`.

Evidence: `walk_sheet2.png`. On the last steps in, and the first steps out, the
8-wide side-on frame at door x + 11..18 lies over the arch's right pillar
(+16..19). His hat and back boot are drawn on the stone. He also rises three rows
while facing sideways, which reads as climbing stairs rather than stepping into a
recess. 1984 gets away with it because it uses six dedicated, narrower back-view
images (`$1E–$23`).

Judgement: acceptable for this checkpoint. The chapter is honest about it (the
Bonus Stage "Seen from behind"), and the art budget is ours. If art time
allows, two back-view frames (≈ 90 bytes of shape table) would fix both the
overlap and the feel. Don't try sprite-behind-background: the open panel has
foreground pixels (it must, for the collision), so he'd vanish.

### 17. NIT (pacing): the first visible payoff arrives about 60 % of the way in

Location: sections "Sixteen bytes an actor" through "A promise from Chapter 3".

Problem: stages A and B both end in "Build and run. Nothing looks different" (or
"draws exactly as before"), and "**The door opens!**" is at line 1,534 of 2,384.
The A/B prose is good, and the engine has to come first, but it's a long climb.

Fix: trim B's lead-in (the "A promise from Chapter 3" section restates what the
reader already knows). Put the budget-meter widget at the end of stage A, where
the "about twice" claim is made, so stage A has something to *watch*. I measured
roughly 2× per frame: 170 vs 88 idle, 448 vs 196 a step.

### 18. NIT (consistency): ladder row 7 material is taught here; log it so ch7 refers back

The Slot Table Power-Up ("removing is setting its flag", with a test that frees
slot 3 and reuses it) and the actor `State` byte's lifecycle are, in substance,
row 7's "reusing free slots" and "a whole state machine in one flag byte". The
outline's ch5 does list the state bitflags, so this isn't wrong, but ch7 must
build on it rather than re-teach it. Add a line to the ch05 ladder bookkeeping.

## Weakest passages, with rewrites

1. Opening scene (finding 6): rewrite given above.
2. "Through the door" lead-in (finding 8): rewrite given above.
3. "What the first pass saves" numbers (finding 2): rewrite given above.
4. Death parenthetical (finding 14): rewrite given above.
5. The `05-bell.png` alt text (finding 4): rewrite given above.

## What works well

- **The JS bridge for arrays of structs lands.** It shows the `monsters.push(new
  Monster())` heap-and-pointers diagram against the `$BD00` slot strip, then the
  slot-0 byte diagram with real values (162/171/8/21/16/0/1), then "`table` is the
  big idea in one line" with `$BD50`/`$BD52` arithmetic. A JS developer will see
  memory differently after this.
- **The hardware first pass is the best "aha" in the series so far.** It's
  motivated by the player's experience (most of the time nobody is touching
  anything) and paid off with a live switch (C) and a measured cost. The
  Only-If-Asked Power-Up pairs it with execute flags, so one idea covers both
  halves of the engine.
- **The 1984 fidelity is excellent, and so is the honesty about deviations.**
  - The walk table, arrival offsets, respawn at the castle start, 30-tick
    run-out, bell reach, open bits on both doors, and handler-table shape are all
    exact.
  - Every deliberate difference is said in-world: the press vs. held fire, the
    taller panel, `u16` sums.
  - Getting the up-and-right input right, against the earlier sign and against
    what most people remember, is exactly the rigour the bible asks for.
- **The ch2 `pressedFire` debt is paid cleanly.** One writer of the stick byte,
  a pure `pressed`, and a test that holds fire across the room.
- **`directEnumArray` was a good choice.** The compile-time completeness check
  doubles as a lesson, and the quoted error is short and real.
- **The tests read like play.** "through the door and out of the one it leads to,
  and back again" and the K test describe the game, not the code.
- **The voice is right.** It's warm, punchy, not patronizing, with three earned
  exclamation points, the title pun paid off in a section heading, and Inside the
  Disk boxes that feel like insider lore.
- **The tooling is solid.** The rebuild is byte-identical across six staged
  builds, and the quoted output is verbatim.
