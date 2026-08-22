# Dr. Creep — C64 Memory Map

> **This is generated analysis**, produced by static reading of the traced disassembly and cross-referencing
> against Robert Crossfield's C++ reverse-engineering of this exact binary. It is not a byte-perfect memory
> map — the zero-page "general purpose pointer" region ($30-$4F) in particular is reused for different things
> by different subroutines, and only the addresses that give clear, repeated, unambiguous evidence are
> called out by name. Everything below cites the evidence it's based on so it can be checked or corrected.
>
> **Evidence sources**
> - `disasm/object.s` — traced disassembly of `object.prg` ($0800-$78C6), symbols for VIC/CIA/SID hardware
>   registers already resolved by the disassembler.
> - `disasm/object.json` — routine/caller index (used to sanity-check entry points, no extra address metadata).
> - `reference/segrax-DrCreep/src/creep.cpp` / `creep.h` — Crossfield's C++ port of *this binary*. It keeps
>   the original C64 addresses as literal `mMemory[0x....]` accesses, and in several places its local variable
>   names literally encode the zero-page address they came from (`word_30`, `word_3C`, `byte_31`, ...). Where a
>   variable has a normal name (`mObjectPtr`, `mRoomPtr`, `mVoice`, ...) its address had to be inferred from
>   surrounding disassembly evidence — those cases are marked "inferred" below.
> - `extracted/*.prg` — the 2-byte PRG load-address header of each extracted file, read directly with `xxd`,
>   confirms the load addresses for the engine, music, castle data and save files.
>
> Where confidence is lower than "confirmed by a direct source read", the table says so explicitly.

## 1. File load addresses (confirmed via PRG headers)

| File(s) | Load address | Contents |
|---|---|---|
| `object.prg` | **$0800** | 28,871-byte game engine (code + tables), spans to $78C6 |
| `music0.prg` … `music8.prg` | **$4000** | Music data (per-tune SID player data blob) |
| `z*.prg` (`zfreedonia`, `ztutorial`, …) | **$7800** | Castle/level data files, loaded over the live castle-state buffer |
| `y*.prg` (`yfreedonia`, `ytutorial`, …) | **$B800** | Per-castle save / "position" file |
| `creepload.prg` | (loader stub, not analyzed here) | Multi-stage loader |
| `_x81pic_a_tit.prg` | (title picture, not analyzed here) | Title screen bitmap |

Confirmed by reading the first 2 bytes little-endian off each file, e.g.:
```
$ xxd -l2 -e extracted/yfreedonia.prg   ->  b800
$ xxd -l2 -e extracted/ztutorial.prg    ->  7800
$ xxd -l2 -e extracted/music0.prg       ->  4000
$ xxd -l2 -e extracted/object.prg       ->  0800
```

## 2. Zero page ($0000-$00FF)

### 2.1 $00/$01 — 6510 processor port (CPU I/O port, DDR + bank config)

Set once, early, by `sub_095F` (called from the game's own IRQ/NMI installer — see §4):

```
0970: a9 07        lda #$07          ; DDR: bits 0-2 output
0972: 85 00        sta $00
0974: a9 05        lda #$05          ; $05 = %00000101 -> LORAM=1,HIRAM=0,CHAREN=1
0976: 85 01        sta $01
```
`$01 = $05` banks the BASIC and KERNAL ROMs out (both become RAM), while keeping the I/O area mapped in
at $D000-$DFFF. This is *why* the game can install its own vectors directly into RAM at $FFFA-$FFFF
(see §4) — those addresses are normally KERNAL ROM.

| Addr | Name | Purpose |
|---|---|---|
| $00 | CPU DDR | Data direction register for the 6510 I/O port, set to $07 |
| $01 | CPU bank config | Set to $05: RAM under BASIC+KERNAL, I/O visible, ROMs banked out |

### 2.2 $10-$2D — VIC-II shadow registers, refreshed every IRQ

This whole block is written to hardware once per frame by the raster IRQ handler at $0A82 (see §4). Confirmed
directly by reading that routine: it does `lda $10 / sta $D000`, `lda $11 / sta $D002`, ... in sequence for all
8 sprites, then continues into general VIC control and sprite-pointer shadows.

| Addr (zp) | Written to | Purpose |
|---|---|---|
| $10,$12,$14,$16,$18,$1A,$1C,$1E | $D000,$D002,...,$D00E | Sprite 0-7 **X** position shadow |
| $11,$13,$15,$17,$19,$1B,$1D,$1F | $D001,$D003,...,$D00F | Sprite 0-7 **Y** position shadow |
| $20 | $D010 (VIC_SPMSBX) | Sprite X MSB (9th bit) shadow |
| $21 | $D015 (VIC_SPENA) | Sprite enable mask shadow |
| $22 | $D018 (VIC_MEMPTR) | Screen/bitmap pointer shadow — set once to **$38** (see §5) |
| $23 | $D020 (VIC_BORDER) | Border color shadow |
| $25 | $D016 (VIC_CTRL2) | X-scroll / multicolor-mode control shadow |
| $26-$2D | $CFF8-$CFFF | 8 sprite-pointer bytes, shadowed into the live sprite pointer table (§5) |

(There is no confirmed $24 shadow register — background color 0 is instead re-applied every IRQ from a
one-byte table at $0B73, likely so it can flash/cycle per raster split; see disasm around $0A98 and $0B12.)

### 2.3 $30-$43 — general-purpose pointer workspace

This cluster of zero-page pairs is used as scratch indirect pointers ( `lda ($xx),y` / `sta ($xx),y` )
by dozens of unrelated subroutines throughout the whole 28KB engine — a standard 6502 space-saving trick.
Two of them are pinned down by name, because `creep.h` declares the corresponding C++ locals with names
that literally encode the original zero-page address:

```c++
// creep.h, class cCreep private members:
word  word_30, word_32, word_3C, mObjectPtr, word_40, mRoomPtr;
```

`word_30` = $30/$31, `word_32` = $32/$33, `word_3C` = $3C/$3D, `word_40` = $40/$41 — directly named.
`mObjectPtr` and `mRoomPtr` sit between them but aren't literally numbered; their addresses are **inferred**
from disassembly:

- **$3E/$3F = `mObjectPtr` (inferred, high confidence).** It is by far the most-referenced zero-page pointer
  in the whole disassembly (216 direct references). The public entry point `obj_stringPrint` (vector table
  slot at $0836 → $1AE6) begins by saving `$3E/$3F` off to scratch ($6067/$6068) and then immediately reads
  the string to print through `($3E),y` — exactly the "current object/data pointer" role `mObjectPtr` plays
  throughout `creep.cpp` (e.g. `mObjectPtr = 0x1AB3; obj_stringPrint();`, `mObjectPtr = readLEWord(&mMemory[0x785F]); roomPrepare();`).
- **$42/$43 = `mRoomPtr` (inferred, moderate confidence).** `creep.cpp`'s `roomPtrSet()` computes
  `mRoomPtr = 0x7900 + roomNumber*8` (see §6, room pointer table). $42/$43 is the next most heavily used
  indirect pointer (26/10 references) after the two confirmed-by-name pairs and is used the same way
  (`($42),y` reads of per-room data starting near $0BC1, inside the room-setup code path).

| Addr (zp) | Name | Confidence | Purpose |
|---|---|---|---|
| $30/$31 | `word_30` | confirmed (named in creep.h) | generic scratch pointer; used e.g. as the **destination** pointer in the startup relocation copy $7572←$77F7 (`sub_0800`→`loc_08C2`, around $0934) |
| $32/$33 | `word_32` | confirmed (named in creep.h) | generic scratch pointer; **source** pointer in that same copy loop |
| $3C/$3D | `word_3C` | confirmed (named in creep.h) | generic scratch pointer (role varies by caller) |
| $3E/$3F | `mObjectPtr` | inferred (usage pattern) | primary "current object / current string / current data" pointer, used almost everywhere (216 refs) |
| $40/$41 | `word_40` | confirmed (named in creep.h) | generic scratch pointer; also seen driving `roomPtrSet(mMemory[word_40+3])` |
| $42/$43 | `mRoomPtr` | inferred (usage pattern) | pointer to the 8-byte room record for the room currently being drawn/processed |

### 2.4 Remaining zero page ($02-$0F, $24, $2E-$2F, $44-$FF)

Not enumerated individually — evidence for a single, stable meaning per address is thin (most bytes in
this range are touched by only 1-3 instructions total in the whole 28KB image, i.e. they're routine-local
scratch, not persistent "globals"). Two exceptions worth flagging:

- **$FB** appears 3 times, always inside indirect-indexed loops similar in shape to the $3E/$42 pattern —
  likely another scratch pointer pair ($FB/$FC), but too little evidence to name it.
- Small bitmask tables of `$80,$40,$20,$10,$08,$04,$02,$01` are baked into the engine's *data* area right
  after the jmp-vector table ($0839 and again near $0881), not into zero page — these are per-sprite bit
  tests (e.g. sprite-enable / collision masks), not zero-page variables.

## 3. Standard C64 hardware registers referenced

These are already resolved to symbolic names by the disassembler (confirmed present in `disasm/object.s`);
listed here for completeness since the engine talks to them constantly.

| Range | Chip | Registers actually referenced in object.s |
|---|---|---|
| $D000-$D02E | VIC-II | `VIC_SP0X/Y`…, `VIC_SPMSBX`, `VIC_SPENA`, `VIC_MEMPTR`, `VIC_CTRL1/2`, `VIC_RASTER`, `VIC_BORDER`, `VIC_BG0`, `VIC_IRQFLAG`, `VIC_IRQMASK`, `VIC_SPMC0/1`, `VIC_SP0COL`, `VIC_SPBGCL`, `VIC_SPEXPX/Y`, `VIC_SPPRIO`, `VIC_SPSPCL`, `VIC_SPMC` |
| $D400-$D41C | SID | `SID_V1CTRL`, `SID_V1FREQLO`, `SID_V2CTRL`, `SID_V3CTRL`, `SID_VOLUME` (also written directly by offset from music player code, e.g. `mMemory[0xD404+X]` in `creep.cpp`) |
| $DC00-$DC0F | CIA1 | `CIA1_PRA`, `CIA1_PRB`, `CIA1_DDRA`, `CIA1_DDRB`, `CIA1_TALO/HI`, `CIA1_CRA`, `CIA1_ICR` — keyboard/joystick port 1 read + Timer A (drives music playback, see §4) |
| $DD00-$DD0F | CIA2 | `CIA2_PRA` (VIC bank select — set to $00, selecting **bank 3 = $C000-$FFFF**, confirmed at $09D2), `CIA2_ICR` |
| $D800-$DBFF | Color RAM | Fixed 1K nibble color RAM; passed directly as `&mMemory[0xD800]` to both the bitmap and text-mode screen draw calls in `creep.cpp` |
| $FFFA-$FFFF | 6510 vectors | NMI/RESET/IRQ vectors — in RAM here because ROMs are banked out (§2.1); overwritten at startup (§4) |

## 4. IRQ / NMI (installed at boot, $0800-region)

Installed by `sub_095F` (called from several places, including the main draw/animate loop):

```
097A: 8d fe ff   sta $FFFE   ; low byte  = $82   -> IRQ vector  = $0A82
097F: 8d ff ff   sta $FFFF   ; high byte = $0A
0984: 8d fa ff   sta $FFFA   ; low byte  = $7B   -> NMI vector  = $0A7B
```

| Addr | Name | Purpose |
|---|---|---|
| $0A7B | NMI handler | Effectively a stub (`jmp` back into the tail of the IRQ handler's exit path) |
| $0A82 | IRQ handler | Raster IRQ. On the raster-compare flag: pushes shadow VIC registers $10-$2D to hardware (§2.2), advances the raster-split table at $0B71-$0B74 (used for the next split's line number and background color), then checks `CIA1_ICR` bit 0 (Timer A underflow) and — if set — calls `sub_1F29` (**confirmed** in `creep.cpp` as `musicBufferFeed()`, the per-frame music sequencer step). This is how CIA1 Timer A drives music playback at a fixed rate independent of the raster IRQ's own timing. |

## 5. Screen / bitmap / sprite memory

Directly confirmed by `creep.cpp`, which calls the emulated VIC-II bitmap loader with literal C64
addresses (this is a straight port, so these addresses are the real ones from the original binary):

```c++
// creep.cpp:638
mScreen->bitmapLoad( &mMemory[0xE000], &mMemory[0xCC00], &mMemory[0xD800], 0 );
//                     ^ bitmap data     ^ screen/color    ^ color RAM      ^ background color 0

// creep.cpp:1264, 1414 — text-mode menu screens
mScreen->drawStandardText( &mMemory[0x400], 0x1000, &mMemory[0xD800] );
//                            ^ screen matrix  ^ char-ROM pointer offset
```

This matches the VIC bank/memory-pointer setup found directly in the disassembly (§2.2, §3):
`CIA2_PRA = $00` selects VIC bank 3 ($C000-$FFFF); `VIC_MEMPTR` shadow ($22) is set to
`($30 & $F0) | $08 = $38`, whose screen-offset nibble (`0011`) puts the screen matrix at
bank-base + $0C00 = **$CC00**, and whose bitmap-select bit puts bitmap data at bank-base + $2000 =
**$E000**.

| Addr (range) | Purpose | Confidence |
|---|---|---|
| $0400-$07E7 | Default/standard screen matrix, used only for text-mode menu screens (`drawStandardText`) | confirmed (`creep.cpp`) |
| $C000-$FFFF | VIC-II bank 3 (selected via CIA2_PRA=$00 at $09D2) | confirmed (disasm) |
| $CC00-$CFE7 | Gameplay screen/color matrix (1000 bytes) | confirmed (`creep.cpp` + VIC_MEMPTR derivation) |
| $CFF8-$CFFF | Sprite pointer bytes (last 8 bytes of the $CC00 matrix), refreshed each IRQ from zp $26-$2D | confirmed (disasm §2.2) |
| $E000-$FF3F approx. | Bitmap graphics data (8000 bytes, hi-res/multicolor bitmap) | confirmed (`creep.cpp`) |
| $D800-$DBFF | Color RAM (fixed hardware address, not bank-relative) | confirmed |

### $BB00/$BC00 — bitmap row-address lookup tables

Built once at startup, inside `start()` ($08C2, `creep.cpp` lines ~256-271, matches disasm `loc_08C2`
through `loc_0932`):

```c++
for( count = 0xC8; ; ) {
    mMemory[0xBC00 + count] = byte_30;   // low byte
    mMemory[0xBB00 + count] = byte_31;   // high byte
    ...
    if( count & 7 )       byte_30 += 1;                  // next scanline within an 8-line band
    else { byte_30 += 0x39; ++byte_31; if(carry) ++byte_31; } // crossing into next 8-line band (+313 total)
}
```
and consumed later (`creep.cpp` ~3871) as:
```c++
word rowAddr = mMemory[0xBC00 + gfxCurrentPosY] | (mMemory[0xBB00 + gfxCurrentPosY] << 8);
```
i.e. **$BB00+row = high byte, $BC00+row = low byte of the bitmap address of the leftmost pixel-column byte
for scanline `row`.** The step pattern (+1 for six-out-of-eight lines, +313 crossing an 8-line band) is
exactly the standard C64 bitmap addressing formula `base + (row/8)*320 + (row%8)`, which independently
confirms the mechanism even though the *exact* generator seed values ($30=$40,$31=$D7) don't cleanly land
on $E000 in this snippet — plausibly because the loop's start index (`count=0xC8`) isn't row 0, or this
particular table build is reused for more than one screen mode. Flagged here as understood-mechanism /
unconfirmed-exact-base.

## 6. Castle data ($7800+) and save data ($B800)

$7800 is the *live* castle-state working buffer: `z*.prg` castle files load straight into it, and it also
doubles as the load/save target for `y*.prg` "position" (save-game) files (`castleManager->positionLoad/
positionSave/castleSave` all operate on `&mMemory[0x7800]`, with the saved size itself stored as a little-endian
word at $7800). Per the PRG headers (§1), `y*.prg` actually loads at **$B800** on real hardware — the natural
read is that the original 6502 code loads the save file to $B800 and then relocates/merges it into the live
$7800 buffer (the C++ port simplifies this into one step). $B800 also appears reused as the **high-score
name-entry buffer** once no save load is in flight (`mMemory[0xB87A]` onward, confirmed in `creep.cpp`).

Fields identified inside the $7800 castle header (all confirmed via direct `mMemory[0x78xx]` reads/writes
in `creep.cpp`):

| Addr | Field |
|---|---|
| $7800-$7801 | Save/record size (little-endian word), also acts as the "is this a save file" length check |
| $7802 | Flags byte (bit 7 checked to decide whether to jump straight into a room via a saved object pointer) |
| $7803 | Player 1 start room |
| $7804 | Player 2 start room |
| $7805 | Player 1 start door |
| $7806 | Player 2 start door |
| $7807 | Player 1 lives remaining (3 = full) |
| $7808 | Player 2 lives remaining |
| $7809 | Player 1 current room |
| $780A | Player 2 current room |
| $780B | Player 1 current door |
| $780C | Player 2 current door |
| $780F | Player 1 "escaped" flag |
| $7810 | Player 2 "escaped" flag |
| $7813 / $7814 | Player 1 / Player 2 key-count index |
| $7815+ | Player 1 keys-held array (indexed by $7813) |
| $7835+ | Player 2 keys-held array (indexed by $7814) |
| $785D/$785E | Scratch object-pointer temp, zeroed on room load |
| $785F | Saved object-list pointer (word) used to resume directly into a room |
| $7900+ | **Room pointer table**: 8 bytes per room, `roomAddr = $7900 + roomNumber*8` (confirmed, `roomPtrSet()`); `mRoomPtr` gets `+= 0x2000` while `mIntro` is set, suggesting an alternate/intro copy of room data 0x2000 further into the file |

## 7. Music ($4000) and music-player state ($20xx)

`music*.prg` (per-tune SID data) loads at **$4000** (§1) — this is the raw tune data blob, distinct from the
music *player engine's* working state, which lives inside the main engine's own data area around $20xx-$21xx
and is directly confirmed in `creep.cpp`:

| Addr | Purpose | Evidence |
|---|---|---|
| $20CB | Current voice/step index (`& 3`) | `musicPtrsSet()`: `X = mMemory[0x20CB] & 3;` |
| $20D2+n | Per-opcode length table for the music bytecode | `musicBufferFeed()` |
| $20DF/$20E1/... (word, +2 per voice) | Voice pointer table → `mVoice` | `readLEWord(&mMemory[0x20DF+X])` |
| $20E5/$20E7/... (word, +2 per voice) | Voice temp/return pointer table → `mVoiceTmp` | `readLEWord(&mMemory[0x20E5+X])` |
| $20DC/$20DD | Note/frame countdown timers | `musicBufferFeed()` |
| $20EF+n (n = 0,7,14) | Per-voice SID gate/control shadow, mirrored to $D404/$D40B/$D412 | `musicBufferFeed()`'s stop-all-voices path |

Playback is driven once per frame from the raster IRQ via CIA1 Timer A underflow → `jsr sub_1F29`
(§4), which `creep.cpp` names `musicBufferFeed()`.

## 8. $0800-$78C6 engine region map

| Range | Contents | Source |
|---|---|---|
| $0800-$0802 | 3-byte stub, `jmp loc_08C2` (the real cold-start entry) | disasm |
| $0803-$0838 | 18-entry `jmp` vector table — the engine's public API (room load, string print, sprite/object updates, menu, etc.) | given / disasm |
| $0839-$0841 | Small data: startup flag byte at $0839 (checked as `mMemory[0x839] != 1` to decide whether to relocate $7572←$77F7 and start a level) + a partial bitmask table | disasm + `creep.cpp` |
| $0842-$087D | Per-object-type handler address table (19 entries) | given |
| $088F-$08C1 | 6×8-byte actor handler records `{fn,fn,fn,flags}` | given |
| $08C2 | `start()` — cold-start entry: builds the $BB00/$BC00 row tables and a small $5CE6/$5D06 offset table, then either resumes into a level or falls through to the menu | `creep.cpp` (`// 08C2`) + disasm |
| $095F | Interrupt installer — sets CPU bank ($00/$01, §2.1) and IRQ/NMI vectors (§4) | disasm |
| $0A7B/$0A82 | NMI / IRQ handlers (§4) | given + disasm |
| $0B8D | Small state-machine setup around $0D0E-$0D19 (4-phase cycling counter) | disasm |
| $0D1A | Room-intro text buffer (`mRoomIntroData` copied here); $0D1A+64 = castle name string buffer | `creep.cpp` |
| $1AE6 | `obj_stringPrint` — reads a string through `mObjectPtr` ($3E/$3F) | disasm + confirms §2.3 |
| ...remaining code/data up to $78C6 | Room drawing, object AI (door/key/mummy/Frankie/raygun/conveyor/trapdoor/lightning), collision, menus, save/load glue | given (routine list in `disasm/object.json`) |
| $7572-$77FF | Relocation source used once at startup: copied to $7572+ from $77F7+ before entering `roomLoad`/level start | `creep.cpp` (`// Removed copy protection` block) |

## 9. Summary table (quick reference)

| Address / range | What's there |
|---|---|
| $00 | CPU port DDR ($07) |
| $01 | CPU port bank config ($05 — ROMs out, I/O in) |
| $10-$1F | Sprite 0-7 X/Y shadow registers (IRQ-refreshed) |
| $20-$23,$25 | VIC control/border shadow registers (IRQ-refreshed) |
| $26-$2D | Sprite pointer shadow (→ $CFF8-$CFFF, IRQ-refreshed) |
| $30/$31, $32/$33, $3C/$3D, $40/$41 | Named generic scratch pointers (`word_30`,`word_32`,`word_3C`,`word_40`) |
| $3E/$3F | `mObjectPtr` — primary object/string/data pointer (inferred) |
| $42/$43 | `mRoomPtr` — current room record pointer (inferred) |
| $0400-$07E7 | Text-mode menu screen matrix |
| $0800-$78C6 | Game engine (code + tables), loads from `object.prg` |
| $0A7B / $0A82 | NMI / IRQ handlers |
| $20CB-$20EF | Music player engine state |
| $4000+ | Raw music/tune data (`music*.prg`) |
| $7800-$78FF+ | Live castle state / save header (players, rooms, doors, keys) |
| $7900+ | Room pointer table (8 bytes/room) |
| $B800+ | Save-file (`y*.prg`) load target / high-score name-entry buffer |
| $BB00/$BC00 | Bitmap scanline row-address lookup table (hi/lo) |
| $C000-$FFFF | VIC-II bank 3 |
| $CC00-$CFE7 | Gameplay screen/color matrix |
| $CFF8-$CFFF | Sprite pointers |
| $D000-$D02E | VIC-II registers |
| $D400-$D41C | SID |
| $D800-$DBFF | Color RAM |
| $DC00-$DC0F / $DD00-$DD0F | CIA1 (keyboard/joystick, Timer A→music) / CIA2 (VIC bank select) |
| $E000-$FF3F | Bitmap graphics data |
| $FFFA-$FFFF | Interrupt vectors (RAM — ROMs banked out) |
