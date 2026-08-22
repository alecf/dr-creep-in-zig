# Dr. Creep in Zig — Design

*2026-08-22 — initial design, written during autonomous session; decisions
made unilaterally and documented here for review.*

## Goal

An art project: take the original **The Castles of Dr. Creep** (Ed Hobbs,
1984, Commodore 64) disk image, decompile it — D64 → 6502 assembly →
annotated assembly → Zig — and rebuild it as a native macOS (Apple Silicon /
Metal) executable **and** a WebAssembly build that runs in a browser. Along
the way, allow *dynamic modification* of game behavior (the point of the art
project: the code becomes a living, editable artifact rather than a frozen
ROM).

## Source material

`roms/castles of dr creep.d64` (not committed — copyrighted; see README).
Contents:

| file | load addr | size | role |
|---|---|---|---|
| `doctorcre` | $0801 | 61 B | BASIC stub: `LOAD "CREEPLOAD",8,1 : SYS 49152` |
| `creepload` | $C000 | 561 B | Loader: clears screen, loads main files, jumps in |
| `object` | $0800 | 28,873 B | **The game engine** ($0800–$78C8) |
| `pic a title` | $0800 | 10,003 B | Title-screen bitmap (loaded before `object`) |
| `z<castle>` ×14 | $7800 | 1.8–5.6 KB | Castle (level) data, one per castle |
| `y<castle>` ×4+ | $B800 | 124 B | Per-castle saved state (high scores) |
| `music0`–`music8` | $4000 | 2.6–7.7 KB | Music: player code + song data |

The engine is a fixed ~28 KB binary; castles are *data* interpreted by it —
Dr. Creep is effectively a bytecode machine for haunted-castle rooms. This
makes the port tractable: engine once, castles are assets.

## Reference implementations (prior art)

- **[segrax/DrCreep](https://github.com/segrax/DrCreep)** — Robert
  Crossfield's 2010 reverse-engineering of this same binary into C++
  (GPLv3). Cloned to `reference/segrax-DrCreep` (gitignored). Used as a
  *Rosetta Stone* for identifying routines and data structures. Our Zig code
  is written from our own disassembly and analysis; where behavior
  understanding derives from studying segrax's work, we credit it. (If we
  ever copy code structure wholesale, this repo must become GPLv3 —
  currently planned license: GPLv3 anyway, to keep this simple and honest.)
- **VICE** (`x64sc`) — ground-truth emulator for verifying behavior.

## Architecture: the three-stage pipeline

```
Stage 1  EXTRACT     tools/d64.py         D64 → .prg files          [done]
Stage 2  DISASSEMBLE tools/dis6502.py     object.prg → annotated .s
Stage 3  PORT        src/*.zig            annotated .s → Zig, per subsystem
```

### Porting strategy: hybrid lift (decision)

Three options considered:

1. **Pure hand-port** (what segrax did): translate all 6502 to idiomatic
   Zig. Maximal art value, but nothing runs until nearly everything is
   ported, and correctness is hard to establish.
2. **Pure emulation**: embed a 6502 core and run `object` unmodified.
   Runs immediately, but it's an emulator, not a decompilation.
3. **Hybrid lift** ← *chosen*: start from a small 6502 interpreter core in
   Zig executing the original binary, then *progressively replace* original
   routines with native Zig functions at their entry addresses (a jump
   table keyed by PC). Every lifted routine can be differentially tested:
   run emulated vs. native on the same game state and compare memory
   writes. The end state is 100% native Zig with the emulator core left as
   a test harness.

This makes "dynamic modification" natural: any routine, lifted or not, can
be intercepted, and lifted routines are plain Zig you can edit and rebuild.

### Memory model

The C64's 64 KB address space is kept as `[65536]u8` in the Zig port for
fidelity and easy differential testing. Game state lives at the original
addresses during the hybrid phase; the *final* fully-native phase may
migrate hot state into real structs (address map documented in
`docs/memory-map.md`).

### Platform layer (native + wasm)

The C64 presents: 320×200 bitmap/char graphics (VIC-II), 3-voice SID audio,
joystick/keyboard input. The port needs only:

- a 384×272-ish RGBA framebuffer blitted to screen each frame (we render
  VIC-II output ourselves into a texture),
- an audio callback (SID emulation or our own synth reading the music data),
- input events.

**Chosen**: [sokol](https://github.com/floooh/sokol) via
[sokol-zig](https://github.com/floooh/sokol-zig) — native Metal backend on
macOS ARM, WebGL2/WebGPU under wasm (emscripten), one `build.zig` for both.
Fallback if sokol-zig lags Zig 0.16: `wasm32-freestanding` + hand-written JS
canvas/WebAudio glue for web, SDL3 for native.

### VIC-II / SID: emulate the *outputs*, not the chips

The game uses: multicolor char mode for rooms, sprites for actors, raster
IRQ for the status line, SID for music/SFX. We do not need cycle-accurate
chip emulation; we need "given these registers/memory, what pixels/samples
come out for this game specifically." Room rendering and sprite compositing
are reimplemented in Zig from the game's own data structures.

## Repo layout

```
roms/            the .d64 (gitignored)
extracted/       .prg files out of the d64 (gitignored, regenerable)
tools/           python tooling: d64.py, dis6502.py, asset decoders
disasm/          generated + hand-annotated assembly, address maps
docs/            analysis: memory map, castle format, music format, plans/
reference/       gitignored clones of prior art (segrax/DrCreep)
src/             the Zig port
  core/          6502 interpreter + lift table
  game/          lifted/ported game code
  platform/      sokol shell (native + wasm)
build.zig        native + wasm targets
```

## Milestones

- **M0** ✅ tooling: d64 extraction, toolchain installed, repo scaffolding
- **M1** disassembly of `object` with entry-point trace; address map doc
- **M2** asset decoding: castle format, charset/sprites, title pic → PNG
  renders as proof
- **M3** Zig core: 6502 interpreter runs `object` headless; VICE-verified
  checkpoints
- **M4** platform shell: native window renders title screen; wasm build
  renders in browser
- **M5** playable via emulation core (input + render + timing)
- **M6+** progressive lift: routine-by-routine Zig replacement with
  differential tests; music/SID; dynamic-modification playground
