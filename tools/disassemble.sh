#!/bin/bash
# Reproducible disassembly of the Dr. Creep binaries.
# Run from repo root after `python3 tools/d64.py extract "roms/castles of dr creep.d64" extracted/`
#
# Entry points and vector tables below were discovered by analysis (see
# docs/plans/2026-08-22-drcreep-port-design.md and disasm/annotations.json):
#   $0800        cold start (creepload does `jmp $0800`)
#   $0803-$0838  jmp vector table: 18 public engine entry points
#                (four entries are XOR-scrambled on disk by the copy
#                protection — tools/descramble.py undoes that first)
#   $0842-$087D  word table: per-object-type handler addresses
#   $088F+       6 records x 8 bytes: {fnA, fnB, fnC, flags} actor handlers
#   $0A82/$0B7B  hardware IRQ / NMI handlers ($FFFE/$FFFA, ROM banked out)
set -euo pipefail
cd "$(dirname "$0")/.."

python3 tools/descramble.py extracted/object.prg extracted/object-descrambled.prg

ENTRIES="--entry 0x0800 --entry 0x0A82 --entry 0x0B7B"
for a in $(python3 -c "print(' '.join(f'0x{a:04X}' for a in range(0x0803,0x0839,3)))"); do
  ENTRIES="$ENTRIES --entry $a"
done

VECTORS=""
for a in $(python3 -c "
v = [f'0x{a:04X}' for a in range(0x0842,0x087E,2)]
for base in range(0x088F, 0x088F+6*8, 8):
    v += [f'0x{base+o:04X}' for o in (0,2,4)]
print(' '.join(v))"); do
  VECTORS="$VECTORS --vector $a"
done

SYMBOLS=""
if [ -f disasm/annotations.json ]; then
  SYMBOLS="--symbols disasm/annotations.json"
fi

python3 tools/dis6502.py extracted/object-descrambled.prg $ENTRIES $VECTORS $SYMBOLS \
  -o disasm/object.s --json disasm/object.json

python3 tools/dis6502.py extracted/creepload.prg \
  -o disasm/creepload.s --json disasm/creepload.json

echo "done: disasm/object.s disasm/creepload.s"
