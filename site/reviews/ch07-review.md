# Review: Chapter 7 ("Lock and Load")

Reviewer scope: `site/chapters/07-lock-and-load.md`, its images
(`images/07-under-fire.png`, `07-keys.png`, `07-locked.png`, `07-panel.png`,
`07-shot.png`, `07-escape.png`), its diagrams (`site/page/diagrams/ch07-swap.html`,
`ch07-gun-byte.html`, `ch07-slots.html`), its tools (`site/tools/ch07/`) and
`site/code/ch07/` against `site/code/ch06/`. I checked them against
`site/AUTHORING.md` (the bible, and the Decision log with the writer's ch07
entries), `docs/tutorial/outline.md` (§7), `site/code/machine/REFERENCE.md`,
Chapters 5–6 and the ch05/ch06 reviews. For 1984 behaviour I used
`reference/segrax-DrCreep/src/creep.cpp` (`obj_Key_Prepare`,
`obj_Key_Infront`, `obj_Key_NotFound`, `obj_Door_Lock_Prepare`,
`obj_Door_Lock_InFront`, `object_Execute`, `obj_RayGun_Prepare`,
`obj_RayGun_Execute`, `obj_RayGun_Control_InFront`,
`obj_RayGun_Control_Update`, `obj_RayGun_Laser_Sprite_Create`,
`obj_RayGun_Laser_Execute`, `obj_RayGun_Laser_Collision`,
`Sprite_CreepFindFree`, `Sprite_Collision_Check`, `Sprite_Collision`,
`hw_SpritePrepare`), `creep.h` (`RAYGUN_*`, `ITM_*`), `docs/castle-format.md`
and the bytes in `disasm/object.s` (`$3040–$30D5`, `$3A7F–$3AD4`,
`$3F14–$3F4E`). Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch07/`:
- `cmp.py`, `cmp.out`: the chapter's labelled ```zig fences compared, label and
  body, with `listings.py`; every step's op.
- `rebuild/`, `rb-A` … `rb-F/`, `rebuild.log`, `outputs.json`: my run of the
  writer's `rebuild.py` (`WORK=` this folder).
- `partial.py`, `partial-D4/`, `partial-D5/`, `partial-E3/`: the reader's
  project stopped right after listings D4, D5 and E3, to check the compile
  error and the test failure the chapter quotes *where it quotes them*.
- `errs/`, `errs.json`: the writer's `errs.py`.
- `code/ch07/`: a clean copy for fmt, build, test, wasm and the Boss Battle
  (`boss.out`). Its `src/main.zig` (also saved as `review-main.zig`) ends with
  review-only tests ("REVIEW …"): waiting in the Ray Guns doorway, waiting
  then climbing, arriving by either door of rooms 10 and 15, the gun's start
  height, the way out after steering, the floor death point, a second visit
  after a death, the gun parked high in Under Fire, a key staying taken, the
  costs, and the table sizes. They print with `std.debug.print`; run
  `zig build test 2>&1 | grep '^\['` to see them.
- `run-A` … `run-F/`: every `runs.py` run on the checkpoint; `run-trap/`: die
  in the Ray Guns doorway, then come back (finding 1).
- `imgcmp.py`; `d_sheet.png`, `shot_sheet.png` (run D frames), `trap_sheet.png`,
  `boss_named.png`; `shots/`: the three diagrams at 1280 and 400 px, light and
  dark, and the two animated ones at five moments (`*-anim.png`).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py`: 65 fences, all
  matching `listings.py` in label and body, in order. `rebuild.py` gives
  **REBUILD BYTE-IDENTICAL**; stages A, B, C, D and F (= E + the fix) each pass
  `zig fmt --check`, `zig build`, `zig build test` and run. Every label reads
  correctly against its op. But see finding 2: the build is broken between
  listings D4 and D12, which the stage runs don't see.
- **The checkpoint is green.** On a clean copy: `zig fmt --check src`,
  `zig build`, `zig build test` (**41**: 40 game + the machine's) and
  `zig build wasm` (all three `web/` files). The Boss Battle, run exactly as
  printed, gives the quoted block **verbatim** (4,555 calls, max 236,486,
  buckets 326 / 235,206 / 1,274 / 2,138 / 3,622, 20 loading pauses, 0
  overruns). The named frames (740, 1720, 2740, 3680, 4110) show what the
  text says, and the last frame is Two's Company (`boss_named.png`).
- **The quoted messages are verbatim.** The `directEnumArray` error (from
  `errs.py`, and from `std/enums.zig:108`) and the failing test (`partial-E3`:
  39 pass, 1 fail, `expected 0, found 3`, at the status check inside the
  loop). Status 3 is `dead` (`player.Status`). The claim that the gap's entry
  is `undefined` is right (`directEnumArrayDefault` with `default = null`).
- **All six screenshots match fresh runs pixel for pixel**: `07-under-fire` = E
  470, `07-keys` = A 740 (= F 740), `07-locked` = B 390, `07-panel` = C 480,
  `07-shot` = D 340 (= D 360), `07-escape` = E 1380. Problems with two
  captions and one unused image in findings 5, 7 and 20.
- **The costs check out**, measured directly: `objects.step` in room 9, 68
  cycles, and 188 with a key removed; a gun moving a row 1,422 (prose ≈
  1,430); an idle turn 4; a row plus a shot 2,086 (so firing ≈ 664); a laser
  turn 16, its last turn 52. Shape table 3,774 bytes, castle 4,496. 6.25 rows
  a second for the gun ("6 rows a second") is right. One wording problem in
  finding 11.
- **1984 fidelity is very good.** Checked line by line:
  - Header pockets: `$7813`/`$7814` counts, `$7815`/`$7835` lists, written
    `list[count]` then `count + 1`; `obj_Key_NotFound` scans `0..count`. Ours
    is the same for player 1.
  - Key record (number, picture, x, y), `0` in the picture byte = taken, prepare
    skips it; key and lock groups end at a `0` first byte (so colour 0 can't be
    a key). Lock record (number, picture, door, x, y); 1984 draws `$58` and
    never reads the picture byte. `docs/castle-format.md` confirms the
    picture bytes are `colour + $50` / `colour + $57`.
  - Removal: `object_Execute` (`$3F96`): `--count`, copy the last slot over
    `X`, then `++X`, so the moved object skips a step. Same as ours.
  - Lock: player, alive, button, key in the pocket, find the door whose number
    is the lock's door, set `EXECUTE` if shut. Same.
  - `RAYGUN_*` bit numbers are exactly the `Gun` field order. Prepare clears
    `DONT_FIRE`, draws `length` track pieces 8 rows apart, gun at `x + 4` or
    `x − 8`, lowest row `y + 8·length − 11`. Execute only on `ticks & 3 == 0`;
    the distance is measured from the gun's old row; fire if `< 5` unsteered;
    steered → clear `PLAYER_CONTROLLING`, need `FIRED_BY_PLAYER`; never while
    `DONT_FIRE`. Panel: `x + 3 − panel x < 8`, stick 0 / 4 / `$80`, anything
    else returns. Laser at gun x ± 8, gun y + 5, ±4 a step, gone at
    `x < 8 or x ≥ $B0`, last turn clears `DONT_FIRE`, `hit` always flashes
    (`Sprite_Collision`: `SPRITE_TYPE_LASER` → flash), `touch` true on a
    lightning machine and on any gun but its own. All match.
  - Hit groups (`$0895`): laser `$04`, the same as lightning's.
  - Every deliberate deviation is in the log, and the ones a player would
    notice are told in boxes (held vs pressed fire at the panel, the full
    sprite table, strict boxes).
- **The three points the writer flagged:**
  - **(a) Slot 0 when the table is full: confirmed, from the bytes.**
    `sprite_creepfindfree` (`$3F14`) steps X by `$20` from 0; after eight
    slots X wraps to 0, `BNE` falls through, `SEC` (`$3F28`) and return with
    X = 0, without clearing the slot. The laser maker calls it at `$3A98`
    and goes straight on to `STA $BD00,X` at `$3A9D` with no carry test. So a
    full table makes the laser overwrite slot 0's kind, position, picture and
    gun link, keeping its old state byte. The box is right. (The C++ port
    returns −1 there, which is why the notes needed the bytes.) Wording in
    finding 9.
  - **(b) Strict `share`: correct, and 1984 really is inclusive.**
    `Sprite_Collision_Check` at `$308E–$30B7` is four `CMP` / `BCC skip`
    pairs (`right ≥ other.x`, `other.right ≥ x`, and the same for y), which
    is `>=`. `share` (`a.x + a.w > b.x and b.x + b.w > a.x`, same for y, sums
    in u16) is the right half-open test. With it, the Under Fire test survives
    400 frames leaning on the field while lasers die at x 84, and the lightning
    and transmitter tests still pass. One wording problem in finding 6, one
    over-claim in finding 10.
  - **(c) Ray Guns fairness: not fair yet.** Standing in the doorway he's shot
    3.3 s after he can move (measured: playing from frame 38, dead at 204).
    That's tight on a first visit (finding 3). Worse, the gun's row is saved in
    the castle, so after one death on the floor the room can't be won from its
    door any more (finding 1, must-fix).
- **Play-test, everything else works both ways:** the lock refuses
  empty-handed and opens with the key; the key leaves the table (lock moved to
  slot 2) and stays taken after N/P (3 objects, pocket 1); Locked Away up by
  booth and down by pole; the gun tracks, holds at the panel, climbs and fires
  over his head; the floor walk kills at feet 91 ("before you're halfway"
  holds, just); the field shields him; Under Fire's solution route works, and
  waiting 0–300 frames before climbing to its panel is always safe.
- **Promises.** ch05's `picked` ("a taken key, Chapter 7") and its note that
  ch7 must refer back to free-slot reuse and the `State` lifecycle, not
  re-teach them: done ("We built everything this needs back in Chapter 5").
  ch06's: laser kind 4 with its own group, keys use `picked`, laser vs field
  groups for the combo room: all paid. The outline's "you can shoot another
  player" is logged for ch9. No new keys.
- **The fiction holds.** No banned names. Five exclamation points in the
  prose, all on milestones or the sign. Prose is 5,028 words (`wc.py`), inside
  5,000–5,500; code 5,532.
- **Rendering.** `python3 site/build.py --no-wasm` builds; at 1280 and 400 px,
  light and dark, the page has no horizontal scroll and the three diagrams
  have no overflowing element; all labels are real text. Paused (reduced
  motion), `ch07-slots` rests on a sensible state. Nits in findings 15 and 21.

## Findings, ranked

### 1. MUST-FIX: after one death on the floor, the Ray Guns room can't be won from its door

Location: `training.zig` room `ray_guns` (gun `{left, x 132, y 96, length 12,
gun_y 152}`, door 0 at x 16, ladder at 56, panel at 40 upstairs); prose "Leave
the room and come back, and it's still up where you sent it"; Boss Battle
"Walk into the Ray Guns room and stand still in the doorway, and watch the gun
come for you."

Evidence:
- The gun tracks his row while he's on the floor, so whenever he dies on the
  floor (standing in the doorway, or the floor walk) it stops at `gun_y` 171,
  and `gun_y` is in the castle (`REVIEW r10 second visit`: "gun_y kept after
  death: 171").
- On the next visit he arrives at door 0 with the gun already on his row. It
  fires on his first turn, and the laser crosses 116 → 22 in under a second.
  Walking straight to the ladder without a pause, he dies with `gun_y` 171 or
  166; he lives only from about 160 up (same test).
- In the real flow: `run-trap/` (N×10, stand still, die, back at the
  Gatehouse, N×10 again, then straight right and up). Frame 780: a laser is
  already on its way while he takes his first steps; at 810 he's gone
  (`trap_sheet.png`).
- Nothing resets it. Death sends him back to the start room with the castle
  as it is, and a new game keeps the castle too, until ch9's clean copy. So
  the reader who follows the Boss Battle's own suggestion breaks the Training
  Castle for the rest of the session. Every later room is still reachable
  only with N/P.

Fix (pick one, then add a regression test "die on the floor, come back by
door 0, reach the panel / get out"):
- **Arrive behind the gun.** Mirror the room: the gun on the left, near door
  0, facing right, with its panel on the floor between door 0 and the track.
  He always arrives behind the muzzle, so a gun parked anywhere can't touch
  him. Without the panel, walking right past the muzzle still gets him shot,
  so the lesson stands. With the gun sent to the top, ~11 s to come down
  against roughly a 5.5 s run to the bell (my estimate; re-measure), so it should be winnable. This also removes
  finding 3.
- **Or arrive upstairs, out of the track's reach.** Door 0 at (16, 96) on the
  upper walkway next to the panel, and a track that starts at y 128 or lower,
  so that `gun_y + 5` can never be on his upper rows (top 107, body to 127)
  and he's never "near". Check that the floor run still kills and that the
  way out after steering still works.
- Either way, change the Boss Battle invitation to something that can't brick
  the castle, and fix "Leave the room and come back, and it's still up where
  you sent it" (it only stays up if he leaves at once; it follows him down as
  soon as he leaves the panel).

### 2. MUST-FIX: "Build now" fails with a different error from the one quoted

Location: the Lasers section. Listing D4 adds
`.laser = .{ .turn = guns.fly, … .hit = guns.blocked, .touch = guns.strike, … }`,
then "Build now, and `directEnumArray` refuses: Cannot create a direct enum
array…", then D5 sets the gap to 1. `fly`, `blocked` and `strike` arrive only in
D11 and D12.

Evidence: `partial-D4/my-creep` (the project after D4) and `partial-D5/` both
fail with

```
src/actors.zig:77:29: error: root source file struct 'guns' has no member named 'fly'
```

The quoted error appears only when the three functions exist (`errs.py` makes
it from the finished checkpoint with the 1 changed back to 0, not from the
reader's project at that point). The reader can't build again until D12.

Fix: move D4, the "Build now" paragraph, the error and D5 to just after D12
("What does a laser hit?"), e.g. "Now the laser can go in the actor table:".
The group paragraph can follow it there. Make `errs.py` take its case from
the partial rebuild at that step, so the error is checked where the chapter
quotes it.

### 3. SHOULD-FIX: on a first visit to Ray Guns you get about one second to start moving

Location: room 10, `gun_y = 152`.

Evidence (`REVIEW r10 wait then climb to the panel`, `REVIEW r10 start
height`):
- Standing in the doorway: dead 166 frames (3.3 s) after he can move.
- Wait, then head for the ladder and the panel: he lives with waits up to 60
  frames (1.2 s) and dies with 70 or more, on the walk or the ladder. The sign
  is six lines long, so a player reading it first is shot.
- Start heights: 144 gives 230 frames (4.6 s) standing, and the floor run
  still dies. At 136 the floor run gets through to room 11 (300 frames), so
  136 and up breaks the lesson.

Fix: if finding 1 keeps door 0 on the floor in front of the gun, use `gun_y =
144` (or the mirrored layout, where this goes away). Update the log's
"standing in the doorway, shot in ≈ 3 s".

### 4. SHOULD-FIX: "about ten seconds to come back down, and you need four" are both off

Location: after the Ray Guns death screenshot.

Evidence (`REVIEW r10 timing of the way out`): from the top (96), the gun
reaches firing range on the floor (`gun_y` > 166) after 70 rows × 8 frames =
11.2 s, and standing at door 0 he's hit after 622 frames (12.4 s). His way
out, leaving the panel: ladder at 26 frames, floor at 90, bell at 262 (5.2 s);
with the bell, the door's 24 steps and the walk in, about 330 frames (6.6 s).

Fix: "It takes about eleven seconds to come back down, and you need about
six." (Re-measure if finding 1 changes the room.)

### 5. SHOULD-FIX: `07-shot.png` shows neither the explorer nor a laser

Location: the image after the sprite-cap test. Caption: "the explorer walks
along the floor towards the gun, and its laser has just reached him".

Evidence: it is run D frame 340 (identical to 360). He's in his black flicker
phase and the laser is already gone, so the floor in front of the gun is
empty (`d_sheet.png`, `shot_sheet.png`). Frame 330 shows the laser a few
pixels from him.

Fix: use run D frame 330 (or dump every frame around 326–332 and take the one
where the laser touches him).

### 6. SHOULD-FIX: "touches" is used for an overlap, in the section about touch vs overlap

Location: "Boxes that only touch": "He stands with his left edge at x 92, up
against the field's sprite, which runs from 88 to 95. So his sprite touches
the field's … A laser arrives at x 84. It covers 84 to 91, touches the field".

The explorer's box overlaps the field's by four fat pixels (92–95), and the
laser's by four (88–91). Both have to *overlap* for the hardware to set the
bits. Two paragraphs later the point is that boxes which only *touch* don't
count. A reader who takes "touches" literally reads the first paragraph as
contradicting the fix.

Fix: "So his sprite overlaps the field's, by four fat pixels, and the VIDEO
chip sets his sprite-to-sprite bit. A laser arrives at x 84. It covers 84 to
91, overlapping the field too, and gets its bit." Keep "touch" for the edge
case only.

### 7. SHOULD-FIX: `07-panel.png` is never used

`images/07-panel.png` (run C 480, at the panel, gun climbing) is in the
folder and in the Decision log's image list, but no `![...]` refers to it. It
would fit after "Run it and play. … At the panel it stops dead. Push up and
it climbs." Use it there or delete it and the log line.

### 8. SHOULD-FIX: a panel shot is lost when the table is full, but the text says the gun tries again

Location: `shoot`'s doc comment ("the gun tries again on its next turn"), the
Inside the Disk box ("Our gun checks for null and simply fires on a later
turn"), the Spawn-and-Free Power-Up ("wait a turn and try again").

That's true for a tracking gun (the "near" test holds next turn). A steered
gun clears `fire` before `shoot` runs, so the press is used up, and the
chapter's own test asserts it ("that press is used up"). Fix: one clause,
e.g. "A gun on its own fires on its next turn; a press at the panel is lost,
and he presses again."

### 9. NIT: the slot-zero box (verified correct) needs plainer words

"The 1984 game's slot finder has the same answer for 'the table is full': it
sets the processor's carry flag." "The same answer" as what? Ours returns
null and theirs sets a flag. "Carry flag" is undefined for this reader.
Suggest: "The 1984 game's slot finder also says when the table is full: it
raises a one-bit signal in the processor. The laser maker never looks at it.
It goes ahead with slot 0, whatever is in it." Also "simply" (§1 word list).

### 10. NIT: "so its explorer can die like ours did" claims more than was checked

The inclusive test is confirmed (finding (b) above). Whether 1984's own
explorer, field and one-row laser really meet edge to edge in a room like
this one wasn't checked. "so its explorer could die the same way" is safe.

### 11. NIT: two Byte Budget sentences

- "Taking a key out of the table costs 120 cycles, most of it the 16-byte
  copy." By the meter the copy alone is 128 (8 a byte), and `remove` is about
  136. 120 is how much `objects.step` grows (68 → 188), because the table is
  one shorter afterwards. Say "adds 120 cycles to that step, the 16-byte copy
  (128) less one slot's worth of loop".
- "The castle is 4,496 bytes, 61 more: two keys, two locks, two guns, a
  forcefield, a teleport and a pole." It also gains room 15's walkway and
  ladder and loses two bells. Either list it all or drop the list.

### 12. NIT: "four locks and guns, and a pocket full of colours"

Rooms 9, 10, 15 and 17 have two locks, two guns and two keys. Suggest "Rooms
9, 10, 15 and 17: two locks, two keys and two guns."

### 13. NIT: `later` still has the title pattern

"Only the monsters are left in `later` now", and the new comment "The monsters
come alive in the next chapter.", but `.pattern = later` remains. Suggest
"Only the monsters and the title screens' pattern are left in `later`", and
fix the comment the same way.

### 14. NIT: the gun's wheel marks aren't white

"The four gun pictures differ only in where the white marks on the wheel
are." In `gun_right_*` the marks in column 0 are codes 01 and 11: grey and
red. Also "Slide the gun one row and the next picture goes up": "is drawn"
is clearer than "goes up" for something that moves up and down.

### 15. NIT: castle-set bits, two vs three

The prose says "Two of them come from the castle file"; `ch07-gun-byte`
shades three (`end`, `no_gun`, `left`) as "the castle file sets it". Say
"Two of them, plus `end`, …" or leave `end` unshaded with its own note. The
diagram's bit-5 cell says "steer" while the field and list say `steered`.

### 16. NIT: the "Two guns, one panel" Bonus Stage contradicts itself

The title says one panel; the text says "Each gun has its own panel in the
record." Rename it ("Two guns, two panels") or make it about steering both
from one spot.

### 17. NIT: the stale-plate box's last clause

"Chapter 9 gives each player his own plate bytes anyway." Per-player bytes
are still slot numbers, so they go stale in exactly the same way. Drop the
clause: "No room puts a key and a plate together, so it never bites."

### 18. NIT: sentences to read twice (§1 "Clear beats clever", "Plain words")

- "That's fine when there's plenty of memory and something to tidy up after
  you. We have neither." What tidies up? → "…and a garbage collector to
  free the old block. We have neither."
- "Player 2's count is the byte after his, and player 2's list starts 32
  bytes after his list." → "Player 2's count is the byte after player 1's,
  and his list starts 32 bytes after player 1's."
- "That's 1984's rule, and it costs nothing: nothing in the game is in such a
  hurry." → "That's 1984's rule. Waiting one step, a 25th of a second, never
  matters to anything in this game."
- "`destroy` is Chapter 5's last turn." → "`destroy` is Chapter 5's flag for
  an actor's last turn."
- "A gap with no name, it can only count." → "For a gap with no name, all it
  can do is count."
- "It's a test of `run` itself, not of a room, so it's allowed." (allowed by
  whom?) → "That's fine for a test of `run` on its own."
- "Looking for a key reads the list from 0 to `count`." → "from 0 up to
  `count − 1`".
- "its arrows blinking green": while it follows him it moves every turn, so
  the up arrow stays lit. "its up arrow lit green".
- The new `step` doc says a picked object "leaves the table on the spot"; the
  prose and `take` say "at the end of the step". Pick one (it happens in
  `objects.step`, after the actors' step).

### 19. NIT: Ray Guns and Under Fire are one-way rooms

Coming back from room 11, he arrives at Ray Guns' door 1 behind the gun and
must walk left through its line: dead at feet 102 (`REVIEW r10 from the
right-hand door`). Coming back from room 16 into Under Fire's door 1, walking
right puts him between the muzzle and the field: dead at feet 73. Under Fire
otherwise fixes itself (wait behind the field and the gun comes down to the
floor; parked at 96–120 the climb to the panel kills, at 140 and 171 it
doesn't). 1984 castles have one-way rooms too. Either accept this and log it,
or the mirrored Ray Guns layout of finding 1 makes the way back a straight
walk behind the gun.

### 20. NIT: `07-escape.png` caption

"the gun is at the top of its track and the field is down, as the explorer
runs … towards the door". In E 1380 the gun is about halfway down, on its way
back, and he's running for the bell. Suggest "the gun is high on its track
and coming back down, the field is down, and the explorer runs for the bell".

### 21. NIT: `ch07-swap` rests on "before"

Paused or with reduced motion, the figure shows the key still in slot 2 and a
count of 4, beside text that describes the result. The ch06 review moved
`ch06-wall` to rest on its result; doing the same here (lock in slot 2,
count 3) makes the paused figure match its words.

## Writer response

All findings are fixed as suggested except where noted here. The Decision
log entry "ch07 review fixes" lists every change.

- **1.** Done with your first option: the room is mirrored. The gun is
  near door 0, facing right, and its panel stands on the floor between the
  door and the track. He always arrives behind the muzzle. The new
  regression test "ray guns: shot once, the room can still be won from its
  door" dies on the floor, goes back to the Gatehouse, presses N ten times
  through the stick, arrives with `gun_y > 166` and wins the room with the
  same `escapeRayGuns` helper the steering test uses. The "still up where
  you sent it" sentence and the Boss Battle invitation are rewritten.
- **2.** Done. `Kind`, the entry, "Build now" and the gap fix now come
  after `fly`, `blocked` and `strike`. `rebuild.py` keeps a copy of the
  reader's project right after D11, and `errs.py` builds that copy as-is
  and insists on exactly one error, so the quoted message is checked where
  the chapter quotes it.
- **3.** Moot after the mirror: behind the gun he can wait in the doorway
  as long as he likes, so `gun_y` stays at the floor (171).
- **4.** Re-measured for the new room: about 11 s for the gun to come back
  down from the top to the floor's firing range, about 280 frames (≈ 6 s)
  from the panel to the doorway. The prose says "about eleven seconds …
  about six".
- **18 (`step` doc vs prose).** The removal happens in `objects.step`,
  which runs right after the actors' step. Both now say so: the doc
  comment says an object picked up in the actors' step "leaves the table
  here", and the prose says "when the objects take their turn, right after
  the actors'".
- **19. Partly disagree with the remedy, agree with the outcome.** The
  mirrored layout does not make the way back a walk behind the gun: door 1
  is now the one in front of the muzzle, so coming back from room 11 with
  the gun low still gets him shot, the same as Under Fire's door 1. Every
  layout that teaches "don't walk in front of the gun" has a side in front
  of it. I accept one-way rooms here (1984 castles have them, and no route
  in the chapter, its tests or the Boss Battle comes back that way) and
  logged it. What mattered, and what finding 1 caught, is that the room
  can always be won from the door you're meant to use, and that's now
  tested.
