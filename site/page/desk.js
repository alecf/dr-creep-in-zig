// The desk view. On a phone or tablet, a checkpoint doesn't play in the
// page: it opens a little room with the Comet 64 on a desk, the game running
// on the monitor behind it, and a touch pad standing in for joystick 1.
//
// The pad doesn't talk to the machine directly. It sends the canvas the same
// key events a keyboard would (arrow keys and Space), so shell.js, which is
// part of the machine every checkpoint ships with, needs no changes.
//
//   import { openDesk } from "./desk.js";
//   openDesk({ canvas, title, power: () => startComet(canvas, ...), onClose });
//
// `power` is called once, the first time; it returns the running machine.

const KEY = { ArrowUp: "ArrowUp", ArrowDown: "ArrowDown", ArrowLeft: "ArrowLeft", ArrowRight: "ArrowRight", Space: " " };

const ROOM = `
<div class="desk-bar">
  <p class="desk-title"></p>
  <button type="button" class="desk-btn" data-act="reset">Reset</button>
  <button type="button" class="desk-btn" data-act="close">Done</button>
</div>
<div class="desk-stage">
  <div class="desk-world">
    <div class="desk-wood"></div>
    <div class="desk-glow"></div>
    <svg class="poster" viewBox="0 0 60 80" aria-hidden="true">
      <rect width="60" height="80" fill="#352879" />
      <circle cx="42" cy="18" r="7" fill="#eee8c8" />
      <path d="M0 62 V48 h6 v-4 h3 v4 h3 v-4 h3 v4 h4 V40 h-2 v-4 h3 v-3 h2 v3 h3 v4 h-2 v8 h8 v-4 h3 v4 h3 v-4 h3 v4 h6 V30 h-2 v-4 h3 v-3 h2 v3 h3 v4 h-2 v32 z" fill="#14112a" />
      <rect y="62" width="60" height="18" fill="#14112a" />
      <text x="30" y="74" text-anchor="middle">CREEP</text>
    </svg>
    <div class="monitor">
      <div class="monitor-top"></div>
      <div class="monitor-face">
        <div class="monitor-glass"><div class="monitor-screen"></div></div>
        <div class="monitor-strip">
          <span class="monitor-name">Comet</span>
          <span class="knob"></span><span class="knob"></span><span class="led"></span>
        </div>
      </div>
      <div class="monitor-foot"></div>
    </div>
    <div class="computer">
      <div class="computer-deck"><div class="keys"></div><div class="fkeys"><i></i><i></i><i></i><i></i></div></div>
      <div class="computer-front">
        <svg class="comet-mark" viewBox="0 0 40 16" aria-hidden="true"><path d="M2 9 C 12 8, 22 5, 30 4" /><path d="M6 13 C 14 12, 22 9, 29 7" /><circle cx="33" cy="6" r="4.5" /></svg>
        <span class="computer-name">Comet 64</span>
        <span class="led"></span>
      </div>
    </div>
  </div>
</div>
<div class="pad">
  <div class="dpad" role="group" aria-label="Joystick">
    <span class="dpad-arm" data-code="ArrowUp"></span><span class="dpad-arm" data-code="ArrowRight"></span>
    <span class="dpad-arm" data-code="ArrowDown"></span><span class="dpad-arm" data-code="ArrowLeft"></span>
    <span class="dpad-hub"></span>
  </div>
  <button type="button" class="fire" data-code="Space" aria-label="Fire">Fire</button>
</div>`;

let room = null;   // the overlay, built on first use
let at = null;     // what's on the desk: { canvas, home, next, comet, onClose, pushed }
let glowTimer = 0;

// ---- the pad ----
// Every finger on the pad maps to a set of keys; what's held is the union,
// so a thumb on the stick and a thumb on Fire work together.
const fingers = new Map(); // pointerId -> Set of key codes
let held = new Set();

function send(code, down) {
  at?.canvas.dispatchEvent(new KeyboardEvent(down ? "keydown" : "keyup", { code, key: KEY[code], bubbles: true, cancelable: true }));
}

// A quick tap can start and end between two frames; hold every key for at
// least a couple of frames so the game sees it.
const MIN_HOLD_MS = 50;
const since = new Map(); // key code -> when it went down

function sync() {
  const want = new Set();
  for (const codes of fingers.values()) for (const c of codes) want.add(c);
  const now = performance.now();
  for (const c of held) {
    if (want.has(c)) continue;
    const wait = since.get(c) + MIN_HOLD_MS - now;
    if (wait > 0 && at) { want.add(c); setTimeout(sync, wait); } else send(c, false);
  }
  let pressed = false;
  for (const c of want) if (!held.has(c)) { send(c, true); since.set(c, now); pressed = true; }
  held = want;
  if (pressed) navigator.vibrate?.(8);
  for (const el of room.querySelectorAll("[data-code]")) el.classList.toggle("on", held.has(el.dataset.code));
}

function releaseAll() {
  fingers.clear();
  if (room) sync();
}

// Which way a finger on the stick points: up to two of the four directions,
// so diagonals work, and nothing near the middle.
function stickCodes(pad, x, y) {
  const r = pad.getBoundingClientRect();
  const dx = x - (r.left + r.width / 2), dy = y - (r.top + r.height / 2);
  const len = Math.hypot(dx, dy);
  const codes = new Set();
  if (len < r.width * 0.08) return codes;
  const nx = dx / len, ny = dy / len;
  if (ny < -0.38) codes.add("ArrowUp");
  if (ny > 0.38) codes.add("ArrowDown");
  if (nx < -0.38) codes.add("ArrowLeft");
  if (nx > 0.38) codes.add("ArrowRight");
  return codes;
}

function wirePad() {
  const pad = room.querySelector(".dpad");
  const fire = room.querySelector(".fire");
  const touch = (el, codesAt) => {
    el.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      el.setPointerCapture(e.pointerId);
      fingers.set(e.pointerId, codesAt(e));
      sync();
    });
    el.addEventListener("pointermove", (e) => {
      if (!fingers.has(e.pointerId)) return;
      fingers.set(e.pointerId, codesAt(e));
      sync();
    });
    const lift = (e) => { if (fingers.delete(e.pointerId)) sync(); };
    el.addEventListener("pointerup", lift);
    el.addEventListener("pointercancel", lift);
    el.addEventListener("lostpointercapture", lift);
    el.addEventListener("contextmenu", (e) => e.preventDefault());
  };
  touch(pad, (e) => stickCodes(pad, e.clientX, e.clientY));
  touch(fire, () => new Set(["Space"]));
}

// ---- the room ----
function build() {
  room = document.createElement("div");
  room.className = "desk";
  room.hidden = true;
  room.setAttribute("role", "dialog");
  room.setAttribute("aria-modal", "true");
  room.setAttribute("aria-label", "Comet 64 on a desk");
  room.innerHTML = ROOM;

  // a 16-wide key grid with a space bar; drawn, not pressable
  const keys = room.querySelector(".keys");
  for (let i = 0; i < 16 * 4; i++) keys.append(document.createElement("i"));
  const space = document.createElement("i");
  space.className = "space";
  keys.append(space);

  room.addEventListener("click", async (e) => {
    const act = e.target.closest("[data-act]")?.dataset.act;
    if (act === "close") closeDesk();
    if (act === "reset" && at?.comet) { await at.comet.reset(); powerFlash(); }
  });
  addEventListener("popstate", () => { if (at) closeDesk(true); });
  document.addEventListener("visibilitychange", () => { if (document.hidden) releaseAll(); });
  wirePad();
  document.body.append(room);
}

function powerFlash() {
  const screen = room.querySelector(".monitor-screen");
  screen.classList.remove("warming");
  void screen.offsetWidth; // restart the animation
  screen.classList.add("warming");
}

// The room is lit by the screen: every few frames, tint the glow on the
// desk with the picture's average colour.
function startGlow(canvas) {
  const probe = document.createElement("canvas");
  probe.width = probe.height = 6;
  const ctx = probe.getContext("2d", { willReadFrequently: true });
  glowTimer = setInterval(() => {
    ctx.drawImage(canvas, 0, 0, 6, 6);
    const d = ctx.getImageData(0, 0, 6, 6).data;
    let r = 0, g = 0, b = 0;
    for (let i = 0; i < d.length; i += 4) { r += d[i]; g += d[i + 1]; b += d[i + 2]; }
    const n = d.length / 4;
    room.style.setProperty("--glow", `rgb(${r / n | 0} ${g / n | 0} ${b / n | 0})`);
  }, 200);
}

export async function openDesk({ canvas, title = "", power, onClose = null }) {
  if (!room) build();
  if (at) closeDesk();
  at = { canvas, home: canvas.parentNode, next: canvas.nextSibling, comet: null, onClose, pushed: false };
  room.querySelector(".desk-title").textContent = title;
  room.querySelector(".monitor-screen").append(canvas);
  room.hidden = false;
  document.documentElement.classList.add("desk-open");
  // The back button (or gesture) closes the room instead of leaving the page.
  history.pushState({ desk: true }, "");
  at.pushed = true;
  room.requestFullscreen?.({ navigationUI: "hide" }).catch(() => {});
  canvas.focus({ preventScroll: true }); // a hardware keyboard still works
  // shell.js lets go of every key when the canvas loses focus; press again
  // whatever is still under a finger
  at.onBlur = () => { held = new Set(); sync(); };
  canvas.addEventListener("blur", at.onBlur);
  // Sharp pixels when the screen is bigger than the picture; smoothed when
  // it's smaller, or whole rows of pixels would drop out.
  at.sizer = new ResizeObserver(([entry]) => {
    const shown = entry.contentRect.height * devicePixelRatio;
    canvas.style.imageRendering = shown < canvas.height ? "auto" : "";
  });
  at.sizer.observe(canvas);
  startGlow(canvas);
  powerFlash();
  const mine = at;
  try {
    const comet = await power();
    if (at !== mine) { comet.pause(); return comet; } // closed while warming up
    at.comet = comet;
    comet.resume();
    return comet;
  } catch (err) {
    if (at === mine) closeDesk();
    throw err;
  }
}

export function closeDesk(fromHistory = false) {
  if (!at) return;
  const was = at;
  releaseAll();
  was.canvas.removeEventListener("blur", was.onBlur);
  was.sizer.disconnect();
  was.canvas.style.imageRendering = "";
  at = null;
  was.comet?.pause();
  clearInterval(glowTimer);
  was.home.insertBefore(was.canvas, was.next);
  room.hidden = true;
  document.documentElement.classList.remove("desk-open");
  if (document.fullscreenElement === room) document.exitFullscreen().catch(() => {});
  if (was.pushed && !fromHistory && history.state?.desk) history.back();
  was.onClose?.();
}
