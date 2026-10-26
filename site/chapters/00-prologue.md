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
the doorbell beside them. The doctor's inventions crackle and hum
along the way, and a couple of residents would rather you left. You can't
fight them. You *can* lure Frankenstein's monster onto a trapdoor, which
is one of the great small pleasures in all of gaming.

The best part is that two of you can play at once, each with a joystick.
One of you holds down the switch that turns a forcefield off while the
other runs through it. It's a
cooperative puzzle game from an era that mostly didn't make those, and
it's still great. Find the exit and you've escaped.

You're going to build all of it.

## The machine: the Comet 64

You're writing for the **Comet 64**, a home computer from 1984. It's a
capable little machine with hard limits, and those limits are the rules
you'll be designing around:

| Limit | What it means |
|---|---|
| **64 KB of memory** | Code, castle, screen and monsters all fit in 65,536 bytes. |
| **1 MHz processor** | About a million tiny steps, called **cycles**, a second. Work is measured in cycles. |
| **50 frames a second** | 19,656 cycles per frame to read the joysticks, move everyone and redraw. |
| **8 hardware sprites** | Eight free-moving pictures over the background, total. |
| **4 colours per 8×8 cell** | The 320×200 screen is cut into 8×8-pixel squares called cells. Each cell gets three colours of its own, plus one background colour shared by the whole screen. |
| **3 voices** | The SOUND chip plays three notes at once, music and effects together. |

Every design decision in this game comes back to that table. Why is the
castle stored as tightly packed bytes instead of a tidy list of objects?
The 64 KB row. Why does the game work so hard never to need a
ninth sprite? The 8-sprite row.

Squeezing a whole castle under these numbers is the fun part. Think of a
level's time limit: nobody plays a platformer and complains that the
clock exists, because the clock is what makes it a game. You also get to
watch your score: a **work meter** on screen shows how many of each
frame's 19,656 cycles your code used.

You don't build the Comet 64; you write the game that runs on it. The
machine comes in the box, along with a web page that runs it in your
browser (the **shell**) and a **headless runner**, which runs your game
from the command line with no window at all. It also comes with a **programmer's reference card**,
[`machine/REFERENCE.md`](../code/machine/REFERENCE.md), the way every
computer of the era came with a thick manual of addresses and registers.
Keep it open in a tab from Chapter 1 on.

## How this site works

Each chapter adds one big piece of the game and ends with it running.
Every listing is shown in full, in the order you type it, so at the
end of each chapter your project matches its finished code, the
**checkpoint** in `code/chNN/`.

Think of the boxes along the way as your strategy guide: tips, what the
new code costs, the bugs everyone hits, and secret passages: optional side trips you
can skip without breaking anything. Each chapter ends with a **Boss Battle** (the
commands to run and what you should see) and a **Warp Zone** (the
finished checkpoint, if you're stuck or want to skip ahead). Some
chapters run the game live on the page, with switches that turn an
optimisation off so you can see what goes wrong without it.

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
to `machine/`, because the build looks for the Comet 64 at `../machine`:

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
with no window, and saves the last frame as a picture:

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

In two seconds of game time your game used 0 of the 19,656 cycles in
each frame. Correct: `frame` doesn't do anything yet.
The picture is a PPM file in `frames/`, which most image viewers open.

Now the real thing, in a browser:

```
zig build wasm
python3 -m http.server -d web
```

That compiles your game to `game.wasm` and puts it in a `web/` folder,
along with the shell page that runs it. Open <http://localhost:8000> and there's the Comet 64: a
purple border around a black screen, and a thin dark bar in the bottom
border. That's the work meter, sitting empty, because your game isn't
doing any work yet. Click the screen so it gets your key presses (arrows or W A S D plus
Space are joystick 1).

Finally, `zig build test` runs your tests (none yet) and runs 100
frames to check the game gets through them without crashing. It prints nothing when
everything passes.

The machine is on and it's running your code. Every room, monster and
doorbell in the castle grows from here.

:::pro-tip Copy without the cache
Zig keeps build work in `.zig-cache/`, and the cache remembers where the
source lives. Copy a built project and the copy gets that cache too,
so it can quietly keep building the *original's* code and ignore
everything you type. So when you copy a project, delete the copy's `.zig-cache`,
`zig-out` and `web`. If you change code and nothing changes on screen,
check this first.
:::

:::warp-zone
The starter kit is at [`code/starter/`](../code/starter/), or as
[`starter.zip`](downloads/starter.zip). If your copy ever gets into a
state you don't like, start over from the kit (or from any checkpoint:
use `ch01`, `ch02` and so on in place of `starter`):

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

The border's colour is set by a single byte in memory. In Chapter 1
you'll find out which one,
change it, and then put something on the screen that answers to your
joystick.
:::
