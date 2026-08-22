// JS host for the wasm build. Fetches the game files (from ./extracted/,
// which you populate locally — game data is not distributed), feeds them to
// the wasm module, and runs the machine at 60 fps onto the canvas.

const status = (msg) => { document.getElementById("status").textContent = msg; };

const { instance } = await WebAssembly.instantiateStreaming(
  fetch("creep.wasm"), {},
);
const wasm = instance.exports;
const mem = () => new Uint8Array(wasm.memory.buffer);

function pushBytes(bytes) {
  const ptr = wasm.wasm_alloc(bytes.length);
  if (!ptr) throw new Error("wasm_alloc failed");
  mem().set(bytes, ptr);
  return ptr;
}

async function fetchBytes(path) {
  const res = await fetch(path);
  if (!res.ok) return null;
  return new Uint8Array(await res.arrayBuffer());
}

status("fetching game files…");
if (!wasm.boot_init()) throw new Error("boot_init failed");

const manifestRes = await fetch("extracted/manifest.txt");
if (!manifestRes.ok) {
  status("missing ./extracted/ — extract your game disk first (see README)");
  throw new Error("no manifest");
}
const names = (await manifestRes.text()).trim().split("\n");
for (const name of names) {
  const data = await fetchBytes(`extracted/${name}.prg`);
  if (!data) continue;
  const nameBytes = new TextEncoder().encode(name);
  const namePtr = pushBytes(nameBytes);
  const dataPtr = pushBytes(data);
  if (!wasm.add_file(namePtr, nameBytes.length, dataPtr, data.length)) {
    throw new Error(`add_file failed for ${name}`);
  }
}

// optional stock font for the boot menu
const chargen = await fetchBytes("chargen.bin");
if (chargen) wasm.set_chargen(pushBytes(chargen), chargen.length);

if (!wasm.boot_start()) {
  status("boot failed — is object.prg present in ./extracted/?");
  throw new Error("boot_start failed");
}
status("running — press space to start");

// ---- input ----------------------------------------------------------------
let joy1 = 0x1f, joy2 = 0x1f;
const JOY1 = { ArrowUp: 0x01, ArrowDown: 0x02, ArrowLeft: 0x04, ArrowRight: 0x08, " ": 0x10 };
const JOY2 = { w: 0x01, s: 0x02, a: 0x04, d: 0x08, Shift: 0x10 };
// C64 keyboard matrix [row, mask]
const KEYS = { Escape: [7, 0x80], Enter: [0, 0x02] };

function updateKey(e, down) {
  const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
  if (k in JOY1) { joy1 = down ? joy1 & ~JOY1[k] : joy1 | JOY1[k]; e.preventDefault(); }
  if (k in JOY2) { joy2 = down ? joy2 & ~JOY2[k] : joy2 | JOY2[k]; e.preventDefault(); }
  if (k in KEYS) { wasm.set_key(KEYS[k][0], KEYS[k][1], down); e.preventDefault(); }
  wasm.set_joy(joy1, joy2);
}
addEventListener("keydown", (e) => updateKey(e, true));
addEventListener("keyup", (e) => updateKey(e, false));

// ---- render loop ----------------------------------------------------------
const canvas = document.getElementById("screen");
const ctx = canvas.getContext("2d");
const W = wasm.fb_width(), H = wasm.fb_height();
const image = ctx.createImageData(W, H);

window.creepWasm = wasm; // debug access from the console

// setInterval rather than requestAnimationFrame (rAF stops entirely in
// occluded windows), with wall-clock catch-up so browser timer throttling
// slows rendering but not emulated time (capped to avoid a death spiral).
const FRAME_MS = 1000 / 60;
const MAX_CATCHUP = 8;
let last = performance.now();
const timer = setInterval(() => {
  const now = performance.now();
  let steps = Math.min(MAX_CATCHUP, Math.floor((now - last) / FRAME_MS));
  if (steps <= 0) return;
  last += steps * FRAME_MS;
  if (now - last > 1000) last = now; // fell too far behind; resync
  while (steps-- > 0) {
    if (!wasm.frame()) {
      status("CPU trapped — see console");
      clearInterval(timer);
      return;
    }
  }
  // the wasm fb is RGBA bytes in memory order, same as ImageData
  const fb = new Uint8ClampedArray(wasm.memory.buffer, wasm.fb_ptr(), W * H * 4);
  image.data.set(fb);
  ctx.putImageData(image, 0, 0);
}, FRAME_MS);
