# Review: the Comet 64 `machine` package, `starter/`, `check-all.sh`

Reviewer scope: `site/code/machine/**`, `site/code/starter/**`,
`site/code/check-all.sh`, checked against `site/AUTHORING.md` §3 + Decision
log, `docs/tutorial/outline.md`, `CLAUDE.md`. Zig 0.16.0.

Scratch experiments live in
`/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/review-machine/`
(a test game `game/`, a panic/overrun game `pgame/`, `stride.zig`,
`w24.zig`, `fontcheck.zig`, `wasmcheck.mjs`, a node harness for the wasm).

## Baseline: what's correct

`./check-all.sh` passes (machine tests, starter build/test/wasm/headless).
I checked these against §3 by reading the code and running experiments, and
found no bugs in them:

- Bitmap layout `$E000 + cell*8 + row`. Pixel code 01 is the screen high
  nibble, 10 the screen low nibble, 11 the colour-RAM low nibble.
  Foreground = codes 10/11. Code 01 does not collide (verified: a bitmap of
  `0x55` under a sprite gives `$D01F = 0`; `0xFF` gives `1`).
- Sprites: origin (24,50), X MSB from `$D010`, partial clipping on the left
  (X=4 shows the right part), double width/height (Y=240 tall reaches row
  199). Multicolour 01/10/11 → `$D025`/own/`$D026`. Pointer ×64 with no
  mask. Priority quirk and behind-bit as logged. Collisions only on
  non-transparent pixels, latched, visible in F+1.
- Meter: costs match §3 exactly. Boot is unmetered. Yellow at exactly 75%,
  still yellow (no stripe) at exactly 100%, red at budget+1. The rounding
  of the filled width is sane.
- Ports: `$FF` idle, up+fire = `$EE`, `$DC02` latched until written 0.
  The wasm harness confirms that `comet_frame(0x1F,0)` gives `$DC01 = $E0`
  and that `comet_key(65)` latches.
- wasm: exports present, 24 pages. ReleaseSafe panics reach `comet_log`
  ("integer overflow") and trap, and `std.log` works. About 0.09 ms/frame
  in node. Headless Debug runs about 0.8 ms/frame.
- Font: 100 lit glyphs (63 printable + 26 lowercase copies + 11 pictures),
  letters within 7×7.
- In-world check: no C64/VIC/SID/emulator/etc. anywhere reader-facing.

---

## Findings (ranked)

### 1. BLOCKER for ch2 as outlined: the machine can't tear, so sprite double-buffering has nothing to fix
**Where:** `machine/src/video.zig:9-10` ("Changing a register halfway through a
frame has no special effect"), `machine/src/machine.zig:254-271`
(`render` runs only after `Game.frame` returns).

**What:** the outline's ch2 teaches "hardware sprites with double-buffered
frame pointers". Its Toggles widget promises "disable sprite
double-buffering → tearing". Ch1 lists "writing hardware registers once per
frame" as a technique. The VIDEO chip only ever sees the finished RAM of a
frame. A half-decoded sprite block, or a pointer flipped before its data is
written, can never be shown. So double-buffering is pure cost on this
machine, and the toggle can't show anything. Per AUTHORING §3, the
alternative (faking a tear in game code) is forbidden. "Real rigour
underneath" also means a chapter can't claim the technique is needed when
it isn't.

**Evidence:** code reading. `render(m)` is called exactly once, after
`Game.frame(m)`, from a RAM snapshot. No register or memory write during
`frame` is observable by the renderer.

**Fix (pick one, log it in the Decision log before ch2 is written):**
- (a) Add a minimal "beam". The frame interrupt fires at the bottom of the
  display (the 1984 game's raster-IRQ position). The chip draws display line
  L when the meter passes `(L + lines_in_vblank) * 63` cycles. Lines not
  yet reached at the end of `frame` are drawn from final RAM. This needs
  only a check in the cycle-charging path (`charge()` → `while (cycles >=
  next_line_at) drawLine()`). It turns the meter into the beam, and makes
  "do register writes early / double-buffer" true, visible and cheap to
  explain. It costs some of the "forgiving" promise; §3 would need a line.
- (b) Keep atomic rendering, drop the tearing toggle and the "once per
  frame" technique from the outline, and teach double-buffering only as
  lore ("Inside the Disk"). Or drop it from the game.

### 2. should-fix (decide before ch3): no display-blank bit, and big redraws can't fit a frame
**Where:** `machine/src/machine.zig:43-65` (`hw` register list), AUTHORING §3
register table, `video.zig:70-88`.

**What:** the 1984 game blanks the display (VIDEO control register, display
enable bit 4) at the start of every room clear, draws the room over several
frames, then turns the display back on. On the Comet, clearing the bitmap,
both planes and the sprite area alone costs about 96,000 cycles (4.9 frames)
before any shape is drawn. So every room flip in ch3 either (a) blows the
budget for one frame (red stripe on every door you walk through, which
teaches the reader that overruns are normal), or (b) has to be spread over
several frames by the game. With no blank bit, the half-drawn room is then
visible. Neither matches the 1984 behaviour the "Inside the Disk" boxes will
describe.

**Evidence:**
- `disasm/object.s:3560-3564` (`screen_clear` at `$18EE`:
  `lda $D011 / and #$EF / sta $D011`). Many `ora #$10 / sta $D011`
  re-enables follow (e.g. lines 778-782, 1447-1451, 4389-4393).
- Experiment `pgame/` (clears bitmap, screen, colour RAM and sprite area
  every 50 frames): `cycles: max 96384 (490%) … overruns: 5`.

**Fix:** add a display-enable bit (e.g. `$D011` bit 4, `hw.display_ctrl`;
when 0 the whole picture is border colour, and sprites and collisions are
off). Document it on the card (§4). In the Decision log, decide how
multi-frame work is expected to look: either "chunk it across frames behind
a blanked display", which is a good ch3/ch5 lesson, or "frames with the
display blanked aren't counted as overruns". Don't leave it to the ch3
writer.

### 3. should-fix: `m.view` accepts types whose layout isn't the RAM layout (padding, stride, host-sized ints)
**Where:** `machine/src/machine.zig:310-320` (`checkViewable`), card
`REFERENCE.md:281-285`.

**What:** ch3 is the "structs and how they lay out as bytes" chapter, and
castle records are odd-sized, little-endian, unaligned. `checkViewable`
only checks "not auto layout" / "bits % 8". It silently accepts:
- `extern struct { color: u8, ptr: u16 }`: `@sizeOf` 4, `ptr` at offset
  2 (a padding byte). Through `view` it reads `0x12` instead of `0x1234`.
- `packed struct { a: u8, b: u16 }`: `@sizeOf` 4. A single value
  reads/writes 3 bytes correctly, but `[4]P` has size 16 (stride 4, not 3).
  `u24` likewise (`[2]u24` = 8 bytes).
- `usize`/`isize`/pointer/`bool` fields: `usize` is 8 bytes headless and 4
  in wasm, so the same view has a different layout in the browser and
  headless.

**Evidence:**
- `game/src/main.zig` test: `sizeOf(extern {u8,u16}) = 4, offset ptr = 2`,
  `view ptr reads 0x12`, `packed sizeOf = 4`, `packed ptr reads 0x1234`.
  An `extern struct {flag: bool, x: u8}` view compiled.
- `stride.zig`: `[4]P3 size 16`, `P5 size 8`, `[2]u24 8`.

**Fix:** make `checkViewable` reject anything whose `@sizeOf` isn't its true
byte footprint:
- ints: `bits % 8 == 0` and `@sizeOf(T)*8 == bits`, and not
  `usize`/`isize`;
- packed: `@bitSizeOf(T) == @sizeOf(T)*8`;
- extern: fields recursively viewable, with `@offsetOf(field)` equal to the
  running sum (no padding);
- arrays: child passes.

Give a friendly compile error ("field `ptr` would start at byte 2 but the
bytes before it only fill 1: use `[2]u8` or a `packed struct(u24)`…"). Say
on the card that multi-byte fields in an `extern struct` must sit at
offsets that keep it padding-free. That's also a ready-made "Game Over?"
box for ch3.

### 4. should-fix: no metered way to put a `const` table (the program image) into RAM
**Where:** `machine/src/machine.zig:166-198` (`copy`/`fill` are RAM→RAM only),
card `REFERENCE.md:276` ("`m.ram` … can be read directly").

**What:** AUTHORING §3 says built-in tables (the shape table) "are copied
into the top of [the program image] at boot by game code". Ch3 copies the
comptime-built Training Castle to `$7800`, and probably re-copies it on
reset or new game, during `frame`. No API takes a Zig slice, so the game
has to write `@memcpy(m.ram[0x7800..][0..n], &castle)`. The card only
blesses *reading* `m.ram`, and the copy is unmetered if it happens in
`frame`.

**Fix:** add `m.load(dst: u16, bytes: []const u8)` (8 cycles/byte, the
same as `copy`; free at boot like everything else), plus a card row. Or
say explicitly on the card that writing `m.ram` directly is allowed and
must be charged with `m.work`. Log it.

### 5. should-fix: keyboard port can't deliver Return or the letters W A S D I J K L; headless can't type non-printables
**Where:** `machine/web/shell.js:21-28, 59-72`; Decision log "Keyboard port";
`machine/src/headless.zig:74-81`.

**What:** ch11 needs typed text. The 1984 string-input routine (initials
for high scores, save-position file names) takes letters, Backspace and
Return to confirm: `reference/segrax-DrCreep/src/creep.cpp:534-600`
(`if( A == 0x0D ) return;`, `if( A == 8 )`). On the Comet:
- Enter is joystick-2 fire and never reaches `$DC02`.
- 8 of the 26 letters (W A S D I J K L) are joystick keys and can't be
  typed. A player named "SAL" can't enter initials.
- Headless `--key FRAME:C` only takes one printable character, so smoke
  tests can't send 13/8/27.

**Fix:**
- Latch *every* keydown into `$DC02` (uppercase ASCII, Return = 13), and
  also apply the joystick mapping. Games ignore `$DC02` while playing, and
  ch3's room-flip key works either way.
- Update the Decision log and card §7.
- Headless: accept `--key FRAME:#13` (decimal code), or names
  (`:RETURN`, `:ESC`, `:BS`).

Optional: a 4-entry key queue. Two keys inside one 20 ms frame currently
drop the first (`comet_key` overwrites `m.input.key`), which a fast typist
will hit.

### 6. should-fix (planning): no disk device, and nothing in §3/Decision log says how ch11 gets one
**Where:** AUTHORING §3 (no device), `machine/src/wasm.zig` (no import
buffer), `headless.zig` (no `--disk`).

**What:** ch11 loads castles "exactly as the original did" through a disk
filesystem. The outline also has a browser file picker feeding a D64 into
the wasm build. All of that needs machine support: a drive device (block
reads with a cost/latency), a wasm-side buffer JS can fill
(`comet_disk_buffer()`/`comet_disk_insert(len)`), and `--disk FILE` for
headless smoke runs. §2 says the machine is identical for every chapter,
so every earlier checkpoint will be rebuilt against the new machine. That's
fine, but the API shape (and whether the Training Castle ships as a disk
image) should be decided before ch3 builds its loader. Otherwise ch3's
"castle at `$7800`" code gets rewritten in ch11.

**Fix:** add a Decision-log entry sketching the device (or a `TODO(ch11)`
like the SOUND one). Sound is already handled this way.

### 7. should-fix: Budget meter widget needs a per-subsystem breakdown the machine doesn't provide
**Where:** `machine/src/machine.zig:129-137`, `wasm.zig:238-246`; outline
"Frame budget meter: per-frame work, broken down by subsystem".

**What:** the meter is one counter. A chapter can't show "drawing vs actors
vs input" without game-side bookkeeping, which is exactly the "fake
hardware in game code" the bible forbids.

**Fix:** a tiny tagging API, e.g. `m.section(.actors)` (switches which of
N buckets receives charges; free). Export `comet_meter_sections()` and
print it in the headless summary. Or drop the breakdown from the widget
spec.

### 8. nit: card register table doesn't give the `machine.hw` names
**Where:** `REFERENCE.md:125-141, 63-65`.

**What:** the card says names exist (`machine.hw.border`) but never lists
them. A reader can't guess `sprite_sprite_hits`, `sprite_bitmap_hits`,
`sprite_behind`, `sprite_mc0`, `color_ram`, or that `spriteX/spriteY/spriteColor` are
functions taking a `u3`. Chapters will quote them.

**Fix:** add a "Zig name" column to the §2 and §4 tables. Mention
`machine.frame_budget`, `machine.video.sprite_origin_x/y` and `m.frames`
if chapters may use them.

### 9. nit: unmapped address ranges aren't stated
**Where:** `REFERENCE.md:46-61`, AUTHORING §3 memory map.

**What:** `$CFE8–$CFF7`, `$D02F–$D3FF`, `$D419–$D7FF`, `$DBE8–$DBFF`,
`$DD00–$DFFF` and `$FF40–$FFFF` aren't described. The game's comptime
memory map (with its overlap check) needs to know whether e.g. the 192
bytes at `$FF40` are usable.

**Fix:** one line: "Gaps inside the chip areas are unused; `$FF40–$FFFF`
is free/unused (pick one)."

### 10. nit: voice — "just"
**Where:** `REFERENCE.md:151` "…without disturbing what's underneath: just change their
registers."

**Fix:** "…underneath. Change their registers and they move."

### 11. nit: meta/author text in reader-visible files
**Where:**
- `REFERENCE.md:323` (`<!-- TODO(author): … music chapter -->`: visible
  in raw Markdown/GitHub).
- `machine.zig:67-69` ("arrives with the music chapter").
- `video.zig:296` (test named "classic coordinates").

**Fix:** keep the TODO in AUTHORING or phrase it in-world ("the speaker
board ships later"). "the 1984 conventions" / "the standard coordinates"
for the test name.

### 12. nit: `font.zig` header disagrees with the code and the card
**Where:** `machine/src/font.zig:5-6` says "0x60-0x7F repeat the capitals".

**What:** the code fills only `'a'..'z'` (0x61–0x7A); 0x60 and 0x7B–0x7F
are blank. The card and Decision log say 0x61–0x7A.

**Fix:** correct the comment.

### 13. nit: headless argument edge cases
**Where:** `machine/src/headless.zig:40, 61-70`.

**What:**
- `--press 5:f:4294967295` panics with integer overflow at
  `p.frame + p.dur` (reproduced).
- `--press 5:` (no keys) is accepted silently and does nothing
  (reproduced: `ran 2 frames`).

**Fix:**
- `frame -% p.frame >= p.dur` (or a saturating add).
- Reject an empty KEYS string with `BadPress`.

### 14. nit: browser shell hardening
**Where:** `machine/web/shell.js`.

**What:**
- Lines 59-79: holding two keys for the same bit (ArrowUp + W) and
  releasing one clears the bit while the other is still down. Fix: keep
  a count per bit, or recompute from `held` on keyup.
- Lines 41-45: `instantiateStreaming` fails on servers that don't send
  `application/wasm`. The message then wrongly says "Did you run zig build
  wasm?". Fix: fall back to `fetch(...).arrayBuffer()` + `instantiate`
  (python 3.13 serves the right type; I checked).
- Lines 117-129: after a panic, `resume()`/`reset()` run a trapped instance.
  The wasm shadow stack pointer isn't unwound by a trap, so each recovery
  leaks stack. Fix: re-instantiate on reset after a crash.
- Line 141: every canvas shares the first `[data-comet-status]` element. A
  chapter page with two embeds will mix messages. Fix: look for a status
  element next to the canvas (e.g. `canvas.nextElementSibling` or
  `data-comet-status="<id>"`).
- Lines 28, 71: Tab is captured with `preventDefault`, so keyboard users
  can't tab out of an embedded canvas. Fix: Esc or Tab with Shift releases
  focus, or only capture Tab while a game "wants" it.

### 15. nit: `check-all.sh` doesn't assert the wasm was written
**Where:** `site/code/check-all.sh:22-23`.

**What:** `zig build wasm` success is the only check.

**Fix:** add `[ -s "$dir/web/game.wasm" ] || exit 1`. Optionally fail if
the headless summary reports overruns for a checkpoint that's supposed to
be in budget.

---

## Consistency with AUTHORING / Decision log

Everything logged is implemented as logged: frame driver, collision timing,
picture geometry, meter colours, pointer no-mask, priority quirk, free
`charRom`, view/copy/fill wrap rules, keyboard latch, headless defaults and
file names, font, colour names, build layout, the SOUND placeholder. One
naming drift: AUTHORING says "colour RAM", the card says "Colour plane",
the code says `hw.color_ram`. Pick one term for the prose.

## Reader-facing text

- The starter README is in voice, accurate, and in-world.
- `starter/src/main.zig` matches the README (purple border, black
  background) and uses named address constants as §4 asks.
- REFERENCE.md is accurate to the code in every number I checked: memory
  sizes, the `$6C` byte diagram, the fat-pixel formula, `$EE`, the meter
  thresholds, the option table.
- Apart from the issues in findings 8–11, I have no voice objections.
