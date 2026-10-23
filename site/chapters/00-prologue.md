---
chapter: 0
title: "The Rules of the Game"
checkpoint: starter
---

:::mission-briefing
Your quest: build *The Castles of Dr. Creep*, a complete two-player
haunted-castle puzzle game, in Zig, for a home computer with 64 KB of
memory. By the end of this page you'll have the starter kit running and
a purple border glowing in your browser. It's a modest start, but it's
*your* purple border, and you'll be changing it in the very next
chapter.
:::

## Welcome to the castles

The doctor isn't home. That's the first thing to know. He's left his
castles unlocked, more or less, and you've let yourself in.

Each castle is a set of rooms seen side on, like a doll's house with the
front wall taken off: stone floors, ladders, sliding poles you drop down
with a satisfying *whoosh*, and shut doors that grind open when you ring
the doorbell beside them. The doctor's inventions crackle and hum in
between, and a couple of residents would rather you left. You can't
fight them. You *can* lure Frankenstein's monster onto a trapdoor, which
is one of the great small pleasures in all of gaming.

The best part is that two of you can play at once, each with a joystick.
One holds the forcefield off while the other runs through. It's a
cooperative puzzle game from an era that mostly didn't make those, and
it's still great. Find the exit and you've escaped.

You're going to build all of it.

## The machine: the Comet 64

You're writing for the **Comet 64**, a home computer from 1984. It's a
capable little machine with hard limits, and those limits are the rules
of the game we're playing:

| Limit | What it means |
|---|---|
| **64 KB of memory** | Code, castle, screen and monsters all fit in 65,536 bytes. |
| **1 MHz processor** | About a million small steps a second. We count work in **cycles**. |
| **50 frames a second** | 19,656 cycles per frame to read the joysticks, move everyone and redraw. |
| **8 hardware sprites** | Eight free-moving pictures over the background, total. |
| **4 colours per 8×8 cell** | A 320×200 screen; each cell picks three colours plus a shared background. |
| **3 voices** | The SOUND chip plays three notes at once, music and effects together. |

Every design decision in this game comes back to that table. Why is the
castle stored as packed bytes instead of a tidy list of objects? The
first row. Why does the game work so hard never to need a ninth sprite?
The fourth.

Treat the limits like a level's time limit. Nobody plays a platformer
and complains that the clock exists. The clock is what makes it a game.
Squeezing a whole castle under these numbers is the fun part, and you
get to watch yourself doing it: a **work meter** on screen shows how
much of each frame your code used.

You don't build the Comet 64. It comes in the box: the hardware, a
browser shell and a headless runner that plays it from the command
line. It also comes with a **programmer's reference card**,
[`machine/REFERENCE.md`](../code/machine/REFERENCE.md), the way every
computer of the era came with a thick manual of addresses and registers.
You'll keep it open in a tab from Chapter 1 on. You write the game.

## How this site works

Each chapter adds one big piece of the game and ends with it running.
Every listing is shown in full, in the order you type it, so your
project ends each chapter matching its **checkpoint** under `code/chNN/`.

Think of the boxes along the way as your strategy guide: tips, what the
new code costs, the bugs everyone hits, and secret passages you can skip
without breaking anything. Each chapter ends with a **Boss Battle** (the
commands to run and what you should see) and a **Warp Zone** (the
finished checkpoint, if you're stuck or want to skip ahead). Some
chapters run the game live on the page, with switches that turn an
optimisation off so you can watch why it's there.

## What you need

- **Zig 0.16.** `zig version` should print `0.16.0` or a later 0.16
  release. Zig changes fast, so other versions may not build these
  listings.
- **A web browser** and **a static web server**
  (`python3 -m http.server` is fine).
- **An editor** with Zig support, if you can get one (ZLS shows errors
  as you type). Optional.

Then **[download the starter kit](downloads/starter.zip)** and unzip it
anywhere:

```
code/
  machine/      the Comet 64 and its reference card
  starter/      the starter kit: your game, before Chapter 1
```

Chapter checkpoints (`ch01.zip`, ...) unzip into the same place.

## Power on

Time to flip the switch. Copy the starter kit to `code/my-creep/`, next
to `machine/` so it can find the computer:

```
cd code
cp -r starter my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
cd my-creep
```

Everything from here on happens in `code/my-creep/`. Three files matter:

```
src/main.zig     your game: boot() and frame()
build.zig        hooks your game up to the Comet 64
build.zig.zon    says where the Comet 64 lives (../machine)
```

First, the headless runner. It powers the machine on, runs your game
with nobody watching, and saves a picture:

```
zig build run -- --frames 100
```

After a slow first build you should see:

```
ran 100 frames (100 calls to frame)
cycles: max 0 (0%), avg 0 (0%) of 19656
overruns: 0, loading pauses: 0
last frame: frames/frame_00099.ppm
```

A hundred frames, two seconds of game time, and your game used zero
cycles of each one. That's accurate: `frame` doesn't do anything yet.
The picture is a PPM file in `frames/`, which most image viewers open.

Now the real thing, in a browser:

```
zig build wasm
python3 -m http.server -d web
```

That builds your game as `game.wasm` into a `web/` folder with the page
and the shell. Open <http://localhost:8000> and there's the Comet 64: a
purple border around a black screen, and a thin dark bar in the bottom
border. That's the work meter, sitting empty, because your game isn't
doing any work yet. Click the screen to give it the keyboard (arrows or
W A S D plus Space are joystick 1).

Finally, `zig build test` runs your tests (none yet) and plays 100
frames to make sure the game gets through them. It prints nothing when
everything passes.

The machine is on and it's running your code. Every room, monster and
doorbell in the castle grows from here.

:::pro-tip Copy without the cache
Zig keeps build work in `.zig-cache/`, and the cache remembers where the
source lives. Copy a built project cache and all, and the copy can
quietly keep building the *original's* code, ignoring everything you
type. So when you copy a project, delete the copy's `.zig-cache`,
`zig-out` and `web`. If you change code and nothing changes on screen,
check this first.
:::

:::warp-zone
The starter kit is at [`code/starter/`](../code/starter/), or as
[`starter.zip`](downloads/starter.zip). If your copy ever gets into a
state you don't like, start over from the kit (or from any checkpoint,
swapping in `ch01` or whichever for `starter`):

```
cd code
rm -rf my-creep
cp -r starter my-creep
rm -rf my-creep/.zig-cache my-creep/zig-out my-creep/web
```
:::

:::boss-battle
Three commands, three results:

- `zig build run -- --frames 100` prints `ran 100 frames` and saves
  `frames/frame_00099.ppm`.
- `zig build wasm`, then `python3 -m http.server -d web` and open
  <http://localhost:8000>: a purple border, a black screen, an empty
  meter.
- `zig build test` prints nothing and exits cleanly.

That purple border is a byte. In Chapter 1 you'll find out which one,
change it, and then put something on the screen that answers to your
joystick.
:::
