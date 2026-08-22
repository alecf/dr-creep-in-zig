#!/usr/bin/env python3
"""dis6502.py — tracing 6502 disassembler for C64 .prg files.

Recursive-descent: starts from declared entry points, follows JSR/JMP/branch
targets, and marks every byte it can prove reachable as code; the rest is
emitted as data. This beats linear-sweep on 6502 binaries, which interleave
code and data freely.

Outputs assembly (with labels, xrefs, and C64 hardware/KERNAL symbols) and a
JSON sidecar of discovered routines for downstream tooling.

Usage:
  python3 dis6502.py <file.prg> [--entry 0xC000 ...] [--data 0xA000-0xAFFF ...]
                     [--vector 0xC123 ...] [--json out.json] [-o out.s]

  --entry   address(es) to begin tracing from (default: load address)
  --data    address range(s) to force as data (never traced)
  --vector  address(es) holding a 2-byte little-endian code pointer (each is
            emitted as .word and its target traced)
"""

from __future__ import annotations
import argparse
import json
import pathlib
import sys

# (mnemonic, addressing mode). Modes: imp acc imm zp zpx zpy abs abx aby ind izx izy rel
OPCODES: dict[int, tuple[str, str]] = {}


def _op(code, mnem, mode):
    OPCODES[code] = (mnem, mode)


# fmt: off
for c, m, md in [
    (0x00,"brk","imp"),(0x01,"ora","izx"),(0x05,"ora","zp"),(0x06,"asl","zp"),
    (0x08,"php","imp"),(0x09,"ora","imm"),(0x0A,"asl","acc"),(0x0D,"ora","abs"),
    (0x0E,"asl","abs"),(0x10,"bpl","rel"),(0x11,"ora","izy"),(0x15,"ora","zpx"),
    (0x16,"asl","zpx"),(0x18,"clc","imp"),(0x19,"ora","aby"),(0x1D,"ora","abx"),
    (0x1E,"asl","abx"),(0x20,"jsr","abs"),(0x21,"and","izx"),(0x24,"bit","zp"),
    (0x25,"and","zp"),(0x26,"rol","zp"),(0x28,"plp","imp"),(0x29,"and","imm"),
    (0x2A,"rol","acc"),(0x2C,"bit","abs"),(0x2D,"and","abs"),(0x2E,"rol","abs"),
    (0x30,"bmi","rel"),(0x31,"and","izy"),(0x35,"and","zpx"),(0x36,"rol","zpx"),
    (0x38,"sec","imp"),(0x39,"and","aby"),(0x3D,"and","abx"),(0x3E,"rol","abx"),
    (0x40,"rti","imp"),(0x41,"eor","izx"),(0x45,"eor","zp"),(0x46,"lsr","zp"),
    (0x48,"pha","imp"),(0x49,"eor","imm"),(0x4A,"lsr","acc"),(0x4C,"jmp","abs"),
    (0x4D,"eor","abs"),(0x4E,"lsr","abs"),(0x50,"bvc","rel"),(0x51,"eor","izy"),
    (0x55,"eor","zpx"),(0x56,"lsr","zpx"),(0x58,"cli","imp"),(0x59,"eor","aby"),
    (0x5D,"eor","abx"),(0x5E,"lsr","abx"),(0x60,"rts","imp"),(0x61,"adc","izx"),
    (0x65,"adc","zp"),(0x66,"ror","zp"),(0x68,"pla","imp"),(0x69,"adc","imm"),
    (0x6A,"ror","acc"),(0x6C,"jmp","ind"),(0x6D,"adc","abs"),(0x6E,"ror","abs"),
    (0x70,"bvs","rel"),(0x71,"adc","izy"),(0x75,"adc","zpx"),(0x76,"ror","zpx"),
    (0x78,"sei","imp"),(0x79,"adc","aby"),(0x7D,"adc","abx"),(0x7E,"ror","abx"),
    (0x81,"sta","izx"),(0x84,"sty","zp"),(0x85,"sta","zp"),(0x86,"stx","zp"),
    (0x88,"dey","imp"),(0x8A,"txa","imp"),(0x8C,"sty","abs"),(0x8D,"sta","abs"),
    (0x8E,"stx","abs"),(0x90,"bcc","rel"),(0x91,"sta","izy"),(0x94,"sty","zpx"),
    (0x95,"sta","zpx"),(0x96,"stx","zpy"),(0x98,"tya","imp"),(0x99,"sta","aby"),
    (0x9A,"txs","imp"),(0x9D,"sta","abx"),(0xA0,"ldy","imm"),(0xA1,"lda","izx"),
    (0xA2,"ldx","imm"),(0xA4,"ldy","zp"),(0xA5,"lda","zp"),(0xA6,"ldx","zp"),
    (0xA8,"tay","imp"),(0xA9,"lda","imm"),(0xAA,"tax","imp"),(0xAC,"ldy","abs"),
    (0xAD,"lda","abs"),(0xAE,"ldx","abs"),(0xB0,"bcs","rel"),(0xB1,"lda","izy"),
    (0xB4,"ldy","zpx"),(0xB5,"lda","zpx"),(0xB6,"ldx","zpy"),(0xB8,"clv","imp"),
    (0xB9,"lda","aby"),(0xBA,"tsx","imp"),(0xBC,"ldy","abx"),(0xBD,"lda","abx"),
    (0xBE,"ldx","aby"),(0xC0,"cpy","imm"),(0xC1,"cmp","izx"),(0xC4,"cpy","zp"),
    (0xC5,"cmp","zp"),(0xC6,"dec","zp"),(0xC8,"iny","imp"),(0xC9,"cmp","imm"),
    (0xCA,"dex","imp"),(0xCC,"cpy","abs"),(0xCD,"cmp","abs"),(0xCE,"dec","abs"),
    (0xD0,"bne","rel"),(0xD1,"cmp","izy"),(0xD5,"cmp","zpx"),(0xD6,"dec","zpx"),
    (0xD8,"cld","imp"),(0xD9,"cmp","aby"),(0xDD,"cmp","abx"),(0xDE,"dec","abx"),
    (0xE0,"cpx","imm"),(0xE1,"sbc","izx"),(0xE4,"cpx","zp"),(0xE5,"sbc","zp"),
    (0xE6,"inc","zp"),(0xE8,"inx","imp"),(0xE9,"sbc","imm"),(0xEA,"nop","imp"),
    (0xEC,"cpx","abs"),(0xED,"sbc","abs"),(0xEE,"inc","abs"),(0xF0,"beq","rel"),
    (0xF1,"sbc","izy"),(0xF5,"sbc","zpx"),(0xF6,"inc","zpx"),(0xF8,"sed","imp"),
    (0xF9,"sbc","aby"),(0xFD,"sbc","abx"),(0xFE,"inc","abx"),
]:
    _op(c, m, md)
# fmt: on

MODE_LEN = {"imp": 1, "acc": 1, "imm": 2, "zp": 2, "zpx": 2, "zpy": 2,
            "abs": 3, "abx": 3, "aby": 3, "ind": 3, "izx": 2, "izy": 2, "rel": 2}

# C64 symbols worth naming in output
C64_SYMBOLS = {
    0xD000: "VIC_SP0X", 0xD001: "VIC_SP0Y", 0xD010: "VIC_SPMSBX",
    0xD011: "VIC_CTRL1", 0xD012: "VIC_RASTER", 0xD015: "VIC_SPENA",
    0xD016: "VIC_CTRL2", 0xD017: "VIC_SPEXPY", 0xD018: "VIC_MEMPTR",
    0xD019: "VIC_IRQFLAG", 0xD01A: "VIC_IRQMASK", 0xD01B: "VIC_SPPRIO",
    0xD01C: "VIC_SPMC", 0xD01D: "VIC_SPEXPX", 0xD01E: "VIC_SPSPCL",
    0xD01F: "VIC_SPBGCL", 0xD020: "VIC_BORDER", 0xD021: "VIC_BG0",
    0xD022: "VIC_BG1", 0xD023: "VIC_BG2", 0xD025: "VIC_SPMC0",
    0xD026: "VIC_SPMC1", 0xD027: "VIC_SP0COL",
    0xD400: "SID_V1FREQLO", 0xD401: "SID_V1FREQHI", 0xD404: "SID_V1CTRL",
    0xD405: "SID_V1AD", 0xD406: "SID_V1SR", 0xD40B: "SID_V2CTRL",
    0xD412: "SID_V3CTRL", 0xD418: "SID_VOLUME",
    0xDC00: "CIA1_PRA", 0xDC01: "CIA1_PRB", 0xDC02: "CIA1_DDRA",
    0xDC03: "CIA1_DDRB", 0xDC04: "CIA1_TALO", 0xDC05: "CIA1_TAHI",
    0xDC0D: "CIA1_ICR", 0xDC0E: "CIA1_CRA",
    0xDD00: "CIA2_PRA", 0xDD0D: "CIA2_ICR",
    0x0314: "IRQ_VECTOR_LO", 0x0315: "IRQ_VECTOR_HI",
    0xFFD2: "KERNAL_CHROUT", 0xFFE4: "KERNAL_GETIN", 0xFFC6: "KERNAL_CHKIN",
    0xFFBA: "KERNAL_SETLFS", 0xFFBD: "KERNAL_SETNAM", 0xFFD5: "KERNAL_LOAD",
    0xFFD8: "KERNAL_SAVE", 0xFFC0: "KERNAL_OPEN", 0xFFC3: "KERNAL_CLOSE",
    0xFFCF: "KERNAL_CHRIN", 0xFFCC: "KERNAL_CLRCHN", 0xFFC9: "KERNAL_CHKOUT",
    0xFFE7: "KERNAL_CLALL", 0xFFDB: "KERNAL_SETTIM", 0xFFEA: "KERNAL_UDTIM",
}


class Disassembler:
    def __init__(self, data: bytes, load_addr: int):
        self.mem = data
        self.load = load_addr
        self.end = load_addr + len(data)
        # per-address flags
        self.is_code: set[int] = set()
        self.is_opstart: set[int] = set()
        self.labels: dict[int, str] = {}
        self.xrefs: dict[int, set[int]] = {}
        self.call_targets: set[int] = set()
        self.vectors: set[int] = set()
        self.forced_data: set[int] = set()
        self.pending: list[int] = []
        self.indirect_jumps: list[int] = []

    def in_range(self, a: int) -> bool:
        return self.load <= a < self.end

    def byte(self, a: int) -> int:
        return self.mem[a - self.load]

    def add_entry(self, a: int, is_call: bool = False, src: int | None = None):
        if src is not None:
            self.xrefs.setdefault(a, set()).add(src)
        if is_call:
            self.call_targets.add(a)
        if self.in_range(a) and a not in self.is_opstart and a not in self.forced_data:
            self.pending.append(a)

    def trace(self):
        while self.pending:
            pc = self.pending.pop()
            while self.in_range(pc) and pc not in self.is_opstart and pc not in self.forced_data:
                op = self.byte(pc)
                if op not in OPCODES:
                    break  # illegal opcode: assume we mis-traced into data
                mnem, mode = OPCODES[op]
                length = MODE_LEN[mode]
                if pc + length > self.end:
                    break
                self.is_opstart.add(pc)
                for i in range(length):
                    self.is_code.add(pc + i)
                operand = 0
                if length == 2:
                    operand = self.byte(pc + 1)
                elif length == 3:
                    operand = self.byte(pc + 1) | (self.byte(pc + 2) << 8)
                if mode == "rel":
                    target = pc + 2 + (operand - 256 if operand >= 128 else operand)
                    self.add_entry(target, src=pc)
                    pc += length
                    continue
                if mnem == "jsr":
                    self.add_entry(operand, is_call=True, src=pc)
                    pc += length
                    continue
                if mnem == "jmp":
                    if mode == "abs":
                        self.add_entry(operand, src=pc)
                    else:
                        self.indirect_jumps.append(pc)
                    break
                if mnem in ("rts", "rti", "brk"):
                    break
                pc += length

    def label_for(self, a: int) -> str | None:
        if a in self.labels:
            return self.labels[a]
        if a in C64_SYMBOLS:
            return C64_SYMBOLS[a]
        if self.in_range(a) and a in self.is_opstart:
            return ("sub_%04X" if a in self.call_targets else "loc_%04X") % a
        return None

    def assign_labels(self):
        for a in sorted(self.xrefs):
            if self.in_range(a) and a in self.is_opstart:
                self.labels[a] = ("sub_%04X" if a in self.call_targets else "loc_%04X") % a

    def fmt_operand(self, mode: str, operand: int, pc: int) -> str:
        def sym(addr: int) -> str:
            name = self.label_for(addr)
            return name if name else f"${addr:04x}"

        if mode in ("imp",):
            return ""
        if mode == "acc":
            return "a"
        if mode == "imm":
            return f"#${operand:02x}"
        if mode == "zp":
            return f"${operand:02x}"
        if mode == "zpx":
            return f"${operand:02x},x"
        if mode == "zpy":
            return f"${operand:02x},y"
        if mode == "abs":
            return sym(operand)
        if mode == "abx":
            return f"{sym(operand)},x"
        if mode == "aby":
            return f"{sym(operand)},y"
        if mode == "ind":
            return f"({sym(operand)})"
        if mode == "izx":
            return f"(${operand:02x},x)"
        if mode == "izy":
            return f"(${operand:02x}),y"
        if mode == "rel":
            target = pc + 2 + (operand - 256 if operand >= 128 else operand)
            return sym(target)
        raise AssertionError(mode)

    def emit(self, out) -> None:
        w = out.write
        w(f"; disassembly of {self.end - self.load} bytes @ ${self.load:04x}-${self.end - 1:04x}\n")
        w("; generated by tools/dis6502.py — tracing disassembler\n\n")
        w(f"        .org ${self.load:04x}\n\n")
        pc = self.load
        while pc < self.end:
            label = self.label_for(pc)
            if label and label.startswith("sub_"):
                refs = ",".join(f"${r:04x}" for r in sorted(self.xrefs.get(pc, [])))
                w(f"\n; ---------- routine (called from {refs}) ----------\n")
            if label:
                w(f"{label}:\n")
            if pc in self.is_opstart:
                op = self.byte(pc)
                mnem, mode = OPCODES[op]
                length = MODE_LEN[mode]
                raw = " ".join(f"{self.byte(pc + i):02x}" for i in range(length))
                w(f"        {mnem} {self.fmt_operand(mode, self._operand(pc, mode), pc):24} ; {pc:04x}: {raw}\n")
                pc += length
            else:
                # data run: until next code or labeled address
                start = pc
                row = []
                while pc < self.end and pc not in self.is_opstart:
                    if pc != start and self.label_for(pc):
                        break
                    row.append(self.byte(pc))
                    pc += 1
                    if len(row) == 16:
                        self._emit_data_row(w, start, row)
                        start, row = pc, []
                if row:
                    self._emit_data_row(w, start, row)

    def _operand(self, pc: int, mode: str) -> int:
        length = MODE_LEN[mode]
        if length == 2:
            return self.byte(pc + 1)
        if length == 3:
            return self.byte(pc + 1) | (self.byte(pc + 2) << 8)
        return 0

    @staticmethod
    def _emit_data_row(w, addr: int, row: list[int]) -> None:
        hexs = ",".join(f"${b:02x}" for b in row)
        txt = "".join(chr(b) if 0x20 <= b < 0x7F else "." for b in row)
        w(f"        .byte {hexs:56} ; {addr:04x} |{txt}|\n")

    def routines_json(self) -> list[dict]:
        subs = sorted(a for a in self.call_targets if self.in_range(a))
        out = []
        for a in subs:
            out.append({
                "address": f"0x{a:04X}",
                "name": f"sub_{a:04X}",
                "callers": sorted(f"0x{r:04X}" for r in self.xrefs.get(a, [])),
            })
        return out


def parse_range(s: str) -> tuple[int, int]:
    lo, hi = s.split("-")
    return int(lo, 0), int(hi, 0)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("prg")
    ap.add_argument("--entry", action="append", default=[])
    ap.add_argument("--data", action="append", default=[])
    ap.add_argument("--vector", action="append", default=[])
    ap.add_argument("--symbols", help="JSON file: {routines:[{address,name,...}]} — names applied to labels")
    ap.add_argument("--json")
    ap.add_argument("-o", "--output")
    args = ap.parse_args()

    raw = pathlib.Path(args.prg).read_bytes()
    load = raw[0] | (raw[1] << 8)
    data = raw[2:]
    d = Disassembler(data, load)

    for r in args.data:
        lo, hi = parse_range(r)
        d.forced_data.update(range(lo, hi + 1))
    for v in args.vector:
        a = int(v, 0)
        if d.in_range(a):
            target = d.byte(a) | (d.byte(a + 1) << 8)
            d.vectors.add(a)
            d.add_entry(target, is_call=True)
    entries = [int(e, 0) for e in args.entry] or [load]
    for e in entries:
        d.add_entry(e, is_call=True)

    d.trace()
    d.assign_labels()

    if args.symbols:
        symdoc = json.loads(pathlib.Path(args.symbols).read_text())
        for r in symdoc.get("routines", []):
            addr = int(r["address"], 16)
            if d.in_range(addr):
                d.labels[addr] = r["name"]

    out = open(args.output, "w") if args.output else sys.stdout
    d.emit(out)
    if args.output:
        out.close()

    code = len(d.is_code)
    total = len(data)
    print(f"; {args.prg}: {total} bytes, {code} traced as code ({100*code/total:.1f}%), "
          f"{len([a for a in d.call_targets if d.in_range(a)])} routines, "
          f"{len(d.indirect_jumps)} indirect jumps at "
          + ",".join(f"${a:04x}" for a in d.indirect_jumps), file=sys.stderr)

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps({
            "file": args.prg, "load": f"0x{load:04X}",
            "routines": d.routines_json(),
            "indirect_jumps": [f"0x{a:04X}" for a in d.indirect_jumps],
        }, indent=1))


if __name__ == "__main__":
    main()
