#!/usr/bin/env python3
"""descramble.py — undo the copy-protection scrambling of object.prg.

The Broderbund protection routine at $2C31 reads a deliberately-errored
disk sector through the drive command channel and XORs the returned status
digits into four bytes of the engine's public jmp vector table:

    $0805 ^= '2' ($32)     jmp #1  $730C -> $410C
    $0808 ^= '2' ($32)     jmp #2  $246A -> $166A
    $080B ^= '7' ($37)     jmp #3  $2047 -> $1747
    $0811 ^= '7' ($37)     jmp #5  $752A -> $422A

(This cracked image hardcodes the expected '2'/'7' values; on an original
disk they came from the drive's error status.) The file on disk is
scrambled; the game descrambles in RAM at boot. For static analysis we want
the descrambled image.

Usage: python3 descramble.py extracted/object.prg extracted/object-descrambled.prg
"""

import pathlib
import sys

PATCHES = {0x0805: 0x32, 0x0808: 0x32, 0x080B: 0x37, 0x0811: 0x37}


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    data = bytearray(pathlib.Path(src).read_bytes())
    load = data[0] | (data[1] << 8)
    for addr, key in PATCHES.items():
        off = addr - load + 2
        old = data[off]
        data[off] ^= key
        print(f"${addr:04x}: ${old:02x} -> ${data[off]:02x}")
    pathlib.Path(dst).write_bytes(data)


if __name__ == "__main__":
    main()
