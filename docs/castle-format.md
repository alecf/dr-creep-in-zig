# Castle / Room Data Format (z* files)

> **This is generated analysis, not primary documentation.** It was produced by
> reading Robert Crossfield's reverse-engineered C++ port
> (`reference/segrax-DrCreep/src/creep.cpp`, `castleManager.cpp`,
> `castle/castle.cpp`, `castle/room.cpp`, `castle/objects/*.hpp`) and then
> **verifying every field against the real bytes** of
> `extracted/ztutorial.prg` and `extracted/zsylvania.prg` with a small Python
> parser that walks the object stream the same way `cRoom::roomLoadObjects()`
> does. Every room in both files parses cleanly end‑to‑end with no unknown
> tags, and the tutorial castle's text objects decode to the exact on-screen
> tutorial copy ("DOORS AND DOORBELLS", "LADDERS", "SLIDING POLES", …), which
> is strong confirmation the layout below is correct. A few fields (marked
> "unclear"/"unverified") are inferred from field names in the C++ source or
> from byte patterns only, and are called out explicitly.
>
> Evidence sources: `reference/segrax-DrCreep/src/{creep.cpp,creep.h,castleManager.cpp}`,
> `reference/segrax-DrCreep/src/castle/{castle.cpp,castle.h,room.cpp,room.hpp}`,
> `reference/segrax-DrCreep/src/castle/objects/*.hpp`, `disasm/object.s`
> (cross-checked references to `$7802`), and hex analysis of
> `extracted/ztutorial.prg`, `extracted/zsylvania.prg`, `extracted/ytutorial.prg`.

## 1. Memory map recap

A castle file (`z*`, e.g. `ZTUTORIAL`) loads verbatim at **$7800**, with the
first two bytes of the `.prg` being the usual C64 load-address header (`00 78`)
that must be stripped to get file-offset-0 == $7800.

*(Corrected after verification against creep.cpp.)* The game itself loads a
castle to **$9800** and keeps that copy untouched (the title sequence tours
its rooms with `mObjectPtr += 0x2000` when `mIntro`). At the start of every
game, `Game()` (`0D71`, creep.cpp:2909–2913) copies `readLEWord($9800)` bytes
down to `$7800` and plays the copy, which it writes to (header scratch, door
open bits). Only a saved position loads straight to `$7800`. The layout below
is the same at either address.

```
$7800 - $78FF   Castle header / player run-state block (256 bytes)
$7900 - ...     Room directory: 8 bytes per room, terminated by 0xFF or 0x40
(after dir)     Per-room object streams (variable length, pointed to by the directory)
```

`cCastle::castleLoad()` (castle.cpp:89) is the authoritative loader; the real
6502 engine's equivalent is `roomLoad`/`roomPtrSet`/`roomPrepare`
(`creep.cpp:676`, `:2874`, `:766`), which the disassembly confirms reads/writes
`$7802` directly (`disasm/object.s:472,948,1099,1103,1343,3400`).

## 2. Castle header ($7800–$78FF)

Only a handful of offsets in this 256-byte block are given meaning by
`cCastle::castleLoad`/`castleSave`; the rest (`$7809`–`$78FE`, excluding
`$785F`) is **runtime scratch space** — `Game()` (creep.cpp:2896) overwrites
`$7809`–`$7814` from `$7803`–`$7808` and other state at the start of every
game, so whatever bytes ship in the file there are never read as initial
values. This explains why the on-disk header is followed by what looks like
leftover/garbage bytes.

| Offset | Field | Meaning |
|---|---|---|
| `$7800` (word, LE) | `mSaveSize` | Total bytes of castle data starting at `$7800` (header + room directory + all room object streams). Used by `castleSave`/`positionSave` as the file's payload length. |
| `$7802` | magic/flags | Must equal **`0x80`** on load or `castleLoad` aborts (`if(*(buffer+2) != 0x80) return;`). At runtime bit 0 gets OR'd in (`mMemory[0x7802] \|= 1`) and bit 7 (`& 0x80`) is tested elsewhere as a distinct in-game flag — so `0x80` on disk doubles as both a format-version marker and the initial state of that runtime flag. |
| `$7803` | `mStart_Room_Player1` | Player 1's starting room number (index into the room directory). |
| `$7804` | `mStart_Room_Player2` | Player 2's starting room number. |
| `$7805` | `mStart_Door_Player1` | Player 1's starting door number within that room. |
| `$7806` | `mStart_Door_Player2` | Player 2's starting door number. |
| `$7807` | `mLives_Player1` | Starting lives, player 1 (3 in both sample files). |
| `$7808` | `mLives_Player2` | Starting lives, player 2. |
| `$7809`–`$785E` | *(runtime scratch)* | Current room/door/status/key-count/elapsed-time slots used **while playing** (mirrors of `$7803`–`$7808`, per-player status bytes, key-ID lists, elapsed-seconds words). Not meaningfully initialized on disk — see note above. |
| `$785F` (word, LE) | `mFinalPtr` | Absolute address (`$7800`-based) of the special "final/bonus" room's object stream, if the castle has one. `0` if not present. |
| `$7860`–`$78FF` | *(unused/unknown)* | Not referenced by name in the reverse-engineered source; likely more runtime scratch (high-score-key tracking, per-player timers, etc. per the `$7813`–`$7858`-ish accesses seen elsewhere in `creep.cpp`). |
| `$7900`+ | Room directory | See §3. |

### Worked example — `ztutorial.prg`

```
7800: 31 10 80 00 00 00 00 03 03 83 a0 b6 80 a0 cc b0 ...
```

- `$7800` word = `0x1031` = 4145 (declared payload size; the extracted `.prg`
  is 4160 data bytes, 15 longer — likely disk-sector padding not counted in
  `mSaveSize`).
- `$7802` = `0x80` ✓ (magic byte, matches `castleLoad`'s check).
- `$7803..$7808` = `00 00 00 00 03 03` → both players start in room 0, door 0,
  with 3 lives each.
- `$785F` = `0x861F` → the tutorial castle has a final/bonus room whose object
  stream begins at `$861F` (see §5).

## 3. Room directory ($7900+)

Each room is a fixed **8-byte** record (`cRoom::roomLoad`/`roomSave`,
room.cpp:104–129). `roomPtrSet(n)` in the real engine computes a room's
directory address directly as `n*8 + 0x7900`.

| Offset | Size | Field | Meaning |
|---|---|---|---|
| +0 | byte | `mColor` | Bits 0–3 = room's base border/floor colour (VIC colour 0–15). **Bit 6 (`0x40`) marks this room as the special "final room" terminator** — the directory-scan loop (`castleLoad`) and the intro-screen loop (`Intro()`, creep.cpp:887) both test `color & 0x40`. |
| +1 | byte | `mMapX` | Room's X position on the in-game castle map (used to draw the mini-map / room-to-room navigation). |
| +2 | byte | `mMapY` | Room's Y position on the map. |
| +3 | byte | size byte | Packed: `height = byte & 7`, `width = (byte >> 3) & 7` — the room's footprint in map cells. |
| +4–5 | word (LE) | "skip" pointer | **Always equals the object-stream pointer (offset +6/+7) plus 2** in both sample files (i.e. it points *past* the first object-type tag word). Not read by `roomLoad` in `creep.cpp`; likely a level-editor convenience field. Purpose beyond that is unverified. |
| +6–7 | word (LE) | `mObjectPtr` | Absolute address (`$7800`-based) of this room's object/bytecode stream (§4). This is the field the real engine reads: `mObjectPtr = readLEWord(&mMemory[mRoomPtr + 6])` (creep.cpp:705). |

The directory is a flat array starting at `$7900`; it ends either at a byte
`0xFF` (plain end of castle, no bonus room) or `0x40` (end of castle, **and**
there is a bonus/"final" room reachable via `$785F`). The terminator itself is
a single byte, not a full 8-byte record.

### Worked example — `ztutorial.prg` (13 rooms)

| # | addr | color | map(x,y) | w×h | objPtr |
|---|---|---|---|---|---|
| 0 | `$7900` | `0x03` | (16,64) | 3×7 | `$7969` |
| 1 | `$7908` | `0x04` | (28,64) | 3×7 | `$7AAD` |
| 2 | `$7910` | `0x05` | (40,64) | 3×7 | `$7BBB` |
| … | … | … | … | … | … |
| 12 | `$7960` | `0x04` | (160,64) | 3×7 | `$857F` |
| — | `$7968` | `0x40` | — | — | *(terminator; final room via `$785F` = `$861F`)* |

Rooms lie in a straight horizontal line (`mapX` increases by 12 per room,
`mapY` constant at 64) matching the tutorial's linear room-to-room layout.
`zsylvania.prg` has 16 rooms in a 2-D grid (mapX/mapY vary in both axes) and
also terminates with `0x40` (has a final room at `$828B`).

## 4. Room object stream

Starting at a room's `mObjectPtr`, the stream is a sequence of
**type-tagged records**, read by `roomPrepare()` in the real engine
(creep.cpp:766) / `cRoom::roomLoadObjects()` in the port (room.cpp:58).

### 4.1 The type tag *is* a jump-vector address

Each record begins with a **little-endian word**. These words are not
arbitrary enum values — they are literally the addresses of the 3-byte
`JMP $xxxx` slots in the public jump table at `$0803`–`$0838` (18 entries, 3
bytes apart) that the game's own binary uses to dispatch object types. That
table is exactly the one listed in this repo's notes as the "jmp vector
table, 18 public entry points." A tag of `0x0000` terminates the room's
object stream.

| Tag (word) | Object | Framing scheme (see 4.2) | Record size |
|---|---|---|---|
| `0x0803` | Door | count-prefixed | 8 bytes/door |
| `0x0806` | Walkway | length-prefixed loop, end=`0x00` | 3 bytes/entry |
| `0x0809` | Sliding pole | length-prefixed loop, end=`0x00` | 3 bytes/entry |
| `0x080C` | Ladder | length-prefixed loop, end=`0x00` | 3 bytes/entry |
| `0x080F` | Doorbell | count-prefixed | 3 bytes/bell |
| `0x0812` | Lightning machine/switch | special loop, ends on a byte with bit 5 set | 8 bytes/entry |
| `0x0815` | Forcefield | loop, end=`0x00` | 4 bytes/entry |
| `0x0818` | Mummy | loop, end=`0x00` | 7 bytes/entry |
| `0x081B` | Key | loop, end=`0x00` | 4 bytes/entry |
| `0x081E` | Lock | loop, end=`0x00` | 5 bytes/entry |
| `0x0821` | MultiDraw | loop, end=`0x00` (count byte; intro-only, see §4.4) | 6 bytes/entry |
| `0x0824` | Ray gun | loop, end=`0x80` | 7 bytes/entry |
| `0x0827` | Teleport | single object, self-terminating | variable |
| `0x082A` | Trap door | loop, end=`0x80` | 5 bytes/entry |
| `0x082D` | Conveyor | loop, end=`0x80` | 5 bytes/entry |
| `0x0830` | Frankenstein | loop, end=`0x80` | 7 bytes/entry |
| `0x0833` | Text | loop, end=`0x00` | variable |
| `0x0836` | Image | one tag **per** image (not shared) | variable |
| `0x160A` / `0x2A6D` | Intro-screen variants of MultiDraw/Text | intro screens only (`$9800`+, `mIntro`) | — |

### 4.2 Framing schemes

- **Count-prefixed** (Door, Doorbell): tag word, then 1 byte = number of
  entries `N`, then `N` fixed-size records back-to-back. No end marker.
- **Loop with end marker** (everything else except Door/Doorbell/Image/Teleport):
  tag word, then fixed-size records repeated until the **next record's first
  byte** equals the type's end marker (`0x00` for most, `0x80` for
  ray gun/trap door/conveyor/Frankenstein, `0x20` for lightning), at which
  point that one marker byte is consumed and the stream moves to the next
  tag. A type can legally have **zero** instances in a room in this scheme —
  the marker byte immediately follows the tag word (this is how `saveObject`
  in `room.cpp:239` special-cases "no objects: write tag=0 instead of a
  marker").
- **Single, self-terminating** (Teleport): exactly one teleport object per
  room; its own internal format (see below) consumes its own `0x00`
  terminator, and the room-level loop does not re-check after it.
- **Per-instance tag** (Image): unlike every other type, each image gets its
  own `0x0836` tag word (see `cRoom::roomSaveObjects` calling `saveObjects`,
  not `saveObject`, for images) — so a room with 3 images has `0x0836` repeated
  3 times, each followed by one image record and its own `0x00` terminator.

### 4.3 Per-type field layout

All coordinates are C64 screen-pixel-ish X/Y byte pairs used directly by the
blitter (`screenDraw`), not tile coordinates.

**Door** (`0x0803`, count-prefixed, 8 bytes/entry) — `objectDoor.hpp:75`:
| off | field | notes |
|---|---|---|
| 0 | X | |
| 1 | Y | |
| 2 | direction | bits 0–1: `0`=up,`1`=right,`2`=down,`3`=left — the wall the door is on, on the castle map. **Bit 7 = door open** (`obj_Door_Prepare` tests `& 0x80`; `obj_Door_Execute` sets it in the castle data when a door opens). *(Corrected after verification against creep.cpp.)* |
| 3 | linkRoom | room number this door leads to |
| 4 | linkDoor | door index (within `linkRoom`) the player arrives at |
| 5 | mapX | the door's position on the castle map, X offset from the room's top-left corner. `mapRoomDraw` uses it for top/bottom-wall doors; `mapArrowDraw` uses both bytes for every door: arrow at (room x + byte5 + dx[side], room y + byte6 + dy[side]), dx = {−1, +2, −1, −5} (`$11DA`), dy = {−10, −2, +6, −2} (`$11DE`). The tutorial's room 0 right-wall door has mapX = 10 in a 12-wide room (width − 2). *(Corrected after verification against creep.cpp.)* |
| 6 | mapY | Y offset of the same (used by `mapRoomDraw` for left/right-wall doors, by the arrow for all) |
| 7 | castleExitDoor | `0`/`1` — `1` marks this as the castle's exit (escape) door. It is **not** a door ID: `obj_Door_Prepare` uses it only to index the frame table at `$41D1` (`$06` normal frame, `$96` exit frame), and the same `X` is then overwritten by `object_Create(byte &X)`. `obj_Door_InFront` sets the escaped flag at `$785D` when it is non-zero. *(Corrected after verification against creep.cpp.)* |

**Walkway / Sliding pole / Ladder** (`0x0806`/`0x0809`/`0x080C`, loop end=`0x00`, 3 bytes/entry):
`length`(1), `X`(1), `Y`(1). Loop stops when the next `length` byte is `0`.

**Doorbell** (`0x080F`, count-prefixed, 3 bytes/entry) — `objectDoorBell.hpp`:
`X`(1), `Y`(1), `door`(1) — the door this bell operates: the door's **index
in the room's door group** (0 = first), matched against `objNumber = count`
in `obj_Door_Button_Prepare`. The bell is drawn in the colour of that door's
destination room. *(Corrected after verification against creep.cpp.)*

**Lightning** (`0x0812`, special loop, end byte `0x20`, 8 bytes/entry) —
`objectLightning.hpp`. Two sub-formats distinguished by the high bit of the
first byte:
- **Machine** (first byte & `0x80` == 0): `state`(1: `0x00`/`0x40` = off/on),
  `X`(1), `Y`(1), `length`(1), then 4 unused/zero bytes.
- **Switch** (first byte & `0x80` != 0): `state`(1: `0x80`/`0xC0` = off/on),
  `X`(1), `Y`(1), 1 unused byte, then 4 bytes = up to 4 **machine indices**
  this switch controls (each stored as `machineNumber * 8`, `0xFF` = unused
  slot).
Loop ends when the next entry's first byte has **bit 5 set** (`& 0x20`,
`LIGHTNING_END_MARKER`), not when it equals `0x20` (real states are
`$00/$40/$80/$C0`, so both read the same on real data). *(Corrected after verification against creep.cpp.)*

**Forcefield** (`0x0815`, loop end=`0x00`, 4 bytes/entry) — two X/Y pairs, no
header byte: `X0,Y0,X1,Y1` (part 0 = one post, part 1 = the other).

**Mummy** (`0x0818`, loop end=`0x00`, 7 bytes/entry) — `objectMummy.hpp`:
`unk`(1, always `0x01` in samples), `X0,Y0` (coffin), `X1,Y1` (roam boundary),
then 2 unused/zero trailing bytes.

**Key** (`0x081B`, loop end=`0x00`, 4 bytes/entry) — `objectKey.hpp`:
`color`(1), `color2`(1, empirically `color+0x50` — a screen-code/colour-code
pair, purpose of the duplicate byte unclear), `X`(1), `Y`(1).

**Lock** (`0x081E`, loop end=`0x00`, 5 bytes/entry) — `objectLock.hpp`:
`color`(1), `color2`(1, `color+0x57`), `doorNumber`(1, matches a Door's
offset-7 ID), `X`(1), `Y`(1).

**Ray gun** (`0x0824`, loop end=`0x80`, 7 bytes/entry) — `objectRayGun.hpp`:
`direction`(1), `X0,Y0` (mount point, part 0), `length`(1, travel range of
part 0), `Y1` (Y of part 1, gun carriage), `X1,Y1'` (2 bytes — the C++ source
re-reads a full X/Y pair for part 1 after already having stashed its Y, so
part 1's Y is effectively stored twice; not fully disambiguated here).

**Teleport** (`0x0827`, single object) — `objectTeleport.hpp`: `X0,Y0`
(2, the "transmitter" booth), `target`(1), then a variable list of
**receiver** `X,Y` pairs (2 bytes each) terminated by a `0x00` byte. A room
has at most one Teleport tag; all its pads (transmitter + N receivers) live
in this one record.

**Trap door** (`0x082A`, loop end=`0x80`, 5 bytes/entry) — `objectTrapDoor.hpp`:
`state`(1: `0`=closed,`1`=open at load), `X0,Y0` (control switch),
`X1,Y1` (the trap door itself).

**Conveyor** (`0x082D`, loop end=`0x80`, 5 bytes/entry) — `objectConveyor.hpp`:
`state`(1: 0–3, direction/speed of belt), `X0,Y0` (control switch),
`X1,Y1` (belt).

**Frankenstein** (`0x0830`, loop end=`0x80`, 7 bytes/entry) —
`objectFrankenstein.hpp`: `direction`(1), `X,Y`(2, coffin position), then 4
unused/zero trailing bytes.

**Text** (`0x0833`, loop end=`0x00`, variable) — `objectText.hpp`: `X`(1),
`Y`(1), `color`(1, VIC colour 0–15), `style`(1: bits 0–1 = height ×1–3, each glyph row repeated, a whole style
byte of 0 = height 1; bits 4–5 pick one of four character sets from the
table at `$2BE8` (`$D000/$D400/$D800/$DC00`), so bit 4 = reversed and
bit 5 = the letters set; `0x22` on title lines, `0x21` on body lines — from
`StringPrint`) *(Corrected after verification against creep.cpp.)*, then a PETSCII-ish string where **every character except the
last has bit 7 clear**, and **the last character has bit 7 set** as an
end-of-string marker (characters are stored uppercase already, `& 0x7F` to
read). A room can have many Text tags in a row sharing a single trailing
`0x00` after the whole run (see worked example below).

**Image** (`0x0836`, one tag per instance) — `objectImage.hpp`: `width`(1),
`height`(1), `0x00`(1, padding/reserved), then a bitmap payload of
`width*height + width*ceil(height/8)*2` bytes (colour cells + hi-res bitmap
data, matching the VIC multicolour-bitmap object format used for the
end-game trophy pieces), followed by a variable list of placement `X,Y`
pairs (2 bytes each, one per instance the piece should be redrawn at) ending
in `0x00`.

### 4.4 MultiDraw and the intro tags

*(Corrected after verification against creep.cpp.)* `obj_MultiDraw` is in
`creep.cpp`: records of 6 bytes (`count, shape, x, y, dx, dy`) until a count
of 0; it draws the shape `count` times, stepping by (dx, dy). The title
screens' tags are the routines' own addresses (`$160A` MultiDraw, `$2A6D`
text) rather than jump-table slots. The rest of this section is the
original note:

`eObjectMultiDraw` (`0x0821`) and its intro variants `0x160A`
(`eObjectIntroMultiDraw`) / `0x2A6D` (`eObjectIntroText`) appear only in the
**menu/intro screens** (loaded at `$9800`, offset `+0x2000` from normal room
addresses, gated by the `mIntro` flag) rather than in castle room data. The
C++ port's own `obj_Multi_Create()` (room.cpp:506) is a stub that returns
`nullptr`, so their byte layout is undocumented even in the reference source.
Neither sample castle file uses these tags in its rooms (confirmed — both
parse cleanly to `0x0000` without ever hitting them), so this gap does not
affect normal castle data, only intro-screen decoding.

## 5. Worked example: `ztutorial.prg`, room 0, full trace

Room 0's directory entry points to `$7969`. Raw bytes from `$7969`:

```
7969: 03 08 01 9c a0 01 01 00 0a 30 00 06 08 28 10 c0
7979: 00 0f 08 01 90 a8 00 33 08 14 00 07 22 44 4f 4f
7989: 52 53 20 41 4e 44 20 44 4f 4f 52 42 45 4c 4c d3
7999: 10 18 0d 21 4f 4e 45 20 57 41 59 20 54 4f 20 4f
```

Decoded:

| addr | bytes | meaning |
|---|---|---|
| `7969` | `03 08` | tag `0x0803` = Door |
| `796B` | `01` | count = 1 door |
| `796C` | `9c a0 01 01 00 0a 30 00` | X=156 Y=160 dir=1(right) linkRoom=1 linkDoor=0 mapX=10 mapY=48 exit=0 |
| `7974` | `06 08` | tag `0x0806` = Walkway |
| `7976` | `28 10 c0` | length=40 X=16 Y=192 |
| `7979` | `00` | end marker (0 length ⇒ stop) |
| `797A` | `0f 08` | tag `0x080F` = Doorbell |
| `797C` | `01` | count = 1 bell |
| `797D` | `90 a8 00` | X=144 Y=168 door=0 (the room's first door) |
| `7980` | `33 08` | tag `0x0833` = Text |
| `7982` | `14 00 07 22` | X=20 Y=0 color=7 style=0x22 |
| `7986`… | `44 4f 4f 52 53 20 41 4e 44 20 44 4f 4f 52 42 45 4c 4c d3` | `"DOORS AND DOORBELL"` + `S`\|0x80 → string = **"DOORS AND DOORBELLS"** |
| … | *(13 more Text entries follow, same shape)* | body copy of the in-game tutorial screen |
| `7AAB` | `00 00` | end of Text run, then `0x0000` end-of-room-stream |

The decoded strings for this room are, verbatim: *"DOORS AND DOORBELLS"*,
*"ONE WAY TO OPEN A"*, *"DOOR IS TO USE THE"*, *"DOORBELL.  OPERATE"*, *"THE
DOORBELL BY"*, *"STANDING IN FRONT OF"*, *"IT AND PRESSING THE"*, *"TRIGGER
BUTTON."*, *"TO GO OUT AN OPEN"*, *"DOOR, STAND IN FRONT"*, *"OF THE DOOR AND
MOVE"*, *"THE JOYSTICK LEVER"*, *"FORWARD AND TO THE"*, *"RIGHT."* — this is
exactly the tutorial's on-screen doors/doorbell lesson, which is the main
confirmation that the field layout and text-terminator scheme above are
correct.

Later rooms in the same file exercise every other object type cleanly:
room 3 has 4 Lightning machines + 1 switch, room 5 a Mummy, room 6 a Key,
room 7 a Ray gun, room 8 a Teleport (with 4 receiver pads), room 9 a Trap
door, room 10 a Conveyor, room 11 a Frankenstein — all parsed with the rules
in §4 and no leftover/misaligned bytes.

### The final/bonus room

`$785F` = `0x861F` for `ztutorial.prg`. Its object stream is **Image-only**:
5 separate `0x0836` tags, each an image (the "Dr. Creep" ending graphic,
assembled from pieces) with 3–5 placement coordinates apiece — consistent
with a piece-by-piece reveal animation played when the castle is completed.

## 6. Save file format (`y*`, e.g. `YTUTORIAL`)

`y*` files hold the **high-score table** for one castle, loaded/saved by
`cCastleManager::scoresLoad`/`scoresSave` (castleManager.cpp:459–476) into a
buffer the real engine keeps at **$B800** (confirmed by the extracted file's
own load-address header, `00 b8` = `$B800`).

> Caveat: the C++ port's own `scoresSave` writes `sizeof(mHighScores)` bytes
> using its **native struct layout** (`sHighScore { char mName[3]; size_t
> mSeconds; }`), which — because `size_t` is 4 or 8 bytes on a modern host —
> does **not** match the original C64 on-disk format at all (it would produce
> a much larger, differently-shaped file). The table below describes the
> **original 124-byte on-disk format**, reverse engineered directly from
> `extracted/ytutorial.prg` (and cross-checked against `yfreedonia.prg`,
> `yteasdale.prg`, `ytannenbau.prg`, all also exactly 124 bytes), not the C++
> port's save routine.

Layout (124-byte `.prg` = 2-byte load address `$B800` + 122 data bytes):

| Offset (from $B800) | Size | Field |
|---|---|---|
| +0 (word, LE) | 2 | payload size = 122 (2 + 20×6) |
| +2 | 20 × 6 bytes | high-score table: **2 players × 10 slots**, one 6-byte record per slot |

Each 6-byte record:

| off | field | notes |
|---|---|---|
| 0–2 | name | 3 uppercase ASCII/PETSCII characters, space-padded (initials) |
| 3 | time byte A | small integer, 0–99 in samples — likely seconds or a display-ready (non-pure-binary) time digit, matching the `Hours()/Minutes()/Seconds()` "`+ 6*tens`" BCD-carry-correction pattern seen in `sPlayerTime` (creep.h:236–254) |
| 4 | time byte B | small monotonically-increasing integer (1–5 in samples) — likely minutes |
| 5 | time byte C | `0` in every filled sample slot — likely hours (tutorial times are all under an hour) |

An **empty slot** is six `0xFF` bytes. Player 1 occupies slots 0–9 (offset
`+2`..`+2+59`), player 2 occupies slots 10–19 (offset `+62`..`+121`).

### Worked example — `ytutorial.prg`

```
b800: 7a 00 4d 49 42 16 01 00 45 4c 4d 18 01 00 45 4c
```

- size word = `0x007A` = 122 ✓ (matches file length − 2 − 2).
- slot 0: `4d 49 42 16 01 00` → name `"MIB"`, time bytes `(0x16, 0x01, 0x00)`.
- slot 1: `45 4c 4d 18 01 00` → name `"ELM"`, time bytes `(0x18, 0x01, 0x00)`.
- Player 1's slots 0–9 are all filled (10 real scores); player 2 (slots
  10–19) has only 2 filled entries (`"CHR"`, and a blank `"   "` name) with
  the remaining 8 slots `0xFF`-filled — i.e. this save reflects a tutorial
  castle played mostly by one player.

The exact semantic split of the 3 time bytes (seconds/minutes/hours vs. some
other packing) is **inferred, not disassembly-confirmed** — worth checking
against `disasm/object.s` around the high-score display routine
(`gameHighScores`/`convertTimerToTime` equivalents) before relying on it for
a byte-exact reimplementation.

## 7. Open questions / not fully verified

- The room-directory "skip" word (offset +4/+5) is empirically always
  `objPtr + 2` in both sample files but is never read by the reverse-engineered
  loader — its purpose (if any, beyond level-editor convenience) is unconfirmed.
- Ray gun's part-1 Y coordinate appears to be stored/read twice by the C++
  source (`mParts[2].mY` then again as part of `cObject::objectLoad(pBuffer,1)`);
  the true intent of the two Y-ish fields (7 bytes total per entry) should be
  checked against the disassembly's `eAnimRayGun` handler ($4B1A) if exact
  byte semantics matter.
- Key/Lock's duplicated "colour2" byte (`color+0x50`/`color+0x57`) looks like
  a colour → screen-code translation baked in at save time rather than a
  second logical field, but this isn't confirmed from disassembly.
- `eObjectMultiDraw`/intro-only tags (§4.4) are undocumented even in the
  reference source; irrelevant to normal castle rooms but relevant if the
  intro/menu screen data (`$9800`+) is reverse engineered later.
- The unused header region `$7860`–`$78FF` was not mapped to specific fields;
  only `$7809`–`$785E` and `$785F` have known meanings from the source.
