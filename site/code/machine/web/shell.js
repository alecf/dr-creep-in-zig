// The Comet 64 in a browser tab.
//
// Loads game.wasm, runs it at exactly 50 frames a second, copies the
// VIDEO chip's picture onto a canvas, and turns the keyboard into two
// joysticks and a keyboard port.
//
// A page uses it with:
//
//   <canvas data-comet="game.wasm" width="384" height="272" tabindex="0"></canvas>
//   <p data-comet-status></p>     (optional, right after the canvas)
//   <script type="module" src="shell.js"></script>
//
// or, for more control, `import { startComet } from "./shell.js"`.

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

export async function startComet(canvas, { wasm = "game.wasm", status = null } = {}) {
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
        // A long frame uses several slots; the time is spent either way.
        owed -= c.comet_frame(joy1, joy2) * FRAME_MS;
        ran = true;
      }
    } catch (err) {
      running = false;
      crashed = true;
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
      // After a panic the old instance is in no state to run again.
      if (crashed) { await powerOn(); crashed = false; say(""); } else c.comet_boot();
      draw();
      start();
    },
    pause() { running = false; cancelAnimationFrame(handle); },
    resume() { if (!crashed) start(); },
  };
}

// Start every <canvas data-comet="..."> on the page. Its status line is the
// element right after it if that has `data-comet-status`.
for (const canvas of document.querySelectorAll("canvas[data-comet]")) {
  const next = canvas.nextElementSibling;
  const status = next && next.hasAttribute("data-comet-status") ? next : null;
  startComet(canvas, { wasm: canvas.dataset.comet || "game.wasm", status })
    .then((comet) => { canvas.comet = comet; })
    .catch((err) => console.error(err));
}
