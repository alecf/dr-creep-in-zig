// JS host for the wasm build. Gets the game files, feeds them to the wasm
// module, and runs the machine at 60 fps onto the canvas. Game data is not
// distributed, so the files come from one of (first that works):
//   1. ./extracted/ next to the page (local dev: symlink your extracted dir)
//   2. a disk image the player chose earlier (kept in this browser only)
//   3. a .d64 the player picks or drops onto the page now (#disk input)

import { extractD64 } from "./d64.js";

const status = (msg) => { document.getElementById("status").textContent = msg; };
const DISK_KEY = "creep-d64";

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
  try {
    const res = await fetch(path);
    if (!res.ok) return null;
    return new Uint8Array(await res.arrayBuffer());
  } catch { return null; }
}

async function fromExtracted() {
  let res;
  try { res = await fetch("extracted/manifest.txt"); } catch { return null; }
  if (!res.ok) return null;
  const files = [];
  for (const name of (await res.text()).trim().split("\n")) {
    const data = await fetchBytes(`extracted/${name}.prg`);
    if (data) files.push({ name, data });
  }
  return files;
}

const hasEngine = (files) => files.some((f) => f.name === "object");

function savedDisk() {
  try {
    const b64 = localStorage.getItem(DISK_KEY);
    return b64 ? Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)) : null;
  } catch { return null; }
}
function saveDisk(img) {
  try {
    let bin = "";
    for (let i = 0; i < img.length; i += 0x8000) bin += String.fromCharCode(...img.subarray(i, i + 0x8000));
    localStorage.setItem(DISK_KEY, btoa(bin));
  } catch {}
}
document.getElementById("forget")?.addEventListener("click", () => {
  try { localStorage.removeItem(DISK_KEY); } catch {}
  location.reload();
});

function diskFiles(img) {
  try {
    const files = extractD64(img);
    return hasEngine(files) ? files : null;
  } catch { return null; }
}

// Resolves once the player picks (or drops) a usable disk image.
function askForDisk() {
  const input = document.getElementById("disk");
  if (!input) {
    status("missing ./extracted/ — extract your game disk first (see README)");
    return new Promise(() => {});
  }
  document.body.classList.add("needs-disk");
  status("choose your Dr. Creep .d64 disk image to start");
  return new Promise((resolve) => {
    const take = async (file) => {
      if (!file) return;
      const img = new Uint8Array(await file.arrayBuffer());
      const files = diskFiles(img);
      if (!files) { status(`${file.name} isn't a Castles of Dr. Creep disk image — try another`); return; }
      saveDisk(img);
      document.body.classList.remove("needs-disk");
      resolve(files);
    };
    input.addEventListener("change", () => take(input.files[0]));
    addEventListener("dragover", (e) => e.preventDefault());
    addEventListener("drop", (e) => { e.preventDefault(); take(e.dataTransfer.files[0]); });
  });
}

status("fetching game files…");
let files = await fromExtracted();
if (!files || !hasEngine(files)) {
  const img = savedDisk();
  files = img && diskFiles(img);
  if (files) document.body.classList.add("has-saved-disk");
}
if (!files) files = await askForDisk();

if (!wasm.boot_init()) throw new Error("boot_init failed");
for (const { name, data } of files) {
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
