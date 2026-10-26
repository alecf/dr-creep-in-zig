# Review: Chapter 6 ("Flip the Switch")

Reviewer scope: `site/chapters/06-flip-the-switch.md`, its images
(`images/06-lightning.png`, `06-switch.png`, `06-zapped.png`,
`06-forcefield.png`, `06-conveyor.png`, `06-transmitter.png`), its diagrams
(`site/page/diagrams/ch06-links.html`, `ch06-wall.html`, `ch06-belt.html`), its
tools (`site/tools/ch06/`) and `site/code/ch06/` against `site/code/ch05/`. I
checked them against `site/AUTHORING.md` (the bible, and the Decision log with
the writer's ch06 entries), `docs/tutorial/outline.md`,
`site/code/machine/REFERENCE.md`, Chapters 1–5 and the ch05 review. For 1984
behaviour I used `reference/segrax-DrCreep/src/creep.cpp`
(`Sprite_Execute`, `Sprite_Collision_Check`, `Sprite_Collision`,
`obj_Player_Sprite_Collision`, `obj_Player_Collision`, `obj_Lightning_Prepare`,
`obj_Lightning_Pole_Execute`, `obj_Lightning_Sprite_Create`,
`obj_Lightning_Execute`, `obj_Lightning_Switch_InFront`,
`obj_Forcefield_Prepare`, `obj_Forcefield_Create`, `obj_Forcefield_Execute`,
`obj_Forcefield_Timer_InFront`, `obj_Forcefield_Timer_Execute`,
`obj_TrapDoor_Prepare`, `obj_TrapDoor_Switch_Check`,
`obj_TrapDoor_Switch_Execute`, `obj_Conveyor_Prepare`, `obj_Conveyor_Execute`,
`obj_Conveyor_InFront`, `obj_Conveyor_Control_InFront`, `obj_Teleport_Prepare`,
`obj_Teleport_InFront`, `obj_Teleport_Execute`), `creep.h` (`CONVEYOR_*`) and
the bytes in `disasm/object.s` (`$088F–$08BE`, `$54C2–$54EF`). Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch06/`:
- `cmp.py`, `cmp.out`: pulls the chapter's labelled ```zig fences and compares
  each one, label and body, with the writer's `listings.py` steps; lists every
  step's op.
- `rebuild/`, `rb-A` … `rb-F/`, `rebuild.log`, `outputs.json`: my run of the
  writer's `rebuild.py` (`WORK=` set to this folder).
- `code/ch06/`: a clean copy for fmt, build, test and wasm. Its `src/main.zig`
  ends with review-only tests ("REVIEW …"): normal play in the Conveyors room,
  the step-on/step-off trick, walking at the open hole, Q through the field,
  fire held at the button, a bolt from the right-hand door, a transmitter round
  trip, the costs, per-room bucket maxima, a replay of the Boss Battle script
  with per-frame bucket sums, and the shape table / castle sizes. They print
  with `std.debug.print`; run `zig build test 2>&1 | grep '\['` to see them.
- `mut/ch06/`: the checkpoint with `conveyor_held` never set, plus a test
  holding fire at the control (finding 5).
- `a_sheet.png` … `e_sheet.png`, `boss_named.png`, `lever_zoom.png`,
  `lever2.png`, `field_zoom.png`, `conv_zoom.png`, `gview.png`: frame sheets
  and close-ups. `shots/`: the three diagrams at 1280 and 400 px, light and
  dark, plus the wall diagram at 1 s steps.

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py` finds 109 fences,
  all matching `listings.py` in label and body, in order, plus two prose-only
  deletions (`doors.find` and its `map` import). `rebuild.py` gives
  **REBUILD BYTE-IDENTICAL**, and stages A–F each pass `zig fmt --check`,
  `zig build` and `zig build test`, and each one runs. I read every label
  against its op; three are loose (finding 14), none breaks the build.
- **The checkpoint is green.** On a clean copy, `zig fmt --check src`,
  `zig build`, `zig build test` (34: 33 game + the machine's) and
  `zig build wasm` (all three `web/` files) pass. The Boss Battle, run with the
  command exactly as printed, gives the quoted block **verbatim** (2,786 calls,
  max 236,486, buckets 326/235,206/1,278/2,750/2,192, 11 loading pauses, 0
  overruns).
- **Five of six screenshots match fresh runs pixel for pixel**: `06-lightning`
  = A/F 200, `06-switch` = A 320/330, `06-zapped` = B 260, `06-forcefield` = C
  350, `06-transmitter` = F 2510/2520. `06-conveyor.png` matches no run the
  tools produce (finding 2). The Boss Battle's named frames (330, 1010, 1700,
  2200, 2540, 2899) show what the text says (`boss_named.png`).
- **The quoted error is verbatim**: `'place' is not marked 'pub'` (`errs.py`).
- **The 1984 fidelity is very good.** Checked line by line:
  - Hit masks at `$0895`: player `$00`, lightning `$04`, forcefield `$03`,
    mummy `$02`, laser `$04`, Frankenstein `$00`. Ours are the first three,
    and the log names the rest for ch7/ch8.
  - `hitting` is `Sprite_Collision_Check`: every other actor with its
    sprite-hit bit, groups not sharing a bit, inclusive box overlap, both
    handlers called (`Sprite_Collision(a, b)` then `(b, a)`), true → flash. It
    runs every step, before the countdown, as 1984's does.
  - `player.hit` is `obj_Player_Sprite_Collision` (forcefield → false, else
    status 2 and true). `player.touch` is `obj_Player_Collision`: trapdoor panel
    with `x + width − panel.x < 4` → dead; switch → note it in `field_1A`, and
    `obj_Player_Execute` flips on "this ≠ last" (`$32DB`), exactly `tread`.
  - Lightning: switch at +4/+8 with pictures `$37/$38`, tip at x − 4, machines
    numbered by byte offset from `mRoomLightningPtr`, `$FF` ends the list,
    up = on / down = off (direction 0/4), `^=` on every listed machine, bolt at
    (tip x, tip y + 8), pace 1–4, picture never the same twice, pole colours
    every `ticks & 3`. All match.
  - Forcefield: wall at `column(field_x + 2)`, row `(field_y + 2 + 25) / 8`
    (`positionCalculate` then `−2`/`+4` bytes), 8 ticks × 30 steps, field
    sprite at `field_y + 2`, pace 4. Match.
  - Trapdoor: the wall at `column(x) + 1` (the ch04 note's `+4` bytes, paid),
    grid opened at once on shutting, panel disabled at once on shutting and
    enabled only when fully open (`roomAnim_Disable` at `$78`,
    `Draw_RoomAnimObject` at the end of opening). Match.
  - Conveyor: prepare clears bits 2–5, the switched/enabled edge rule, `^=`
    on+direction when running, `|= on` when stopped, ±1 a tick for the player
    and ±2 on `ticks & 7 == 0`, walking frames only, a 32-pixel belt. Match
    (`$54C2–$54EF` confirms the `& 7` on `$2E36`).
  - Transmitter: up (direction 0) changes on `ticks & 15 == 0`, wrap at the 0
    terminator, colour = target + 2, fire sends to (pad x, pad y + 7) and sets
    `execute`, ignored while executing. Match, with the logged 21-row offset.
  - Every deliberate deviation is in the log, and the important ones are told
    in Inside the Disk boxes (bolt link direction, field flag table, redraw vs
    recolour).
- **Play-test: every mechanic works, both ways.** With review tests and
  frame sheets:
  - Lightning: walking right from door 0 into the first bolt, and left from
    door 1 into the second, both kill (flicker, respawn at the Gatehouse).
    Down at the lever kills both bolts and dulls both poles; up brings them
    back. The lever's erase and redraw is clean (`lever2.png`).
  - Forcefield: stopped at feet 87 from the right and 76 from the left; the
    button drops it; the gauge refills bottom up one row every 30 steps; the
    field returns after 240 steps. **Q** walks straight through, as the
    chapter says.
  - Trapdoor: the plate flips it once per step-on; with the hole open, walking
    at it stops him at feet 83, alive; **G** shows the floor line broken on
    both sides of the hole (`gview.png`).
  - Conveyor: the control stops and reverses, then restarts; the belt carries
    him; with the hole open, the belt carries him in and he dies.
  - Transmitter: up cycles the lamp and wraps; fire sends him to pad 1 (by the
    door) and to pad 0 (upstairs, y 107 on the walkway); the pole takes him
    back down; no double send while flashing.
  - But see finding 1: in two rooms the layout keeps the reader from meeting
    the hazard the room is about.
- **The cost numbers check out**, measured directly: tint one cell 28, belt
  tint 224, belt draw 1,320, belt erase-and-draw 2,972, pole tint 88, pole
  draw 1,704, `room.first(.lightning)` 576, Lightning-room actors' bucket peak
  2,218 (walking, no switch). Shape table 3,265 bytes, castle 4,438 bytes.
  Exceptions in finding 7.
- **Every logged promise to ch6 is kept.** ch3's `later` entries (five of
  them now real), ch4's "Chapter 6 does the same" (trapdoors rewrite grid
  bits, with 1984's two-cell rule), ch5's `hit`/`touch` handler fields,
  sprite–sprite collision, "real deaths" through `player_status = dead` and
  `flash`, and "linking by index used lightly" (now taught properly). The
  `player_actor` indirection pays off (the field takes slot 0). No new keys;
  G, Q and N are reused.
- **The fiction holds.** No banned names. Three exclamation points, all on
  milestones. Prose is 5,431 words (`wc.py`), inside the 5,000–5,500 target;
  code 9,101.
- **Rendering.** All three diagrams fit at 400 px with no page or figure
  overflow, in both themes, with real text. Problems in findings 8 and 20.

## Findings, ranked

### 1. MUST-FIX: in the Trapdoors and Conveyors rooms the plate is on the way in, so the reader never meets the open hole

Location: `training.zig` rooms `trapdoors` (plate x 112, hole x 76) and
`conveyors` (plate x 124, belt 60–91, hole x 56). Prose: "Build and walk left.
The hole stops him at its edge. Step on the plate and its middle turns from red
to green". The `06-conveyor.png` alt text: "carried left towards the open
trapdoor". The Boss Battle: "Try riding the belt into the trapdoor". The sign:
"THIS ONE RUNS TO A TRAPDOOR!". The Mission Briefing: "A belt carries you
somewhere you'd rather not go".

Evidence:
- In both rooms the explorer arrives at door 0 on the right, and the plate
  lies between him and the hole. Walking left, he steps on it first, so the
  trapdoor shuts before he gets there. `d_sheet.png`: the plate turns green at
  frame 250, and he never sees the hole open. `e_sheet.png`: the same in the
  Conveyors room. "REVIEW conveyors room played normally": at the control the
  trapdoor is shut, and walking on and standing on the belt for 500 frames
  ends alive by the left door.
- `06-conveyor.png` itself shows the plate **green** and the trapdoor drawn
  shut (`conv_zoom.png`), so the caption is wrong.
- The only way onto the belt with the hole open is to step on the plate, step
  back off it, and step on again ("REVIEW … the on-off-on trick": then he is
  carried in and dies). No reader will find that.
- The writer's own test admits it: `explorer(m).box.x = 80; // on the belt,
  past the switch that would have shut the trapdoor`. Nothing tests that the
  open hole stops him, or that a trapdoor kills, without teleporting him.

Fix: change the two layouts so the room teaches what its sign says, then
regenerate the run, screenshots and tests. One way that works with the existing
code:
- **Trapdoors:** start the trapdoor **shut** and put the plate left of the hole
  (for example x 28, clear of the bell's box). He walks over the shut trapdoor,
  steps on the plate, and it swings open behind him; he has to step on it again
  to get back. Sign: "STEP ON THE SWITCH AND THE TRAPDOOR BEHIND YOU OPENS.
  STEP ON IT AGAIN TO SHUT IT." Or keep the trapdoor open and add an upper
  route to a plate beyond the hole.
- **Conveyors:** start the trapdoor **shut**, with the plate between door 0 and
  the control box (for example x 116). Walking in opens the hole ahead of him,
  and the running belt carries him into it. To get through, he reverses the
  belt at the control and steps back onto the plate to shut the hole. That is
  a real puzzle, and the sign stays true.
- Prose: rewrite "Build and walk left…" to match what happens. Replace the
  conveyor test's `box.x = 80` with plain walking. Add a test that walking at
  the open hole stops him at the cell beside it.
- Boss Battle: add a death on the belt (or say how to get one).

### 2. SHOULD-FIX: `06-conveyor.png` can't be regenerated from the tools

Location: `06-conveyor.png`; the log says "a room-7 run frame 320".

Evidence: no frame of `rb-A` … `rb-F` matches it. The nearest, `rb-E` 250/260,
differs in 278 pixels. `runs.py` has no other room-7 run. Every other image in
the series comes from a recorded run.

Fix: add the run to `runs.py` (after finding 1's layout change), take the
image from it, and log the frame. Make the caption say what is in the frame.

### 3. SHOULD-FIX: "a pointer to a slot that was freed and reused" argues the wrong way, and the paragraph repeats the Power-Up

Location: after the `ch06-links` diagram: "You can also check it. `$FF` can
mean "none", and a number can be compared with the table's size. A pointer to a
slot that was freed and reused looks just as good as a pointer to the right
one."

Problem: the contrast implies an index catches a freed-and-reused slot. It
doesn't. A stale slot number is exactly as wrong as a stale pointer. The code
avoids the problem a different way: `run` writes `actors.none` back the moment
it tells the bolt to go. The paragraph's other points (one byte, valid wherever
loaded, `$FF` for none) are repeated in the Index Link Power-Up.

Fix: cut the paragraph down to what the Power-Up doesn't say, and fix the
claim: "An index has one weakness it shares with a pointer: if the thing it
names goes away and its slot is reused, the number still looks fine. So
whoever lets go of a slot writes `$FF` back straight away, as the machine does
when its bolt goes."

### 4. SHOULD-FIX: "Five of the spare bytes in each object slot get names" is wrong

Location: "Objects that find each other": "The object table needs two new
things. Its comment says what lives there now:" and "Five of the spare bytes in
each object slot get names."

Evidence: `spare: [5]u8` becomes `actor`, `timer`, `spare: [3]u8`. Two spare
bytes get names. `number`, `open` and `step` already existed; only their
comments widen. "Two new things" never says which two.

Fix: "Two of the five spare bytes get names, and three old fields get wider
jobs. `number` was the door's place among the doors; now it's whatever number
links this object to others. `actor` holds…". Drop "The object table needs two
new things", or name them.

### 5. SHOULD-FIX: a Game Over symptom that can't happen

Location: Game Over: "**The belt reverses on every step while fire is held.**
The `held` bit isn't being kept from one step to the next."

Evidence: `a.fire` is already a *press* (ch05's `read`), so it is true for one
turn however long fire is held. In `mut/ch06/` I removed
`if (pressed) c.state |= castle.conveyor_held;` and held fire at the control
for 100 steps: **one** flip. The mistake that does cause flapping is forgetting
to clear `pressed` (`c.state &= ~(…)`): the belt then reverses every step
forever after one press.

Fix: "**The belt keeps reversing after one press.** `run` must clear
`conveyor_pressed` every step." Also say once, in the conveyor prose, why the
held bit is there at all when `a.fire` is already a press: 1984's control reads
the held button, and the bit is how the belt makes it an edge (and it keeps
player 2's bits for Chapter 9).

### 6. SHOULD-FIX: "the trapdoor's `touch` kills": the trapdoor has no `touch`

Location: after the conveyor screenshot: "The belt pushes, and the trapdoor's
`touch` kills."

Problem: `touch` belongs to the *explorer's* behaviour (`player.touch`). The
point of the trapdoor section was that the actor decides.

Fix: "The belt pushes him, and his own `touch` does the rest when his feet are
over the hole."

### 7. SHOULD-FIX: the Byte Budget's step numbers mix up buckets

Location: "In the Lightning room the actors' bucket peaks at 2,218 cycles, with
two bolts and the explorer. The busiest step in the whole Boss Battle run is
2,750 cycles, a seventh of a frame." And: "`objects.find` is about 76 cycles in
the Lightning room".

Evidence ("REVIEW boss replay"):
- 2,750 is **bucket 3 alone**, at frame 318. That is the step where he throws
  the switch in the Lightning room. The lever's erase and redraw runs inside
  his `touching`, so it lands in the actors' bucket.
- The same step's buckets 3 + 4 are **3,042** (the machines' `run` adds 292),
  about a sixth of a frame.
- So the two sentences seem to disagree about the same room.
- `find` costs 52 for machine 0 and 64 for machine 8. 76 is a miss over all six
  objects.

Fix: "Walking in the Lightning room, the actors' bucket peaks at 2,218 cycles,
with two bolts and the explorer. Throwing the switch is the busiest step of the
Boss Battle: 2,750 in the actors' bucket (the lever's erase and redraw happen
during his turn), about 3,040 with the machines' own work, a sixth of a frame.
`objects.find` takes 52–64 cycles in the Lightning room."

### 8. SHOULD-FIX: the wall diagram rests on "wall down", and the paragraph after it repeats it

Location: `ch06-wall` and the paragraph after it ("A wall goes up in one cell,
but no bit in that cell changes. The cell on its left loses its way right …").

Problems:
- The figure loops between "wall down" (0–2 s) and "wall up" (2–4 s). Paused,
  and for reduced-motion readers who start paused, it shows **wall down**:
  every arrow is present, which is the state that isn't the point
  (`shots/ch06-wall-*-light.png`). The bible says the resting state "must make
  sense on its own".
- In dark mode the hole marker is `--c0` black on a near-black cell, which is
  invisible (`shots/wall-t1.png`).
- The diagram's own small print, `grid.wall`'s doc comment and the paragraph
  all say the same thing ("left loses right, right loses left, what's inside
  can walk out"). Bible §5: "A diagram replaces the paragraph that was
  describing the same thing."

Fix:
- Swap the keyframes so 0–50 % is "wall up".
- Give the hole a visible outline or use `--ink-soft`.
- Cut the paragraph to the part the figure can't show: "This is the 1984
  game's own trick, and it has a nice side effect: a wall can never trap him
  inside it."

### 9. SHOULD-FIX: an Inside the Disk box quotes a name the 1984 disk doesn't have

Location: "Four belts and a backwards bit": "the bit we call `conveyor_left` is
named in the 1984 data as the belt moving *right*."

Evidence: the 1984 game has no names. `CONVEYOR_MOVING_RIGHT` is a label in a
much later reconstruction (`creep.h`). The behaviour is real (`$54D4–$54E0`:
bit set → `$FF`, so things move left). Inside the Disk boxes are lore about
the shipped disk, and this one claims something the disk doesn't contain.

Fix: keep the behaviour and drop the name: "One more thing: the 1984 belt's
direction bit is easy to read backwards. With it set, the belt's pictures run
one way and whatever stands on it moves left. We named ours after what it does
to you." Or drop the paragraph.

### 10. SHOULD-FIX: refer back correctly (Edge Detector, `inline for`, the final room)

- "Chapter 2's fire button had the same problem: a press is "down now, and up
  last time"." The rule is **Chapter 1's Edge Detector Power-Up** (ch02 and ch05
  both call it that). Fix: "That second rule is Chapter 1's Edge Detector again:
  a press is "down now, and up last time"."
- "`inline for` unrolls the loop at compile time, so `name` is known…" is
  explained as if new. Chapter 3's Training Castle test already uses the same
  loop (`03-haunted-blueprints.md:2151`). Fix: "The loop is Chapter 3's: `inline
  for` over the room names, so `@field` can pick each room's plan."
- "The final room isn't in the plan, so the loop now stops before it. Chapter 9
  builds that room properly." The final room *is* in the plan, as
  `plan.final`, and it is already built (ch3). Fix: "The final room's plan is
  `plan.final`, not one of `plan.rooms`, so this loop leaves it out. It has no
  machines to check." Drop the Chapter 9 promise, or log it as ch9's.

### 11. SHOULD-FIX: press vs held fire matters for the forcefield, and the reader isn't told

Location: the button, control and booth all use `a.fire` (a press). The log
lists it as deviation (5).

Evidence ("REVIEW forcefield: fire held at the button"): holding fire at the
button for 300 steps, the field comes back after 240. In 1984,
`obj_Forcefield_Timer_InFront` re-arms the timer every turn while fire is
*held*, so standing at the button holding fire keeps the field down. That's a
real tactic in two-player rooms, unlike the bell, where press vs held changed
nothing visible (and ch05 still told the reader).

Fix: one sentence after `press`: "In 1984, holding fire at the button keeps
restarting the gauge; ours wants a fresh press each time. Chapter 9's second
player may want the 1984 way back." Or adopt held fire for the button only.

### 12. SHOULD-FIX: `^=` explained in a way that needs a second read

Location: "Throwing a switch flips one of them with `^=`, which turns over the
bits that are set on its right and leaves every other bit alone."

Problems:
- "On its right" reads as "to the right of the bit".
- "One of them" is vague: the switch flips only `lightning_on`.
- JavaScript has the same operator, and that's the cheapest possible bridge.

Fix: "Throwing a switch flips `lightning_on` with `^=`. `state ^= mask` turns
over every bit that is set in `mask` and leaves the others alone (JavaScript's
`^=` does the same). So `state ^= lightning_on` turns a running machine off and
a stopped one on, without reading it first."

### 13. SHOULD-FIX: the lever's movement is never visible

Location: "**Both machines die at once!** The bolts vanish, the poles go grey,
and the lever drops." and `06-switch.png`.

Evidence: `lever_zoom.png`. The explorer stands in front of the switch to work
it, so his sprite hides the lever whenever it moves. The screenshot shows him
covering the plate. The pictures themselves are fine (`lever2.png`, after he
steps away).

Fix: take the screenshot a few steps later, after he has walked off the switch
(A 360), and say "step away and the lever is down". Or raise the lever above his
hat line in `lever_plate`.

### 14. NIT: three labels don't quite say what the listing does

- D24 "(in the searching test, replace the comment and the `walls` line)". It
  shows four lines: the comment, the unchanged `plan` line, `var walls`, and a
  new `for`. Say "replace the comment and the two lines below it".
- A31 "(… replace everything up to `player.add`)": the listing includes
  `player.add`. Say "the first seven lines of the branch, from
  `m.poke(hw.control, 0);` through `player.add(m);`" (it shows eight, because
  the new order adds a `m.bucket` line).
- A35 "(add above `hold`, at the very end)": `hold` is the last function, so
  this goes *second-to-last*. Say "add above `hold`, the last function in the
  file".

### 15. NIT: filler and banned words

- "An open trapdoor under his feet is simply `die`." Drop "simply".
- "The obvious way is to draw it again". Write "One way is to draw it again".
- "It's another link by number, just pointing the other way." Drop "just".

### 16. NIT: small wording

- "`die` is the part of `kill` that any hazard can use: only if he's playing,
  he's now dead." Rewrite: "`die` is the part of `kill` every hazard shares: if
  he's playing, he's dead now, and it says whether that happened."
- "And a switch that works when he **steps onto it**, not while he stands on
  it." is a fragment. Write "And a switch works when he **steps onto it**…".
- "then moves one into the other" (the `tread` paragraph). Write "then copies
  this step's into `player_last_plate`".
- "Either can find the other with `objects.find`, so no one has to store a
  link." Both store the number, which is the link. Write "so neither has to
  store the other's slot".
- "A trapdoor needs the actor to decide": add why, in a clause: "(the same hole
  kills an explorer, will trap a monster in Chapter 8, and means nothing to a
  laser)".

### 17. NIT: "a pole hanging from the ceiling"

Location: the prose, and the `06-lightning.png` alt text ("two machines hang
from the ceiling").

Evidence: the poles start at y 112, in mid-air below the sign
(`06-lightning.png`). There is no ceiling. The old sign's "between ceiling and
floor" is gone.

Fix: "a pole hanging in the air", or start the machines at the top of the room.
The sign is above them, so a short beam under the text would do.

### 18. NIT: "draws all six pieces again"

Location: Inside the Disk "The bolt that remembers its machine".

Evidence: `obj_Lightning_Pole_Execute` redraws `length` pieces (`word_40 + 3`).
Six is our room's length.

Fix: "draws every piece of the pole again".

### 19. NIT: Byte Budget "105 more for the machines' records"

The 105 bytes also include five rewritten signs and the Transmitter's ladder
replaced by a pole. Write "105 more: the machines' records and the rewritten
signs."

### 20. NIT: the belt diagram, paused, shows two shades

Location: `ch06-belt` at rest (reduced motion).

Evidence: `shots/ch06-belt-400-dark.png`. The cells read $B1 $BF $BF $B1 … The
third cell's `-0.32s` delay lands exactly on the `66.667%` step and rounds to
the previous keyframe. Playing, it shows three shades.

Fix: delays of `-0.17s` and `-0.33s` (or keyframes at 33%/66%).

### 21. NIT: Bonus Stage

- "What happens when the two switches disagree?" is a quiz with an answer
  (each switch flips its machines' bits). Write: "Throw them in different
  orders and watch a machine run with one lever down. 1984 lets that happen.
  Decide whether you want it to."
- "Make the forcefield's ticks depend on a byte in its record" changes the
  4-byte record that real castles must load unmodified in Chapter 11. Write "a
  byte in a small table of your own, by the field's number".

### 22. NIT: note for Chapter 11 (log only)

`room.tint`, `room.unplace` and `screen.erase` compute `x − castle.left_edge`
and `x / 4` with no off-left handling. A machine at castle X < 16 panics
(overflow) in Debug and ReleaseSafe. Add them to the log's ch11 "check the real
castles for X < 16" note.

### 23. NIT: Stage B retypes the whole lightning test

The stage A test (19 lines) is replaced wholesale in stage B by a 24-line
version that adds five lines. An insertion ("add below the first
`expectEqual`: …") saves the reader retyping 19 lines.

### 24. NIT: boxes and captions that repeat

- Game Over's first bullet repeats the prose's quoted `pub` error word for
  word.
- `ch06-links` has a paragraph of small print ("No address is stored
  anywhere…"), then a caption saying the same, then the prose.

Keep one of each.

### 25. NIT: the apology sits in a lore box

Location: "Up to choose, fire to go": "It's my mistake, and the sign is fixed
below."

Inside the Disk boxes are 1984 lore. Ch05 owned its sign mistake in the main
text. Move the last sentence into the prose before the room listing ("Chapter
3's sign for this room had up and fire the wrong way round; this one is
right"), and keep the box for how the 1984 booth works.

## Weakest passages, with rewrites

1. "Build and walk left. The hole stops him at its edge…" (finding 1): after
   the layout change, describe the room as it plays.
2. The stale-pointer sentence (finding 3): rewrite given above.
3. "Five of the spare bytes…" (finding 4): rewrite given above.
4. The `^=` sentence (finding 12): rewrite given above.
5. The Byte Budget's time paragraph (finding 7): rewrite given above.

## What works well

- **One pattern, five machines.** Framing every machine as "a control linked
  to a device" makes five mechanics feel like one lesson. The pattern
  paragraph after `pull` ("The switch never touches a bolt or a pole. It
  changes the castle's bits and asks the machines to look.") is the clearest
  statement of the engine's design in the series so far.
- **The under-the-hood box lands the ladder idea.** The JS bridge is concrete:
  `JSON.stringify` silently duplicating the machines, then the id fix, then
  1984's byte-offset ids. The `ch06-links` diagram follows one switch all the
  way to a sprite slot with the room's real numbers.
- **"The grid isn't the castle any more."** Turning the ch4 invariant test
  into "two differing cells per wall", and using Q to *show* the difference
  in play, is a great way to teach runtime patching of a derived table.
- **The Recolour Power-Up is earned.** It comes with measured costs (224 vs
  1,320 vs 2,972; 88 vs 1,704) and the belt diagram, and its last line ("Plan
  the art for it") is the advice a retro artist would give.
- **The fidelity work is careful.** The hit masks, the wall arithmetic, the
  trapdoor's "deadly only when fully open, safe from the first step", the
  conveyor's `& 7` extra pixel, and up-to-choose/fire-to-go all match 1984,
  and the transmitter sign correction is owned honestly.
- **Death is wired cleanly.** `die` shared by `kill`, `hit` and `touch`, with
  the flag doing the rest, means Chapter 8's monsters can plug in without
  touching the lifecycle.
- **The tooling is solid**: 109 listings, six staged builds, a byte-identical
  rebuild, and a verbatim Boss Battle.

## Writer response

All findings are addressed. One was done differently from the suggestion,
and one was log-only, as asked:

- **#1 (rooms 6 and 7).** Room 6 follows the suggestion (trapdoor shut,
  switch at x 32 beyond it, so it opens behind you). For room 7 I couldn't
  use the suggested layout (shut trapdoor, switch at x 116 between the door
  and the control). With one plate between the way in and the hole, 1984's
  step-on rule flips the trapdoor on every crossing. A hole met open can
  then only be crossed by turning round *on* the 4-pixel plate (an
  8-frame window). So reversing the belt and stepping back onto the plate
  reopens it the moment he crosses again, and the room can't be passed in
  practice. Instead, the trapdoor starts open with its switch beyond it
  (x 28), and the belt runs into it: walking in along the floor kills him.
  A high walkway (ladder at x 112, pole at x 36) is the way round, and
  stepping on the switch at the bottom shuts the hole. Two tests prove it
  in normal play without setting `box.x`:
  - trapdoor: opens behind him; walking back, he is stopped alive at x 72;
    stepping on the switch again shuts it;
  - conveyor: carried in and dies; the control stops and reverses the
    belt; the high road takes him round, and the switch shuts the hole.

  The prose now says the switch flips from either side, so you must stop
  on it before turning round. The Boss Battle takes the high road, and the
  chapter says how to ride the belt to your death.
- **#22** is log-only (ch11 note), as the finding asks.
- **#24:** I kept the `ch06-links` small print and dropped its caption,
  and dropped the duplicate Game Over bullet.

Everything else (#2–#21, #23, #25) is applied as suggested or near it.
Details are in the Decision log entry "ch06 review fixes".
