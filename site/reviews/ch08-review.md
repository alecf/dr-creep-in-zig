# Review: Chapter 8 ("Monster Mash")

Reviewer scope: `site/chapters/08-monster-mash.md`, its images
(`images/08-storm.png`, `08-rise.png`, `08-frank.png`, `08-trap.png`,
`08-ride.png`), its diagrams (`page/diagrams/ch08-dice.html`, `ch08-choose.html`,
`ch08-ride.html`), its tools (`site/tools/ch08/`) and `site/code/ch08/` (against
`site/code/ch07/`). I checked them against `site/AUTHORING.md` (the bible and the
Decision log, including the writer's new ch08 entries), `docs/tutorial/outline.md`,
`site/code/machine/REFERENCE.md`, Chapters 2–7 and the ch05–ch07 reviews. For 1984
behaviour I used `reference/segrax-DrCreep/src/creep.cpp` (`seedGet`,
`obj_Mummy_Prepare`, `obj_Mummy_Infront`, `obj_Mummy_Sprite_Create`,
`obj_Mummy_Execute`, `obj_Mummy_Collision`, `obj_Mummy_Sprite_Collision`,
`obj_Mummy_Tomb_Execute`, `obj_Frankie_Prepare`, `obj_Frankie_Sprite_Create`,
`obj_Frankie_Execute`, `obj_Frankie_Collision`, `obj_Frankie_Sprite_Collision`,
`obj_Conveyor_InFront`, `obj_RayGun_Laser_Collision`,
`obj_Player_Sprite_Collision`, `screenDraw`), `creep.h` (`FRANKIE_*`) and the bytes
in `disasm/object.s` (`$5ED5–$5EFB`, `$3846–$38CB`, `$39EF–$3A06`, `$088F`, the
shape headers through the pointer table at `$603B`). Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch08/`:
- `tools/cmp.py`: compares the chapter's 84 labelled ```zig fences, label and
  body, with `listings.py`.
- `rebuild/`, `rb-A` … `rb-F/`, `at-B3/`, `errs/`, `rebuild.log`, `outputs.json`:
  my run of the writer's `rebuild.py` and `errs.py` (`WORK=` set to this folder).
- `tools/img.py` → `object.bin`: the 1984 program bytes rebuilt from
  `disasm/object.s`, for the table and shape-header reads below.
- `code/ch08/`: a clean copy for fmt, build, test and wasm. Its `src/main.zig` ends
  with review-only tests ("REVIEW speeds", "REVIEW room 13 …", "REVIEW room 12
  revisit", "REVIEW room 14: one press only …", "REVIEW room 13: fall in the open
  hole yourself …", "REVIEW sizes", "REVIEW turn costs"). They print to stderr;
  `zig build test 2>&1 | grep REVIEW` shows the numbers quoted here.
- `boss_sheet.png` (Boss frames 500/1380/2040/2950/3780/4059), `rise_sheet.png`
  (the climb, frames 380–460 of run B), `room13.png`, and `fig-*.png` (the three
  diagrams at 1280 and 400 px, light and dark; `tools/shots.cjs`).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py` finds 84 fences, all
  matching `listings.py` in label and body, in order. The three prose-only
  deletions (`gunOf`, the explorer's `underfoot` and `tread`) are each told in
  the prose. `rebuild.py` gives **REBUILD BYTE-IDENTICAL**, and stages A–F each
  pass `zig fmt --check`, `zig build` and `zig build test`, and run. I spot-read
  the riskier labels against the ops (`add`'s "last two lines before `return n`",
  "replace the `spare` bytes", the `kinds` first line, the castle record
  replacements) and they say what the op does.
- **The checkpoint is green.** On a clean copy: `zig fmt --check src`,
  `zig build`, `zig build test` (**56/56**: 55 game + the machine's) and
  `zig build wasm` (writes `web/game.wasm`, `index.html`, `shell.js`).
- **The Boss Battle is quoted verbatim.** The command in the chapter is
  `RUNS['F']` exactly, and the output block matches my run byte for byte
  (`3881 calls`, `max 242822 (1235%)`, buckets 348/241532/1278/4248/2432,
  `loading pauses: 17`, 0 overruns). The named frames show what the text says
  (but see nit 13 on frame 500's wording).
- **The quoted error is verbatim.** `errs.py` on the snapshot after B3 gives
  exactly one error, `src/shapes.zig:213:13: error: the shape table doesn't fit
  in its region`.
- **The screenshots match fresh runs pixel for pixel.** All five are the stated
  frames of runs B/C/D/E at 2× nearest (`ImageChops` bounding box `None`), and
  the captions describe them correctly.
- **Sizes:** shape table **5,106** bytes and castle **4,652** bytes ("REVIEW
  sizes"), so +1,332 and +156 are right. The 26 new pictures are 12 + 14 Ids.
- **The dice are 1984's, bit for bit (flagged point c).**
  - `$5ED5`: `lda $5EFB; ror; lda $5EFA; ror; sta $5EF9; lda #0; rol; eor $5EFA;
    sta $5EFA; lda $5EF9; eor $5EFB; sta $5EFB; eor $5EFA; sta $5EFA; rts`. The
    first `ror`'s carry-in is thrown away, so the routine is exactly: turned =
    (high & 1) << 7 | low >> 1; high ^= turned; low = (low & $FE) ^ high; return
    low. That is `roll`.
  - The seeds are the bytes after the `rts`: `$5EFA = $C6` (low), `$5EFB = $57`
    (high). `$5EF9 = $A0` is scratch. Nothing else in the program writes
    `$5EFA/$5EFB`, so "seeded once, never reset" is right.
  - The diagram's arithmetic is right (`$57C6` rotr 1 = `$2BE3`; `$57 ^ $E3 =
    $B4`; `$C6 ^ $B4 = $72`), and the first eight rolls are
    `72 FF 8C B8 D0 D0 B8 8C`.
  - I mapped the whole state space in Python: every pair has exactly one
    successor, half the pairs have no predecessor, and there are only **two
    loops**: the 32,767 one and the stuck pair `(0, 0)`. `$57 $C6` has a tail of
    1 and then the 32,767 loop, as the chapter says. Over one loop the low two
    bits come up 8,191/8,192/8,192/8,192 times. (But see findings 8 and 9.)
  - The bolt's use is 1984's (`$3658`/`$3663`): pace = 1 + (roll & 3); picture
    = roll & 3, the next one (wrapping) if it equals the current.
  - Other 1984 consumers (`$19C9` escape-time screen, `$4E39` teleport sound)
    also roll the same dice. Nothing in the chapter claims otherwise.
- **The mummy matches 1984 where it says it does (flagged point d).**
  - The climb table at `$39EF/$39F7/$39FF` has **7 entries** before the `$FF`:
    frames `45 46 47 48 49 4A 4A`, dx `00 FE FE FE FE FE FE`, dy `00 00 00 02 02
    02 02`. Ours keeps the 7 entries and the dy exactly (the `comptime` check
    sums to 8), and drops dx (−2 × 6) as the box and Deviation (1) say. 1984 has
    six pictures, ours three. Art is ours, so that's fine.
  - Pursuit (`$3846–$38CB`): stop when |dx| < 2, else one fat pixel toward the
    target if the feet cell has the `right` (`$04`) / `left` (`$40`) bit; X only,
    never Y; record bytes 5/6 updated each step. Same as `walk`.
  - Release (`$47A7`): player only, x + width − ankh.x < 8, state 1 → 2, ankh
    `execute` with 8 steps. Ours adds `playing`, which is harmless.
  - The ankh's flash (`obj_Mummy_Tomb_Execute`): every 4th tick, 8 steps, ending on the normal
    colour. Ours ends on gold too.
  - Touch (`$38CE`) and hit (`$3940`): an open trapdoor within 4 of the feet
    kills, a switch is noted; any sprite but a player or Frankenstein kills. With
    the `$088F` groups (player 0, lightning 4, forcefield 3, mummy 2, laser 4,
    Frank 0; flicker byte 1 for player, mummy, Frank) that leaves lightning and
    lasers. Our groups and `flickers` match the table byte for byte.
  - Two small timing differences, both harmless: 1984 snaps him to (tomb + 4,
    tomb + 7) and starts chasing on the turn the table runs out (ours waits one
    turn); 1984 also bumps the walking frame when the grid blocks him.
- **Frankenstein matches 1984 closely (flagged point b).**
  - The grid patch (`$564E`): row (y + 24) / 8, column (x >> 2) − 4; facing
    right, cells col..col+2 AND `$BF` (lose `left`); facing left, col−1..col+1
    AND `$FB` (lose `right`). Ours is the same.
  - Waking (`$3B31`): a playing explorer with |Δy| < 4 (sprite tops), and
    in front: player x > Frank x for a right-facing alcove, ≤ for a left-facing
    one. He moves on the same turn. Ours is the same.
  - `choose` is `$3B9C–$3CB4`: count the open ways (descending, so the lowest
    wins); one → it; two opposite, current way open and not still → keep;
    otherwise the distance table (`$3F0C`, `$FF` = none), dx ≥ 0 → right, dy < 0
    → up, then pick the largest strictly below the last tried, with `A < best`
    skipped so a tie goes to the **lower index**; none left → still. The
    "farthest way first" rule and the tie quirk are both 1984's. The `ch08-choose`
    numbers (64 rows vs 28 fat pixels) are consistent with room 13.
  - `move` (`$3CB4`): along, y −= feet_y % 8, ±1, frames cycle; up/down, x −=
    feet_x % 4, x += 1, then feet cell's `up` bit → climb ±2 with frame
    ((y & 6) >> 1) + base, else slide +2. Ours is the same apart from the logged
    rungs rule.
  - Touch (`$3D6E`): an open trapdoor kills awake or asleep; switch noted. Hit
    (`$3DDE`): only when awake; player/forcefield/mummy nothing; Frank–Frank
    sets avoidance masks (skipped, logged); anything else kills. The laser stops
    on `OBJECT_TYPE_FRANKIE` (`$3A60`), as `strike` now does. The record layout
    and `FRANKIE_*` bits match `creep.h`.
- **Belts carry monsters as 1984 does** (`obj_Conveyor_InFront`): mummy or Frankenstein, 2 a
  turn always; the explorer 1, or 2 every 8th tick. The "+3 a turn" in the
  diagram and the test (6 px in two turns) check out.
- **Play-test: every room on arrival, and on a revisit after a death.**
  - Beyond the writer's tests (all pass), I played other deaths. Room 12:
    caught at three different times, then waited upstairs. Frank paces the
    whole floor (x 32–169) and is near the pole only 6–9 % of the time, so
    there's always a window. Room 14: pressed the control **once** (belt
    stopped) and got caught. On the revisit he paces the floor; going down
    behind him and pressing once more gives a left-running belt and the escape
    works. Room 13: walked into the open hole myself. Frank follows down the
    ladder into it as well, so the revisit is an empty room. Standing at five
    other spots on room 13's floor (feet 66–90), Frank always came down within
    100 frames, with no dithering. Room 16: a badly timed throw leaves the
    switch's own machine running, and a mummy that follows you under the switch
    walks into it, so the room solves itself.
  - **The rooms are fair on arrival and on revisit.** The "door 0 upstairs" rule
    works: no monster could reach any door 0 in any run. It reads a little
    samey: rooms 11, 12, 13 and 14 all have an upper-left door, a one-way pole
    down, the floor and a bell by a lower-right door. But the chapter says why
    in one paragraph ("every monster room in this chapter has the same shape"),
    and room 16 is mirrored. I'd keep it. The one room that reads oddly is 13,
    for a different reason (finding 6).
- **Rendering.** `python3 site/build.py --no-wasm` builds. At 1280 and 400 px,
  light and dark, there's no horizontal page scroll and no overflowing element
  in the three figures. The dice rows wrap cleanly at 400 px, and the paused
  states of `ch08-dice` and `ch08-ride` read on their own.
- **Ladder and promises.** ch2's `^` and "making numbers look random" are paid
  (with the star LCG as the contrast). ch3's `later` is down to the pattern.
  ch5's groups and `hit`/`touch` are used as designed. ch6's "monsters ride
  belts in Chapter 8" and "Chapter 8 makes proper dice" are paid. ch7's
  `directEnumArray` gap is closed. Prose is **5,531** words (`wc.py`), just
  over the 5,000–5,500 target, which is fine for five rooms.

## Findings, ranked

One must-fix (one word). The rest are should-fix factual corrections and nits.

### 1. MUST-FIX: "A 6510" names the real machine's CPU

Location: the `Math.random()` box: "A 6510 can't multiply in one instruction, so
the 1984 dice use its two cheapest tricks".

Problem: AUTHORING §1 "Stay in the world" bans naming the real machine. The 6510
is the C64's own chip, and no earlier chapter or the reference card names the
Comet's CPU. It's the only fiction break I found (the banned-word grep is
otherwise clean).

Fix: "The Comet's CPU can't multiply in one instruction, so the 1984 dice use
its two cheapest tricks: moving bits along, and XOR." (The reference card's
`m.mul8`, a 120-cycle software routine, already says so.)

### 2. SHOULD-FIX: the speeds are wrong. Both monsters walk at half your speed

Locations:
- The Mummy room: "He's as fast as you on the flat, but he has to turn round
  first."
- "Frankenstein's monster": "He's slower than the mummy, but he climbs …"

Evidence: "REVIEW speeds" holds right for 60 frames. The explorer moves **+30**
fat pixels, the mummy **+15**, Frankenstein **+15**. In the code both monsters
have pace 2 and step 1 fat pixel. The explorer has pace 1 and steps 1. 1984 is the
same (`Sprite_field_6 = 2` for both in `obj_Mummy_Sprite_Create`/`$39D0` and
`obj_Frankie_Sprite_Create`). The chapter itself says Frank is "only half as
fast" as you and that the belt makes him "faster than you" at +3 a turn, which
only works if +1 a turn is half your speed. So the mummy line contradicts the
Frank lines, and a reader following "as fast as you" will think the escape is
harder than it is.

Fix: Mummy room: "He's half as fast as you, so lead him to the left end, then
run right for the pole: he can't keep up." Frankenstein intro: "He's no faster
than the mummy, but he climbs, he slides down poles, and he chooses his way at
every junction, by where you are." Also update `frankenstein.zig`'s top comment
if you keep "slower than you" (that one is right; leave it).

### 3. SHOULD-FIX: "The nearest explorer" box: the 1984 mummy doesn't chase the nearest

Location: inside-the-disk "The nearest explorer": "Chapter 5 said a mummy chases
the nearest explorer, and so he does in 1984."

Evidence: `$3846`: `lda $780D; beq → ldy #0; else lda $780E; beq → ldy #1; else
skip the turn`, then `lda $34D1,y`. The 1984 mummy chases **player 1 while player
1 is playing, and player 2 only when player 1 isn't**. Distance never enters into
it. Frankenstein (`$3C15`) is different: he takes each direction's distance as
the smaller of the two playing explorers'. Waking checks either one. An
inside-the-disk box is supposed to be a real fact, and this one is false for the
very monster it names. The Decision log's ch9 promise ("monsters … serve the
nearest playing explorer") would build it into Chapter 9.

Fix: "Chapter 5 said a mummy chases the nearest explorer. That was close, not
exact: in 1984 he chases player 1 while player 1 is playing, and player 2 only
after that. Frankenstein measures both and goes by the nearer one in each
direction. Ours has only player 1 so far; Chapter 9 brings player 2." Update the
ch08 Promises entry (and leave ch5's sentence: it was a forward glance, and this
box now corrects it).

### 4. SHOULD-FIX: "no other preparer has done" this, but forcefields and trapdoors already change the grid

Location: "Preparing his record does something no other preparer has done: it
changes the navigation grid."

Evidence: since Chapter 6, `forcefields.prepare` → `raise` → `grid.wall`, and the
trapdoor preparer walls an open hole (`trapdoors.wall`). Chapter 4's
inside-the-disk box even said "an opening trapdoor clears the bits … Chapter 6
does the same", and this chapter's own search-test listing names both as
exceptions.

Fix: "Preparing his record changes the navigation grid, as a forcefield's wall
does, but only one way: the three cells of walkway under his alcove lose the way
back in."

### 5. SHOULD-FIX: the tomb, ankh and alcove sizes, and the `$1C` box (flagged point a)

Evidence, from the shape headers at `$603B` (width in 4-fat-pixel bytes ×
rows):
- `$42` brick **4 × 7** (pitch 8, so the 1984 tomb is 20 × 23); `$43` hole 12 × 8
  at (tomb + 4, tomb + 8). Ours: 4 × 8 bricks (20 × 24), the same hole. Fine.
- `$44` ankh **8 × 23**. Ours is **8 × 16**. That isn't in the Deviations list.
  In a real castle (Chapter 11) the record's `ankh_y` places a 23-row picture
  standing on its walkway, so ours would float 7 rows above the floor, and its
  `in_front` box would be shorter.
- `$90/$91` alcove **8 × 32** at (x, y), its bottom 8 rows over the walkway.
  Ours is **16 × 24** at (x − 4, y). Deviation (3) records "drawn at x−4" but not
  the size. The object box (laser stop) and the author overlap check use ours,
  so real castles with an alcove beside a ladder, wall or another object may
  overlap differently.
- **`$1C` is the walkway's middle piece**, the same shape `obj_Walkway_Prepare`
  draws between a run's ends (`$1B`/`$1C`/`$1D`). The teleport preparer uses
  it the same way. `obj_Frankie_Prepare` first **erases shape `$92`** (8 × 6) at
  (x, y + 24) with `screenDraw` mode 1, draws the alcove, then, **only for a
  right-facing alcove**, redraws one `$1C` at (x + 4, y + 24): it patches the
  walkway in front of the alcove's open side. The box's "1984 draws one more
  small piece under a Frankenstein alcove" is right in spirit but says "a" alcove
  (it's right-facing only) and doesn't say what the piece is.

Fix: in "What else is different", say: "1984's alcove is narrower and taller,
and stands on the walkway; it rubs out a strip of walkway and, under a
right-facing one, draws one walkway piece back. Ours stands above the walkway
and needs neither." Log the ankh size (or, better, draw our ankh 23 rows tall
now and set room 11/16's `ankh_y` 7 rows higher, so Chapter 11 has nothing to
translate) and the alcove size as Chapter 11 risks in the Promises entry.

### 6. SHOULD-FIX: A Trap for Frank has an invisible wall in a walkway that looks continuous

Location: room 13 (`frank_trap`): `walkway = &.{ floor, upper_left, upper_right }`,
with `upper_left` 16–95 and `upper_right` 96–175.

Evidence: the two runs abut. On screen they read as one walkway with a faint
seam (`room13.png`: end caps meet under the middle of the screen), running from
door 0 to the exit door at the upper right. In the grid each run's end cell has
no outward bit, so "REVIEW room 13" walking right from door 0 stops at **feet 92**,
in the middle of what looks like open floor. The design needs that wall (Frank
must not reach door 0, and you must go round by the pole). But the player can't
see why he stops, and the sign doesn't say. Every other room in the castle shows
a walkway end as a gap.

Fix: shorten `upper_left` to 18 (16–87, a visible 8-fat-pixel gap before Frank's
walkway; the pole at 80 is still on it) and change the trap-revisit test's
`while (feet(m) < 92)` to the new end (≈ 84). A drawn gap also explains the room
on sight: "his walkway, my walkway, and the long way round".

### 7. SHOULD-FIX: "our Zig code doesn't live in the Comet's memory" contradicts the reference card

Location: after the map change: "The space comes out of the program image, which
is only a reservation: our Zig code doesn't live in the Comet's memory."

Problem: the reference card says of `$0800–$77FF`: "Program image. Your game's
code lives here", and Chapter 1 says constants are "part of the program image on
the disk". This sentence tells the reader the opposite and pokes a hole in the
fiction. It also makes the reservation sound pointless, when AUTHORING §3 keeps
it "so the 64 KB budget is honest".

Fix: "The 2 KB comes out of the program image, the room we keep for the game's
code. It started at 28 KB and is still nearly 22 KB, plenty for our code. Boot
copies the stars and the table to their new homes without a line changed."

### 8. SHOULD-FIX: "as fair as a four-sided die" overclaims. Two rolls in a row are linked

Location: after the dice tests: "That's what the bolts use, `roll & 3`, as fair
as a four-sided die." Also the Power-Up's "Use the bottom bits for small
choices".

Evidence: each value of `roll & 3` does come up a quarter of the time. But
consecutive rolls are not independent: the new low byte's bit 0 is the new high
byte's bit 0 (`low & $FE` clears it), and that is `high₀ ^ low₁` of the previous
pair. Over a whole loop, the pairs (r₁ & 3, r₂ & 3) take only **8 of the 16**
combinations, 4,096 times each (bit 0 of the second = bit 0 ^ bit 1 of the
first). A bolt rolls twice a turn, so its wait and its picture are tied: after a
given wait, only two of the four pictures can come up. This is 1984's behaviour
too, so the code is right. The claim isn't.

Fix: "Each of 00 to 11 comes up a quarter of the time. That's what the bolts use,
`roll & 3`. (Two rolls in a row aren't independent: the second's bottom bit
follows from the first. For a flickering bolt nobody can tell.)" In the Power-Up,
"fine for small choices like a bolt's flicker" instead of a general rule.

### 9. NIT: the "Loaded dice" Bonus Stage seed is ambiguous, and one reading jams the dice

Location: Bonus Stage: "Start the dice from a different seed, say `$01 $00`, and
count how long the loop is. Is it 32,767 again?"

Evidence: the chapter writes the seed both ways round: "`$C6` and `$57`" (low,
high) in the prose and `$57 $C6` (high, low) in the diagram and test comment.
Read as high `$01`, low `$00`, the answer is 32,767 again. Read as low `$01`,
high `$00`, the first roll gives `(0, 0)`, and the dice return 0 for ever. The
reader's copy of the second test would then say "1 roll" and fail on the `fours`
check. The state map shows there are only two loops at all: the 32,767 one and
the stuck zero.

Fix: make the surprise the point. "Start the dice from `first_low = 0x01,
first_high = 0x00` and roll. Then try any other pair. Why do almost all of them
give 32,767?" Or state the order ("low `$00`, high `$01`").

### 10. NIT: the Byte Budget's cycle numbers are low

Location: "A roll of the dice costs 24 cycles … A mummy's turn costs about 90
cycles, a Frankenstein's 130 or so in a corridor". The Decision log says the
same.

Evidence ("REVIEW turn costs"): `roll` is **40** cycles (`m.work(24)` plus two
peeks and two pokes, 16). A walking mummy's turn is 774, of which `setFrame` is
648, so **≈ 126** without the picture. A standing mummy's turn is 106.
Frankenstein in room 12's floor corridor is 856 a turn, **≈ 208** without the
picture. `owner`'s search (12 per object) and `grid.at` are what the estimates
left out. Also "A mummy's position is two bytes of his record, a
Frankenstein's six": Frankenstein's are **four** (`frank_x`, `frank_y`,
`frame`, `way`).

Fix: "A roll costs 40 cycles … A mummy's turn costs about 120 cycles, a
Frankenstein's about 200 in a corridor … a Frankenstein's four." Also note that
both walk with a new picture every turn, so in practice each turn is ~650 more.

### 11. NIT: the tie box's reason doesn't hold

Location: "Ties go to the lower number": "It almost never happens, because one of
the two distances is in fat pixels and the other in rows".

Problem: different units don't stop two numbers from being equal. Whenever
|dx| = |dy| (say 28 and 28) it happens. The behaviour described is right (I
checked `$3C67`: `A < best` skips, so the lower index wins a tie, and the
strictly-shorter rule then skips the equal one).

Fix: "It's rare: the two numbers have to match exactly, fat pixel for row. But
it's 1984's rule, so it's ours."

### 12. NIT: "We said then that the monsters would have to choose"

Location: inside-the-disk "The rungs rule".

Problem: Chapter 4's box only says the 1984 explorer shows the pole pose for a
moment. The "monsters will have to choose" note is in the Decision log, which the
reader never sees.

Fix: drop the sentence, or "That leaves the monsters a choice."

### 13. NIT: small wording

- "A mummy's record says four things: his state, where his ankh stands, and where
  his tomb is." That's three. → "A mummy's record says three things: …"
- Banned words (AUTHORING §1): "the dice just carry on" → "the dice carry on";
  "just like the ankh" → "like the ankh"; "his rule is simple" → "his rule is
  short". (The "mummy just released" one is time, not tone. Fine.)
- Boss Battle: "`frame_00500.ppm` has the mummy out of his tomb and following the
  explorer along the walkway above." It reads as if the mummy is on the walkway.
  → "… and following along the floor, under the explorer on the walkway above."
- The search test is still named "… except at a machine's walls", and its label
  "(in the search test, replace the end of the loop)" is vague. → "(in the search
  test, replace the comment above `const plan` and the lines down to the
  `expectEqual`)", and consider renaming the test "… except at walls and
  alcoves" (only if you're happy to touch the old test line in a listing).

### 14. NIT: room 12's sign gives advice you can't take on the first visit

Location: Frankenstein room sign: "… THEN HE PACES / IT. GO DOWN BEHIND / HIM, AND
RUN!"

Problem: on a first visit he's asleep, facing right, against the left wall, and
the pole lands you in front of him. "Behind him" only makes sense on a revisit,
when he's pacing. The chapter text says the right thing ("the pole drops you
right in front of him … Run for the bell").

Fix (18-character lines): "FRANK SLEEPS UNTIL / YOU STAND ON HIS / FLOOR, IN FRONT
OF / HIM. THEN HE PACES / IT. HE'S SLOW: RUN / FOR THE BELL!"

### 15. NIT: the alcove reads as an empty doorway

In `boss_sheet.png` (rooms 12, 13, 14) the alcove is a grey stone arch with a
black inside, the same silhouette and colours as the door arches. On room 13's
upper walkway, with Frank already out, it looks like a fourth door. A darker
back wall (fill the inside with code `1`, dark grey) or a lintel shape unlike
the doors' would tell them apart at a glance. Art only, no code change.

## Writer response

All findings are fixed as suggested (1–12, 14, 15, and 13 apart from the
point below). For 5, I logged the ankh and alcove sizes and the `$92`
erase and `$1C` redraw in the box and the Decision log as Chapter 11
work. I didn't make the ankh 23 rows tall now. Our walkway rows and
`in_front` boxes are all our own sizes, and Chapter 11 has to translate
every picture's placement anyway, so it's better to do this in one place.
For 6, room 13's upper-left walkway is now 18 long, so it shows a gap.
The prose mentions the gap, and the revisit test walks to the new end.

One point in 13 I left alone: renaming the old search test
("… except at a machine's walls"). The name is still true, because an
alcove's one-way cells are a wall too. Renaming it would add a listing
that only touches a test name. I made the D25 label precise instead.
