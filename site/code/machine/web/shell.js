// The Comet 64 in a browser tab.
//
// Loads game.wasm, runs it at exactly 50 frames a second, copies the
// VIDEO chip's picture onto a canvas, and turns the keyboard into two
// joysticks and a keyboard port.
//
// A page uses it with:
//
//   <canvas data-comet="game.wasm" width="384" height="272" tabindex="0"></canvas>
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

// Non-printing keys that still reach the keyboard port.
const SPECIAL = { Escape: 27, Backspace: 8, Tab: 9 };

export async function startComet(canvas, { wasm = "game.wasm", status = null } = {}) {
  const say = (msg) => { if (status) status.textContent = msg; };
  let memory = null;
  const decoder = new TextDecoder();
  const env = {
    comet_log(ptr, len) {
      console.log("[comet]", decoder.decode(new Uint8Array(memory.buffer, ptr, len)));
    },
  };

  let instance;
  try {
    ({ instance } = await WebAssembly.instantiateStreaming(fetch(wasm), { env }));
  } catch (err) {
    say(`Couldn't load ${wasm}. Did you run "zig build wasm"?`);
    throw err;
  }
  const c = instance.exports;
  memory = c.memory;

  const width = c.comet_width(), height = c.comet_height();
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");

  // ---- input ----
  let joy1 = 0, joy2 = 0;
  const held = new Map(); // key code -> [stick, bit], so release undoes the right thing

  function down(e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return; // leave browser shortcuts alone
    const bit1 = STICK1[e.code], bit2 = STICK2[e.code];
    if (bit1 || bit2) {
      if (bit1) joy1 |= bit1; else joy2 |= bit2;
      held.set(e.code, [bit1 ? 1 : 2, bit1 || bit2]);
    } else if (!e.repeat) {
      let code = SPECIAL[e.key] ?? 0;
      if (e.key.length === 1) code = e.key.toUpperCase().charCodeAt(0);
      if (code > 0 && code < 128) c.comet_key(code);
      else return;
    }
    e.preventDefault();
  }
  function up(e) {
    const h = held.get(e.code);
    if (!h) return;
    if (h[0] === 1) joy1 &= ~h[1]; else joy2 &= ~h[1];
    held.delete(e.code);
    e.preventDefault();
  }
  function releaseAll() { joy1 = joy2 = 0; held.clear(); }

  canvas.addEventListener("keydown", down);
  canvas.addEventListener("keyup", up);
  canvas.addEventListener("blur", releaseAll);
  canvas.addEventListener("pointerdown", () => canvas.focus());

  // ---- the frame loop ----
  let running = true, last = performance.now(), owed = 0, handle = 0;

  function draw() {
    const pixels = new Uint8ClampedArray(memory.buffer, c.comet_screen(), width * height * 4);
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
        c.comet_frame(joy1, joy2);
        owed -= FRAME_MS;
        ran = true;
      }
    } catch (err) {
      running = false;
      draw();
      say("The machine stopped (the game panicked). Details are in the console.");
      throw err;
    }
    if (ran) draw();
    handle = requestAnimationFrame(tick);
  }

  c.comet_boot();
  draw();
  say("");
  handle = requestAnimationFrame(tick);

  return {
    exports: c,
    /** A live view of all 64 KB of the machine's RAM. */
    ram: () => new Uint8Array(memory.buffer, c.comet_ram(), 0x10000),
    meter: () => c.comet_meter(),
    budget: () => c.comet_budget(),
    overruns: () => c.comet_overruns(),
    reset() { c.comet_boot(); draw(); },
    pause() { running = false; cancelAnimationFrame(handle); },
    resume() {
      if (running) return;
      running = true; last = performance.now(); owed = 0;
      handle = requestAnimationFrame(tick);
    },
  };
}

// Start every <canvas data-comet="..."> on the page.
for (const canvas of document.querySelectorAll("canvas[data-comet]")) {
  const status = document.querySelector(`[data-comet-status]`);
  startComet(canvas, { wasm: canvas.dataset.comet || "game.wasm", status })
    .then((comet) => { canvas.comet = comet; })
    .catch((err) => console.error(err));
}
