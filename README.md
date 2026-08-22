# Dr. Creep in Zig

An art project in software archaeology: taking the original 1984 Commodore 64
disk of **The Castles of Dr. Creep** (Ed Hobbs, Broderbund) and decompiling it
— disk image → 6502 assembly → annotated assembly → Zig — until it runs as a
native Apple Silicon macOS app and as WebAssembly in a browser, with the code
open to live modification along the way.

**Status**: the game boots and is *playable* inside this repo's Zig emulation
core — intro, menus, castle map, rooms, player movement, the works — running
the original 28 KB engine binary on a from-scratch 6502 interpreter with a
"lift table" that lets original routines be replaced by native Zig one at a
time.

```
$ zig build
$ ./zig-out/bin/creep-headless --frames 9000 --dump-every 500 \
    --press 1400:f:10 --press 2400:f:10 --press 3400:f:10 --press 5000:f:10
# frames/frame_*.ppm now contain the intro, menu, castle map, and gameplay
```

## Getting the game

The game data is copyrighted and **not included**. You need a D64 disk image
of The Castles of Dr. Creep (the common "dungeonmaster" disk, 174,848 bytes);
place it at `roms/castles of dr creep.d64`. Then:

```
python3 tools/d64.py extract "roms/castles of dr creep.d64" extracted/
./tools/disassemble.sh
```

For the boot menu's stock font, the C64 character ROM is loaded from a VICE
installation if present (`brew install vice`), or from `roms/chargen.bin`.
Everything else — KERNAL, BASIC — is *not needed*: the game banks out all
ROM and this project intercepts its disk I/O directly (see below).

## How it works

### The pipeline

1. **Extract** — `tools/d64.py` parses the 1541 filesystem: 31 files — the
   engine (`object`, loaded at $0800), a boot loader, a title bitmap, 9 music
   files, and per-castle level data (`z*`) + save files (`y*`).
2. **Disassemble** — `tools/dis6502.py` is a recursive-descent tracer: it
   proves code reachable from entry points instead of guessing, currently
   covering 72.7% of the engine as code (the rest is graphics/table data).
   `tools/descramble.py` first undoes a copy-protection XOR on four vector
   table bytes (the disk stores them scrambled; the game fixes them at boot
   using digits read from the floppy drive's error channel — this repo's
   image is a period crack that hardcodes the expected values).
   Routine names in `disasm/object.s` come from `disasm/annotations.json`
   — 147 routines identified by cross-referencing
   [segrax/DrCreep](https://github.com/segrax/DrCreep), Robert Crossfield's
   2010 C++ reverse-engineering of this same binary.
3. **Run / lift** — `src/core/` is a C64 machine model in Zig: a full
   documented-opcode 6502 (`cpu6502.zig`), memory/banking/VIC/SID/CIA model
   (`machine.zig`), and a per-frame VIC-II renderer (`vic.zig`). The core
   mechanism is the **lift table** (`Machine.hooks`): native Zig functions
   keyed by 6502 PC. Today it implements the KERNAL disk API
   (`kernal.zig` — files served from memory, directory listings synthesized
   in 1541 format); tomorrow it replaces game routines one at a time until
   the whole engine is Zig. Every lifted routine can be differential-tested
   against the interpreter.

### Things learned from the binary

- The game runs with **all ROM banked out** ($01 = $05) and its own hardware
  IRQ vector at $0A82 (raster-split driven: sprite DMA, input scan, music).
- The engine is a **bytecode machine**: castles are data files interpreted
  by per-object-type handlers dispatched from a vector table at $0842 —
  doors, keys, forcefields, mummies, matter transmitters, trapdoors,
  conveyors, Frankensteins, lightning machines, ray guns.
- The options menu is opened by the **RUN/STOP key** — discovered the hard
  way when emulated joystick input accidentally held bits 5–7 of the CIA
  port low and the game kept "pressing" RUN/STOP forever.
- The castle menu's order comes from the **disk directory order**
  (`extracted/manifest.txt` preserves it).

## Repo layout

```
tools/       d64.py (disk images), dis6502.py (disassembler),
             descramble.py (protection), disassemble.sh (reproduce)
disasm/      generated assembly, routine JSON, annotations
docs/        analysis: memory-map, castle/graphics/music formats, plans/
src/core/    cpu6502, machine (+lift table), vic renderer, kernal stubs
src/         headless.zig — verification harness (PPM frame dumps,
             scripted joystick input)
roms/        your game disk goes here (gitignored)
extracted/   files pulled out of the d64 (gitignored, regenerable)
reference/   prior-art clones for study (gitignored)
```

## Roadmap

- [x] M0 tooling, extraction, repo scaffolding
- [x] M1 traced + annotated disassembly of the engine
- [x] M3 headless emulation core boots the game (VICE-class behavior for
      this one program, no Commodore ROMs required)
- [x] M5 playable via core (input + render; verified by scripted runs)
- [ ] M4 platform shell: native macOS (Metal) window + wasm build
- [ ] M2 asset decoding: castle format renderer, sprite/charset extraction
- [ ] M6 progressive lift: replace engine routines with Zig, with
      differential tests; SID audio; the dynamic-modification playground

## Credits & license

- Original game: Ed Hobbs / Broderbund Software (1984).
- [segrax/DrCreep](https://github.com/segrax/DrCreep) (GPLv3) — invaluable
  prior reverse-engineering, used as reference for identifying routines.
- [VICE](https://vice-emu.sourceforge.io/) — ground-truth emulator and
  GPL-distributed character ROM.
- This repo's code: **GPLv3** (keeps the reference-derived understanding
  honest). Game data remains copyright its owners and is not distributed.
