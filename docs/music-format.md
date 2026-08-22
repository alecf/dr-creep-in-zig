# Dr. Creep — Music & Sound Format

> **This is generated reverse-engineering analysis**, produced by cross-referencing three
> independent sources and validating the resulting model against every shipped music file:
>
> - `reference/segrax-DrCreep/src/creep.cpp` (functions `musicPtrsSet`, `musicBufferFeed`,
>   `musicChange`, `sound_PlayEffect`) and `reference/segrax-DrCreep/src/sound/sound.cpp` —
>   Robert Crossfield's C++ reimplementation, which keeps the original C64 addresses as
>   `mMemory[0x1234]` and is annotated with the original 6502 routine addresses in comments
>   (e.g. `// 1F29 : Play Music Buffer`).
> - `disasm/object.s` — the traced disassembly of `object.prg`, specifically `sub_1F29`
>   (music feed), `sub_20A9` (voice-pointer setup), `sub_21C8` (sound-effect trigger), and
>   the IRQ handler at `loc_0B68`.
> - `extracted/music0.prg` … `music8.prg` — the actual $4000-resident data files, decoded
>   byte-for-byte with a throwaway Python decoder built from the opcode table below. **All
>   nine files parse cleanly from the first command to the very last byte of the file**,
>   which is strong evidence the opcode table here is correct, not merely plausible.
>
> Treat addresses as C64 memory addresses (`object.prg` loads at $0800; music data loads at
> $4000). Where something is inferred rather than directly observed, it's flagged as such.

## 1. Architecture in one paragraph

There is no 6502 "music player" hidden inside the `music*.prg` files — they are **pure
data**. The player is a byte-code interpreter permanently resident in `object.prg`
(`sub_1F29` / `sub_20A9`, C64 addresses $1F29–$20A9). It is pumped once per raster IRQ,
consumes one or more variable-length commands from a data stream, and translates them
directly into SID register writes. Sound effects reuse the *exact same* interpreter by
temporarily redirecting its stream pointer at a short effect-specific command sequence
elsewhere in `object.prg`, which is why music and effects can never play simultaneously —
triggering an effect silences and hijacks whatever the music was doing.

## 2. File layout ($4000, `music0.prg` … `music8.prg`)

Every `MUSICn` file uses a small 4-byte container around the raw command stream:

| Offset | Size | Meaning |
|---|---|---|
| `+0` | 2 bytes, LE | PRG load address — always `$4000` |
| `+2` | 2 bytes, LE | Length of everything after the load address (`filesize − 2`) |
| `+4` | rest | The opcode/command stream (see §4) |

Verified against every file (`filesize − 2` always equals the header word exactly):

| File | Size (bytes) | Header length word | Commands decoded |
|---|---|---|---|
| music0.prg | 3902 | `0x0F3C` (3900) | 2318 |
| music1.prg | 7406 | `0x1CEC` (7404) | 4140 |
| music2.prg | 4890 | `0x1318` (4888) | 2914 |
| music3.prg | 7710 | `0x1E1C` (7708) | 4406 |
| music4.prg | 5428 | `0x1532` (5426) | 3235 |
| music5.prg | 6571 | `0x19A9` (6569) | 3760 |
| music6.prg | 2579 | `0x0A11` (2577) | 1483 |
| music7.prg | 4915 | `0x1331` (4913) | 2937 |
| music8.prg | 5678 | `0x162C` (5676) | 3391 |

`cCreep::musicChange()` loads the file and sets `mMusicBuffer = MusicPtr + 4` — i.e. it
skips the load address *and* the length word, and starts the interpreter directly on the
command stream. The length word itself is never read back by the player; it looks like a
generic container convention (possibly shared with other resource types) rather than
something the interpreter needs.

Track selection is a simple round-robin: `mMusicCurrent` is the ASCII string `"MUSIC0"`;
`musicChange()` increments its last character each time it's called and tries to load that
file, wrapping back to `MUSIC0` the moment a load fails (i.e. past `MUSIC8`). Music only
plays on the title/menu screen (`sub_1F29` has exactly one caller in the whole binary,
inside the IRQ handler, gated behind the menu loop) — there is no in-game background music,
only one-shot sound effects (§7).

## 3. The command stream — one shared byte-code for all 9 tracks

Every command starts with a single **command byte**:

```
 7 6 5 4 3 2 1 0
+-------------+-+-+
|   opcode    | V |
+-------------+-+-+
```

- **bits 7–2** (`byte >> 2`): opcode, 0–8 used by the shipped tracks, ≥9 is a terminator.
- **bits 1–0**: a 2-bit field, used as a **voice index (0–2)** by the note/instrument/
  transpose opcodes, and unused (always `00`) by the global opcodes.

The interpreter looks up how many bytes the whole command occupies (command byte included)
in a fixed table at `$20D2`–`$20DA`, copies that many bytes into a small work buffer at
`$20CB`, advances the stream pointer, and dispatches on the opcode. Confirmed directly from
the static data in `disasm/object.s` right after `sub_20A9`:

```
$20D2: 02 01 02 02 06 05 02 02 02      ; length (incl. opcode byte) for opcodes 0..8
$20DB: 01                              ; opcode 9 ("end") is 1 byte, no params
```

### Opcode table

| Op | Len | Name (inferred) | Effect |
|---|---|---|---|
| 0 | 2 | **Note On** | param = note number. `index = note + transpose[voice]` (transpose set by op 6). Reads two 96-entry tables at $2108 (freq lo) / $2168 (freq hi) indexed by `index`, writes `SID voice+0/+1` (frequency), then sets the gate bit (`|= 1`) in the voice's control register, preserving whatever waveform op 4 configured. |
| 1 | 1 | **Note Off** | Clears the gate bit (`&= 0xFE`) on the given voice's control register — starts SID release phase. No parameters. |
| 2 | 2 | **Wait (primary counter)** | param → `$20DC`. Frame-tick counter; the interpreter self-throttles: each pump decrements `$20DC` and only fetches a new command once it (and the secondary counter) hit zero. This is the per-step "note length" delay. |
| 3 | 2 | **Wait (secondary counter)** | param → `$20DD`. An outer counter consumed once per exhaustion of `$20DC` — a coarser, slower delay. **Never used by any of the 9 shipped tracks** (0 occurrences). |
| 4 | 6 | **Set instrument (waveform/ADSR)** | 5 params for the addressed voice: pulse-width lo, pulse-width hi, control/waveform byte (gate bit preserved from current state), attack/decay, sustain/release. Writes SID regs `+2..+6`. This is the "patch" command — sets the timbre once (or occasionally re-patches) before notes play. |
| 5 | 5 | **Set filter** | 4 params: filter cutoff lo (`$D415`), cutoff hi (`$D416`), resonance+routing (`$D417`, ORs in a bit for *the addressed voice* so it also carries the previous frame's routing bits), filter mode/master-volume low nibble (`$D418`, low 4 bits combined with existing high nibble). **Never used by any of the 9 shipped tracks** (0 occurrences) — the filter is left off for all music. |
| 6 | 2 | **Set transpose** | param → `$2104 + voice`. Per-voice base-note offset added to every subsequent Note-On's note number for that voice. |
| 7 | 2 | **Set volume** | param → low nibble of `$D418`/master volume, high nibble (filter routing bits) preserved. Global, not per-voice. |
| 8 | 2 | **Set tempo** | param → `$2107`, and `CIA1 Timer A high byte = (param << 2) \| 3` (§5). Global playback speed for the whole stream, changeable mid-song. |
| ≥9 | 1 | **End of stream** | Always encoded as byte `$24` (opcode 9, field 0) in every shipped file, and always the *literal last byte* of the file. If not the title/intro loop, the player stops (`mMusicBuffer = 0`); the intro loop instead rewinds to the start of the buffer and keeps playing. |

Opcode-usage histogram across all 9 files (2318+4140+2914+4406+3235+3760+1483+2937+3391 =
28,584 total commands):

| Op | Count | |
|---|---|---|
| 2 (wait) | 10043 | most common — one per note-length step |
| 0 (note on) | 8800 | |
| 1 (note off) | 8800 | **exactly matches note-on count — every note is properly closed** |
| 7 (volume) | 581 | mostly used in short crescendo/arpeggio intros (see §4 example) |
| 4 (instrument) | 171 | ~19/track — voices get re-patched occasionally, not just once |
| 8 (tempo) | 99 | ~11/track — tempo changes throughout a song |
| 6 (transpose) | 81 | ~9/track |
| 3, 5 | 0 | defined by the interpreter, unused by any shipped track |
| 9 | 9 | exactly one per file — the terminator |

### Worked example (`music0.prg`, bytes at file offset `0x0E`–`0x25`, i.e. right after the 4-byte header)

```
12 00 00 20 0a 60   op=4 (instrument) voice=2: PWLO=00 PWHI=00 CTRL=20(sawtooth) AD=0a SR=60
08 01               op=2 (wait) param=1
19 18               op=6 (transpose) voice=1: transpose = 0x18
08 01               op=2 (wait) param=1
1a 18               op=6 (transpose) voice=2: transpose = 0x18
08 01               op=2 (wait) param=1
10 00 00 20 0a 60   op=4 (instrument) voice=0: PWLO=00 PWHI=00 CTRL=20(sawtooth) AD=0a SR=60
```

and later (offset `0x6a`), the first actual melody notes on voice 1:

```
20 0c               op=8 (tempo) param=0x0c -> TAHI = (0x0c<<2)|3 = 0x33
08 0a               op=2 (wait) param=0x0a
01 24               op=0 (note on) voice=1, note=0x24
08 0b               op=2 (wait) param=0x0b
05                  op=1 (note off) voice=1
01 23               op=0 (note on) voice=1, note=0x23
08 0d               op=2 (wait) param=0x0d
05                  op=1 (note off) voice=1
```

## 4. Notes, frequency table, and voices

There is no independent "octave+note" encoding — a note is a single byte that is added to
the current voice's transpose value (op 6) and used directly as an index into two 96-entry
parallel tables baked into `object.prg`:

```
$2108-$2167  96 bytes  frequency-lo, indexed by (note + transpose[voice])
$2168-$21C7  96 bytes  frequency-hi, indexed by (note + transpose[voice])
```

These are static SID frequency tables (exponential note→frequency mapping, one entry per
semitone across ~8 octaves), visible directly in `disasm/object.s` as data immediately
after `sub_20A9`:

```
; freq-lo table starts $2108
84 0f 0c 0c 0c 14 0c 1c 2d 3e 51 66 7b 91 a9 c3 dd fa 18 38 5a 7d a3 cc f6 ...
; freq-hi table (monotonically increasing bytes, low values -> high values across octaves)
01 01 01 01 01 01 01 01 01 01 02 02 02 02 02 02 02 03 03 03 03 04 04 04 04 ...
```

Only **3 voices** are addressable by the command byte's 2-bit field (values 0–2 map to SID
voices; SID base addresses $D400/$D407/$D40E are present verbatim as a small pointer table
at $20DF–$20E4). A 4th slot (field value 3) exists in the pointer tables but maps to a RAM
scratch area rather than a real SID voice — never exercised by the shipped tracks (their
command-byte low bits are always 0–2 in practice, matching 3 real voices).

Because SID registers are write-only, the engine keeps a **RAM shadow copy** of each
voice's 7 registers so it can read back and modify bits (e.g. preserving the gate bit when
changing waveform in op 4). These mirrors are also visible as a static pointer table,
spaced exactly 7 bytes apart matching the SID register block size:

| Voice | SID base | RAM mirror base |
|---|---|---|
| 0 | $D400 | $20EB |
| 1 | $D407 | $20F2 |
| 2 | $D40E | $20F9 |

## 5. Tempo

Tempo is not a fixed frame divisor — it's driven by **CIA #1 Timer A**, reprogrammed live
by opcode 8. Confirmed from both the IRQ-setup code and `sound_PlayEffect`:

```
CIA1_TALO ($DC04) = $FF                          ; fixed, set once at IRQ init (disasm 0A0F)
CIA1_TAHI ($DC05) = (speed_byte << 2) | 3         ; disasm 0A19, 2069, and creep.cpp mTimerSet()
```

So the full 16-bit timer reload value is `((speed << 2) | 3) * 256 + 0xFF`. For the default
tempo byte `0x14` (used at both `musicChange()` init and `sound_PlayEffect()` init):

```
TAHI = (0x14 << 2) | 3 = 0x53
period = 0x53FF + 1 = 21504 cycles
IRQ rate ≈ 985248 Hz (PAL) / 21504 ≈ 45.8 Hz
```

Every raster IRQ, `loc_0B68` checks `CIA1_ICR & 1` (Timer A underflow flag) and only then
calls `sub_1F29` — so the *music* stream advances at the CIA-driven rate above, not at the
50 Hz PAL frame rate, and mid-song opcode-8 commands can speed up or slow down playback
(99 tempo changes observed across the 9 tracks, ~11 per track — these are genuine tempo/
groove changes within a piece, not just a single fixed BPM).

## 6. SID register writes

Only a handful of writes use the labeled `SID_*` symbols directly in `disasm/object.s`
(`SID_V1CTRL/V2CTRL/V3CTRL`, `SID_VOLUME`, `SID_V1FREQLO`) — those are the sound-effect
reset path (§7) and the shutdown path. The vast majority of register writes happen through
computed offsets (`sidWrite(mVoiceNum*7 + reg, value)` in the C++ model, `sta ($46),y` /
indexed addressing in the disassembly) because the same command handler serves whichever of
the 3 voices the command byte selects — so a symbol table lookup alone undercounts actual
SID traffic; the opcode table in §3 is the complete picture.

| SID register | Address | Written by |
|---|---|---|
| Voice freq lo/hi | `$D400/1`, `$D407/8`, `$D40E/F` | op 0 (note on) |
| Voice control (gate+waveform) | `$D404`, `$D40B`, `$D412` | op 0 (gate on), op 1 (gate off), op 4 (waveform) |
| Voice PW lo/hi | `$D402/3`, `$D409/A`, `$D410/1` | op 4 |
| Voice AD / SR | `$D405/6`, `$D40C/D`, `$D413/4` | op 4 |
| Filter cutoff lo/hi | `$D415/6` | op 5 (unused by shipped tracks) |
| Filter resonance/routing | `$D417` | op 5 (unused), also zeroed on effect start/stop |
| Filter mode / master volume | `$D418` | op 5 (unused for filter bits), op 7 (volume) |

## 7. How sound effects interleave with music

Sound effects (`sub_21C8`, called from 14 different gameplay object handlers — collision,
death, doors, etc.) **reuse the exact same command interpreter and the exact same stream
pointer** (`mMusicBuffer`) that music uses. There is no separate SFX voice or mixing — an
effect *takes over* playback entirely:

```cpp
// creep.cpp, sound_PlayEffect (disasm sub_21C8)
if (mIntro) return;                    // never during the title screen
if (mDisableSoundEffects == 1) return;
if (mPlayingSound >= 0) return;        // an effect is already playing -> drop this one

mPlayingSound = pA;                    // effect id
sidWrite(0x04,0); sidWrite(0x0B,0); sidWrite(0x12,0); sidWrite(0x17,0);   // silence all 3 voices
mMusicBuffer = &mMemory[ readLEWord(&mMemory[0x7572 + pA*2]) ];           // steal the stream ptr
sidWrite(0x18, 0x0F);                  // full master volume
mMemory[0x20DC] = mMemory[0x20DD] = 0; // clear wait counters
mMemory[0x2104] = mMemory[0x2105] = 0x18; // reset voice 0/1 transpose
```

and reprograms CIA Timer A to a fixed effect tempo (speed byte `0x14`, same formula as
§5) directly rather than through opcode 8, so an effect always plays at the same fixed rate
regardless of whatever tempo the interrupted music was using. Because `mMusicBuffer` is
simply overwritten (not saved/restored), **triggering any sound effect discards whatever
position the music was at** — `musicBufferFeed()`'s end-of-stream handling only distinguishes
"intro loop" (rewind and keep looping) from "not intro" (stop, `mMusicBuffer = 0`); nothing
restores a pre-empted music position. In practice this is moot in-game, since music only
ever plays on the title screen and effects only trigger during gameplay — they are
temporally exclusive by construction, not by an explicit mute/resume mechanism.

The effect-id → stream pointer table is read via `readLEWord(&mMemory[0x7572 + id*2])`
(confirmed in both `creep.cpp` and the matching indexed-load code in `sub_21C8` at
`disasm/object.s:5058-5062`). **Caveat:** the static disassembly labels `$7572` as the entry
point of an unrelated screen-clearing subroutine (`sub_7572`, called once from `$091E`
during title-screen setup) — its opcode bytes don't decode to a sane pointer table if read
literally from the shipped binary image. Since `sub_21C8` is only ever called from deep
gameplay object handlers (long after the title screen/menu code has run), the likeliest
explanation is that this memory region is repurposed at runtime — overwritten with the real
effect-pointer table once the title-screen-only code that lived there is no longer needed —
rather than the table living at a fixed static offset. This wasn't independently confirmed
against a runtime memory trace and is flagged here as an open question for follow-up rather
than asserted as fact.

## 8. Open questions / suggested follow-ups

- The exact runtime contents (and true address) of the sound-effect pointer table (§7) —
  would benefit from a memory trace of a live emulator session rather than static analysis.
- Whether opcodes 3 and 5 (secondary wait counter, filter) are exercised by any sound
  *effect* stream even though no *music* track uses them — the SFX streams themselves
  weren't individually decoded in this pass.
- The precise semantics of the 4th (unused) voice-pointer slot at $20EB pointing into RAM
  rather than a SID register.
