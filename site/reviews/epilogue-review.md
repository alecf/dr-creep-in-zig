# Review: Epilogue ("All the Castles")

Reviewer scope: `site/chapters/12-epilogue.md`, its tools
(`site/tools/epilogue/measure.py`, `diagrams.py`, `errs.py`), its diagrams
(`page/diagrams/ep-memory.html`, `ep-frame.html`), the `build.py` navigation
change, and the Epilogue's Decision log entries in `site/AUTHORING.md`. I
checked the chapter against the finished game it plays (`site/code/ch11/`),
`code/machine/REFERENCE.md`, the promises Chapters 8–11 left for it, and the
earlier chapters it quotes numbers from. For 1984 I used
`reference/segrax-DrCreep/src/creep.cpp` (`Game()` around `0D71`, `roomMain`,
`obj_Player_Add`) and `disasm/object.s` (`$0DC6–$0E7D`, `$14FC–$15C4`).
Zig 0.16.0. No new checkpoint, so no listings or `rebuild.py` to run.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-epilogue/`:
- `measured.json`: `measure.py` run fresh with `WORK=` set here.
- `fixed/`: the same probe, with the tour's first N moved to frame 400 so the
  Gatehouse also gets 300 frames (finding 3).
- `kind/ch11/`: `errs.py`'s scratch copy, left in its final state (spider
  kind added, shape id removed).
- `turn/ch11/`: a copy of ch11 whose `main.zig` ends with two review-only
  tests: "REVIEW turn order: two players starting apart" (findings 2 and 4)
  and "REVIEW quest: N again and again fills in the map?" (finding 1).
- `shots.mjs`, `shot-*.png`, `full-*.png`: Playwright renders at 1280 and
  400 px, light and dark.

## Baseline: what I verified and found correct

- **The tools run and match the prose and the Decision log.** `measure.py`
  (33 regions, 21 + 21 + 21 room records, 3,478 Boss calls, the same count
  as headless) and `diagrams.py` reproduce every number they print.
  Regenerating the diagrams leaves `ep-memory.html` and `ep-frame.html`
  byte-identical (`git status` clean afterwards).
- **Memory numbers.** Reserved 24,221 = program image 20,992 + stack 256 +
  expansion 2,973. The five expansion ranges match REFERENCE §2 exactly.
  Hardware 12,179, which includes the 48 disk-drive bytes. Castle 16,762 =
  9,666 + 7,096, with Training at 4,644 of each 8,192. Tables 8,464 = 7,277 +
  1,187, and each table's fill matches (shape 5,325/6,144, music
  1,029/1,280, effects 267/384, star map 256, row table 400). Working memory
  1,838 (I added up the 13 regions by hand). The grid is 1,000, so 838 is
  left. Free 2,072 in 11 runs, the largest `$0500–$07FF` (768), and the zero
  page untouched. The six classes sum to 65,536 (the script asserts this
  too). "More than half" (55.5 %) and "a quarter" (25.6 %) check out, and so
  do 640 bytes of slots (40 × 16) and seven shared bytes (`between`,
  `$0200–$0206`).
- **The memory diagram matches ch11's `map.zig`.** Every region comes from
  `map.regions`, with fills from the game's own `shapes.table`,
  `tunes.music`/`effects`, `title.star_map` and `training.bytes`. The only
  addresses not in `map.zig` are the expansion ranges, and those are copied
  from REFERENCE. "All but the row table were built by the compiler and
  copied into place at boot" is true: `main.boot` loads the shape table and
  star map, `sound.start` loads the music and effects, and `screen.start`
  works out the row table. "33 regions, and the compiler still checks every
  pair" matches the `comptime` block. Chapter 1's map is as described.
- **Frame numbers.** 3,450 in Under Fire (objects 2,502) is 17.6 %, which
  rounds to 18 %. The averages are 497–1,238 (2.5–6.3 %; but see finding 3).
  Q gives 1,408 (worst 5,146) and C gives 743 (worst 3,780). Boss Battle:
  34 loading pauses use 356 of 3,800 slots (7.1 s of 76 s), with 0 overruns.
  The average room frame is 953. The busiest room frame is 5,090 at frame
  2,054, and I confirmed it is room 19, the Way Out (actors 2,500, objects
  2,146). The busiest display-on frame is 14,436 on the escape screen, 73 %.
  The biggest loading frames are 638,586 (power-on) and 244,096 (a room
  draw, 12.4 frames' worth). The sound driver's Boss maximum is still 228
  and its silent cost 14.
- **Quoted figures from earlier chapters.** 204 / 1,626 (ch04 table), 224 /
  1,320 / 2,972 (ch06 byte budget) and 14 / 228 (ch10) are verbatim. The
  ~70 % for C in a full room matches ch05's own 8 × 32 × 54 = 13,824. The
  dice cost does not (finding 6).
- **The new-kind walkthrough.** `errs.py` passes on the current ch11. I
  checked each `file:line:col` against its output myself, because the
  script only checks the file name and the message (finding 9):
  `castle.zig:259:12` with the note `castle.zig:107:5 … 'spider'`,
  `author.zig:321:31`, `room.zig:37:70`, `actors.zig:76:62`,
  `shapes.zig:233:46`. The test failure prints exactly
  `error: 'castle.test.tag codes turn into kinds and back' failed:` /
  `       expected null, found .spider` (7-space indent, as quoted). It is
  the only failure (88 pass, 1 fail). The order matches the order a reader
  meets them, and each named table is the one on that line (`framing`,
  `author.Room`'s field use, `prepares`, `actors.kinds`, the shape-table
  packer). "the shape table doesn't fit in its region" is the real
  `@compileError` string. 819 spare bytes is correct, and so is `$0839` as
  the next tag after `$0836`.
- **In-world disk loading.** It matches ch11. `files.powerOn` runs on the
  first frame (`draw_title`), and `files.catalog` loads `$0:Z*` into
  staging. `files.pick(0)` loads over it and checks `$80`, and the title
  prints `files.entry(shell_castle)`. `--disk` is a real headless flag,
  and the page's labels are "Got a castle disk? Slot it in" and "Save the
  disk" (`build.py`). `room.draw`, `doors.ring`, `mummy.walk` and
  `frankenstein.turn` all exist. Image records are drawn from the castle's
  own bytes (`room.image`). No real castle names or data are quoted
  anywhere.
- **Bonus Stages, checked against the code.** The kit limits are real:
  31 rooms, 8 KB, doors that must lead back, ladders that must start on a
  walkway, "runs off the screen". So is `master.zig`'s `drive.save` line.
  `author.door` exists (private, but fine as a pointer).
- **Navigation.** `part: epilogue` gives view `epilogue`, nav label
  "Epilogue" and kicker "Epilogue". The TOC order is Chapter 11, Epilogue,
  then Manual. ch11's pager ends "All the Castles →", and the Epilogue's
  pager has "← The Castle Keeper" and no next link. The play section is
  titled "The finished game" with the note "The whole game, as Chapter 11
  left it." plus the Esc note, and it loads `play/ch11.wasm`. At 400 px
  the page scroll width is 400 in both themes.
- **Diagrams render** at 1280 and 400 px, light and dark. The memory grid
  shrinks to 332 px wide and stays readable, and the frame chart's room
  names wrap cleanly. Both are static, so pausing animation doesn't apply.
- **Voice.** Warm and in-world, and it never breaks the fiction. Prose is
  3,035 words by ch11's `wc.py`, just over the ~3,000 target.

## Findings

### 1. MUST-FIX: "press N again and again" does not fill in the map

Location: quest intro, "First, the map shows every room you've been in. To
see a whole castle, start a game, and on the map press N again and again.
Each room N flips to counts as visited, and the castle fills in." Quest
item 1 depends on it ("Fill in each castle's map and look at every gap").

Evidence: a room's visited bit is set only in `chart.draw`
(`chart.zig:60`), and only for the room each player is about to enter
(`castle.room + p`). N on the map (`main.zig:128`) goes straight to
`draw_room`. N inside a room (`main.zig:165`) flips again without drawing
the map, so the flipped-to rooms are never marked. A review test (start a
game, then N 25 times with 4 frames between) ends in room 4 with **1 of 20**
rooms visited. Dying (X) doesn't help either, because `game.after` sends
the player back to the start room before the map is drawn.

Fix: give the reader a method that works. Since the Epilogue adds no code,
the cleanest is a test: "In a test, set bit 7 (`castle.visited`) of every
directory entry, then draw the map with `chart.draw` and dump the frame."
Another option is to walk the castle through its doors. A new debug key
would mean a ch11 code change, so I wouldn't add one. Update the Decision
log's quest entry ("N repeatedly on the map marks rooms visited") too.

### 2. MUST-FIX: 1984's turn order is misdescribed. ch09's box is right; ch11, the Decision log and quest item 4 are not

The writer flagged this. Here are the three texts:
- ch09 "Whose turn is it?": "1984 decides the next room just as `next`
  does. Together, they play together. Apart, they take strict turns: the
  one who just played waits while the other plays one room."
- ch11 "Still to check", Decision log "Deviation for ch11 (1984 turn-order
  quirk)", and Epilogue quest 4: "1984 lets player 2 play on until he meets
  player 1, where ours take strict turns."

What the disassembly does:
- `$0DF6`: a new game stores `$7811 = 0`.
- `$0E38–$0E59`: if both players are in the same room, both play.
  Otherwise the player who plays is **not** `$7811`: `ldx $7811`, clear
  `$11C9,x`, `eor #$01`, set the other one. So in the first room, **player
  2 plays first**.
- `$1594–$15AF`: on every pass of the room loop, if P1's status `$780D` is
  0 the game stores `$7811 = 0` and loops. Otherwise, if P2's `$780E` is
  0, it stores `$7811 = 1` and loops.
- `$15B2–$15C2`: the room ends only when neither status is 0, 5 or 6. So
  `$7811` ends up as the last player still walking the room, and the other
  player plays next.

That is strict alternation. Our `player.roomOver` and `game.next` do the
same thing (`castle.last ^ 1`).

The "quirk" is real, but its effect is not what ch11 says. `$1594` reads an
absent player's status. A room can only end with both statuses non-zero,
and `obj_Player_Add` (`$35F1`) writes 0 only for a player who is present.
So the absent status can be 0 only if the castle file's header byte is 0
and that player has never played a room. In that case the loop **never
ends**. The present player walks out of the door and the room carries on
with nobody in it, until RESTORE (`$156B`) sets status 2. Player 2 does not
"play on until he meets player 1". The docs' worked example of the 1984
tutorial castle (`docs/castle-format.md` §2) shows `$780D = $A0` and
`$780E = $CC`, which are non-zero, so for files like that 1984 simply
alternates.

Verdict: **ch09's box is right**, with one detail missing: when the start
rooms differ, player 2 plays the first room. The ch11 bullet, the Decision
log entry and Epilogue quest item 4 are wrong about 1984.

Fix:
- Quest item 4: "Then 1984 takes strict turns, as ours does, but player 2
  goes first. 1984 clears the 'last player' byte when a game starts, and
  the next room is the other player's. Ours reads that byte from the castle
  file (finding 4). Look for such a castle … The rule lives in `game.start`
  and `game.next`."
- ch11's "Still to check" bullet: "**Turn order** when a game for two
  starts in different rooms: who goes first."
- Add a Decision log entry that supersedes the ch09-review "Deviation"
  paragraph and records the analysis above. Leave ch09's box as it is, or
  add "(player 2 first, if they start apart)".

### 3. SHOULD-FIX: the Gatehouse is measured for 11 frames, not 300, and Q isn't on there

Location: "he stands in the doorway for six seconds (300 frames)", and "from
497 cycles in the Gatehouse". The "707 … 1,408" and "707 to 743" figures are
affected too.

Evidence: `measure.py`'s `tour()` presses fire at 60/75 and the first N at
**frame 100**, so the Gatehouse gets **11** in-play frames
(`"calls": 11`). The Long Gallery then gets 387, and the other rooms
286–289. Q and C are pressed at frame 250, which is in the Long Gallery,
so `rooms_q[0]` is a Gatehouse with Q off. Its 497 is identical to the
plain tour.

With the first N at 400 and the rest every 300 (`fixed/`), the Gatehouse
gets 311 frames and averages **481**. The other numbers become: average of
averages **706**, with Q **1,442** (2.04×, so "doubles" still holds) and
worst 5,146; with C **743**. The worst frame (3,450, Under Fire) and the
1,238 maximum don't change.

Fix: in `tour()`, use `keys = [(400 + ROOM_FRAMES * i, ord('N')) for i in
range(20)]` and frames `400 + ROOM_FRAMES * 20 + 50`. Rerun both scripts
and update the prose ("481 cycles in the Gatehouse", "706 … 1,442", "706
to 743"), the frame diagram and the Decision log.

### 4. SHOULD-FIX (ch11 code, raised by the quest): `game.start` trusts header bytes that 1984 clears, and a real castle can crash `game.next`

Location: `game.zig` `start`: "The header's scratch bytes are zeros in the
castle file, so the copy clears them too". `castle.zig`'s header comment
says the same. Epilogue quest 4 sends readers to play exactly the case
that is exposed.

Evidence: 1984's `Game()` zeroes the time (`$7855–$785C`, at `$0DCC`), the
escape flags (`$785D/E`, at `$0DD6`) and the last-player byte (`$7811`, at
`$0DF6`). It doesn't trust the file for these. Ours clears none of them.
The docs' worked example shows that a 1984 castle carries non-zero bytes in
`$7809–$780F`. Whether any real file has non-zero bytes at `$7811` or
`$7855–$785E` can't be checked in this tree, but here is what would happen:
- `game.next` computes `p = @intCast(m.peek(castle.last) ^ 1)` into a
  `u1`. My review test (Training Castle with player 2's start room set to
  1, then fire on stick 2) shows:
  - `$7811 = 0`: player 2 plays first, as in 1984.
  - `$7811 = 1`: player 1 plays first.
  - `$7811 = $B6`: **"panic: integer does not fit in destination type"**.
    The browser build is ReleaseSafe (`machine/build.zig:74`), so a page
    with such a disk would stop.
- A non-zero `escaped` byte ends the game after the first room. A non-zero
  `time` starts the clock part-way.

Fix (ch11, a small listing change): in `game.start`, do what 1984 does:
`m.poke(castle.last, 0)`, and zero `castle.time` (8 bytes) and
`castle.escaped` (2 bytes). Then the header comments should say "1984 clears
these when a game starts". This also makes finding 2's "player 2 first" our
behaviour too. If ch11 is frozen, the Epilogue's quest 4 must at least say
that ours reads `$7811` from the file and can stop on a castle whose byte
isn't 0 or 1.

### 5. SHOULD-FIX: "Press Esc, pick a castle, and press fire" skips a step, and the 16-castle limit is missing

Location: "Slot in a castle disk".

Evidence: fire on a menu castle returns to the **title** (`main.zig:204`,
`.castle => .draw_title`). The game starts with a second fire on the title,
and which stick fires chooses one or two players. `files.catalog` also
stops at 16 castles (`max_castles`; ch11 logged 1984's menu as 24). "The
menu fills with the doctor's castles" promises all of them.

Fix: "Press Esc, pick a castle with fire, and the title says its name.
Press fire again (stick 2 for a game for two)." Then: "The menu holds the
first 16 castles on the disk, in directory order (Chapter 11's 'More than
16 castles' Bonus Stage lifts that)."

### 6. SHOULD-FIX: the dice cost 40 cycles, not 24

Location: "The dice (Chapter 8) cost 24 cycles a roll." The Decision log
says "dice 24 (ch08)".

Evidence: `dice.roll` does `m.work(24)` plus two peeks and two pokes at 4
cycles each (AUTHORING §3), which is 40. ch08's byte budget says "A roll of
the dice costs 40 cycles".

Fix: "cost 40 cycles a roll". Fix the log line too.

### 7. NIT: wording a JS reader will trip on

- "Most of it is the program image, 20,992 bytes at `$0800` set aside for
  the game's code. Our Comet doesn't count code bytes, but the space is held
  back so the budget stays honest." The reader can't tell what "doesn't
  count code bytes" means. Try: "Most of it is the program image, 20,992
  bytes at `$0800` kept for the game's code. Our Zig code doesn't actually
  sit in those bytes, but we keep them empty anyway, so the map shows the
  room a real game's code would need."
- "The screen and the program took more than half before we wrote a line"
  conflicts with "set aside" above. Try: "The hardware and the space kept
  for the program took more than half before we wrote a line."
- "power on the page below" refers to the play section, which is at the
  very bottom, after "The last door". Try: "power on the Comet at the bottom
  of this page".
- The working-memory list ("both explorers, 8 actor slots, 32 object slots,
  the sound driver, the shell, and the navigation grid") leaves out the
  text region. At 128 bytes it is bigger than the shell, the players and
  the sound driver combined. Add "the text printer".
- "They cost bytes, but no cycles at all." Copying them in at boot does
  cost cycles. Try: "They cost bytes, but no cycles to work out."
- Bonus Stage 3: "until it has a behaviour: a turn, how it dies, and what it
  does when it touches someone". Only `.turn` is required (`errs.py`'s
  spider builds without `hit`/`touch`). Try "until it has a behaviour (at
  least a turn)".
- Bonus Stage 2: "Each mistake is a compile error that names the room."
  The 31-room and 8 KB errors don't name a room. Try "Each mistake is a
  compile error, and most name the room."
- Quest 5: "list the whole disk with `$`". `files.catalog` uses `$0:Z*`.
  Try "load the directory with the name `$`, not `$0:Z*`".

### 8. NIT: the diagrams

- `ep-memory`: in dark mode, "castle room to spare" (cyan at 30 % on the
  sheet) and "stack, program, expansion" (ink-soft at 55 %) are both
  dark slate and hard to tell apart at 400 px (`shot-400-dark-0.png`).
  "Table room to spare" against "nobody's" is close too. Raise the spare
  mixes to about 45 % in dark, or give the spare classes a diagonal
  hatch.
- "Hover over a square to see who owns it." `title` tooltips don't appear
  on touch. Try "Hover over (or long-press) a square", or rely on the key.

### 9. NIT: `errs.py` doesn't check the line numbers it proves

It asserts the file name and message, not `file:line:col`. The quoted
`:259:12`, `:321:31` and so on would drift silently if ch11 changed. The
Decision log already says "rerun `errs.py` and update the prose", but the
rerun wouldn't catch the drift. Put the full `src/x.zig:L:C: error: …`
string in each `expect` (and `castle.zig:107:5` for the note).

## Counts

Must-fix 2 (1, 2), should-fix 4 (3–6), nit 3 (7–9, with several small
items each).
