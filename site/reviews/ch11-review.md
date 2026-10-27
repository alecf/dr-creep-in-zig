# Review: Chapter 11 ("The Castle Keeper")

Reviewer scope: `site/chapters/11-the-castle-keeper.md`, its images
(`images/11-title`, `-menu`, `-signing`, `-times`, `-save`), its diagrams
(`page/diagrams/ch11-disk`, `ch11-listing`), its tools (`site/tools/ch11/`),
`site/code/ch11/` against `ch10`, and the machine change: `machine/src/drive.zig`,
the `$DD00` registers and `driveCommand` in `machine.zig`, `boot`'s disk,
headless `--disk`/`--save-disk`, wasm `disk_buf`/`comet_insert`/`comet_disk`,
`shell.js` (`insertDisk`, `reset`, `wireDisk`), the play section's
`.play-disk` row in `build.py`/`template.html`/`theme.css`, and REFERENCE §13.
I checked them against `site/AUTHORING.md` (the bible and the whole Decision
log, including the writer's ch11 entries), `docs/tutorial/outline.md`, the
promises Chapters 3–10 made to this one, and the ch05 and ch10 reviews. For
1984 I used `reference/segrax-DrCreep/src/creep.cpp` (`gameHighScoresHandle`,
`gameHighScores`, `gamePositionSave`/`Load`, the Frankenstein sprite code) and
`disasm/object.s`: `kernal_load_file` `$28EC` and its address table `$291D`,
`kernal_save_file` `$288E` and its table `$28E6`, `castle_select_and_load`
`$23BB`, the castle-list reader at `$7643–$76F7`, `game_high_scores_handle`
`$1B9F` and its caller at `$0EBD`. Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch11/`:
- `rebuild/`, `rb-A` … `rb-F/`, `rb-A.d64`, `outputs.json`, `expanded.md`,
  `rebuild.log`, `checkall.log`: the writer's tools run with `WORK=` set
  here, and `check-all.sh`.
- `py/d64check.py`: my own 1541 image checker, written from the published
  format, not from `drive.zig` (BAM counts against bitmaps, stray bits past
  a track's sectors, header bytes `$A0–$FF`, directory chain, every file
  chain, block counts, cross-links, used-but-free and free-but-used sectors).
- `venv/`: the third-party `d64` Python package (1.10), whose `d64-fsck` and
  reader are a second, independent opinion; `py/via_d64.py`,
  `py/mkforeign.py`.
- `zd/stress.zig` (+ `drive.zig` copy): stress disks `s1` (30 files, every
  third replaced with `@0:`, `@0:` of a new name), `s2` (tiny files until the
  directory is full), `s3` (exactly full, same-size and bigger replace);
  `foreign35.d64` written by the `d64` package and read back by our drive;
  `pad40`, `err35`, `err40`, `bad` images for `--disk`.
- `hl-D/E/F.d64`: the disks after stage D, E and the Boss, from the final
  checkpoint with `--save-disk`.
- `proj/ch11/`: a copy whose `main.zig` ends with six review-only tests
  (costs; browser-style Space/Return while typing; a full disk; a castle
  saved at `$7800` with a 15-letter name and a Z file that isn't a castle;
  resuming a file that isn't a game; a key pressed during the escape screen).
- `py/bosses.py` + `bosses.log` (every chapter's Boss Battle on the new
  machine), `site/` (full `build.py` output with wasm), `web/play.mjs`
  (the play section end to end in Chromium), `web/shots.mjs` + `shot-*.png`
  (diagrams and images at 1280 and 400 px, light and dark).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `rebuild.py` gives
  **REBUILD BYTE-IDENTICAL**; stages A–F each pass `zig fmt --check`,
  `zig build` and `zig build test`, and run. `expand.py` over the template
  with my outputs reproduces the chapter byte for byte (76 listings, in
  order). Every quoted run output (A–F) is verbatim.
- **The checkpoint is green.** `zig fmt --check` (ch11 and machine),
  `zig build`, `zig build test` (88 + 33 machine, as logged), `zig build wasm`.
- **The machine change didn't change any earlier checkpoint's game.**
  `check-all.sh` is all green (machine tests, starter, ch01–ch11). Every
  chapter's Boss Battle, ch01–ch11, run on the new machine, matches its
  quoted output byte for byte. A game without `pub const disk` boots with
  an empty drive and never touches `$DD00`, so cycles and frames are
  unchanged. (The *pages* did change: finding 1.)
- **The D64 is a real, standard 1541 image.** On the master disk (stage A)
  and on every disk the game wrote (stages D, E, Boss, and the browser's
  download) both my checker and the third-party `d64-fsck` report no
  errors, and `d64-fsck` leaves the files untouched. BAM at 18/0: link
  18/1, `$41`, four bytes a track with correct counts and no bits past a
  track's last sector, name at `$90` padded with `$A0`, `$A0 $A0` at
  `$A0–$A1`, ID at `$A2`, `$A0` at `$A4`, "2A" at `$A5`, `$A0` to `$AA`,
  zeros after. 664 blocks free on a fresh disk. The directory grows with
  the 1541's own interleave of 3 (18/1, 4, 7, 10, 13, 16, 2, 5 … 18), stops
  at 144 entries with DISK FULL, and its last sector ends `00 FF`. File
  chains, last-byte index, block counts and `$82` types are all right.
  The `d64` package's reader lists our disk exactly as a 1541 would
  (`0 "CASTLES OF CREEP" 84 2A`, `19 "ZTRAINING" PRG`, `643 BLOCKS FREE.`).
- **Foreign disks read.** A disk written by the `d64` package (which
  allocates the 1541's way) lists and loads through `drive.load`, all three
  files with matching checksums, including a 16-letter name. `--disk`
  accepts 174,848 / 175,531 / 196,608 / 197,376-byte images and exits 2 with
  "not a disk image (1000 bytes)" on a short one. A disk with no castle
  powers on to NO CASTLE DISK and fire starts nothing.
- **`@0:` replace and full disks behave.** Replacing frees the old chain
  first, so a same-size replace on a full disk succeeds and one block more
  is refused with nothing written; `@0:` of a new name creates it; `Y*` and
  over-long names are `bad_name`. The score file after two signings is
  replaced in place (still one block, 642 free).
- **A 1984 castle disk would load.** 1984 reads the castle list exactly as
  we do: `$7643–$7669` loads `"$0:Z*"` (5 letters) to `$9800`, and
  `$7681–$76CB` walks the lines, skipping the link and line number, and takes
  each quoted name that starts with `Z`. `castle_select_and_load` loads
  `Z`+name to `$9800` and `Y`+name to `$B800`, and on a failed score load
  writes `$7A $00` and `$FF`s, our `fresh`. `kernal_load_file` uses
  secondary address 0, so 1984 ignored a file's load address, as our drive
  does: a castle saved with `$7800` in front (as 1984's are) loads into
  staging and plays (review test). Staging is `$9800–$B7FF`, the 8 KB 1984
  allowed. A 15-letter castle name (the most a 16-letter Z file leaves)
  lists, loads and centres.
- **The score file is 1984's.** On the disk it's 124 bytes, load address
  `$B800`, size word `$7A`, then 2 × 10 six-byte places. The Boss's file
  holds `DUO 18 00 00` above `ACE 29 00 00` in the two-explorer table.
  `game_high_scores_handle` picks the table by `$7812` (the game's
  `two` byte, not the player number, despite creep.cpp's naming),
  compares hours, minutes, seconds most significant first, and on a tie
  falls through to "this place", so a tie goes above, as ours does. The
  caller at `$0EBD` skips it with unlimited lives or with `$7802` bit 0
  set (creep.cpp:3002–3004), our `restored`. The record order (initials,
  seconds, minutes, hours) agrees with the worked example in
  `docs/castle-format.md` §6.
- **Frankenstein's frame bytes are 1984's.** creep.cpp:2527–2565 and 2686:
  `$84–$86` walking right (`mButtonState == 2`, `++mX`), `$87–$89` left,
  `$8A` sliding, `$8B–$8E` climbing, `$8F` asleep.
- **Every number in the prose checks out.** 23 sectors × 19,656 + 2,316 =
  454,404; 627,734 cycles is 31.9 frames; 19 + 2 blocks leave 643; the
  listing is 30 + 32 + 32 + 30 + 2 = 126 bytes; saving the game is BAM +
  two directory walks + 19 = 22 sectors (435,218 cycles); a score save is
  4 sectors either way (78,946); resume 20; pick Training 21 (414,082 in my
  test, 414,074 logged: the blanking poke); menu draw 139,728; pointer
  move 1,086; a letter 940 ("about 900"); a castle in under half a second
  (21 frames); `m.copy` is a `@memmove`, so the overlapping shift is safe.
  REFERENCE §13's "4,323 bytes: 19 frames" is right.
- **Screenshots match fresh runs pixel for pixel**, and their captions
  describe them.
- **No copyrighted data anywhere.** No `.d64`, `.prg` or `extracted/`
  file has ever been committed (`git log --all`), the only binaries in
  the six ch11 commits are the five 4–5 KB screenshots, `master.zig`
  saves only `training.bytes` and `hall.bytes` (ours since Chapter 3), and
  no 1984 castle or player name appears in `site/code`, `site/chapters` or
  `site/tools`.
- **The browser path works.** In Chromium on the built site: after Power
  on, the ch11 disk row appears; a 1,000-byte file says "bad.d64 isn't a
  disk image (.d64)." and the machine keeps running; `hl-E.d64` says "is in
  the drive", focus returns to the canvas, and the keyboard alone (Esc,
  Space on RESUME GAME, `M Y Space G A M E`, Enter) resumes MY GAME onto the
  map. Esc on the map, `WEB SAVE`, Enter saves; **Save the disk** downloads
  `comet-disk.d64` (174,848 bytes) holding both saved games, which both
  checkers pass. Space typed in a name is also stick 1's fire and Return
  stick 2's: the name screen ignores the sticks while typing and `finish`
  eats both presses, so neither leaks (also a review test, holding the
  stick bit as long as the key, the way the shell does).
- **Keys.** Esc is not a reserved stick key and nothing in the page or
  shell binds it; Backspace and Esc are `preventDefault`ed. On the map only
  Esc is taken, so N and P still flip; in a room `room.flip` swallows any
  stray key. The menu, best times (viewing: fire or Esc), resume (Esc →
  menu) and title flows all go where the prose says (review test).
- **Rendering.** No horizontal page scroll at 400 px; the disk diagram
  scrolls inside its figure; the listing diagram wraps; both read in light
  and dark, and the disk diagram's paused state is legible.

## Findings

### Must-fix

**1. Every chapter's play section now offers a disk slot that does
nothing.** `shell.js` decides `hasDrive` from `typeof c.comet_insert ===
"function"`, but `wasm.zig` exports `comet_insert` for every game, so
starter and Chapters 1–10 now show "Got a castle disk? Slot it in:" and
**Save the disk** after Power on (screenshot
`web/ch10-play.png`). Picking a file there reboots the checkpoint into a
game that never reads the drive; **Save the disk** silently does nothing
(empty drive). It also previews Chapter 11 on Chapter 1's page. The
Decision log's intent is "shown when the wasm has a drive". *Fix:* export
something game-specific, e.g. `export fn comet_has_disk() u32 { return
@intFromBool(@hasDecl(game, "disk")); }`, and use it for `hasDrive` (or test
`comet_disk_size() > 0` right after boot). Rebuild the site and check a
ch10 page shows no row.

### Should-fix

**2. A bad file in the picker throws away the game in progress.**
`insertDisk` calls `c.comet_boot()` first and only then tries `insert`, so
picking a wrong file mid-castle resets to the title before saying "isn't a
disk image". *Fix:* check the size in JS (the four image sizes, or
`comet_insert` into the buffer without booting) and boot only when it's a
disk. While there: set `input.value = ""` after handling, or a real browser
won't fire `change` when the same file is picked again (e.g. to put the
just-saved disk back in).

**3. "Saved with the address of staging … the way 1984's castles did."**
`master.zig`'s doc comment says each castle is "a Z file that loads at
staging, the way 1984's castles did", and the prose says "saved with the
address of staging, `$9800`, as its load address". 1984's Z files carry
`$7800` in front (`docs/castle-format.md` §1: `00 78`; the save table at
`$28E6` is `$7800, $9800, $B800`, and castles were saved from `$7800`). It
didn't matter, because `kernal_load_file` loads with secondary address 0 to
`$9800` regardless, as our drive does. *Fix:* keep the code; reword to
"each as a Z file. The drive ignores a file's load address and puts it
where it's told, as 1984's loader did, so a castle loads into staging
whatever address it carries." The "Got a castle disk?" section's "Z files
that load at `$9800`" is fine as it stands.

**4. Interleave: "Our drive keeps the habit, so its disks look like any
other."** A real 1541 steps 10 on and, when it wraps, one back: track 17
goes 0, 10, 20, **8**, 18, 6, 16 … (the `d64` package writes exactly that;
see `zd/foreign35.d64`). Ours goes 0, 10, 20, **9**, 19, 8. Any reader
handles either, so this doesn't affect compatibility, but the sentence
claims a match. *Fix (preferred, two lines in `nextFree`):* `var s = p.sector
+ 10; if (s >= n) { s -= n; if (s > 0) s -= 1; }`, then search forward from
`s` as now. Regenerate stage A, the disk diagram and the prose's "17/0,
17/10, 17/20, 17/8". Or keep the code and say "Our drive does the same,
give or take a sector."

**5. Earlier chapters still promise things to Chapter 11 that moved to the
Epilogue.** The Decision log moves them ("Promises left for the
Epilogue") and the "Still to check" box tells readers, but the old text
still says otherwise:
- ch08 line 2586: "Chapter 11 will have to place both pictures for the real
  castles" (ankh and alcove).
- ch09 line 2585: "a real castle's own bytes may put a gap or an arrow a
  little differently, and Chapter 11 can check."
*Fix:* change both to "the Epilogue". (ch08's Frankenstein translation
sentence was kept: paid here.)

**6. A key pressed during the escape screen is read as the first key of
the initials.** Nothing clears `$DC02` between the room and the best times:
`escape.run` doesn't read it, and `typing.begin` doesn't clear it. A review
test presses Esc during the fanfare: the signing is cancelled at once and
the place stays blank (`mode over, initials 20 20 20`). A letter would
become the first initial without being seen typed. *Fix:* `m.poke(hw.key,
0)` in `typing.begin` (it also covers the name screen).

**7. A full disk loses a best time without a word.** With 0 blocks free
(review test), `saveScores` returns `.full` (status 4), the flow goes on to
GAME OVER, and YTRAINING isn't on the disk: the time is gone at the next
power-off, and the player never knew. Saving a *game* on a full disk says
THE DISK IS FULL; best times should say something too. *Fix:* if
`saveScores` isn't `.ok`, stay on the screen one more beat with "NOT
SAVED: THE DISK IS FULL" (fire to go on), or at least add the case to
Common mistakes / a Bonus Stage. 1984 printed IO ERROR for its saves.

### Nits

**8. "`Mode` grows two modes, a screen's usual pair, and one line each is
easier to read now:"** A reader has to work out that "one line each" is
the layout of the enum. *Rewrite:* "`Mode` grows two modes, the usual pair
for a screen. With twelve modes, one to a line is easier to read:"

**9. "Chapter 9 promised this would be easy."** "Easy" is on the bible's
banned list, and Chapter 9 didn't say it (it said a saved castle "is just
the castle with its header"). *Rewrite:* "Chapter 9 set this up."

**10. Two power-on numbers.** The Power on section explains 627,734 cycles
(stage B, before ESC FOR THE MENU was drawn); the Byte Budget says 638,586.
A careful reader will see both. Add "(the title's menu line, added below,
makes it 638,586)" after the stage B paragraph, or leave it.

**11. Lines touch on the new screens.** In `11-menu.png`, THE DISK'S
CASTLES (y 64) sits directly on TRAINING (y 72), and castle names 8 apart
touch each other; with 16 castles it's one solid block of text. On
`11-signing.png` the two header lines touch too. *Suggestion:* leave a row
under the heading (castles from y 80, which fits 15 castles, not 16), or
drop the heading and start the castles at y 64. Or keep it as a style
choice; it is readable.

**12. NO CASTLE DISK still says PRESS FIRE** underneath
(`zd/fr-foreign35/frame_00059.png`). Hide PRESS FIRE / STICK 2 FOR TWO
when `!files.ready(m)`, or let it be.

**13. A disk whose first Z file isn't a castle** powers on to NO CASTLE
DISK even when the menu lists good castles after it, and the menu draws
the bad one in white (`shell_castle` is set before the load fails).
`powerOn` could try each castle until one picks. Rare; a Bonus Stage line
would do.

**14. The play note doesn't mention Esc.** `build.py`'s play-note is the
same for every chapter ("arrow keys or WASD and Space…"). For ch11 add
"Esc on the title for the menu; Esc on the map saves."

**15. Disk diagram legend.** Unread ZTRAINING sectors are drawn at 45 %
opacity and turn full as the head reads them; the legend shows only the
full colour, and the paused resting state is all pale. Add "(pale until
read)" to the ZTRAINING key.

**16. A 40-track image comes back as 35 tracks.** `--save-disk` and **Save
the disk** write 174,848 bytes, dropping tracks 36–40 (and error bytes)
silently. REFERENCE §13 says the drive "ignores the rest"; add "and saves
the disk back as 35 tracks".

**17. Prose length.** `wc.py`: 5,554 words, a touch over the 5,000–5,500
target. Nothing needs cutting for it; findings 8–10 are where I'd trim.

## Summary

The drive is right: standard BAM, directory, chains, `@0:` and full-disk
behaviour, confirmed by an independent checker and a third-party fsck,
and it reads a disk another tool wrote. The castle loader, the Y file and
the best-time rules match 1984's code byte for byte, the listings rebuild
the checkpoint, and every earlier game is unchanged. Must-fix: the disk
slot showing on every chapter's page (1). Should-fix: the picker's
reboot-before-check (2), the load-address and interleave claims (3, 4),
two stale "Chapter 11" promises (5), a stray key cancelling the initials
(6), and a silent best-time loss on a full disk (7).

## Writer response

- **1 (fixed).** `wasm.zig` exports `comet_has_disk()` (1 only when the
  game declares `pub const disk`); `shell.js` sets `hasDrive` from it, so
  starter–ch10 pages show no disk row (checked in Chromium on the ch10 and
  ch11 pages of a fresh full build).
- **2 (fixed).** `comet_is_disk_size(len)` is checked before `comet_boot`,
  so a wrong file leaves the game running; `input.value = ""` after each
  pick. REFERENCE §12 says both.
- **3 (fixed).** `master.zig`'s comment and the prose now say the drive
  ignores a file's load address and puts it where it's told, as 1984's
  loader did. Code unchanged.
- **4 (fixed, the preferred way).** `nextFree` steps ten on and one back on
  each wrap; a new drive test checks 17/0, 10, 20, 8, 18, 6. Stage A's disk,
  the disk diagram and the prose ("17/0, 17/10, 17/20, 17/8") are
  regenerated; your checker was rerun on the new disks.
- **5 (fixed).** ch08 ("The Epilogue, with every real castle loaded, will
  have to place both pictures") and ch09 ("the Epilogue can check")
  regenerated from their templates; both rebuilds still byte-identical.
- **6 (fixed).** `typing.begin` clears `$DC02`; new test "a key pressed
  before the best times ask isn't an initial" (Esc during the fanfare,
  then ACE signs).
- **7 (fixed).** If `saveScores` isn't `.ok`, the top line becomes TIME NOT
  SAVED (red) and the screen waits for stick-1 fire or Esc before going on
  (`shell_signing = 0xFE`). New test on a full disk.
- **8, 9, 10, 14, 15, 16 (done).** Mode sentence rewritten; "Chapter 9 set
  this up"; the stage-B paragraph notes 638,586; the play note gains the
  Esc keys from Chapter 11 on; legend "(pale until read)"; REFERENCE §13
  "a saved disk comes back as 35 tracks".
- **11 (kept).** A spare row would cost the sixteenth castle, and the
  screen reads clearly at 8-pixel spacing (the font has its own blank
  bottom row); the same spacing is used across earlier screens.
- **12 (kept).** NO CASTLE DISK is in red right above PRESS FIRE, and fire
  is safely ignored; hiding the lines would add a branch to the title for
  a case the screen already explains.
- **13 (Bonus Stage).** Added "A bad first castle".
- **17.** Prose is back to ≤ 5,500 words by `wc.py`.
