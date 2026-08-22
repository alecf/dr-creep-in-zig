#!/usr/bin/env python3
"""d64.py — Commodore 1541 disk image (.d64) parser and file extractor.

A .d64 is a raw sector dump of a 5.25" single-sided 1541 floppy:
35 tracks, variable sectors per track (21/19/18/17), 256 bytes per sector,
683 sectors total = 174,848 bytes.

Track 18 holds the filesystem: sector 0 is the BAM (block availability map)
plus disk name; sectors 1+ are directory entries. Files are linked lists of
sectors: the first two bytes of each sector point to (track, sector) of the
next block, or (0, n) in the final block where n = last used byte index.

PRG files begin with a 2-byte little-endian load address.

Usage:
  python3 d64.py dir  <image.d64>              # list directory
  python3 d64.py extract <image.d64> <outdir>  # extract all files
  python3 d64.py map  <image.d64>              # sector usage map
"""

from __future__ import annotations
import sys
import pathlib
from dataclasses import dataclass

SECTORS_PER_TRACK = [0] + [21] * 17 + [19] * 7 + [18] * 6 + [17] * 5  # 1-indexed
TRACK_OFFSET = [0] * 36
_off = 0
for _t in range(1, 36):
    TRACK_OFFSET[_t] = _off
    _off += SECTORS_PER_TRACK[_t] * 256

FILE_TYPES = {0: "DEL", 1: "SEQ", 2: "PRG", 3: "USR", 4: "REL"}

PETSCII_SUBS = {0xA0: ""}  # shifted-space pads directory names


def petscii_to_ascii(data: bytes) -> str:
    out = []
    for b in data:
        if b == 0xA0:  # padding
            continue
        if 0x41 <= b <= 0x5A:  # unshifted letters -> lowercase in ASCII terms
            out.append(chr(b).lower())
        elif 0xC1 <= b <= 0xDA:  # shifted letters
            out.append(chr(b - 0x80))
        elif 0x20 <= b <= 0x5F:
            out.append(chr(b))
        else:
            out.append(f"\\x{b:02x}")
    return "".join(out)


@dataclass
class DirEntry:
    file_type: int
    closed: bool
    locked: bool
    track: int
    sector: int
    raw_name: bytes
    blocks: int

    @property
    def name(self) -> str:
        return petscii_to_ascii(self.raw_name)

    @property
    def type_name(self) -> str:
        return FILE_TYPES.get(self.file_type & 0x07, f"?{self.file_type:02x}")


class D64:
    def __init__(self, path: str | pathlib.Path):
        self.data = pathlib.Path(path).read_bytes()
        if len(self.data) not in (174848, 175531):  # plain / with error bytes
            raise ValueError(f"unexpected d64 size {len(self.data)}")

    def sector(self, track: int, sector: int) -> bytes:
        if not (1 <= track <= 35) or sector >= SECTORS_PER_TRACK[track]:
            raise ValueError(f"bad sector t{track} s{sector}")
        off = TRACK_OFFSET[track] + sector * 256
        return self.data[off : off + 256]

    @property
    def disk_name(self) -> str:
        bam = self.sector(18, 0)
        return petscii_to_ascii(bam[0x90:0xA0])

    def directory(self) -> list[DirEntry]:
        entries = []
        t, s = 18, 1
        seen = set()
        while t != 0 and (t, s) not in seen:
            seen.add((t, s))
            block = self.sector(t, s)
            for i in range(8):
                e = block[i * 32 : i * 32 + 32]
                ftype = e[2]
                if ftype == 0:
                    continue
                entries.append(
                    DirEntry(
                        file_type=ftype,
                        closed=bool(ftype & 0x80),
                        locked=bool(ftype & 0x40),
                        track=e[3],
                        sector=e[4],
                        raw_name=e[5:15],
                        blocks=e[30] | (e[31] << 8),
                    )
                )
            t, s = block[0], block[1]
        return entries

    def read_chain(self, track: int, sector: int) -> bytes:
        """Follow a sector chain, returning the file payload."""
        out = bytearray()
        seen = set()
        t, s = track, sector
        while t != 0:
            if (t, s) in seen:
                raise ValueError(f"sector loop at t{t} s{s}")
            seen.add((t, s))
            block = self.sector(t, s)
            nt, ns = block[0], block[1]
            if nt == 0:
                out += block[2 : ns + 1]  # ns = index of last valid byte
            else:
                out += block[2:]
            t, s = nt, ns
        return bytes(out)

    def extract_file(self, entry: DirEntry) -> bytes:
        return self.read_chain(entry.track, entry.sector)


def safe_filename(name: str) -> str:
    return "".join(c if c.isalnum() or c in "-_." else "_" for c in name) or "unnamed"


def cmd_dir(image: str) -> None:
    d = D64(image)
    print(f'disk name: "{d.disk_name}"')
    print(f"{'blocks':>6}  {'type':4}  name             (start t/s, bytes, load addr)")
    for e in d.directory():
        data = d.extract_file(e)
        load = f"${data[0] | (data[1] << 8):04x}" if e.type_name == "PRG" and len(data) >= 2 else "-"
        lock = "<" if e.locked else " "
        print(f"{e.blocks:>6}  {e.type_name}{lock}  {e.name:16} (t{e.track}/s{e.sector}, {len(data)} bytes, {load})")


def cmd_extract(image: str, outdir: str) -> None:
    d = D64(image)
    out = pathlib.Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    for e in d.directory():
        data = d.extract_file(e)
        ext = e.type_name.lower()
        path = out / f"{safe_filename(e.name)}.{ext}"
        path.write_bytes(data)
        print(f"wrote {path} ({len(data)} bytes)")


def cmd_map(image: str) -> None:
    d = D64(image)
    used: dict[tuple[int, int], str] = {}
    for e in d.directory():
        t, s = e.track, e.sector
        seen = set()
        while t != 0 and (t, s) not in seen:
            seen.add((t, s))
            used[(t, s)] = e.name[:12]
            block = d.sector(t, s)
            t, s = block[0], block[1]
    for track in range(1, 36):
        row = []
        for sec in range(SECTORS_PER_TRACK[track]):
            if track == 18 and sec == 0:
                row.append("BAM")
            elif track == 18:
                row.append("DIR" if (track, sec) in used or sec < 19 else ".")
            else:
                row.append(used.get((track, sec), "."))
        print(f"t{track:02}: " + " ".join(f"{c:>4.4}" for c in row))


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd, image = sys.argv[1], sys.argv[2]
    if cmd == "dir":
        cmd_dir(image)
    elif cmd == "extract":
        cmd_extract(image, sys.argv[3] if len(sys.argv) > 3 else "extracted")
    elif cmd == "map":
        cmd_map(image)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
