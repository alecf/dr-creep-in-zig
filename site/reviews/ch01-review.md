# Review: Prologue and Chapter 1 ("It's Alive!")

Reviewer scope: `site/chapters/00-prologue.md`, `site/chapters/01-its-alive.md`,
`site/code/ch01/` (diffed against `site/code/starter/`), checked against
`site/AUTHORING.md` (bible + Decision log), `docs/tutorial/outline.md`,
`site/code/machine/REFERENCE.md` and `machine/src/machine.zig`. Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-ch01/`:
`blocks/NN.zig` (the chapter's 20 ```zig fences, in order), `code/my-creep/`
(the project rebuilt from `starter/` by following the chapter), `f-*/`
(frame dumps from the intermediate steps, as PNGs).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** I copied `starter/` to
  `my-creep/` and applied every listing in the order the chapter gives
  them, following its instructions ("add the import below `hw`", "replace
  `steer`", and so on). The result is byte-identical to `ch01/` for
  `build.zig`, `build.zig.zon` and all four `src/*.zig` files. The
  "complete" `main.zig` listing matches too. The starter `main.zig` the
  chapter quotes matches `starter/src/main.zig`, and the quoted `ram:` line
  matches `machine.zig:171`.
- **Every "build and reload" step compiles and shows what the chapter
  says:** border change; floor only (grey strip at display row 192–199);
  "the floor's there, the explorer isn't"; "white, standing on the grey
  floor"; walking right stops at X = 255 (about 72–80% of the way across).
- **Boss Battle:** `zig build`, `zig build test` and `zig build wasm`
  succeed silently (wasm writes `game.wasm`, `shell.js` and `index.html`).
  The headless command prints exactly the promised five lines (max 100,
  avg 92) and writes six frames. Frame 0 is pixel-identical to
  `images/01-its-alive.png`. Frame 100 shows him left and on his way up.
  Frame 249 shows him cyan, mid-screen.
- **Secret Passage tear:** reproduced (`m.work(6000)` before `show`, up
  134 frames, fire at 150, frame 151). It matches `images/01-tear.png`
  apart from a 1-px offset.
- **Overflow:** removing `x < max_x` gives `panic: integer overflow` at the
  `x += 1` line, as claimed.
- **Compile errors quoted:** `type 'u8' cannot represent integer value
  '256'` is verbatim. A poke of 300 fails the same way. The Game Over
  overlap message `memory map: stack (reserved) overlaps monsters` is
  verbatim, if you add a `monsters` region at `$01F0`.
- **Precedence:** `stick & b != 0` compiles as `(stick & b) != 0`, and
  `zig fmt` keeps parentheses that the reader adds.
- **Numbers I recomputed, all correct:** 0x10000 = 65,536;
  2⁸ = 256; `$A5` = 1010 0101; the six hex/decimal pairs; 24 × 320 =
  7,680 = `$1E00`, giving `$FE00–$FF3F`; 24 × 40 = `$3C0`, giving
  `$DBC0–$DBE7`; 50 + 192 − 21 = 221; 24 + 320 − 24 = 320; 51 × 63 =
  3,213; 6,000 / 63 = line 95, which is display row 44; floor fill (320 +
  40) × 8 = 2,880; 19,656 / 4 ≈ 4,900 peeks; 8,000 × 4 = 32,000; `$FB`,
  `$EE`; frame cost 24 + 68 = 92, plus 8 for fire = 100 (0.47% and 0.51%);
  `Machine` ≈ 65,536 + 384 × 272 × 4 ≈ 0.48 MB.
- **Inside the Disk:** "30 bytes near the very bottom of memory" matches
  `docs/memory-map.md` §2.2: zero page `$10–$2D`, refreshed by the IRQ.
- **Format:** front matter, file names and titles match the Decision
  log. The map rows, the player byte layout, the colours, the clamps, the
  `held` idiom, the frame order, `steer`'s `m.work(40)` and the
  Edge Detector name all match it as well.
- **Prologue commands:** in a fresh copy of `starter/`, the four-line
  headless summary is verbatim, and test and wasm succeed. The frame shows
  a purple border, black display and empty dark meter bar, as described.

---

## Findings, ranked

### 1. BLOCKER: the `last_stick = $FF` explanation is backwards

**Where:** `01-its-alive.md`, "Fire!", the paragraph after the `steer`
listing (lines 1060–1063).

> Remember that `start` set `last_stick` to `$FF`, "nothing held". That
> way, if someone is already holding fire when the machine powers on, the
> first frame doesn't count it as a press, because there's no "before" to
> compare against.

**Problem:** this is the opposite of what the code does. `$FF` means
"nothing held last frame", so on frame 0 a held fire gives `held(stick,
fire) and !held(0xFF, fire)` = true, and it **is** counted as a press.

**Evidence:**
- `zig build run -- --frames 3 --press 0:f:50` → the explorer is red
  (`#68372B`) in frame 2.
- The chapter's own test depends on the real behaviour. It holds fire on
  the very first frame after boot and expects `color + 1`.

**What `$FF` really buys:** power-on RAM is `$00`, and to a joystick byte
`$00` reads as "every switch held". Left at 0, frame 0 would think all five
switches were held a moment ago. A fire held at power-on would be
swallowed, and a release detector (which the Power-Up box teaches) would
fire five phantom releases.

**Fix (prose only, code is fine):**

> Remember that `start` set `last_stick` to `$FF`? Memory powers on as
> zeros, and to a joystick byte, zero means *every switch is held*. Left
> alone, the first frame would think all five switches had been held a
> moment ago, and a release check would see five releases that never
> happened. `$FF` is what the port itself reads when nobody's touching it,
> so the first frame compares against an idle stick.

### 2. BLOCKER (trivial fix): the narrator steps out of the fiction

**Where:** `01-its-alive.md`, "The memory map", line 453; and the Game
Over "Common mistakes" box, last bullet (lines 1227–1229).

> Why be so strict? The honest in-world answer is that in 1984 there's
> nowhere else to put it.

> **A Zig `var` at the top of a file.** It compiles, and it works, and
> it's outside the machine's 64 KB, where the memory map, the widgets and
> your tests can't see it.

**Problem:**
- "In-world" tells the reader there's an out-of-world answer. That's
  exactly the meta talk the bible bans (§1 "Stay in the world").
- "Outside the machine's 64 KB" says the program runs somewhere other
  than the computer it's written for, which reveals the emulator.
- "A Zig `var` would be a byte the machine doesn't know it's spending"
  (line 455) is the right idea, said in-world.

**Fix:** frame a global as a byte hidden in the program image, where the
map can't see it. That's true in spirit and needs no second world:

> Why be so strict? Because on a 64 KB machine, a byte nobody wrote down is
> a byte you'll spend twice. A Zig `var` would be tucked away inside the
> program image, at an address only the compiler knows, where the memory
> map can't account for it...

For the Game Over bullet: "It compiles, and it even works, but it hides a
byte inside the program image where the memory map, the widgets and your
tests can't see it."

### 3. SHOULD-FIX: the naming rule is broken in the listing that states it

**Where:** `01-its-alive.md`, "The memory map", lines 557–560, against the
`src/map.zig` listing (line 510). Code: `ch01/src/map.zig:15`,
`ch01/src/player.zig`. Bible: Decision log, "Memory map style".

> Naming convention, from here to the end: a region is a `Region` constant
> named for what it holds, and its fields are `u16` address constants
> named `region_field`, all in `map.zig`.

```zig
pub const last_stick = player.first + 3; // joystick 1 as it read last frame
```

**Problem:** under the stated rule this should be `player_last_stick`. Ten
lines after announcing a rule "from here to the end", the listing breaks
it. Chapter 9 adds player 2, and by then a bare `last_stick` is ambiguous.
It's cheap to fix now and expensive later, because every chapter's diff
inherits it.

**Fix:** rename it to `map.player_last_stick` in `ch01/src/map.zig`, in
`player.zig` (`start` and `steer`), and in the chapter's listings and prose
("`last_stick` at `$0203`" → "`player_last_stick`"). Also make the Decision
log line say `player_last_stick`. If the writer prefers the short name,
reword the rule instead, but don't leave them disagreeing.

### 4. SHOULD-FIX: copying a built checkpoint silently ignores your edits (and "copy it next to `machine/`" is ambiguous)

**Where:** `01-its-alive.md` Warp Zone ("Copy it next to `machine/` to
start Chapter 2"); `00-prologue.md` Warp Zone ("copy it again, or copy
any chapter's checkpoint"), and "Power on" (`cp -r starter my-creep`).

**Problem 1 (verified, nasty):** if a project folder has been built, its
`.zig-cache/` records the absolute paths of the original's sources.
`cp -r` carries that cache along, and in the copy `zig build` / `zig
build run` then reuse the original's binary.
- I copied a built `my-creep` and added `comptime { @compileError("boom"); }`
  to the copy's `room.zig`. `zig build` succeeded silently.
- After deleting the copy's `.zig-cache` it failed with `error: boom`, as
  it should.
- A reader who builds `code/ch01/` in place to compare, then copies it,
  gets a project that ignores everything they type. Any site pipeline that
  builds checkpoints in place before packaging `code/` would trigger the
  same thing.

**Problem 2:** the reader works in `my-creep` (Decision log). `cp -r ch01
my-creep` when `my-creep` already exists creates `my-creep/ch01/`, not a
replacement. "Copy it next to `machine/`" doesn't say what to call it.

**Fix:** give exact commands wherever a copy is suggested:

```
cd code
rm -rf my-creep
cp -r ch01 my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out
```

Add a one-line Game Over? or Pro Tip: "copied a project and your changes
don't show up? Delete its `.zig-cache`." Do the same for the Prologue's
`cp -r starter my-creep`. Also tell whoever owns the Pages workflow to
package `code/` from a clean checkout.

### 5. SHOULD-FIX: the "Make it tear" Secret Passage arrives too early and can't really be seen in the browser

**Where:** `01-its-alive.md`, "Racing the beam", `:::secret-passage Make
it tear` (lines 815–834).

> Then steer the explorer up to about a fifth of the way down the
> screen and press fire (you'll have both by the end of the chapter).

> His hat is still white; the rest of him is already red.

**Problems:**
- It asks for steering and fire two sections before they exist. The
  parenthesis admits it, which is a sign it's in the wrong place.
- The tear lasts exactly one frame (the frame the colour changes), so in
  the browser it's a 20 ms blip that most readers will miss. The prose
  half-admits this too ("At 50 frames a second it's a flicker").
- In the screenshot, and in my reproduction, his face is white too, not
  just the hat. The alt text says the same as the prose.

**Fix:**
- Move the box to the end of "Fire!" (or keep a one-line forward pointer
  in "Racing the beam").
- Give the reader a headless command that catches the torn frame. I
  verified this one:

  ```
  zig build run -- --frames 152 --press 0:u:134 --press 150:f:5
  ```

  "Fire lands at frame 150, so `frames/frame_00151.ppm` is the torn one."
- Say "his hat and face are still white".

### 6. SHOULD-FIX: `&picture` and "a pointer to the machine" go unexplained, and `&` then turns up meaning AND

**Where:** `01-its-alive.md`. Line 82 ("Both get `m`, a pointer to the
machine"). The `start` listing, `m.load(hw.sprite_data + block * 64,
&picture);`, and its bullet list (lines 695–698). Then "Reading the
joystick", where `&` is introduced as bitwise AND.

**Problems:**
- The persona half-understands pointers and has never used one, and
  pointers proper are ladder row 2. That's fine, but the chapter uses
  pointer syntax twice without a word.
- The reader then meets `&` as AND fifteen minutes later. A JS developer
  will wonder whether `&picture` is some AND.
- `*Machine` gets "a pointer to the machine" with no bridge.

**Fix:** two sentences, bridged from JS and deferring to Chapter 2:
- At line 82: "`*Machine` means 'a pointer to a `Machine`': like passing
  an object in JavaScript, `boot` gets the machine itself, not a copy.
  Chapter 2 shows what a pointer really is."
- In the `m.load` bullet: "`&picture` hands `load` the table's address
  rather than a copy of its 63 bytes. In front of a name, `&` means
  'address of'. Between two numbers, as you'll see shortly, it means
  AND."

### 7. SHOULD-FIX: a "you can guess" prompt in the Prologue

**Where:** `00-prologue.md`, "The machine: the Comet 64", line 95–96.

> Why does the game work so hard to never need a ninth sprite? You can
> guess.

**Problem:** the bible and the outline both ban "can you guess?" prompts.
It's rhetorical rather than a quiz, but it reads as one. The two questions
before it answer themselves ("The first row." / "The third."), so this one
should too.

**Fix:** "Why does the game work so hard never to need a ninth sprite? The
fourth row, and you'll meet it head-on when the lasers arrive."

### 8. SHOULD-FIX: the Prologue never says how to get the code

**Where:** `00-prologue.md`, "What you need", line 154.

> Then get the tutorial's code folder. It looks like this:

**Problem:** this is the one step with no instruction. There's no link, no
"download the zip", and no clone command. Everything after it depends on
it.

**Fix:** a link or placeholder the site generator fills in (for example
`[Download the code folder](../code.zip)`, or a "Download" button
directive), plus "unzip it anywhere".

### 9. SHOULD-FIX: promises to later chapters that aren't logged (one may not come true)

**Where:** `01-its-alive.md`:
- Byte Budget, line 1202–1203: "Chapter 2 starts drawing whole rooms, and
  the meter will start to have opinions."
- Line 701: sprite-pointer animation is "a trick we'll lean on hard from
  Chapter 2".

**Problems:**
- Boot is unmetered. Chapter 2's checkpoint is "a static title screen and
  a hand-placed room". If the Chapter 2 writer draws the room in `boot`,
  the meter has no opinions at all.
- Neither promise is in the Decision log list "ch01 already told readers:
  …".

**Fix:** add both to that Decision log entry, with a note for Chapter 2:
draw (or redraw) the room from `frame` at least once, so the meter shows
its cost (or a loading pause). Or soften the line to "…and the meter will
finally have something to say."

### 10. SHOULD-FIX (pacing): a long dry stretch between the floor and the explorer

**Where:** `01-its-alive.md`, from the end of "Laying a floor" (line 384)
to "Build and reload. The floor's there." (line 750).

**Problem:** about 1,900 words with nothing new on screen. In that
stretch:
- "Fifty times a second", with its cost table.
- The budget-meter widget.
- The whole memory map: a table, a byte diagram, a 55-line listing, and
  three "things to notice".
- A comptime explanation.
- A Game Over box and two Pro Tips (the `comptime` audience tip is about
  a failure that can't happen yet).
- The sprite intro.

The outline asks for Chapter 1 to be "short and hands-on: get something on
screen fast". The prose is good, but the momentum dips just as the reader
is eager for the sprite. The chapter is also dense for the bible's "two or
three new ideas". It teaches the four ladder ideas plus active-low, masks,
the beam/tear rule, shadow copies, comptime and edge detection.

**Fix (pick some):**
- Cut the `comptime blocks need an audience` Pro Tip. It warns about a
  refactor nobody will do in Chapter 1. If kept, move it to Chapter 3,
  where `comptime` is the topic.
- Trim "The `comptime` block runs…" to about three sentences.
- Fold the cost table into one sentence: "a peek or poke is 4 cycles; a
  fill is 8 per byte; your own sums you charge with `m.work`". The full
  table is on the card.
- Or reorder: introduce the sprite picture and `start` (the fun part)
  first, and the memory map just before `start` needs `map.player_x`.

### 11. NIT: the `&`/`==` Pro Tip forgets Python and is a touch patronizing

**Where:** `01-its-alive.md`, Pro Tip "`&` binds tighter than `==` in Zig".

> Coming from JavaScript, add the parentheses if it makes you feel safer

**Problems:**
- The reader is "JS *or Python*". Python agrees with Zig here
  (`(stick & LEFT) == 0`), which is worth one clause.
- "If it makes you feel safer" talks down a little.

**Fix:** "Python happens to agree with Zig; JavaScript and C don't. If
your fingers learned on JavaScript, the parentheses are free: `zig fmt`
keeps them."

### 12. NIT: "floats back up"

**Where:** "Reading the joystick", line 872–873.

> let go and the wire floats back up to 1

**Problem:** a floating input is exactly the undefined case. What holds it
at 1 is a pull-up.

**Fix:** "let go and a resistor pulls the wire back up to 1."

### 13. NIT: the wrong card section is cited for 19,656

**Where:** "Fifty times a second", line 402–403: "(the card's section 9
explains where the number comes from)".

**Problem:** section 9 states the number. Section 6 ("Racing the beam")
explains it: "That's where the budget of 19,656 cycles comes from."

**Fix:** cite section 6, or, better, say it inline: "312 lines of 63
cycles each; you'll see why in a moment."

### 14. NIT: "where sprites are drawn but nobody can see them"

**Where:** "A sprite is 63 bytes", lines 754–757.

**Problems:**
- The VIDEO chip doesn't draw sprites outside the display window at all
  (card §5: "only seen inside the display window").
- The colour register is also still 0 (black on black). `show` copies
  the colour as well, which the prose glosses ("It never told the VIDEO
  chip *where* to draw sprite 0").

**Fix:** "…(0, 0) is up and to the left of the display, off in the
border where sprites don't show. (His colour register is still 0, too:
black on a black screen.)"

### 15. NIT: the outline's shell-internals Secret Passage was dropped without a log entry

The outline (ch1) says the shells' "internals get a Secret Passage, not a
lesson". There isn't one. That's probably the right call, since the bible
makes the shells part of the provided machine, but log it so the next
reviewer doesn't flag it again.

### 16. NIT: the Under the Hood box skips the "what it costs" leg

**Where:** `:::under-the-hood Where does x live?`.

**Problem:** the outline defines the box as "a familiar snippet, what it
really costs in memory and time, and the low-level version we're writing
instead". The box has the first and the spirit of the third, but no cost.

**Fix:** one line: "In this game `x` costs exactly one byte, and reading
it costs 4 cycles. You'll know both numbers for every piece of state
you ever add."

### 17. NIT: ```zig fences that aren't standalone Zig

**Where:**
- Blocks 2 (`ram: [0x10000]u8 = @splat(0),`, a struct field).
- Block 3 (`const x: u8 = 256;`, deliberately fails).
- Block 4 (a bare statement).
- Block 8 (`var player_x…  // not in this game`).

**Problem:** these are real Zig syntax. But if the site tooling ever
compiles or extracts every ```zig block (the bible says "every ```zig
block should be real Zig"), these four will trip it.

**Fix:** decide on a marker for snippet and intentional-error fences (for
example ```zig snippet / ```zig compile-error) and log it.

### 18. NIT: borderline fiction in quoting the machine's source

"It's in the machine's source, in the definition of `Machine`" (line 86)
and "It's 64 KB of RAM plus the picture on the tube" (the test Pro Tip)
both show that the computer is a Zig struct. The bible makes the machine a
provided package, so I'd keep the `ram` line, which is the chapter's best
"aha". Phrase it as "the machine's own definition, in `machine/src`",
and drop "plus the picture on the tube" ("about half a megabyte with
everything the machine keeps" is enough).

### 19. NIT: magic last-addresses in `map.zig`

The hardware regions use literal ends (`0x01FF`, `0xC7FF`, `0xCFFF`,
`0xD02E`, `0xDBE7`, `0xFF3F`). The bible asks for regions "built from
`machine.hw` names". Several are derivable (`hw.sprite_data + 32 * 64 -
1`, `hw.color_ram + 1000 - 1`, `hw.bitmap + 8000 - 1`) and would read as
explanations rather than numbers to check. That's optional, and only
worth doing together with finding 3, since both touch `map.zig`.

### 20. NIT: small Zig syntax left unexplained

- `[_]Region{…}` (the `_` lets the compiler count).
- `regions[i + 1 ..]` (a slice from `i + 1` to the end).
- `//!` vs `///` doc comments.

One parenthesis each in the existing "(`for (regions, 0..) |a, i|` walks…)"
aside would do it.

---

## The weakest passages, with rewrites

1. **The `$FF` paragraph** (finding 1). It's wrong; the rewrite is above.
2. **"Why be so strict?"** (finding 2). It breaks the fiction; the rewrite
   is above.
3. **The "Make it tear" Secret Passage** (finding 5). Move it after
   "Fire!", add the headless command, and fix "hat" to "hat and face".
   Suggested opening once moved: "Now that he moves and changes colour, you
   can break him on purpose."
4. **The memory-map stretch** (finding 10). Cut the comptime-audience
   Pro Tip, compress the comptime explanation, and fold the cost table into
   a sentence.
5. **`m.load(..., &picture)`** (finding 6). Add the two bridging sentences.

## What works well (keep these)

- **The spine of the chapter:** "here's the most important line in the
  whole Comet 64: `ram: [0x10000]u8`". Then poke a number and the border
  changes: "There isn't a `setBorderColour` function anywhere in the
  machine. There's a byte, and the chip looks at it." That's the "aha"
  named exactly the way the outline wants.
- **Experience first, then mechanism:** the opening ("the first time a game
  answered you"), sprites "from the player's side", the joystick "from the
  machine's side", and the "wall made of arithmetic". That last one sets up
  a mystery, pays it off on screen, and promises Chapter 4.
- **The Fire! section** walks the reader into the bug ("five colours per
  tap") before the fix. Naming the Edge Detector Power-Up and pointing at
  doorbells and the ray-gun panel is the series working as designed.
- **The byte diagrams:** bit worths, the joystick port, and the two AND
  worked examples are the right tool at the right size.
- **Sanity checks the reader can see:** "both runs end on the last byte
  of their plane, which is a good sign we did the sums right" is how a
  senior dev actually thinks.
- **Bridges that land:** the JS `let x` heap/closure story, `#FF8800` in
  CSS, "keep each frame under 16 ms", and `if` as a ternary.
- **Correctness:** every number checks out, the listings rebuild `ch01`
  byte for byte, and every intermediate "build and reload" shows what the
  prose says. That's rare and valuable.
- **The voice:** no "just/simple/easy/obviously", about four earned
  exclamation points, no empty praise. The jokes ("crashed only on
  Tuesdays", "the meter will start to have opinions", "Well, it's standing
  there. Close enough for one more section.") are well judged.
- **The Prologue's castle tour** is lovely: the doll's house with the
  front wall off, "the doctor isn't home", and "one of the great small
  pleasures in all of gaming". The limits table followed by "nobody
  complains that the clock exists" frames the constraints exactly as the
  outline intends.
