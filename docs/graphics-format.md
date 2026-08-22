# Dr. Creep — Graphics Format Notes

> **This is generated analysis**, produced by cross-referencing the tracing
> disassembly (`disasm/object.s`, `disasm/creepload.s`) against Robert
> Crossfield's reverse-engineered C++ port (`reference/segrax-DrCreep/src/`)
> and by directly parsing the extracted binaries (`extracted/*.prg`) with a
> small Python script during this session. Addresses are original C64
> addresses (`object.prg` loads at $0800; `creepload.prg` is the boot
> loader resident at $C000). Where a claim is inferred rather than directly
> observed, it is flagged as such. Treat this as a working map for the Zig
> port, not a verified spec — some details (marked "open question") need a
> live-hardware or VICE trace to nail down completely.
>
> **Evidence sources:**
> - `disasm/creepload.s` — boot loader at $C000 (KERNAL LOADs + VIC init)
> - `disasm/object.s` — the 28KB engine at $0800 (init code at $08C2, IRQ
>   handler at $0A82, shape table at $603B)
> - `reference/segrax-DrCreep/src/vic-ii/{screen,sprite,bitmapMulticolor}.cpp`
> - `reference/segrax-DrCreep/src/creep.cpp` (`titleDisplay`, `mainLoop`,
>   `screenClear`, `screenDraw`, `hw_SpritePrepare`, `roomLoad`)
> - `extracted/_x81pic_a_tit.prg`, `extracted/object.prg` (parsed directly)

---

## 1. Video mode: full-screen multicolor bitmap, always

Dr. Creep never uses VIC-II text mode for gameplay. It runs in **Multicolor
Bitmap Mode (BMM=1, MCM=1)** for the entire session — title screen and game
both. This is set up once by the boot loader and re-affirmed by the engine's
own init code; both agree on the same register values:

| Register | Value | Bits | Meaning |
|---|---|---|---|
| `$D011` VIC_CTRL1 | `$3B` | BMM=1, DEN=1, RSEL=1 (25 rows), YSCROLL=3 | bitmap mode on, display enabled |
| `$D016` VIC_CTRL2 | `$18` | MCM=1, CSEL=1 (40 cols), XSCROLL=0 | multicolor on |
| `$D018` VIC_MEMPTR | `$38` | screen ptr=3 (bank+$0C00), bitmap ptr=1 (bank+$2000) | see §2 |
| `$DD00` CIA2_PRA bits 0-1 | `00` | VIC bank 3 | VIC sees $C000–$FFFF |

Source: `disasm/creepload.s` lines `loc_C119`–`loc_C12B` (initial setup before
jumping into the game), and `disasm/object.s` `sub_095F`/`loc_0970` (engine's
own re-init, called on every screen change) plus the IRQ handler at `$0A82`
which re-pokes `VIC_MEMPTR` from a shadow byte at `$22` every frame — same
`$38` value (built as `($30 & $F0) | $08` at `object.s:0970-09AE`, and `$30`
is loaded as `$38` earlier).

Because the VIC bank is bank 3 ($C000–$FFFF) and MEMPTR selects screen-ptr 3
/ bitmap-ptr 1, the two VIC-visible display planes are:

- **Bitmap data**: bank base + $2000 = **$E000–$FF3F** (8000 bytes, 320×200 @ 2bpp)
- **"Screen" (color) data**: bank base + $0C00 = **$CC00–$CFE7** (1000 bytes, one per 8×8 cell)

This matches `cScreen::mainLoop()`'s one-time setup call:
```cpp
mScreen->bitmapLoad( &mMemory[0xE000], &mMemory[0xCC00], &mMemory[0xD800], 0 );
```
(`reference/.../creep.cpp:638`) — the third pointer, `$D800`, is the
physical VIC-II **Color RAM**, which is always mapped at $D800–$DBFF
regardless of bank/CPU-port config.

## 2. Multicolor bitmap pixel encoding

Standard C64 multicolor bitmap decode, confirmed against
`cBitmapMulticolor::load()` (`vic-ii/bitmapMulticolor.cpp:37-95`): each
bitmap byte holds 4 pixels (2 bits each), each pixel doubled to 2 screen
dots. For a byte at bitmap offset `B` (row `Y`, cell-column `X/8`) and the
corresponding "screen"-plane byte `S` at `$CC00 + (Y/8)*40 + X/8` and
color-RAM byte `C` at `$D800 + (Y/8)*40 + X/8`:

| 2-bit code | Color source | Priority |
|---|---|---|
| `00` | `$D021` (VIC_BG0, background register — a live register, not stored per-pixel) | background |
| `01` | high nibble of `S` | background |
| `10` | low nibble of `S` | **foreground** |
| `11` | low nibble of `C` (Color RAM) | **foreground** |

"Background" vs "foreground" here is the priority bit `cScreenSurface`/
`sScreenPiece::mPriority` uses for sprite/bitmap occlusion in the port — it
mirrors the real hardware's sprite-priority-vs-bitmap-color-bit-1 behavior.

## 3. The title picture file (`extracted/_x81pic_a_tit.prg`)

**Correction to the initial assumption**: the file does **not** start with
executable code. It is loaded to `$0800` by the KERNAL LOAD's embedded
address, but at load time `$0800` is just RAM — the boot loader (resident at
`$C000`, see §5) treats the whole thing as a passive 3-plane bitmap image,
then explicitly `jmp $0800` only *after* loading the second file (`OBJECT`)
overwrites this data with real code. Directly parsing the file confirms this:

```
offset 0000: 00 08                  ; PRG load address = $0800
offset 0002: bb ee bb ee bb ee ...  ; bitmap data begins immediately (not opcodes)
```

Layout (10003 bytes total = 2-byte load address + 10001-byte payload),
verified with a Python parse of the file:

| Payload offset | Size | Content | Loads to (in-memory, per loader) |
|---|---|---|---|
| `$0000`–`$1F3F` | 8000 B | bitmap plane | `$E000` (copied as 8192 B; the 192 trailing bytes copied past $FF3F are harmless spillover — the actual bitmap is only 8000 B) |
| `$1F40`–`$2327` | 1000 B | "screen"/color-nibble plane | `$CC00` |
| `$2328`–`$270F` | 1000 B | Color RAM plane | `$D800` |
| `$2710` | 1 B | value `$01` — **unused**, see below | not read by the loader |

The trailing byte is coincidental/vestigial: `cCreep::titleDisplay()`
hardcodes the background color to `1` rather than reading it
(`mScreen->bitmapLoad(buffer, buffer+0x1F40, buffer+0x2328, 1)` —
`creep.cpp:163`), and the real boot loader does the same
(`lda #$01 / sta VIC_BG0` at `creepload.s:loc_C133`). The file's last byte
happens to also be `$01`, but nothing in the traced code path reads it.

## 4. Boot loader's memory build (`disasm/creepload.s`, resident at $C000)

The 559-byte loader at `$C000` (from the `.d64`, not part of `object.prg`)
does, in order:

1. Clears $0400–$07FF (default text screen) and $D800–$DBFF (Color RAM) to
   `$20`.
2. Decompresses/prints the "PLEASE ALLOW TWO MINUTES..." loading message
   using a small token-substitution scheme (table at `$C16B`, strings at
   `$C19D`+) — unrelated to game graphics, mentioned only because it lives
   in the same file (`creepload.s:9-139`).
3. `LOAD"​<0x81>PIC A TITLE   ",8` with secondary address 0 → loads the file
   from §3 to `$0800` (its embedded address).
4. Copies payload+$1F40 (1000 B) → `$CC00` (`loc_C0A6`).
5. Copies payload+0 (8192 B, i.e. a bit more than the 8000 B bitmap) →
   `$E000` (`loc_C0C9`).
6. Copies payload+$2328 (1024 B) → `$D800` (`loc_C0EC`).
7. Sets `CIA2_PRA` bank bits to `00` (bank 3), `VIC_CTRL1=$3B`,
   `VIC_CTRL2=$18`, `VIC_MEMPTR=$38`, `VIC_BORDER=$07`, `VIC_BG0=$01`
   (`loc_C10F`–`loc_C135`) — i.e. exactly the mode from §1, so the picture
   is already on screen once these copies finish.
8. `LOAD"OBJECT",8` (secondary 0, → `$0800` again) then `JMP $0800`
   (`loc_C138`–`loc_C153`), overwriting the picture with the game engine.

This is strong, direct confirmation that the in-memory layout used for the
title picture is identical in kind to the in-game bitmap planes (§1), just
built by explicit `LDA ($ptr),Y / STA ($ptr),Y` copy loops instead of the
`bitmapLoad()` abstraction the C++ port uses.

## 5. Screen row-pointer tables at `$BB00`/`$BC00` (built at `$08C2`)

`object.s` `loc_08C2`–`loc_08F9` (mirrored in `creep.cpp:cCreep::start()`,
lines 254–274) builds a 256-entry, 2-byte-per-entry (`$BB00`=hi, `$BC00`=lo)
address table, seeded at `$D740` and advanced per index `i` (0–255, wrapping)
as:

```
if (i % 8 != 0): addr += 1        ; next scanline within an 8-row cell
else:             addr += 0x39    ; (57) jump to the next cell-row, +1 carried into hi
```

Net effect: every group of 8 consecutive table entries advances the pointer
by exactly 64 (`7×1 + 57`), and since the loop covers 200 useful entries
(`25 × 8`), the table spans **`$D740`–`$DD80`**. It is read back by index
`gfxCurrentPosY` (a Y pixel row, 0–199) in the object/text bitmap-compositing
routine at `object.s:$5A21`–`$5B50` (`lda $BC00,x` / `lda $BB00,x` at
`5A6D`/`5A72`) to get a fast per-scanline base address for AND/OR mask
blitting (`and ($36),y` / `sta ($36),y` at `5AC3`/`5AC5`, mirrored in
`creep.cpp` around line 3892: `gfxCurrentPosY < 0xC8`, `byte_36 = byte_34 + …`).

**Open question**: `$D740`–`$DD80` sits inside the CPU I/O region
($D000–$DFFF) which, under the CPU port config used during normal gameplay
(`$01=$05`: LORAM=1,HIRAM=0,CHAREN=1 → I/O visible, RAM at $E000/$A000 —
confirmed by the IRQ handler at `$0A82` freely poking `$D000`-range VIC/CIA
registers without any port switch), would **not** be ordinary RAM at that
moment. The engine performs an all-RAM CPU-port switch elsewhere for a
similar reason — see `object.s:$2B2E`–`$2B45` (`sei; lda #$07 sta $00; lda
#$01 sta $01; …read $D000-range as Character ROM…; lda #$05 sta $01; cli`),
so it's very plausible that the whole room/object compositing pass (driven
from `roomPrepare()`/`roomLoad()`) is bracketed by a similar `SEI` / `$01`
switch to a full-RAM config (bit pattern `LORAM=0,HIRAM=0`, e.g. `$30`) so
that `$D000`–`$DFFF` doubles as extra off-screen composition RAM during that
window, then switches back to `$05` for normal IRQ-driven VIC access. This
session did not trace every call site to `screenDraw()`/`roomPrepare()` to
find that bracketing instruction pair — flagging it as the most likely
explanation, not a confirmed one.

## 6. Object/sprite/text "shape" pointer table at `$603B`

This is the most concrete, fully-confirmed finding. **A single master table
of little-endian word pointers at `$603B`** is shared by three different
consumers — background room graphics (`screenDraw`, C++: `creep.cpp:3630`),
inline text strings (also `screenDraw`, decode-mode 1), and hardware sprite
frames (`hw_SpritePrepare`, `creep.cpp:4878`). All three index the same
table the same way: `entry_addr = word_at($603B + id*2)`.

```
id=0x00: $603B → *($603B) = $6171
id=0x01: $603D → $619C
id=0x02: $603F → $61C7
...
```
(directly verified by parsing `extracted/object.prg`).

Each entry is a small header followed by packed pixel data:

```
byte 0: width   (bytes per row)
byte 1: height  (rows)
byte 2: flags   (used by sprite frames — see §7; ignored/reused for images)
byte 3..: width*height bytes of packed 2-bit-per-pixel row data, row-major
```

Confirmed exactly (`header + width*height == distance to next entry`) for
small sprite-frame entries:

| id | addr | header (w,h,flags) | payload len | matches w×h ? |
|---|---|---|---|---|
| `0x0A` | `$63DB` | `1, 8, 0` | 8 | 1×8=8 ✓ |
| `0x0B` | `$63E8` | `1, 3, 0` | 3 | 1×3=3 ✓ |
| `0x0C` | `$63EE` | `1, 8, 0` | 8 | 1×8=8 ✓ |
| `0x0D` | `$63F9` | `1, 8, 0` | 8 | 1×8=8 ✓ |

For the larger background-graphic entries used via `screenDraw` (e.g.
`0x93`/`0x94`/`0x95`, drawn with `screenDraw(2, 0x95, x, y, 0x94)` from
`creep.cpp:3598`), the same 3-byte header is present but the payload is
**larger than `width*height`** (e.g. `id=0x93`: header `8,7,0`, expected
56 bytes, actual span 72 bytes) — these entries likely carry an additional
plane (an AND-mask or a second color pass) beyond the raw pixel bytes; this
session did not fully decode that extra data. Flagged as **needs more work**
before porting the room-graphic decoder.

The whole table + its data blobs occupy roughly **`$603B`–`$7600`** (~6 KB)
of `object.prg` — this is the "large `.byte` run" region the task pointed
at; it directly follows the code at `sub_6009` (`object.s:18061`) and is
never disassembled as instructions because the tracer correctly never jumps
into it as code.

## 7. Hardware sprites

Dr. Creep uses real VIC-II hardware sprites (not custom bitmap-drawn actors)
for the player and monsters, multicolor mode, with:

- Shared multicolor colors fixed once at init: `VIC_SPMC0=$0A`, `VIC_SPMC1=$0D`
  (`object.s:09C1-09C8`, mirrored in `cSprite::cSprite()` constructor
  defaults `_multiColor0=0x0A, _multiColor1=0x0D`).
- Per-sprite color = low nibble of the shape entry's flag byte
  (`sprite->_color = spriteFlags & 0x0F`).
- Flag byte bits (from `creep.h:79-82`):

  | bit | mask | meaning |
  |---|---|---|
  | 7 | `0x80` | double width |
  | 6 | `0x40` | double height |
  | 5 | `0x20` | priority (sprite behind background) |
  | 4 | `0x10` | **clear** = multicolor sprite; **set** = hi-res (single color) sprite |
  | 0-3 | `0x0F` | sprite color register value |

- Sprite bitmap data (63 useful bytes/frame, 3 bytes × 21 rows, hardware
  format) lives in **VIC bank 3, blocks 0–31** = **`$C000`–`$C7FF`** (2048
  bytes, cleared every room load by `screenClear()`, `creep.cpp:668`). This
  is *not* static data in `object.prg` — it is decoded at runtime from the
  `$603B` shape table (§6) into this scratch area by `hw_SpritePrepare()`.
- **Double-buffered** to avoid tearing: the VIC sprite-pointer shadow bytes
  live at zero page `$26`–`$2D` (one per hardware sprite 0–7), initialized
  to sentinel blocks `$20`–`$27` by `screenClear`/`DisableSpritesAndStopSound`
  (`object.s:098C-0999`, matches `creep.cpp` setting
  `mMemory[0x26+X] = 0x20+X`). Each `hw_SpritePrepare()` call XORs the
  current pointer with `8` (`word_32 = (mMemory[0x26+n] ^ 8) << 6 | 0xC000`)
  to decode the *next* frame into the other half of a 512-byte-apart block
  pair, then commits the flipped pointer back to `$26+n` once decoding is
  done. The IRQ handler (`object.s:$0A82`+) copies this zero-page shadow
  array (`$10`–`$29`ish) out to the real VIC sprite registers every frame.

## 8. Text rendering: no custom charset — real Character ROM, sampled into the bitmap

Because the engine runs in full-screen bitmap mode for the entire game
(§1), it has **no use for `VIC_MEMPTR`'s character-set-base field** and, as
far as this session could find, **ships no custom 8×8 font graphic** in
`object.prg`. Instead, on-screen text (menus, room names, status text) is
rendered by:

1. Briefly switching the CPU port to expose the real **Character Generator
   ROM** at `$D000`–`$DFFF` (`$01 = $01` → LORAM=1,HIRAM=0,CHAREN=0), inside
   a `SEI`/`CLI` pair, e.g. `object.s:$2B2E`–`$2B45`:
   ```
   sei
   lda #$07 : sta $00      ; DDR
   lda #$01 : sta $01      ; bank in Character ROM at $D000-$DFFF
   ldy #$07
   loc_2B39: lda ($30),y : sta $2BF0,y : dey : bpl loc_2B39
   lda #$05 : sta $01      ; back to normal (I/O visible)
   cli
   ```
   copying 8 bytes (one glyph row set) from the real char ROM into a work
   buffer at `$2BF0`.
2. The C++ port mirrors this exactly via `cCreep::charRom(word pAddress)`
   (`creep.h:372-374`, `return m64CharRom[pAddress - 0xD000]`) reading a
   *separately supplied* `CHAR.ROM` resource file — i.e. Crossfield's port
   also treats this as "the real C64 character ROM", not a game asset.
3. `cScreen::drawStandardText()` (`vic-ii/screen.cpp:312-350`) then plots
   each glyph's 8×8 pixels directly into the bitmap surface pixel-by-pixel
   (`mSurface->pixelDraw(...)`), i.e. text is burned into the multicolor
   bitmap like any other graphic, not displayed via a separate VIC text
   layer.

**Implication for the Zig port**: reproducing text rendering requires either
embedding a copy of the real C64 character ROM (widely available separately,
not part of this game's assets) or substituting a compatible bitmap font —
there is no font to extract from `object.prg` itself.

## 9. Summary table: where things live

| Region | Address range | Contents |
|---|---|---|
| VIC bitmap plane | `$E000`–`$FF3F` | 320×200 2bpp multicolor bitmap, 8000 B |
| VIC "screen" plane | `$CC00`–`$CFE7` | 1000 B, hi/lo nibble = colors for pixel codes `01`/`10` |
| Color RAM | `$D800`–`$DBFF` | 1000 B (nibble), color for pixel code `11` |
| Sprite pointer shadow | `$26`–`$2D` (zero page) | 8 bytes, double-buffered (XOR 8) block indices |
| Sprite pointer table (VIC) | `$CFF8`–`$CFFF` | = screen-plane-base + `$3F8`, standard VIC convention |
| Hardware sprite bitmap scratch | `$C000`–`$C7FF` | 32 × 64 B blocks, decoded at runtime, cleared per room |
| Shape/sprite-frame/text pointer table | `$603B`–~`$6171` | ~155 × LE word pointers |
| Shape/sprite-frame/text data blobs | ~`$6171`–~`$7600` | `[width][height][flags][packed pixel rows]` |
| Row-pointer table (compositing) | `$BB00`/`$BC00` | 256×2 B, per-scanline base addresses (see §5) |
| Character ROM (borrowed, not shipped) | `$D000`–`$DFFF` (banked) | real C64 char ROM, sampled for text glyphs |

## 10. Open questions for further work

- Confirm the CPU-port (`$01`) bank-switch bracketing around the
  `roomPrepare()`/`screenDraw()` object-compositing pass, to settle whether
  `$BB00`/`$BC00`'s `$D740`-based addresses genuinely target banked-in RAM
  (§5).
- Fully decode the extra payload bytes on background-graphic shape-table
  entries (beyond `width*height`) — likely a second mask/color plane (§6).
- Confirm whether any of the castle data files (`z*.prg`) or the `y*.prg`
  save files carry additional graphics (they're small — `y*.prg` are only
  124 bytes and are almost certainly save-state, not graphics; `z*.prg`
  range 1.8–5.6 KB and are the per-castle room/object layout data, not
  scanned for embedded pixel data in this pass).
