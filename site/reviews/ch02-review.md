# Review: Chapter 2 ("Ghosts in the Bitmap")

Reviewer scope: `site/chapters/02-ghosts-in-the-bitmap.md`, its images
(`images/02-title.png`, `02-room.png`, `02-tear.png`) and `site/code/ch02/`
(diffed against `site/code/ch01/`). I checked them against `site/AUTHORING.md`
(the bible and its Decision log), `docs/tutorial/outline.md`,
`site/code/machine/REFERENCE.md`, `machine/src/machine.zig`, the Prologue,
Chapter 1 and `reviews/ch01-review.md`. Research cross-checks used
`docs/graphics-format.md` and `reference/segrax-DrCreep/src/creep.cpp`.
Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-ch02/`:
- `blocks/NN.zig`: the chapter's 30 ```zig fences, in order.
- `steps/*.py` + `apply.py`: the edits, applied the way the prose describes.
- `code/my-creep/`: the project rebuilt from `ch01/`.
- `f-s0N/`: frames from the intermediate "run it now" steps.
- `code/tear/`: the Secret Passage reproduction.
- `code/fix/`: the loading-pause fix from finding 2, tested.

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** I copied `ch01/`, added
  `art.zig` from the Warp Zone as instructed, and applied all 30 listings
  in order, following each label ("add above `rowAddress`", "replace
  everything from `// ---- tests` down", "replace `player.start(m);`"). The
  result is byte-identical to `ch02/` across `src/` (all ten files),
  `build.zig` and `build.zig.zon`. The "complete" `main.zig` listing matches
  as well. `zig fmt --check src/` is clean.
- **Every intermediate step compiles, and the headless outputs are
  verbatim.**
  - The first stars version prints exactly the quoted block (`49 calls`,
    `max 96024`, `overruns: 48`).
  - The row-table version prints exactly its block (`96 calls`, `avg 7602`,
    `overruns: 0`). The frame shows the meter about a third full.
  - The castle-only step shows the castle and moon. The text step is
    pixel-identical to `02-title.png` apart from the star phase.
  - The room step and the walk step behave as described, with one
    exception (finding 5).
- **Boss Battle:** `zig build`, `zig build test` (6/6 tests: the game's 5
  plus the machine's boot test) and `zig build wasm` (writes `game.wasm`,
  `shell.js`, `index.html`) all succeed. The headless run prints the quoted
  seven lines exactly.
  - `frame_00000` is blank.
  - `frame_00100` is pixel-identical to `02-room.png`.
  - In frame 150 he faces left, mid-walk. I checked the mirrored head
    pixel by pixel.
  - In frame 250 he stands at x = 120, 40 px left of where he started.
- **Secret Passage tear:** reproduced with `m.work(14000)` and `^ 8`
  removed, using the given command. `frame_00071` matches the left panel
  of `02-tear.png`, and restoring `^ 8` gives the right panel.
- **The Game Over compile error is verbatim**, down to the location:
  `src/shapes.zig:95:17: error: shape explorer_right_1: row 20 is 9 fat
  pixels wide, not 8`. The "Widen before you shift" error (`type 'u2'
  cannot represent integer value '4'`) is verbatim. The `&`/`|`
  equal-precedence claim is true: `a | b & c` evaluates as `(a | b) & c`.
- **Numbers I recomputed or measured, all correct:**
  - Per star: 172 cycles, so 22,020 per frame. 120/172 ≈ seven tenths.
  - The row-table frame is 6,672 (6,660 stars + 12 glue).
  - `clear` is 80,000, about 4.07 frames. `title.draw` without shapes is
    96,000, about 4.9 frames.
  - The title draw is 156,428 cycles (8 slots). The room draw is 125,476
    (7 slots); `room.draw` alone is 124,812.
  - Unpack is 612 and `setFrame` 628. Room frames are 100 idle and 728 on
    a frame change (bucket 2: 716).
  - The shape table is 1,059 bytes with a 40-byte directory. The tower is
    243 bytes, the walkway 12, an explorer frame 45.
  - The map has 15 regions. Text occupies `$0300–$035F` = 96 bytes, and
    the glyph is 23 bytes.
  - `$6C`, the `$F7` mask walkthrough, the widen entries `$04`/`$45`/`$55`,
    313 = 320 − 7, and 256,000 canvas bytes against 10,000 Comet bytes are
    all right.
  - The star exclusion boxes match the text and moon cells (moon 13 rows
    at y = 4 → cell rows 0–2, columns 31–33).
- **Inside the Disk lore checks out against `creep.cpp`:**
  - `start()` at `08C2` builds `$BB00` (hi) and `$BC00` (lo), stepping +1
    and +`$139` (313), and wraps so that index 0 = `$E000`.
    `graphics-format.md` §5 misreads this as "+57 from `$D740`". The
    chapter is right and the doc is wrong.
  - `screenDraw` looks up only the top row, then walks +1 / +`$139`.
  - `StringPrint` uses a 16-entry widen table at `$2BF8` and draws with
    mask shape `$94` and glyph shape `$95` (mode 2: AND the mask, then OR
    the glyph).
  - Strings end on bit 7.
  - `hw_SpritePrepare` uses the `^ 8` pair and pads with the blank row at
    `$5E89`.
  - The shape table is about 155 pointers at `$603B`, roughly 6 KB.
- **Fiction:** no C64, Commodore, VIC, SID, emulator, reverse engineering,
  AI, "pretend", "in-world", or real author or publisher anywhere.
- **Banned words:** no "just", "simple", "easy" or "obviously". There are
  two exclamation points in the prose, both on real milestones ("There's
  your title screen!", "He walks!").
- **Chapter 1's promises are honoured:**
  - "Chapter 2 shows what a pointer really is."
  - "Masks and moving bits around."
  - "Four pixels, code 11."
  - "The meter will finally have something to say", paid off with a
    loading pause and the overrun demo.
  - "Sprite-pointer animation from Chapter 2", paid off by the double
    buffer.
- **Chapter 1 behaviour removed gracefully.** Up/down is deferred with
  "(Up, down and the ladders are Chapter 4.)". The fire colour cycle gets
  "in the castle, fire is for doorbells and gun panels". The Edge Detector
  is reused, by name, in `pressedFire`.
- **Decision-log conformance:** file names, `Mode`, bucket ids and names,
  the map rows, the shape-table format and IDs, the blitter rules, the
  text, sprite and player APIs, `floor_top` = 184, front matter and image
  sizes (768×544 ×2, 656×256) all match.

---

## Findings, ranked

### 1. BLOCKER (trivial fix): the first shift Pro Tip teaches a rule Zig doesn't have

**Where:** "Masks: changing two bits and no others", `:::pro-tip Zig sizes
your shifts` (lines 370–379).

> Why `@as(u8, code) << shift`, and why is `shift` a `u3`? Zig won't let a
> shift quietly lose bits. Shifting a `u2` left would push the code straight
> out of its two bits, so we widen it to a `u8` first.

**Problem:** this is false. Zig's `<<` drops the bits shifted out without
complaint.
- `var b: u8 = 0xFF; var s: u3 = 4; b << s` gives `0xF0` with no error
  and no panic.
- What Zig enforces is the **type of the shift amount**. It must be
  `Log2Int(T)`, which is `u3` for a `u8` and `u1` for a `u2`.
- The real error for `code << shift` with `code: u2, shift: u3` is
  `error: expected type 'u1', found 'u3'`.

The reader will remember "Zig catches lost bits" and get bitten later. The
second Pro Tip ("Widen before you shift", line 1083) explains the same
mechanism correctly, so the chapter now has two boxes on one topic, and
they contradict each other.

**Fix:** merge the two into one box at line 370 and delete the second:

> :::pro-tip Zig sizes your shifts
> Why `@as(u8, code) << shift`, and why is `shift` a `u3`? In Zig the
> shift *amount* has a type that depends on what you're shifting: a `u8`
> can be shifted by a `u3` (0 to 7, since 8 or more would empty it), and a
> `u2` only by a `u1`. Shift our `u2` code by a `u3` and the build stops
> with `expected type 'u1', found 'u3'`. So we widen the code to a `u8`
> first, and then the `u3` fits. The same thing bites with colours:
> `@intFromEnum(Color.dark_grey)` is a `u4`, and `... << 4` fails with
> `type 'u2' cannot represent integer value '4'`. Widen first. What Zig
> does *not* do is stop you shifting bits off the top of a byte: `0xFF << 4`
> is quietly `0xF0`, exactly like JavaScript. `@truncate` in `codeAt`
> drops the high bits on purpose.
> :::

### 2. SHOULD-FIX: the room's loading pause shows a half-drawn room, and the prose promises a blank screen

**Where:** `frame`, the `.draw_room` branch, and "Drawing a screen is a
loading pause" (lines 543–552):

> The frame runs as long as it needs, the meter shows a grey bar instead of
> a red one, and the player sees a blank screen for a moment and then the
> finished title. Every room change in the game will work this way.

**Problem:** that holds for the title only by luck.
- The machine finishes the current lap of the beam from final RAM after
  `frame` returns (card §6: "the rest of the picture is drawn with your
  finished screen").
- The title draw ends on raster 299, which is vblank, so its picture is
  blank.
- The room draw ends on raster 119 (125,476 / 63 = 1,991 lines; mod 312 =
  119). Display rows 68–199 are then drawn with the display back on.
- So for all 7 slots (frames 21–27, about 140 ms in the browser) the
  player sees the bottom two thirds of the new room under a blank top
  third. See `scratchpad/.../code/my-creep/g/frame_00021.png`.
- Any redraw whose length isn't a lucky multiple will do the same. The
  Decision log's "'blank → big job → re-enable → return' is a loading pause
  whose final picture is the finished screen" is wrong in general. So is
  the card's code sample.

**Fix (verified in `scratchpad/.../code/fix/`):** don't re-enable at the end
of the long frame. Do it at the top of the next frame, with the other
hardware writes. That is the chapter's own "hardware first" rule.

```zig
.draw_title => {
    m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
    m.bucket(bucket_drawing);
    title.draw(m);
    setMode(m, .title); // the display comes back on at the top of the next frame
},
.title => {
    m.poke(hw.control, machine.display_on); // before the beam reaches the display
    ...
```

The same applies to `.room`, before `player.show`.
- With this change, frames 21–27 are entirely border colour and frame 28
  is the finished room.
- `zig build test` still passes.
- It costs 4 cycles a frame. The Boss Battle becomes `max 156424`, `avg
  1476`, `bucket 0: max 42`, `bucket 2: max 720, avg 181`. Room frames go
  to 104 and 732, and the title frame to 6,698.
- Update the prose ("switch it back on at the top of the next frame,
  before the beam arrives"), the Game Over bullet, the Byte Budget and the
  Decision log.
- Flag the card's §6 sample to the machine owner. It needs either the
  same advice or a note that the reveal shows the rest of the current lap.

### 3. SHOULD-FIX: heavy comptime with no "Chapter 3 explains this", and one wrong explanation

**Where:** `star_map` and its paragraph (line 460); `shapes.zig` (`mirror`,
`pack`, `build`); `text.terminated`/`say`.

> `star_map` is worked out while the game compiles: a `blk:` block runs at
> compile time

**Problems:**
- **The explanation is wrong.** `blk:` is only a label so `break :blk out`
  can return a value. The block runs at compile time because it initialises
  a top-level `const`. A reader who labels a block inside `frame` will
  expect compile-time evaluation and won't get it.
- **The idioms are unexplained.** A JS/Python dev cannot read these, and
  the chapter is silent on all of them:
  - `@setEvalBranchQuota`
  - `undefined`
  - `comptime a: Art` / `comptime words` parameters
  - `const done = flipped; rows[r] = &done;` (freezing a comptime value so
    you can point at it)
  - `all[0..all.len].*`
  - the `[words.len]u8` return type
  - `[_]u8{x} ** cells`
  - `?[3]Color = null` with `if (a.colors) |c|`
  - `std.enums.values`
- **There is no forward pointer.** The Decision log (Ladder bookkeeping)
  says ch3 "teaches comptime properly; it can refer back to `shapes.zig`".
  The chapter never tells the reader that.
  - Without the pointer, the reader can't tell whether they were meant to
    understand `mirror` or not. That is the "lost" feeling the outline's
    test warns about.
  - The chapter shouldn't teach comptime fully here (that's ch3's thunder).
    It does need to say "type this, trust it, Chapter 3 opens it up", plus
    the three idioms a reader will otherwise stare at.

**Fix:** correct the `blk:` sentence, and add one short box after the
`shapes.zig` walkthrough:

> :::pro-tip Reading comptime code
> Chapter 3 is where `comptime` gets the full treatment; for now, four
> things make `shapes.zig` readable. A top-level `const` is always worked
> out while compiling, which is why `star_map` and `table` cost the game
> nothing (the `blk:` label only lets `break :blk out` hand back the
> answer). A `comptime` parameter, like `say`'s `words`, must be known
> while compiling: fine for the title's words, and the reason Chapter 3
> needs `draw` for text that comes from the castle file. `?[3]Color` is
> "three colours, or `null`", like `Optional` in Python, and
> `if (a.colors) |c|` runs only when there are some, with `c` the
> unwrapped value. And `const done = flipped; ... &done` freezes a
> compile-time value so the finished table can point at it. Every
> comptime builder you'll write uses that last line.
> :::

Also give `@setEvalBranchQuota` a comment ("compile-time loops are
capped; this raises the cap").

### 4. SHOULD-FIX: length and pacing (about 15,000 words; a 570-line stretch with nothing new on screen)

**Where:** from the row-table win (line 697) to the castle appearing (line
1265).

**Problem:** the chapter is 14,982 words: 8,518 of prose and 6,464 of
code. That's at the top of the bible's 4–9k guide. Its content matches
the outline, which overloads Chapter 2, so most of the density is
inherited. The pacing problem is specific, though. After the best moment
in the chapter (red meter → green), the reader goes through these before
a new pixel appears:
- "What a pointer really is"
- an Under the Hood box
- an Inside the Disk box
- the shape-table format
- the art excerpt
- the 170-line `shapes.zig`
- a Game Over box, a Pro Tip and a Byte Budget
- the blitter
- a Secret Passage

That is roughly 2,300 words and 220 lines of code. The same dry stretch
was the ch01 review's finding 10.

**Fix (pick some; together they save about 1,200 words and about 90 code
lines):**
- **Move "What a pointer really is" and its JS Under the Hood box to
  right after the blitter walkthrough**, at "Walk through it with a
  pointer in each hand". That code is where pointer arithmetic is actually
  seen (`dst += 8`, `src += width`, a directory pointer to a shape, a
  pointer to `$0310`). The lesson lands harder there, and the stretch
  shrinks.
- **Fold the mid-chapter `byte-budget The shape table`** into the final
  Byte Budget (−80 words).
- **Cut the `secret-passage Where this blitter will be used next`.** It
  isn't a deep dive, it's a forward note. Make it one sentence after the
  blitter prose ("Chapter 3's castle X is a fat pixel plus 16; the
  conversion goes in the castle reader, not here").
- **Merge the two shift Pro Tips** (finding 1; −120 words).
- **Use insertion listings instead of whole-function replacements** where
  only a line or two changes:
  - `boot` is listed whole five times (blocks 8, 11, 17, 26).
  - `title.draw` is listed whole three times. Block 19 only adds three
    `text.say` lines.

  "Add after `screen.drawShape(m, .moon, 124, 4);`" keeps the
  exhaustiveness rule with a third of the code.
- **Consider dropping the 105-line "complete `main.zig`".** It duplicates
  the checkpoint, which the Warp Zone links. If you keep it for
  consistency with Chapter 1, fine.
- **Trim the Lookup Table Power-Up box**, which repeats the paragraph
  before it, to its rule and its cost.

### 5. SHOULD-FIX: "still in one colour" is false at that step

**Where:** "Into the Entrance Hall", lines 1661–1665.

> with Chapter 1's explorer standing on its floor. He still floats up and
> down if you push the stick, still in one colour, and never moves his legs.

**Problem:** at this step `player.zig` is still Chapter 1's. Fire still
cycles his colour: with `--press 70:f:5` he turns red. See
`f-s07/grid.png`.

**Fix:** "He still floats up and down if you push the stick, still flashes
through colours when you press fire, and never moves his legs. Let's fix
all three."

### 6. SHOULD-FIX: a string that runs off the right edge crashes the game

**Where:** `text.draw` (`left += 8`), `map.text_buffer_size` (48 letters),
and the Bonus Stage "Design your own room".

**Problem:**
- The blitter promises clipping ("Anything past the right ... is cut
  off").
- `left` is a `u8`, so the 33rd letter from x = 0, or the 21st from
  x = 100, overflows.
- Changing the room title to `"THE ENTRANCE HALL OF THE DOCTOR CREEP"`
  gives `panic: integer overflow` at `text.zig:50 left += 8`. I reproduced
  it in `scratchpad/.../code/long/`.
- The buffer and `terminated`'s compile-time check allow 48 letters, but
  only 20 fit on a line. The Bonus Stage invites exactly this edit.

**Fix (one line):** stop at the edge, the way the blitter does:

```zig
if (letter & 0x80 != 0 or left >= 160 - 8) break; // the end, or the edge of the screen
```

Or size the buffer at 20 letters ("one line of text") and say why. Either
way, add a Game Over bullet. Chapter 4 is the overflow chapter, so a
pointer to it is enough.

### 7. SHOULD-FIX: "add a shape and its name to `Id`" can silently break the walk

**Where:** Bonus Stage, "Redecorate".

> Add a shape to `art.zig` and its name to `Id`

**Problems:**
- `player.steer` relies on the eight explorer IDs being consecutive,
  right-facing first: `first + step`, and `now >= left_0`.
- A reader who adds `cobweb` between `explorer_right_1` and
  `explorer_right_2` makes the walk unpack a room shape as a sprite frame.
  The result is garbage, with no compile error.
- It also breaks the Decision log rule "Add new shapes at the end of `Id`
  so existing IDs (and the hex inspector) stay stable".

**Fix:**
- Bonus Stage: "Add a shape to `art.zig` and its name **at the end of
  `Id`**".
- `shapes.zig`: add a doc line on `Id` ("new shapes go at the end; IDs are
  stored in castle files and the walk counts on the explorer frames being
  in a row").
- Optionally, add a cheap guard in `player.zig`:
  `comptime { std.debug.assert(@intFromEnum(shapes.Id.explorer_left_3) ==
  left_0 + 3 and left_0 == right_0 + 4); }`.

### 8. SHOULD-FIX (low): `pressedFire` only works if it's called every frame

**Where:** `player.pressedFire` and "The title needs to notice fire"
(lines 1587–1591).

**Problems:**
- The function reads like a question but also updates
  `player_last_stick`.
- In room mode nothing updates `player_last_stick` any more (Chapter 1's
  `steer` did).
- Chapter 1's Power-Up promised that doorbells (Chapter 5) would use this
  byte. If Chapter 5 calls `pressedFire` only while the explorer stands at
  a bell, a fire button held all the way across the room counts as a
  fresh press on arrival, against the stale title-screen value.

**Fix:**
- One sentence in the prose: "It also stores this frame's stick, so call
  it exactly once a frame."
- A Decision-log note for Chapter 5: update `player_last_stick` once per
  frame (for example at the end of `steer`) and make the press test a pure
  function of `stick` and `before`.

### 9. NIT: the reason given for `floor_top` = 184 isn't the real one

**Where:** lines 1579–1581.

> `floor_top` moved up to row 184, so the floor sits on the bottom of the
> screen with the walkway's full brickwork showing.

**Problems:**
- A 7-row walkway at 192 would also show its full brickwork (rows
  192–198).
- At 184 the floor does *not* sit on the bottom of the screen: rows
  191–199 are a 9-row black band under it. You can see it in
  `02-room.png`, and it looks unintended.

**Fix:** either keep 192 (Chapter 1's floor, flush with the bottom, and
the explorer limits follow automatically), or give the real reason (for
example "so the floor sits on a cell boundary with a row of shadow below
it"). If it moves, update the Decision log's `floor_top`.

### 10. NIT: small number inconsistencies

- Byte Budget: "the stars cost **6,694 cycles a frame**". The stars cost
  6,660; 6,694 is the whole title frame, including `pressedFire`. Earlier
  the chapter said 6,672, which was right at that step. Say "a title frame
  costs 6,694 (the stars are 6,660 of it)", or the reader will wonder
  which number is true.
- Lookup Table Power-Up: "a read (8 cycles here) instead of the
  calculation (132 cycles here) ... eleven times faster". 132/8 is 16.5.
  The eleven comes from 132/12, the read plus the doubling. Say "a read
  and a shift (12 cycles)".
- "a blank screen for an eighth of a second". The pauses are 8 and 7
  slots, 160 ms and 140 ms: "about a sixth of a second".
- Shape-table Byte Budget: "the table can quadruple before the overlap
  check complains". 4 × 1,059 = 4,236, which is more than 4,096. And it's
  `build()`'s own "doesn't fit in its region" error that fires, not the
  overlap check. Say "can nearly quadruple before `build` refuses it".

### 11. NIT: the twinkle comment says every frame, the code says every eighth

**Where:** line 392 ("Every frame, each star moves one step") and the
`twinkle` doc comment.

**Problem:** the code steps every 8 frames (`>> 3`) and replots all 128
stars every frame anyway. Seven frames in eight redraw identical pixels.

**Fix:** reword to "every eight frames". Also add a Bonus Stage line,
since cost is this chapter's theme: "Skip the replot when `phase` hasn't
changed, and watch bucket 1 drop on seven frames out of eight."

### 12. NIT: two Game Over bullets are muddled or overstated

- **"Text that's a few stray dots. ... Or `say` was handed a string with a
  lowercase letter where you meant a picture glyph"**: a lowercase letter
  prints as a capital, not as stray dots, and the picture glyphs (`$01–$0B`)
  can't be typed as lowercase anyway. Replace the second half with a real
  failure: "No words at all: `boot` never called `text.start`, so the widen
  table and the glyph's header are still zeros."
- **"`m.poke(hw.control, 0)` must be the first thing the frame does"**:
  the rule is "within the first 3,213 cycles", as the code comment says.
  Say that (and finding 2 changes the second half of this bullet).

### 13. NIT: Chapter 3 and Chapter 4 ideas used without a word

- **Little-endian (ladder row 3).** It's used without explanation in the
  directory (`// low byte first`) and in `poke16`. One clause would do:
  "(two-byte values go low byte first on the Comet; Chapter 3 says why)".
- **Several flags packed in one byte (ladder row 4).** The flags-byte
  section teaches this fully here. That's good, but log it so Chapter 4
  refers back rather than re-teaching.

### 14. NIT: small Zig syntax left unexplained

- `while (true) : ({ at += 1; left += 8; })`: the continue expression,
  which runs only when the loop goes round again, not after `break`.
- `[_]u8{...} ** n` (repeat), next to Chapter 1's `++`.
- `@enumFromInt` on an exhaustive `Mode` panics if RAM ever holds 4 or
  more. That's good (loud), and worth a clause, because JS would hand you
  `undefined`.

One parenthesis each, or fold them into the finding 3 box.

### 15. NIT: the pointer lesson could close one door

**Where:** "What a pointer really is".

The reader may now try `m + 1`. One sentence: "Zig won't let you add to a
`*Machine`; a pointer to one thing has no 'next'. Our `u16` addresses are
the kind you do sums on."

### 16. NIT: `drawShape` on a sprite frame reads the next shape as colours

Sprite frames carry no colour cells, so `drawShape(m, .explorer_right_0,
...)` (a natural Bonus Stage experiment) paints colours from the next
shape's bytes. Make the doc comment say "room shapes and the glyph", or
mention it in the Bonus Stage.

### 17. NIT: wording

- "Old programmers called this a **blitter**, from 'block transfer'": say
  "Programmers of the era" (warmer), and the term is from "**bit**-block
  transfer".
- Tear Secret Passage: "the beam is down by the explorer's knees when a
  frame gets unpacked".
  - At 14,000 + `show` cycles the beam is on raster 223, sprite row 9
    (his chest), when the unpack starts.
  - The unpack (about 28 cycles a row) outruns the beam (63 a line) until
    about row 15. That's why the seam lands at his knees.
  - Say "the beam is crossing his middle when the unpack starts, and the
    unpack only overtakes it at his knees". It's a nice extra lesson in
    racing.
- Step 4 (`main.zig` "replace the whole file") silently drops Chapter 1's
  explorer, floor and test. Add one line: "The explorer and his test step
  out for a few sections; both come back, better."

### 18. NIT: the title is never paid off

"Ghosts in the Bitmap" is a good level name, but no ghost ever appears in
the prose. The torn explorer (two frames at once) or a cell that takes the
wrong colours are both natural "ghost" moments. One line in the tear
Secret Passage would do it: "That's the ghost in the bitmap: half of one
frame haunting the next."

### 19. NIT (art)

- **Title.** "THE CASTLES OF" (yellow `#B8C76F`) and "DR. CREEP" (light
  green `#9AD284`) are nearly the same pale yellow-green on screen. The
  name should pop. Try `DR. CREEP` in pink or light red against a white or
  light-grey first line.
- **Moon.** It reads a little like a cloud at 1×. A rounder silhouette
  would help.
- **Room.** The torches are muddy (brown, red and yellow at 2×8 cells).
- **What's good.** The explorer reads well: hat, skin, white coat, belt,
  boots, and a real stride frame. The doors, windows and brickwork are
  charming, the palette is coherent, and the tear close-up is excellent.
- **Alt text** is accurate for all three images.

---

## The weakest passages, with rewrites

1. **The "Zig sizes your shifts" Pro Tip** (finding 1). It states a false
   rule; the merged rewrite is above.
2. **"The player sees a blank screen for a moment and then the finished
   title. Every room change in the game will work this way."** (finding 2).
   After the code fix:

   > ...switch the display off first thing, while the beam is still above
   > the display, and do the work. Then *leave it off*: the long frame ends
   > somewhere in the middle of a sweep, and if the display came back on
   > now, the beam would finish that sweep with the new screen, a room
   > appearing from the middle down. Instead the next frame switches the
   > display back on as its very first job, before the beam reaches the
   > top of the display, and the player sees one clean cut from blank to
   > finished. Every room change in the game will work this way.

3. **The `star_map` paragraph** (finding 3):

   > `star_map` is a top-level `const`, and Zig works out every top-level
   > `const` while it compiles, so this whole block (scattering 128 stars
   > with a little arithmetic, throwing away any that would land in a cell
   > the words or the moon need) runs on your computer, not the Comet's.
   > The `blk:` label is only there so `break :blk out` can hand back the
   > answer. (Chapter 8 has the proper story of making numbers look random,
   > and Chapter 3 the proper story of `comptime`.) The game copies the
   > finished 256 bytes to `$6700` at boot.

4. **"He still floats up and down..."** (finding 5); the rewrite is above.
5. **The `floor_top` paragraph** (finding 9):

   > `floor_top` is now 192, the bottom row of cells, as in Chapter 1, and
   > the walkway's seven rows of brick fill it. The explorer stands on it
   > because his limits still come from `room.floor_top`.

   Or give the real reason for 184.

## What works well (keep these)

- **The star demo is the chapter's best moment.** The reader writes the
  obvious version and runs it. The meter goes red and the sky twinkles at
  half speed (49 calls in 100 frames). The chapter adds it up to the cycle
  (172 a star, "seven tenths of it is one `mul8`") and fixes it with a
  table. The meter goes green, a third full, with "same stars, same
  pixels, same picture". That is the ladder's "lookup tables vs computing
  (what a multiply costs)", taught exactly as the outline asks, and every
  number in it is real.
- **The mask walkthrough for `plot`** (the byte, the mask, `~mask`, AND,
  shift, OR, `$F7`) is a model byte diagram. "Clear with AND, set with OR"
  is the line a junior will keep.
- **Experience before mechanism:** "the pixels are wide ... a colour never
  quite ends where you'd like it to", then the 2-bit codes. The ORing
  explained by a ladder through bricks. The door gap in the castle wall as
  the 4-colour rule made visible.
- **Honest engineering.** "Today our frame is short and the unpacking
  finishes long before the beam reaches the floor", then why to double
  buffer anyway, then a Secret Passage that proves it with a reproducible
  torn frame.
- **Compile-time art validation** with verbatim, located errors ("Bad art
  doesn't build"), and `@field(art, @tagName(id))` called out as "the neat
  part". The precedence Pro Tip is told as a bug "that bit us", which is
  exactly the senior dev voice.
- **Inside the Disk boxes** are accurate in every detail I could check:
  the 313 step, the top-row-only walk, the `$2BF8` widen table, the mask
  shape, `^ 8` and the blank padding row. They also say what the disk does
  *better* ("goes one better", the AND mask), which keeps them from being
  trivia.
- **Continuity:** the Chapter 1 promises are paid, the Edge Detector is
  reused by name, the "wall made of arithmetic" comment is kept, and the
  bucket ids are stable and named.
- **Correctness of the build:** 30 listings rebuild `ch02` byte for byte,
  and every headless output in the chapter is verbatim. The code is
  `zig fmt`-clean and small-file, the costs are charged honestly at the
  places the prose says, and there are no `var` globals or magic addresses
  outside `map.zig`.
- **Voice:** warm, no banned words, two earned exclamation points, and
  good named "aha"s ("One table, two jobs", "a pointer can point
  anywhere; the table doesn't care", "its end costs nothing at all").
