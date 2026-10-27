# Review: Chapter 9 ("The Great Escape")

Reviewer scope: `site/chapters/09-the-great-escape.md`, its images
(`images/09-escape.png`, `09-two.png`, `09-company.png`, `09-map.png`,
`09-over.png`), its diagrams (`page/diagrams/ch09-header.html`,
`ch09-union.html`, `ch09-bcd.html`), its tools (`site/tools/ch09/`) and
`site/code/ch09/` (against `site/code/ch08/`), plus the two-line change to
`site/code/machine/REFERENCE.md`. I checked them against `site/AUTHORING.md`
(the bible and the Decision log, including the writer's ch09 entries),
`docs/tutorial/outline.md`, Chapters 3 and 5–8 (for the promises they made to
this one) and the ch05 and ch08 reviews. For 1984 behaviour I used
`reference/segrax-DrCreep/src/creep.cpp` (`Game`, `roomMain`'s exit loop,
`mapDisplay`, `mapArrowDraw`, `mapRoomDraw`, `gameEscapeCastle`, `hw_IntSleep`,
`obj_Player_Sprite_Collision`, `obj_Player_Add`, `obj_RayGun_Execute`,
`obj_Forcefield_Timer_InFront`) and the bytes in `disasm/object.s` (`$0A82`
IRQ handler, `$0F61–$0F93` GAME OVER strings, `$11C9–$1202` map tables,
`$1AB2–$1AE5` escape strings and walk table). Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch09/`:
- `tools/cmp.py`: compares the chapter's 116 labelled ```zig fences, label and
  body, with `listings.py`.
- `rebuild/`, `rb-A` … `rb-E/`, `at-A4/`, `at-D21/`, `errs/`, `rebuild.log`,
  `outputs.json`: my run of the writer's `rebuild.py` and `errs.py` (`WORK=`
  set to this folder).
- `code/ch09/`: a clean copy for fmt, build, test and wasm. Its `src/main.zig`
  ends with review-only tests ("REVIEW whole castle for two …", "REVIEW a new
  game after a whole game …", "REVIEW turn order …", "REVIEW player 2's last
  life …", "REVIEW costs", "REVIEW two on one ladder …").
  `zig build test 2>&1 | grep REVIEW` prints the numbers quoted here; the
  screen dumps (`rv-*.ppm`) land in `code/ch09/`.
- `boss1.png`, `boss2.png` (Boss frames 30 … 3499), `mapzoom.png` (the map
  frame at 8×), `p2sheet.png` (player 2's GAME OVER and the map after it),
  `fig/` (the three diagrams and two images at 1280 and 400 px, light and dark;
  `tools/shots9.cjs`).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `cmp.py` finds 116 fences,
  all matching `listings.py` in label and body, in order. The unlabelled steps
  are the two `| Replace | With |` tables (A5–A7, A51) and the prose-only
  deletions (the old `player` region and its `regions` entry, `newGame`, three
  `map` imports, the final room's "YOU ESCAPED!" line), each told in the prose.
  `rebuild.py` gives **REBUILD BYTE-IDENTICAL**, and stages A–E each pass
  `zig fmt --check`, `zig build` and `zig build test`, and run. Three labels
  don't say what their op does (finding 9).
- **The checkpoint is green.** On a clean copy: `zig fmt --check src`,
  `zig build`, `zig build test` (**67/67**: 66 game + the machine's) and
  `zig build wasm` (writes `web/game.wasm`, `index.html`, `shell.js`).
- **The Boss Battle is quoted verbatim.** The command is `RUNS['E']` exactly,
  and the output block matches my run byte for byte (`3243 calls`,
  `max 244058 (1241%)`, buckets 37346/241532/2510/2618/2160,
  `overruns: 0, loading pauses: 28`). Frames 700, 1420, 2100, 2700, 3000 and
  3499 show what the text says (the map at 1420 really has 00:00:21 against
  00:00:10). The stage A command is `RUNS['A']` exactly. One sentence about
  *when* the N keys land is wrong (finding 12).
- **The quoted errors are verbatim.** `errs.py` on the snapshot after A4 gives
  exactly one error, `local constant shadows declaration of 'room'`
  (`src/castle.zig:386:11`); after D21, exactly one,
  `m.view(game.Between): game.Between.over is smaller than the union; every
  field must be the same size` (from the machine's `layout.zig`, which has had
  this check since chapter 1; the card's new bullet now documents it).
- **The screenshots match fresh runs pixel for pixel.** All five are the
  stated frames of runs A/B/C/D at 2× nearest (`ImageChops` bounding box
  `None`), and each caption describes its picture.
- **The numbers in the prose check out**, with three exceptions (finding 10).
  Measured in "REVIEW costs" (frame figures carry the frame loop's own 20
  cycles): copy 37,346 − overhead → 37,244; first map 111,890 ("nearly six
  frames", 5.7); map frame 136; `clock.print` 5,472; `tick` with two explorers
  72; `up` 14; escape draw 118,902. Castle 4,644 bytes, 11 new shape Ids,
  `players` 10 bytes, `between` 7.
- **A new game really is a fresh castle (flagged point a).** "REVIEW a new game
  after a whole game" plays the whole Training Castle alone (every door opened,
  keys taken, mummies and Frankensteins dealt with, belts turned, trapdoors
  flipped), sits through GAME OVER, presses fire again and compares *all 64 KB*
  with a first game at the same moment (the first room just drawn). After the
  whole game, 102 bytes of the castle differ from staging, all inside its
  4,644-byte size, none beyond; the staging copy still equals
  `training.bytes`. After the new game, `$7800–$97FF` is identical, header
  scratch (pockets, key counts, times, `escaped`) included, and so are the
  visited bits. The only differences anywhere are the dice, `game_tick`, one
  text-buffer byte, the recoloured map pictures in the shape table, stale bytes
  in *free* actor and object slots, and registers of disabled sprites: none of
  it game state.
- **The whole castle plays, alone and for two (flagged point a).** Both
  whole-castle tests pass. Because the two-player test asserts only player 1's
  bytes, I re-ran it and read player 2's: **both escaped, both still have 3
  lives, both `in_game` 0**, equal times (00:04:31, as they move in step). So
  player 2 genuinely gets to the end. (Finding 13 suggests asserting it.)
- **Turn order is 1984's (flagged point b).** 1984 `Game()` (`$0E2A`): both in
  game and the rooms differ → the player in `$7811` sits out and `X ^ 1` plays;
  same room → both; one left → him. `$7811` is written in `roomMain`'s loop
  (`$1594`): 0 while player 1's status is 0, else 1 while player 2's is.
  Ours (`roomOver` scanning player 2 then player 1, `next` taking `last ^ 1`)
  is the same rule. "REVIEW turn order" splits the players in the Long Gallery
  (player 1 on to Ladders first, player 2 back to the Gatehouse), then lets
  whoever is shown walk straight back out: the rooms come up **2, 0, 1** (player
  1, player 2, together). Strict turns, as the main text says, but not as the
  "Whose turn" box says (finding 2).
- **The map matches 1984 where it says it does (flagged point b).**
  - Arrow offsets: `$11DA` = `FF 02 FF FB` (dx −1, +2, −1, −5) and `$11DE` =
    `F6 FE 06 FE` (dy −10, −2, +6, −2), added to room + door map bytes, then
    `(A − 4) × 2` and `+ $32` for the sprite, which is `sprites.place`'s
    `2x − 8` and `+50`. The arrow pictures by wall (`$11E2` = `14 15 12 13`)
    point into the room, as ours do.
  - Blink: `$11D1/$11D2` = `06`, `0F`. The map loop alternates `$11D7` between
    the players once a pass, and each pass waits one `interruptWait(1)`, which
    is one frame: the IRQ at `$0A82` decrements `$2E35` only on raster split 0.
    So each counter ticks every other frame: 6 × 2 = **12** and 15 × 2 = **30**
    frames. Right.
  - ONE UP/TWO UP colour by lives: `$11E5 + lives` → `0A 07 0D` for 1, 2, 3
    (pink, yellow, light green). Right. Steady white when both use one door
    (`$10C8`, comparing only the doors). Right.
  - Door gaps: 1984 draws the side-wall gap at room y + `map_y`, and top/bottom
    gaps two fat pixels wide at room x + `map_x` (with the `& 2` alignment
    folded into the picture choice). Ours is equivalent.
- **The escape matches 1984 where it says it does.** The walk table at `$1AD1`
  is `80 00 19 02 2D 00 00` and, from `+8`, `AC 00 2C 01 19 02 2D 00 00`: legs
  {128 right, 25 cheer, 45 right} and {172 right, 44 left, 25 cheer, 45 right},
  chosen when `seedGet() & $0E == 0` (one in eight), a step every
  `interruptWait(2)`, starting at x 8. GAME OVER waits `hw_IntSleep($23)` = 6 ×
  35 = **210** frames, says "FOR PLAYER n" only in a game for two for each
  player whose `in_game` is 0, and comes after every escape or lost last life
  (`$0F62`). The order after a room (dead → lives − 1 → start room, or out;
  escaped → escape screen → out) is `$0E8D–$0F06` exactly.
- **Two's Company mechanics are 1984's.** Jostle is `$353F`: other sprite in a
  climbing frame (`$2E–$31`) or the pole frame (`$26`) → nothing; same Y →
  nothing; other lower → mask `$EF` (no down), higher → `$FE` (no up). Our
  `climb_0 … explorer_slide` range is exactly those five pictures. Guns: P2
  looked at first, strictly nearer wins, so a tie goes to P2 (`$4B46`). The
  forcefield button runs every step `mButtonState` is set, which is the raw
  held button (`$2208`). All as the chapter says.
- **Player 2's last life while player 1 plays on (flagged point d) is
  sensible.** I re-ran the writer's scenario with screen dumps: GAME OVER shows
  only "FOR PLAYER 2" (in 1984's place, y 128), then the map shows only ONE UP
  with player 1's time and his arrow, and the game goes on in player 1's room.
  That is exactly 1984's sequence. Escapes for one while the other is elsewhere
  also follow 1984 (escape → GAME OVER "FOR PLAYER n" → the other's map).
- **The diagrams are right and legible.** The header list's offsets match
  `castle.zig`; the union's field order matches `Chart`/`Escape`/`Over`, and its
  resting (paused) state lights `chart` alone, which reads correctly; the BCD
  rows are right bit for bit (`$09`, `$0A`, `$10`, `$60`, `$00`). At 1280 and
  400 px, light and dark, nothing overflows and the page has no horizontal
  scroll (one word wraps badly, nit 21).
- **Promises kept.** Chapter 3's clean copy at `$9800`; Chapter 6's "the 1984
  way back" for the forcefield and its player-2 conveyor bits; Chapter 7's
  second pocket; Chapter 8's nearest-explorer box. No new keys (reserved-keys
  rule holds). Prose is **5,450** words by `wc.py`, inside the 5,000–5,500
  target. The ladder rungs (union, BCD) are the outline's.

## Findings

### Should fix

**1. The Game Over box lists correct behaviour as a mistake.** The last bullet:

> **Two explorers climbing a ladder walk through each other.** `steer` must `&`
> the grid's ways with `r.mask`, then reset the mask to `0xFF`.

But by the rule the chapter just taught (and 1984's `$353F`), two explorers who
are *both* on a ladder do pass through each other: each one's `jostle` sees the
other in a climbing frame and returns. "REVIEW two on one ladder" shows it:
player 1 eight steps up (y 155), player 2 climbs after him and ends above him
at y 131. A reader who sees this and "fixes" `steer` is chasing a bug that
isn't there. **Fix:** describe the real symptom: "**The one up the ladder climbs
down through the other's head.** `steer` must `&` …".

The same section's prose has the same blur: "A side-by-side touch, or one on a
ladder or pole, changes nothing" comes right after "if one of them is on a
ladder above the other, he can't climb down", so "one on a ladder" seems to
contradict it. **Fix:** "A side-by-side touch changes nothing, and neither does
touching an explorer who is on a ladder or pole himself."

**2. The "Whose turn is it?" box says something that can't happen.**

> That means a player can wait on the map while the other plays several rooms,
> if the other keeps going through doors.

`last` is always set in a room someone played (whoever is still walking at the
end of it), so apart, the players alternate strictly; "REVIEW turn order" gives
rooms 2, 0, 1. The main text says so ("So the players take turns, and neither
has to wait for long"), and the box contradicts it. (The waiting player isn't
on the map either: `here` leaves him off.) In 1984 a run of rooms for one player
*can* happen, but only through a quirk: an absent player's header status still
counts if it is 0, which is true only before he has ever been added, so in a
two-player game whose two **start rooms differ**, player 2 keeps playing until
he reaches player 1's room or leaves the game. Ours skips absent players
(`actor == none`), which is the sensible reading, and the Training Castle starts
both in the Gatehouse, so the quirk never shows. **Fix:** replace the sentence
with something true, e.g. "Apart, they take strict turns: the one who just
played waits while the other plays one room." Optionally log the start-room
quirk for Chapter 11 (real castles), as a deviation.

**3. "A clock in a chip" breaks the fiction.**

> 1984 doesn't count frames. Its machine had a time-of-day clock in one of its
> chips … Our machine has no such clock, so `tick` counts frames instead

In the fiction (AUTHORING §2) the 1984 game *is* a Comet 64 game. Saying its
machine had a chip ours lacks says the 1984 game ran on a different computer,
which is the real-world story the bible keeps out. **Fix:** keep the facts that
fit the fiction and drop the hardware comparison: "1984 timed each room in
tenths of a second, not frames, and kept the same four BCD bytes at the same
`$55`: tenths, seconds, minutes and hours. Ours keeps frames in the first byte,
so its seconds, minutes and hours come out the same. The map shows the times;
1984 never puts them on screen during a room, and nor do we." (Also, line 1350
is one long unwrapped line in the source.)

**4. The second `| Replace | With |` table breaks the convention.** The
Decision log's rule: purely mechanical, "a missed occurrence fails to compile",
and the prose says "with your editor's find and replace" and names that safety
net (Chapter 5 did: "any you miss won't compile"). Here:
- `, m.ram[map.room_number])` → `, m.ram[castle.room])` is not a rename. It
  swaps which byte the tests read (the header's "where he's going" for the room
  on screen), it is needed because going through a door now sets `castle.room`
  at once, and a missed one still compiles (it fails a test, or worse, passes).
  The prose calls them all "the old player bytes", but `room_number` isn't one.
  At 400 px the cell also renders as a lone "," on its own line.
- Neither table's lead-in says "find and replace" or mentions the compile
  error.

**Fix:** keep the three `map.player_*` rows with Chapter 5's wording ("Find and
replace these in `main.zig`'s tests (any you miss won't compile)"). Move the
`room_number` change out of the table and say why: "and where a test checks
which room he went to, it now reads `castle.room`, because the header knows the
next room the moment he steps into the doorway". The `room` → `bytes` table
needs the same lead-in ("a missed one is the same error again").

**5. "This is the chapter's ladder rung."** "Ladder rung" is the outline's
author-facing name for the under-the-hood ladder; the reader has never been
told about it, so the sentence has no referent they can name. **Fix:** "This
is the chapter's big idea under the hood."

**6. GAME OVER colours the players with 1984's coats, not ours.** `drawOver`
writes "FOR PLAYER 1" in yellow and "FOR PLAYER 2" in orange. Those are 1984's
player colours (`$0F71`/`$0F83`), but the chapter made ours white and yellow and
says so in the Inside the Disk box. So on our GAME OVER, player 1's line is in
player 2's coat. The orange line is also dim on black (see `09-over.png`).
**Fix:** colour each line with `player.coat(p)` (white, yellow), or say in the
box that GAME OVER keeps 1984's colours.

### Nits

**7. The "harmless, for now" rule (flagged point c) reads honestly, but "for
now" points the wrong way.** "So a `player` joins the forcefield as harmless,
for now" suggests explorers will later hurt each other. They never do. What
comes later is jostling. **Suggest:** "So a `player` joins the forcefield as
harmless. (In Two's Company they'll at least get in each other's way.)"

**8. Jostling switches person.** "If the other one is lower down, **my** next
step can't go down … the ways **I'm** still allowed", in a section that
otherwise says "he"/"his". **Suggest** "his next step", "the ways he's still
allowed".

**9. Three labels don't say what their op does.**
- C18 "(in the through-the-door test, add after the two `doorway` checks)"
  shows the **whole test**, and the change is two `onward` lines in two places.
  **Suggest** "(replace the through-the-door test)".
- A33 "(in `ring`)" is the doc comment only. **Suggest** "(the comment on
  `ring`)".
- A30 "(in the `.draw_room` prong)" replaces `player.add(m);`. **Suggest**
  "(in the `.draw_room` prong, replace `player.add(m);`)".

**10. Three numbers are off.**
- "That's 4,644 bytes at 8 cycles each, 37,244 cycles in all": 4,644 × 8 is
  37,152; the other 92 are the stores around it. **Suggest** "37,152 cycles for
  the bytes, 37,244 with the rest".
- Byte Budget: "The header gives the game 87 bytes of state". `$09–$5E` is
  2+2+2+2+1+1+2+64+8+2 = **86** (87 counts `$5F`, which is `final_room`).
- Byte Budget "GAME OVER: 98,708" is the one-line case; with both "FOR PLAYER"
  lines (the screenshot, the Boss) it is **106,856**. The busiest escape frame
  in my two-escape run is 14,376 (14,238 quoted). Both are still loading pauses
  or well inside the budget, so only the figures need care.

**11. The header comment says "the rest are zeros".** `castle.zig`: "The castle
file fills in the first nine bytes. The rest are zeros on the disk". But
`final_room` at `$5F` comes from the file, and the Training Castle sets it. The
prose's "Most of the rest" is right. **Suggest** "The castle file fills in the
first nine bytes and `final_room`. The rest are zeros on the disk …".

**12. The Boss text puts the N keys on the map.** "On the map, N eighteen times
goes to Two's Company." The run presses fire on the map at frame 40 and the N
keys (60 … 315) land in rooms (frames 50 and 70 are room-drawing blanks; the
first map is frame 30). Also why Two's Company never appears on the later map:
N doesn't mark rooms visited. **Suggest** "Fire on the map, then N eighteen
times flips to Two's Company."

**13. The two-player whole-castle test doesn't check player 2.** It ends with
player 1's `in_game`. Add `escaped + 1 == 1`, `in_game + 1 == 0` and
`lives + 1 == 3` (all true, as above) so "for one or two" is something the test
proves.

**14. "Escaping is checked after dying … even if he got the `escaped` byte on
the way."** He can't: `escaped` is set in `walkIn`, which makes him `doorway`,
and only a `playing` explorer can die. The sentence invents a case. **Suggest**
dropping it, or "A dead player can't also have escaped, so the order is only
tidiness."

**15. The map screenshot's "one white arrow" is hard to find.** In `09-map.png`
the steady white arrow sits on the Long Gallery's white bottom wall (the
Ladders door is at the room's foot, and dx −5 puts the arrow over the
neighbour's wall), so only its tip shows (`mapzoom.png`). 1984's numbers, so
not a bug, but the caption points at something the reader can barely see.
**Suggest** a frame where the two arrows are at different doors (coat colours),
or a caption that says where to look ("at the foot of the wall between the
Long Gallery and Ladders").

**16. The Mission Briefing says he cheers while the room builds.** "the final
room builds itself piece by piece while you cheer". Ours builds first, then he
walks and cheers. **Suggest** "the final room builds itself piece by piece, and
then you cheer."

**17. `inRoom`'s explanation.** "That keeps every later frame where it was in
Chapter 8, so the tests that count frames still count right." The room now
starts 8 frames later than in Chapter 8, not at the same frame. What 8 keeps is
the engine's phase: 8 frames is 4 steps, so anything that happens every second
or fourth step still lines up with the old tests. **Suggest** saying that.

**18. `up`'s limit for hours.** "At the `limit` (60 for seconds and minutes,
100 for hours)" but the code passes `0xA0`, and "100" in a BCD byte reads as
`$100`, which can't exist. **Suggest** "for hours, `$A0`: what `$99` + 1 + 6
becomes, since there's no third digit to carry into."

**19. "they agree with the Training Castle's first room".** In "What's ours in
the escape", the reader can't tell what the door map bytes agree with. **Suggest**
"Our room builder works out each door's map bytes itself; a real castle's own
bytes may put a gap or an arrow a little differently, and Chapter 11 can
check." The box's title is also narrower than its contents (it covers the map,
the coats and fire too): "What's ours" would fit. One unlogged difference there:
1984 changes the cheer picture every step (`$1A0A`), ours every four.

**20. The map pictures' sentence.** "A room on the map is drawn in cells 4 fat
pixels wide and 8 rows tall, the sizes in its directory entry." The entry gives
how many cells, not their size. **Suggest** "… 8 rows tall; its directory entry
says how many across and how many down."

**21. Union diagram at 400 px.** `overflow-wrap: anywhere` splits "steady" into
"stead / y". `hyphens: auto` or a slightly smaller font for that cell would
keep the word whole. A JavaScript bridge would also help the union paragraph:
"like one `ArrayBuffer` read through different typed views".

## Summary

The checkpoint is solid: it rebuilds byte for byte, every test passes, the Boss
output and screenshots are exact, and the whole Training Castle plays from title
to escape for one and for two. A new game leaves no trace of the last one in any
byte that matters. Turn order, the map's arrows, blink rates and lives colours,
the escape walk and GAME OVER all match 1984's bytes, and player 2's game over
behaves exactly as 1984's does. What needs work is in the boxes and
bookkeeping: a Game Over bullet that calls correct behaviour a bug (1), a
turn-order claim that can't happen (2), a fiction break (3), a replace table that
isn't mechanical (4), outline jargon (5), and GAME OVER's colours (6).

## Writer response

All six should-fixes are done as suggested (GAME OVER now uses the
coats, white and yellow; the turn-order quirk is logged for Chapter 11 in
the "ch09 review fixes" Decision log entry). Nits 7–14 and 16–21 are done
as suggested, including the two-player whole-castle test's player-2
asserts. Nit 15: I kept the frame and rewrote the caption and the text
after it to say where the arrow's tip is and why (1984's nudge puts it
over the neighbour's wall): it's the honest picture of a shared door, and
a frame with two arrows at different doors would need the players split,
which the map run doesn't do. Nit 10's escape figure is now "about
14,400" (the busiest frame varies a little with which records a run
draws).
