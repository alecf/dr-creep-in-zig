// The Comet 64 in a browser tab.
//
// Loads game.wasm, runs it at exactly 50 frames a second, copies the
// VIDEO chip's picture onto a canvas, plays the SOUND chip through the
// speakers, and turns the keyboard into two joysticks and a keyboard port.
//
// A page uses it with:
//
//   <canvas data-comet="game.wasm" width="384" height="272" tabindex="0"></canvas>
//   <p data-comet-status></p>     (optional, right after the canvas)
//   <script type="module" src="shell.js"></script>
//
// or, for more control, `import { startComet } from "./shell.js"`.
//
// A machine with a disk drive takes a disk image from the page: a file
// input with `data-comet-disk` (for <canvas id="x">, `data-comet-disk="x"`,
// or the first canvas if it's empty) slots in the file it picks and powers
// on with it, and a button with `data-comet-save-disk` downloads the disk
// as it is now, saves and all. The image is read right here in the page.
//
// Browsers only let a page make sound after the person has clicked or
// pressed a key on it. The sound starts at the first click or key press on
// the canvas; a page that starts the machine from a button can pass its
// own `audio` (an AudioContext made in that click) to start it at once.
// Several machines on one page can share one.

const FRAME_MS = 1000 / 50;
const MAX_CATCH_UP = 5; // frames; beyond this we let time slip instead

// Joystick bits, as in the machine's `joy` table.
const UP = 0x01, DOWN = 0x02, LEFT = 0x04, RIGHT = 0x08, FIRE = 0x10;

// Physical keys (layout-independent) for the two sticks.
const STICK1 = {
  ArrowUp: UP, ArrowDown: DOWN, ArrowLeft: LEFT, ArrowRight: RIGHT,
  KeyW: UP, KeyS: DOWN, KeyA: LEFT, KeyD: RIGHT, Space: FIRE,
};
const STICK2 = { KeyI: UP, KeyK: DOWN, KeyJ: LEFT, KeyL: RIGHT, Enter: FIRE, NumpadEnter: FIRE };

// Non-printing keys that reach the keyboard port.
const SPECIAL = { Enter: 13, Backspace: 8, Escape: 27 };

// What a key event puts in the keyboard port: uppercase ASCII, or 0.
function asciiOf(e) {
  if (e.key.length === 1) {
    const code = e.key.toUpperCase().charCodeAt(0);
    return code < 128 ? code : 0;
  }
  return SPECIAL[e.key] ?? 0;
}

async function instantiate(url, env) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  try {
    return (await WebAssembly.instantiateStreaming(response.clone(), { env })).instance;
  } catch {
    // Some servers don't label .wasm files; fall back to plain bytes.
    return (await WebAssembly.instantiate(await response.arrayBuffer(), { env })).instance;
  }
}

// ---- sound ----
// Each frame slot's samples go into a little buffer, queued to start the
// moment the last one ends. If the queue runs dry (a busy tab, a pause),
// it starts again a little way ahead; if it gets too far ahead, a slot's
// sound is dropped so the speaker never lags the screen.
// The speaker paces itself by the frame loop but plays by the audio clock;
// over minutes the two drift a little, and LEAD/MAX_AHEAD absorb it with a
// tiny gap now and then.
const LEAD = 0.06, MAX_AHEAD = 0.25; // seconds
// comet_listen fills at most this many samples a slot (the wasm buffer).
const SLOT_MAX = 4096;

// An AudioContext at 48,000 samples a second if the browser will make one
// (older browsers refuse the option), or at the device's own rate.
export function makeAudioContext() {
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return null;
  try { return new AC({ sampleRate: 48000 }); } catch {}
  try { return new AC(); } catch { return null; }
}

function makeSpeaker(given) {
  const ctx = given ?? makeAudioContext();
  if (!ctx) return null;
  const rate = ctx.sampleRate;
  const perFrame = rate / 50;
  let next = 0, owed = 0;
  return {
    ctx,
    wake() { if (ctx.state !== "running" && ctx.state !== "closed") ctx.resume().catch(() => {}); },
    // A page's own AudioContext may be shared with other machines, so only
    // one we made ourselves is put to sleep; a paused machine queues nothing.
    sleep() { if (!given && ctx.state === "running") ctx.suspend().catch(() => {}); },
    // One frame slot went by: fetch its samples from the machine and queue them.
    slot(c) {
      owed += perFrame;
      const n = Math.min(Math.floor(owed), SLOT_MAX);
      owed -= Math.floor(owed);
      const samples = new Float32Array(c.memory.buffer, c.comet_listen(rate, n), n);
      if (ctx.state !== "running") return;
      const now = ctx.currentTime;
      if (next < now + 0.005) next = now + LEAD;
      if (next > now + MAX_AHEAD) return;
      const buf = ctx.createBuffer(1, n, rate);
      buf.copyToChannel(samples, 0);
      const src = ctx.createBufferSource();
      src.buffer = buf;
      src.connect(ctx.destination);
      src.start(next);
      next += n / rate;
    },
  };
}

export async function startComet(canvas, { wasm = "game.wasm", status = null, audio = null } = {}) {
  const say = (msg) => { if (status) status.textContent = msg; };
  const decoder = new TextDecoder();
  let c = null; // the machine's exports
  const env = {
    comet_log(ptr, len) {
      console.log("[comet]", decoder.decode(new Uint8Array(c.memory.buffer, ptr, len)));
    },
  };

  async function powerOn() {
    try {
      c = (await instantiate(wasm, env)).exports;
    } catch (err) {
      say(`Couldn't load ${wasm}. Did you run "zig build wasm"?`);
      throw err;
    }
    c.comet_boot();
  }
  await powerOn();

  // ---- the disk drive (machines from Chapter 11 on) ----
  const hasDrive = typeof c.comet_insert === "function";
  function insert(bytes) {
    if (!hasDrive || bytes.length > c.comet_disk_buffer_size()) return false;
    new Uint8Array(c.memory.buffer, c.comet_disk_buffer(), bytes.length).set(bytes);
    return c.comet_insert(bytes.length) === 0;
  }
  function currentDisk() {
    const n = hasDrive ? c.comet_disk_size() : 0;
    return n ? new Uint8Array(c.memory.buffer, c.comet_disk(), n).slice() : null;
  }

  const width = c.comet_width(), height = c.comet_height();
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");

  // ---- input ----
  // Each held key maps to a stick bit; the sticks are rebuilt from the set
  // of held keys, so releasing one of two keys for the same direction
  // doesn't let go of it.
  const held = new Set();
  let joy1 = 0, joy2 = 0;
  function rebuild() {
    joy1 = joy2 = 0;
    for (const code of held) { joy1 |= STICK1[code] ?? 0; joy2 |= STICK2[code] ?? 0; }
  }

  function down(e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return; // leave browser shortcuts alone
    if (e.key === "Tab") return; // so keyboard users can move on
    let used = false;
    if (STICK1[e.code] || STICK2[e.code]) { held.add(e.code); rebuild(); used = true; }
    const ascii = asciiOf(e);
    if (ascii && !e.repeat) { c.comet_key(ascii); used = true; }
    if (used) e.preventDefault();
  }
  function up(e) {
    if (held.delete(e.code)) { rebuild(); e.preventDefault(); }
  }
  canvas.addEventListener("keydown", down);
  canvas.addEventListener("keyup", up);
  canvas.addEventListener("blur", () => { held.clear(); rebuild(); });
  canvas.addEventListener("pointerdown", () => canvas.focus());

  // A machine built before the speaker board has no comet_listen: run it silent.
  const speaker = c.comet_listen ? makeSpeaker(audio) : null;
  if (speaker) {
    speaker.wake();
    canvas.addEventListener("pointerdown", () => speaker.wake());
    canvas.addEventListener("keydown", () => speaker.wake());
  }

  // ---- the frame loop ----
  let running = false, crashed = false, last = 0, owed = 0, handle = 0;

  function draw() {
    const pixels = new Uint8ClampedArray(c.memory.buffer, c.comet_screen(), width * height * 4);
    ctx.putImageData(new ImageData(pixels, width, height), 0, 0);
  }

  function tick(now) {
    if (!running) return;
    owed += now - last;
    last = now;
    if (owed > MAX_CATCH_UP * FRAME_MS) owed = MAX_CATCH_UP * FRAME_MS;
    let ran = false;
    try {
      while (owed >= FRAME_MS) {
        // A long frame uses several slots; the time is spent either way,
        // and the SOUND chip plays through all of them.
        const slots = c.comet_frame(joy1, joy2);
        owed -= slots * FRAME_MS;
        if (speaker) for (let i = 0; i < slots; i++) speaker.slot(c);
        ran = true;
      }
    } catch (err) {
      running = false;
      crashed = true;
      speaker?.sleep();
      draw();
      say("The machine stopped (the game panicked). Details are in the console.");
      throw err;
    }
    if (ran) draw();
    handle = requestAnimationFrame(tick);
  }

  function start() {
    if (running) return;
    running = true; last = performance.now(); owed = 0;
    handle = requestAnimationFrame(tick);
  }

  draw();
  say("");
  start();

  return {
    get exports() { return c; },
    /** A live view of all 64 KB of the machine's RAM. */
    ram: () => new Uint8Array(c.memory.buffer, c.comet_ram(), 0x10000),
    meter: () => c.comet_meter(),
    budget: () => c.comet_budget(),
    /** Last frame's cycles in each of the 8 meter buckets. */
    buckets: () => Array.from({ length: 8 }, (_, i) => c.comet_bucket(i)),
    overruns: () => c.comet_overruns(),
    async reset() {
      // A floppy doesn't forget when the power goes off: keep the disk.
      const keep = currentDisk();
      // After a panic the old instance is in no state to run again.
      if (crashed) { await powerOn(); crashed = false; say(""); } else c.comet_boot();
      if (keep) insert(keep);
      draw();
      start();
    },
    /** True if this machine has a disk drive. */
    hasDrive,
    /** Power on again with the disk image `bytes` (a Uint8Array) in the drive. False if it isn't one. */
    insertDisk(bytes) {
      if (crashed || !hasDrive) return false;
      c.comet_boot();
      const ok = insert(bytes);
      draw();
      start();
      return ok;
    },
    /** A copy of the disk in the drive, saves and all, or null. */
    disk: currentDisk,
    pause() { running = false; cancelAnimationFrame(handle); speaker?.sleep(); },
    resume() { if (!crashed) { speaker?.wake(); start(); } },
    /** The AudioContext the SOUND chip plays through (null if the browser has none). */
    get audio() { return speaker?.ctx ?? null; },
  };
}

// Start every <canvas data-comet="..."> on the page. Its status line is the
// element right after it if that has `data-comet-status`.
for (const canvas of document.querySelectorAll("canvas[data-comet]")) {
  const next = canvas.nextElementSibling;
  const status = next && next.hasAttribute("data-comet-status") ? next : null;
  startComet(canvas, { wasm: canvas.dataset.comet || "game.wasm", status })
    .then((comet) => { canvas.comet = comet; wireDisk(canvas, comet, status); })
    .catch((err) => console.error(err));
}

// The page's disk controls for one machine (see the top of this file).
export function wireDisk(canvas, comet, status, root = document) {
  const mine = (el) => {
    const id = el.dataset.cometDisk ?? el.dataset.cometSaveDisk ?? "";
    return id ? id === canvas.id : canvas === root.querySelector("canvas[data-comet], canvas[data-wasm]");
  };
  for (const input of root.querySelectorAll("input[data-comet-disk]")) {
    if (!mine(input)) continue;
    input.hidden = input.disabled = !comet.hasDrive;
    const label = input.closest("label");
    if (label) label.hidden = !comet.hasDrive;
    input.addEventListener("change", async () => {
      const file = input.files?.[0];
      if (!file) return;
      const ok = comet.insertDisk(new Uint8Array(await file.arrayBuffer()));
      if (status) status.textContent = ok ? `${file.name} is in the drive.` : `${file.name} isn't a disk image (.d64).`;
      canvas.focus();
    });
  }
  for (const button of root.querySelectorAll("button[data-comet-save-disk]")) {
    if (!mine(button)) continue;
    button.hidden = button.disabled = !comet.hasDrive;
    button.addEventListener("click", () => {
      const bytes = comet.disk();
      if (!bytes) return;
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([bytes], { type: "application/octet-stream" }));
      a.download = "comet-disk.d64";
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    });
  }
}
