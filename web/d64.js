// In-browser port of tools/d64.py's extract: parses a 1541 disk image and
// returns its files as [{ name, data }] in directory order, with the same
// names `d64.py extract` writes (minus the extension). The browser never
// uploads the image anywhere — it is read straight into the wasm module.

const SECTORS = [0, ...Array(17).fill(21), ...Array(7).fill(19), ...Array(6).fill(18), ...Array(5).fill(17)];
const OFFSET = [0];
for (let t = 1, off = 0; t <= 35; t++) { OFFSET[t] = off; off += SECTORS[t] * 256; }

export const D64_SIZES = [174848, 175531]; // plain / with error bytes

function sector(img, t, s) {
  if (t < 1 || t > 35 || s >= SECTORS[t]) throw new Error(`bad sector t${t} s${s}`);
  const off = OFFSET[t] + s * 256;
  return img.subarray(off, off + 256);
}

function petsciiToAscii(bytes) {
  let out = "";
  for (const b of bytes) {
    if (b === 0xa0) continue; // padding
    if (b >= 0x41 && b <= 0x5a) out += String.fromCharCode(b).toLowerCase();
    else if (b >= 0xc1 && b <= 0xda) out += String.fromCharCode(b - 0x80);
    else if (b >= 0x20 && b <= 0x5f) out += String.fromCharCode(b);
    else out += "\\x" + b.toString(16).padStart(2, "0");
  }
  return out;
}

const safeName = (name) => name.replace(/[^A-Za-z0-9\-_.]/g, "_") || "unnamed";

function readChain(img, t, s) {
  const parts = [];
  const seen = new Set();
  while (t !== 0) {
    const key = t * 256 + s;
    if (seen.has(key)) throw new Error(`sector loop at t${t} s${s}`);
    seen.add(key);
    const block = sector(img, t, s);
    const [nt, ns] = block;
    parts.push(nt === 0 ? block.subarray(2, ns + 1) : block.subarray(2));
    t = nt; s = ns;
  }
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
}

export function extractD64(img) {
  if (!D64_SIZES.includes(img.length)) throw new Error(`unexpected d64 size ${img.length}`);
  const files = [];
  const seen = new Set();
  let t = 18, s = 1;
  while (t !== 0 && !seen.has(t * 256 + s)) {
    seen.add(t * 256 + s);
    const block = sector(img, t, s);
    for (let i = 0; i < 8; i++) {
      const e = block.subarray(i * 32, i * 32 + 32);
      if (e[2] === 0) continue;
      files.push({ name: safeName(petsciiToAscii(e.subarray(5, 15))), data: readChain(img, e[3], e[4]) });
    }
    t = block[0]; s = block[1];
  }
  return files;
}
