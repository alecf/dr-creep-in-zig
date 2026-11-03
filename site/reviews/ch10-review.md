# Review: Chapter 10 ("Things That Go Bump")

Reviewer scope: `site/chapters/10-things-that-go-bump.md`, its image
(`images/10-waltz.png`) and clips (`10-note.mp3`, `10-waltz.mp3`,
`10-chime.mp3`, `10-boss.mp3`), its diagrams (`page/diagrams/ch10-envelope`,
`ch10-command`, `ch10-weave`, `ch10-interrupt`, `ch10-beat`), its tools
(`site/tools/ch10/`), `site/code/ch10/` (against `ch09`), and the machine
change: `machine/src/sound.zig`, the register latch in `runFrame`,
`Machine.listen`, headless `--wav`, wasm `comet_listen`, the speaker in
`web/shell.js`, the Power-on handler in `page/template.html`, and
REFERENCE.md §1, §11 and §12. I checked them against `site/AUTHORING.md`
(the bible and the Decision log, including the writer's ch10 entries),
`docs/tutorial/outline.md`, the promises Chapters 6–9 made to this one, and
the ch05 and ch09 reviews. For 1984 I used
`reference/segrax-DrCreep/src/creep.cpp` (`sound_PlayEffect`, every call site
of it, `musicChange`, `musicBufferFeed`) and the bytes and code in
`disasm/object.s`: the IRQ handler `$0A82`/`$0B61`, timer setup `$0A0D–$0A3A`,
the interpreter `$1F29–$20A8`, its tables `$20D2–$21C7`, and
`sound_play_effect` `$21C8`. Zig 0.16.0.

Scratch work is in
`/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/review-ch10/`:
- `rebuild/`, `rb-A` … `rb-E/` (with `rb-*.wav`), `at-A5/`, `errs/`,
  `outputs.json`, `expanded.md`, `rebuild.log`, `checkall.log`: my runs of the
  writer's tools with `WORK=` set to this folder, and of `check-all.sh`.
- `py/mem.py` (a memory image from `object.s`'s byte comments, for the 1984
  tables), `py/wav.py` and `py/score.py` (WAV loading, FFT pitch, and the
  tunes' scores read out of `tunes.zig`), `py/bosses.py` (runs every
  chapter's Boss Battle on the new machine and compares it with the quoted
  output).
- `proj/ch10/`: a copy whose `src/sound.zig` ends with two review-only tests
  ("review: sizes and costs", "review: each effect, alone"). They print
  the numbers quoted below.
- `web/harness.html` + `audio.mjs` (the speaker at 44.1, 48 and 96 kHz, and
  with no Web Audio at all), `page.mjs` (the tutorial page's Power-on path
  under both autoplay policies), `shots.mjs` / `calm.mjs` and `shot-*.png` /
  `calm-*.png` (the diagrams, image and players at 1280 and 400 px, light and
  dark, and paused), `site/` (`build.py --no-wasm` output),
  `b9/` (Chapter 9's Boss frames, to compare with ch10's).

## Baseline: what I verified and found correct

- **The listings rebuild the checkpoint exactly.** `rebuild.py` gives
  **REBUILD BYTE-IDENTICAL**; stages A–E each pass `zig fmt --check`,
  `zig build` and `zig build test`, and run. `expand.py` over the template,
  with my outputs and errors, reproduces the chapter byte for byte (58
  listings, in order). The import lines told as a table instead of listings
  are in the rebuilt files.
- **The checkpoint is green.** `zig fmt --check` (ch10 and machine),
  `zig build`, `zig build test` (**78/78**, as the Decision log says) and
  `zig build wasm`.
- **The machine change didn't change any earlier checkpoint.**
  `check-all.sh` is all green (machine tests, then starter and ch01–ch10:
  build, test, wasm, 100 headless frames). Every chapter's Boss Battle,
  ch01–ch09, run on the new machine, matches its quoted output byte for byte
  (`bosses.py`), and so does ch10's. The `sound:` line only appears with
  `--wav`. The latch copies 25 bytes and charges nothing, so cycles, beam and
  overruns are untouched.
- **Adding sound didn't change gameplay.** Chapter 9's Boss frames against
  ch10's (shifted 280 frames): all 311 in-game frames have identical display
  areas. The only differences are the title screens at either end (the
  twinkle phase) and the meter. The transmitter's warble takes a roll of the
  dice, which shifts the lightning's random pattern after a teleport. 1984
  does the same (`obj_Teleport_Execute` calls `seedGet()` every even tick), so
  this is faithful.
- **Every quoted output is verbatim.** Stages A/B, C, D and the Boss match my
  runs (`142 calls`, `bucket 5: max 424, avg 46`, `3523 calls`,
  `max 244072 (1241%)`, `loudest 97%` …). The quoted error is verbatim
  (`errs.py`: exactly one error, `src/tunes.zig:22:32`), but it drops the
  `error: ` prefix the earlier chapters keep (finding 10).
- **Every number in the prose checks out.** A4 = 440 × 16.777216 = 7,382; middle
  C 4,389; C0 274; B7 66,288; `$FFFF` = 3,906.2 Hz; note 57 at `$5A72`; `$B0`
  = 34.375 ticks/s; the waltz 768 ticks = 22.34 s; the fanfare 256 ticks at
  `$E0` = 5.85 s; GAME OVER 96 ticks at `$80` = 3.84 s, inside its 210
  frames; 22.3 s × 44,100 ≈ 985 KB. The review test measures the Byte
  Budget's numbers exactly: music 1,029 bytes (table 190, waltz 482,
  fanfare 263, over 94); effects 267 bytes, 16–31 each (trapdoor 16 …
  teleport 31); step 14 cycles when silent; `music(.title)` 420;
  `effect(.key)` 250 (`effectAt` 254); a dropped effect 10; waltz steps
  max 424 / avg 46.
- **The synth plays what it's told.** I measured the WAVs:
  - **The note:** `rb-A.wav`'s A4 measures **439.991 Hz** (the register's
    439.999 Hz), peak 0.333, DC 0.0000.
  - **The waltz, note by note:** `score.py` reads the three parts out of
    `tunes.zig`, schedules them at `$B0`/unit 8, and finds every note at its
    expected time and pitch. That's 87 notes, all within 0.1 cents. Two "misses"
    are my band filter catching the lead's G#4 in the chord's band.
  - **The tunes as music:** every bar of every part adds up (waltz bars 6
    units, all three parts 768 ticks; fanfare 64 units per part; over 24).
    The harmony is sound: Am | Dm | Am | E7 …, bass on one, chord on two and
    three.
  - **The Boss WAV, second by second:** waltz to 6.04 s; chime A5→E6 at
    6.42; the C3 buzz from 15.78 to 23.80 (8.0 s, no creak inside it);
    the countdown D4 E4 F#4 G#4 A#4 C5 D5 E5, eight blips climbing; the chime;
    the Way Out's creak climbing C#3 … B4; two fanfares (43.2 and 53.5 s);
    E5 D5 C5 B4 A4 G#4 A4 for GAME OVER; the waltz again. The narration is
    right in every detail.
  - **Clipping and envelopes:** no sample clips (the peak is 0.971, with the
    fanfare's three voices). The attack and release ramps behave as the card's
    table says; the machine's tests pin them.
  - **The effects, one at a time (review test):** 87–415 ms each, peak 0.33
    (one voice); Frankenstein's two voices reach 0.60.
- **The browser path works at common rates.** On the tutorial page, the
  Power-on click makes `window.cometAudio` inside the gesture, and the
  context is `running` with chapter 10's machine queueing 882-sample buffers
  (max 0.68), under both `user-gesture-required` and
  `no-user-gesture-required`. Switching chapter stops the queue (0 buffers in
  a second), and coming back resumes it (49 a second). With no Web Audio
  (`AudioContext` deleted), the machine runs silently with no errors. At
  48 kHz it's 960-sample buffers, correct. At 96 kHz it breaks (finding 1).
- **1984 fidelity of the driver.**
  - **The command set** matches the disassembly: the
    lengths table `$20D2` is `02 01 02 02 06 05 02 02 02`, then `01`; the
    command byte is op<<2 | voice; note-on adds the voice's transpose `$2104,x`
    and sets the gate; op 4 keeps the gate (`and #$01 / ora`); a wait N
    resumes on the Nth tick, exactly as ours (`$1F2E–$1F46` vs `step`); op 8
    sets `$2107` and the timer; op ≥ 9 ends.
  - **Effects:** `$21C8` drops an effect during the intro (`$0D0F`), with sound off
    (`$0839`) or while one plays (`$2232` ≥ 0), then silences the three
    voices, volume 15, and steals the stream pointer. That's our
    `effect`/`begin` rule, and the chapter's "rules, which are 1984's".
  - **The timer** (brief item d): `$0A0F` writes TALO = `$FF`, and
    `$0A19`/`$2069`/`$2220` write TAHI = (tempo<<2)|3. The IRQ handler sends
    a non-VIC interrupt to `$0B61`, which calls the feed only on a Timer A
    underflow. Effects force tempo `$14`: 21,504 cycles = **45.82 Hz** on
    PAL. Our `$EA` gives 45.70 Hz, a deliberate match.
  - **The 13 effects** are in 1984's order (`creep.h` `SOUND_*`). Each call
    site matches 1984's trigger and pitch shape: the door climbs
    (`$10 − field_2`, field_2 counting down), the flash falls
    (`field_8 << 3`), the teleport takes a random note every even tick, the
    mummy climbs as he rises, the laser depends on the gun, and the map
    closes on release. 1984 has no sound for a bell, the map's arrow, a lock
    or an escape, and music only on the title. The "Whose notes?" box is
    right on all of it except the count (finding 6).
- **The tunes are original** (brief item e). Neither the repo nor the
  reference holds 1984's MUSICn data, and nothing in ch10 was derived from
  it. The waltz, fanfare and fall are new: an A-minor waltz built on Am/Dm/E7,
  an A-major arpeggio fanfare, and a stock minor cadence. None of them quotes
  a melody I can recognise.
- **Rendering.** `build.py --no-wasm` builds. There's no horizontal scroll at
  400 px. The five diagrams, the spectrogram and the four players render in
  light and dark. The two animated diagrams make sense paused (the beat
  rests on frame 1, the interrupt's playhead at 0 ms). Every diagram is
  arithmetically right: the beat sequence `$B0 $60 $10 $C0 $70 $20 $D0 $80`
  with ticks on 2, 3, 5, 6, 8; the forcefield's 16 bytes with `$3C` at byte
  9; the weave's stream is the composer test's.
- **Prose length.** 5,552 words by `wc.py`, at the top of the 5,000–5,500
  target.
- **Consistency.** Bucket 5 = sound (Decision log). The new regions don't
  overlap (the map's own test). Every promise from ch06 (switch, forcefield
  tick, trapdoor swing, conveyor, teleport change/send), ch07 (key, gun;
  lock declined and told) and ch09 (map blink, bell declined; escape and
  GAME OVER) is kept or explicitly declined. Ch09's "Next chapter, it gets a
  voice" is kept.

## Findings

### Must-fix

**1. The browser speaker reads past the end of its buffer when the sound
card runs above 50 kHz, and plays garbage at full scale.** `wasm.zig` has
`var sound_buf: [1000]f32` and `comet_listen` renders at most 1,000 samples.
But `shell.js` asks for `rate / 50` samples (`perFrame = rate / 50`) and
reads `n` floats from the returned pointer: `new Float32Array(c.memory.buffer,
c.comet_listen(rate, n), n)`. At 88.2 kHz, 96 kHz or 192 kHz, `n` is 1,764,
1,920 or 3,840, so the speaker queues whatever wasm memory follows the buffer.
The browser picks the context's sample rate from the device, and 96 kHz is a
common setting on audio interfaces, and on Windows and macOS. Also, the chip
then runs only 1,000/96,000 s = 10.4 ms per 20 ms slot, so envelopes and
tunes would run at half speed even if the read were safe. **Evidence:**
`audio.mjs` with `new AudioContext({sampleRate: 96000})` passed as `audio`:
in 4 s, `copyToChannel` saw a max of **3.3 × 10³⁸** and 14 non-finite
samples (44.1 and 48 kHz were clean: max 0.71). Web Audio clamps those to
±1, so the result is full-scale noise in the listener's ears. The tutorial
page makes its context with the device's default rate
(`new (window.AudioContext || …)()`), so any reader on a 96 kHz device hears
it after Power-on. **Fix:** do both of these.
- Make `sound_buf` big enough for any rate a browser allows (4,096 covers
  192 kHz), and clamp in both places: `comet_listen` already clamps; have
  `slot` use `Math.min(n, 4096)`, or export the capacity.
- Ask for a sane rate where the context is made: `new AudioContext({
  sampleRate: 48000 })` in `template.html` and `makeSpeaker`, inside a
  try that falls back to the default constructor. Older Safari rejects the
  option.

Update the wasm comment ("1,000 samples covers a 50,000-a-second speaker")
and the Decision log ("returns a pointer to ≤1,000 f32 samples").

### Should-fix

**2. 1984's note numbers are the same as ours. Only the register values
differ, because 1984 tuned its table for an NTSC clock.** The Decision log
(deviation 2) says "1984's note numbers and table differ, so its MUSICn
files need translating (ch11)", and the ch11 promise says "translate note
numbers". The table at `$2108`/`$2168` (`py/mem.py`) is 96 entries,
268 … 64,814. At the NTSC clock (1,022,727 Hz), entry *n* is within 5 cents
of equal temperament from C0. Entry 57 is 7,217 = 439.95 Hz: A4 is entry 57,
and entry 95 is B7 (3,951 Hz). So 1984 numbers its notes **exactly as we
do**, C0 = 0 to B7 = 95. On a PAL C64 the whole table plays 65–70 cents flat;
against our 1 MHz Comet it would be 39–44 cents flat, which is why no
register value matches ours (0 of 95). The writer's unchecked claim (brief
item d) is half right: the *table* differs, but the *numbers* don't.
**Fix:** reword deviation (2): "same note numbers (C0 = 0 … our table stops at
A#7 = 94; 1984's has B7 = 95); 1984's registers are tuned for a 1.0227 MHz
NTSC clock, so on a PAL machine its music sounds about two-thirds of a
semitone flat". Change the ch11 promise to "1984's note bytes play as they
are, plus the voice's transpose (effects reset it to `$18`); any note that
lands on 95 needs handling". If ch11 wants to say something interesting, it
could be that a PAL Dr. Creep was always slightly flat. Nothing in the
chapter's prose makes the wrong claim: "Its note numbers and formulas are
its own" in the box is about the effects' pitch choices, and that's true.

**3. The 1984 timer rate is right; record its formula, because ch11 will need
it, and correct three errors in `docs/music-format.md` (brief item d).**
- **The rate (verified, see Baseline):** the period is
  ((tempo<<2 | 3) << 8 | `$FF`) + 1 = 1,024 × (tempo + 1) cycles, so 1984's
  tick rate is **985,248 / (1,024 × (tempo + 1)) ≈ 962 / (tempo + 1) Hz** on
  PAL. Tempo `$14` gives 45.8 Hz. The doc's music0 example `$0C` gives 74 Hz.
  Every tempo byte below `$13` is faster than 50 ticks a second, and our
  accumulator tops out at 49.8 (`$FF`). So "translate the timer tempo byte"
  (ch11 promise) can't be one-to-one for fast passages: ch11 must either
  scale waits (e.g. double the tempo and halve every wait) or let the
  accumulator carry more than once a frame. Add this to the promise.
- **The doc misses the title tune's pause between loops.** At the end of
  the stream during the intro (`$208B`), 1984 rewinds to `$7802` (not a
  `$4000` buffer; the doc's §2 says the files are "`$4000`-resident") and
  sets `$20DD = 2`. That's a 512-tick silence, about 11 s at `$14`, before
  the tune plays again (creep.cpp line 1197 agrees). The doc says it
  "rewinds to the start of the buffer and keeps playing". The loop also
  clears `$D417`'s low nibble.
- **The doc's §7 says the effect trigger resets "voice 0/1 transpose".**
  `$220C–$2214` set **all three**, `$2104`, `$2105` and `$2106`, to `$18`.
  creep.cpp omits `$2106`.
- **The doc's §3 has op 5's `$D418` write backwards.** The code (`$2022–$202D`)
  keeps the existing *low* nibble (the volume) and ORs the parameter in.

These are doc errors, not chapter errors. Log them in the Decision log for
ch11, or fix the doc, since it's flagged "trust but verify".

**4. The output stage's "smoother" does nothing, and the output carries a
wandering DC offset.** `Chip.render` computes
`k = @min(1.0, 2π × 12,000 × dt)`, which is 1.71 at 44.1 kHz and 1.57 at
48 kHz, so `k` is clamped to 1 and `smooth += (target − smooth) × 1` just
copies the mix. It only smooths above 75 kHz. The doc comment ("A gentle
smoothing of the output, like the chip's own output stage") and the Decision
log ("then a one-pole 12 kHz smoother") describe something that doesn't
happen. Meanwhile the pulse waves carry DC: width `$600` is 37.5 % high and
`$300` is 19 %, and `$200` for the door is 12.5 %. Their DC rises and falls
with every note's envelope. In the WAVs, 20 ms means wander
**−0.136 … +0.006** in the waltz and **−0.27 … +0.05** in the Boss run (the
fanfare's reed), at note rate: a subsonic pumping you can feel on
headphones. A real C64 AC-couples its audio output, so this is also a
fidelity gap. **Fix:** in `render`, use a real one-pole coefficient,
`k = 1 − exp(−2π × fc × dt)` (0.82 at 44.1 kHz for 12 kHz). Then add a DC
blocker after it, `y = x − x₁ + 0.995·y₁` (about 35 Hz at 44.1 kHz). That's
three lines and a field. Earlier chapters are unaffected (they never touch
the SOUND chip, and only `--wav` prints a `sound:` line). But in ch10 the
`loudest N%` figures in stages A–E and the MP3s would need regenerating
(`runs.py` / `shots.py` do it). Update the Decision log sentence. If the
writer prefers to keep the chip as it is, delete the inert smoother and its
comment instead.

**5. "From the same thirteen places" is wrong; it's fourteen,
in both games.** 1984 calls `sound_PlayEffect` from 14 places (creep.cpp lines
2000, 2385, 3309, 5233, 5519, 5927, 5940, 6276, 6583, 6678, 6882, 6910, 7065,
7141). The forcefield is played both from its countdown (`$45E0`) and from
the button held (`$4647`). Ours also has 14 effect call sites (forcefield in
`press` and `count`). **Fix:** "1984 plays its thirteen effects from the same
fourteen places (the forcefield's from two)", or "from the same places".

**6. The Fraction Power-Up says "add a fraction to a byte every tick and act
on the carry".** In this chapter the carry *is* the tick; what you add on is
the frame. A reader who has just learned "each time it wraps, that's a tick"
will stumble. **Fix:** "add a fraction to a byte every frame (or whatever
the clock gives you), and act on the carry".

**7. "Our tunes have nine commands" disagrees with the `Op` enum on the same
screen, and "Two of the nine are 1984's" implies the other seven aren't.**
`Op` lists ten names, `note_on` … `end` (numbers 0–9), and `lengths` has nine
entries because `end` is handled by `else`. **Fix:** "Our tunes have ten
commands, numbered 0 to 9, each with the number it had in 1984. Each starts
with one byte …". Later: "Two of them do nothing here. `filter` is for … We
keep both so every command keeps its 1984 number." Then the following sentence
("We keep both numbers so every command has the number it had in 1984") can
go.

### Nits

**8. "Sixteenths of full" for the sustain level is fifteenths.** REFERENCE
§11 says "The sustain level is sixteenths of full: 15 is full, 0 is silence",
and the envelope diagram's caption says "Sustain is a level, in sixteenths of
full." If 15 is full, each step is a fifteenth, and that's what the code does
(`sustain / 15`, like the real chip's ×17/255). **Fix:** "0 (silence) to 15
(full)" in both places.

**9. Clicks.** At every game start, `stop()` writes `control = 0`, and
`voiceSample` returns 0 for a voice with no waveform. The waltz, held through
the castle copy's loading pause, drops from −0.176 to 0 in one sample
(`rb-D`/`rb-E` at 6.040 s): an audible tick. A forgiving chip could fade a
voice whose waveform goes to none over a few ms (keep its last output and
decay it), or `stop()` could clear only the gates and let the release finish.
Optional if finding 4's filter goes in, since it softens the step.

**10. The quoted compile error dropped its `error: ` prefix.** Chapters 7–9
show `error: …` (the ch09 template writes `error: {{X shadow}}`). The ch10
template's line 138 is `{{X b7}}` alone. **Fix:** `error: {{X b7}}`.

**11. "even when `compose` is called from code that runs on the Comet, like a
test".** Tests don't run on the Comet; they run natively. **Fix:** "even when
`compose` is called from ordinary code that runs later, like a test".

**12. "The effects are a region of their own, in RAM rather than in the
program image."** On the Comet the program image is RAM too (the built-in
tables are copied there at boot), so this reads as a contradiction. **Fix:**
"in free memory rather than among the built-in tables at the top of the
program image, because the game writes into them".

**13. One thing, three names.** `sound_at` is introduced as "the
interpreter's own program counter", then the effects section says "whoever
owns its stream pointer is playing" without saying that's the same thing.
**Fix:** "whoever owns `sound_at`, its stream pointer, is playing", or use
one term throughout.

**14. Common mistakes: "The waltz plays one long note per voice. The
composer's `gap` must be at least 1."** With `gap = 0`, each new note still
changes the frequency; what you lose is the gate going off between notes. So
the notes run together, and repeated notes (the fanfare's `E2:4 E2:4`, the
bass's `E2 | E2`) merge into one. **Fix:** "**Notes run together, and two of
the same note sound as one.** …".

**15. Diagrams.**
- `ch10-command` calls `$3C` "the yellow byte", but it's olive-green in both
  themes. Say "the highlighted byte".
- At 400 px the bit row's labels "bits 1–0: voice 1" and "4 × 4 + 1" run
  together.
- `ch10-interrupt` is unreadable at 400 px: the row labels and "a loading
  pause" render at about 5 px. A taller viewBox on narrow screens, or larger
  type, would fix it.

**16. The spectrogram starts at frame 1, but the waltz starts at frame 9
(0.18 s).** The bar ticks sit 8 frames early, and the last ~0.16 s of bar 4
is cut off at the right edge. **Fix:** in `shots.py`, set `first` to the
first frame with sound (9).

**17. Close ch08's promises in the Decision log.** Ch08 promised "sounds
(ankh, tomb opening, Frank's steps, deaths)". The tomb opening is the
mummy's rise, and deaths are the flash; but the ankh and Frank's steps get
none. 1984 has none either. That's fine, but deviation (5) should list them
beside bell, map blink, lock and escape.

**18. The prologue's "3 voices" row says "music and effects together"**, but
this chapter's design never plays them together (one interpreter, music
between rooms, effects in rooms). Either reword the prologue ("…three notes
at once, for music and sound effects alike"), or add a sentence here: "Three
voices, but one player: music and effects take turns."

**19. Aliasing.** The sawtooth and pulse are drawn naively, so their upper
harmonics fold back under 44.1 kHz. Aliased energy below 16 kHz is −21 dB for
a sawtooth A4, and −14 dB for a sawtooth C7 (−16 dB for a pulse C7, the key's
last note). It's audible as grit on the high effects (key, laser at C6, the
chime). It's arguably part of the 8-bit charm. A PolyBLEP correction on the
saw and pulse edges is about ten lines if the writer wants it clean.

**20. `shell.js` robustness.**
- If a stale `game.wasm` without `comet_listen` is served
  (`build.py --no-wasm` over an old `web/`), `c.comet_listen(...)` throws
  inside the frame loop and the page says "the game panicked". Guard it:
  `const speaker = c.comet_listen ? makeSpeaker(audio) : null;` after
  instantiating.
- `wake()` resumes only `"suspended"`. iOS Safari also uses `"interrupted"`.
  `ctx.state !== "running"` would cover both.
- The speaker paces itself by the frame loop's clock but plays by the audio
  clock. Over minutes, drift between the two makes it either drop a slot
  (MAX_AHEAD) or restart the queue (LEAD), a tiny gap each time. That's
  acceptable; maybe worth a comment.

**21. Small wording.**
- "the loudest it gets a third of full" reads twice → "at its loudest, a
  third of full volume".
- REFERENCE §11 "Middle A, 440 Hz" → the chapter's "the A above middle C".
- "Its high six bits are the command's number" is right, but the diagram
  calls them "bits 7–2". Either is fine; pick one.

## Writer response

All must-fix and should-fix findings are fixed, and every nit except #19
(aliasing). Details are in the Decision log's "ch10 review fixes" entry.
- **#1:** the wasm buffer is 4,096 samples, `shell.js` clamps each slot
  to it, and both `makeAudioContext` and the Power-on handler ask for
  48 kHz, falling back to the device rate. I re-ran your `audio.mjs`
  harness with the new wasm and shell. At 44.1, 48 and 96 kHz the slots
  are 882, 960 and 1,920 samples. The max is 0.717, with no non-finite
  samples. With no Web Audio, the game runs silent with no errors.
- **#2, #3:** the deviation and the ch11 promise are corrected, and the
  tempo formula and its above-50 Hz limit are recorded for ch11. The
  three errors in `docs/music-format.md` are fixed. I checked them in
  the disassembly: `$2022–$202D`, `$208B–$209D` and `$220C–$2214`.
- **#4:** the output stage now has a real one-pole low-pass and a DC
  blocker, and a machine test checks the DC. The WAVs, MP3s, quoted
  `loudest` lines and the spectrogram are regenerated. `check-all.sh` is
  green.
- **#9:** fixed in the chip. A voice whose waveform goes to none now
  fades over about 4 ms instead of stepping to zero.
- **#20:** all three points done: the stale-wasm guard, `!== "running"`
  for waking, and the drift comment.
- **#21:** I kept "bits 7–2" in both the prose and the diagram.
- **#19 (declined):** the naive saw and pulse stay. The grit on the
  highest effects is part of the 8-bit sound readers expect, and the
  synth stays short enough to read. PolyBLEP would make a good Bonus
  Stage for a later edition.
