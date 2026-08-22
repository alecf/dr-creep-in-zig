# CLAUDE.md — working notes for AI agents

Read `README.md` first for the project story. This file is operational
knowledge for working in this repo.

## Build & verify

```
zig build                 # builds creep-headless (Zig 0.16.x required)
zig build test            # core unit tests (CPU semantics, banking)
./tools/disassemble.sh    # regenerate disasm/ from extracted/ (idempotent)
```

The end-to-end smoke test (boots the game to playable state, needs
`extracted/` populated from the D64 — see README):

```
./zig-out/bin/creep-headless --frames 9000 --dump-every 500 \
  --press 1400:f:10 --press 2400:f:10 --press 3400:f:10 --press 5000:f:10 --press 6000:l:120
# expect final line ~"ran 9000 frames", vic d011=3b (bitmap mode), d015=01 (player sprite on)
# frames/*.ppm: view with `sips -s format png frame_x.ppm --out x.png`
```

Input script syntax: `--press FRAME:keys[:DURATION]` with keys from
`udlrf` (joystick 1). The known-good sequence above: fire at title →
fire → fire (exit menu / start) → fire on castle map → walk left.

## Zig 0.16 gotchas (cost real time; don't rediscover)

- `std.ArrayList(T)` init is `.empty`, methods take the allocator:
  `list.append(alloc, x)`, `list.deinit(alloc)`.
- No `std.fs.cwd()`; file I/O threads a `std.Io`:
  `pub fn main(init: std.process.Init)` gives `init.io`, `init.gpa`,
  `init.minimal.args`; then `std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(n))`.
- Args: `std.process.Args.Iterator.init(init.minimal.args)`.
- `std.heap.GeneralPurposeAllocator` is gone (use `init.gpa` or
  `std.heap.DebugAllocator`).
- Container fields must precede declarations; `@splat` for array init.

## Architecture invariants

- `src/core/` must stay platform-free (no file I/O, no OS deps) — it is
  the code that must compile for wasm32-freestanding. All I/O goes through
  the in-memory `kernal.Fs` or the host shell (`src/headless.zig`).
- The **lift table** (`Machine.hooks`, keyed by PC) is the single
  interception mechanism. A hook returning `false` falls through to 6502
  code (watchpoint); returning `true` means it fully handled the routine
  (must end with `m.rts()` or explicit PC change). Use fall-through hooks
  for debugging — that's how the RUN/STOP bug was found.
- The VIC renderer reads memory through `Machine.vicRead` (char ROM shadow
  at $1000/$9000 in banks 0/2), never `ram[]` directly.
- Joystick state (`joy1`/`joy2`) is 5-bit active-low; CIA reads OR the
  upper bits back in (`| 0xE0`). Clearing bits 5–7 makes the game see
  RUN/STOP (menu key) held — see README "learned from the binary".

## Key addresses (full map: docs/memory-map.md, disasm/annotations.json)

| addr | what |
|---|---|
| $0800 | engine entry (cold start) |
| $0803–$0838 | public jmp vector table (4 entries protection-scrambled on disk) |
| $0842–$087D | per-object-type handler address table |
| $0A82 / $0B7B | IRQ / NMI handlers (installed at $FFFE/$FFFA) |
| $2E35 | interruptWait counter, decremented once per raster IRQ |
| $5EFC | KeyboardJoystickMonitor (A=player); results: $5F56 dir, $5F57 button |
| $7800 | castle data (relocated from $9800 staging at game start) |
| $9800 | castle/music load staging buffer |
| $B800 | per-castle save data (y files) |
| $CC00 / $E000 | game screen RAM / bitmap (VIC bank 3) |

## Working style for this repo

- The disassembly is *generated* — never hand-edit `disasm/object.s`; fix
  `tools/dis6502.py`, `disasm/annotations.json`, or `tools/disassemble.sh`
  and regenerate.
- When identifying a routine, cross-reference
  `reference/segrax-DrCreep/src/creep.cpp` (clone it if missing:
  `git clone https://github.com/segrax/DrCreep reference/segrax-DrCreep`).
  Its `mMemory[0xNNNN]` addresses are original C64 addresses; comments like
  `// 2C31` mark original routine addresses.
- Debug the emulation with fall-through hooks + PPM frame dumps, comparing
  against VICE (`x64sc "roms/castles of dr creep.d64"`) as ground truth.
- Docs in `docs/` (castle-format, graphics-format, memory-map,
  music-format) are agent-generated analysis: trust but verify against the
  disassembly before building on a detail.
