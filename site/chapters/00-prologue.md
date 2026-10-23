---
chapter: 0
title: "The Rules of the Game"
checkpoint: starter
---

:::mission-briefing
Your quest: build *The Castles of Dr. Creep*, a complete two-player
haunted-castle puzzle game, in Zig, for a home computer with 64 KB of
memory and a processor that runs a million cycles a second. Eleven
chapters from now you'll boot it, pick a castle, and play it from the
front gate to the escape door.

This page is the briefing: what the game is, what the machine allows, how
the site works, and how to get the starter kit running. By the end of it
you'll have a purple border glowing in your browser. It's a modest start,
but it's *your* purple border, and it's coming from code you'll be
changing in the very next chapter.
:::

## Welcome to the castles

The doctor isn't home. That's the first thing to know. He's left his
castles unlocked, more or less, and you've let yourself in.

Each castle is a set of rooms. You see one room at a time, side on,
like a doll's house with the front wall taken off: stone floors, ladders
running between them, sliding poles you drop down with a satisfying
*whoosh*. Doors connect the rooms. Most of them are shut, and next to each
shut door there's a **doorbell**. Walk up to it, press fire, and the door
grinds open. Walk through and you're in the next room.

That's the gentle part. The doctor has filled the place with his
inventions.

- **Lightning machines** crackle between ceiling and floor. A switch on the
  wall turns them off, if you can reach the switch. Sometimes one switch
  runs four machines, and sometimes it's on the far side of the one you
  need to get past.
- **Forcefields** block a corridor. A button switches them off for a few
  seconds, and then they're back on. You'd better be fast, or have a
  friend.
- **Trapdoors** open in the floor when someone throws a switch. Fall
  through one and that's a life gone.
- **Conveyor belts** carry whatever stands on them, you included, one way
  or the other depending on the control box.
- **Matter transmitters** are booths that beam you to another booth. Press
  the button to pick a destination by colour, step in, and reappear
  somewhere else in the castle.
- **Ray guns** slide up and down the wall, tracking you, and fire when
  you're level with them. There's a control panel, though. Stand at it and
  *you* steer the gun.
- **Keys** lie around in different colours. Pick one up and it opens the
  **lock** of the same colour, which opens a door somewhere.

And then there are the residents. A **mummy** sleeps in his tomb until
you walk past the ankh, then shuffles after you along the floors. **Frankenstein's
monster** stands in his alcove until you share a floor with him, then
wakes up and comes for you. You can't fight either of them. You *can*
lure Frankenstein onto a trapdoor or into a lightning machine, which is
one of the great small pleasures in all of gaming.

Every castle has a **map**. It starts nearly blank and fills in as you
explore, room by room, with an arrow showing where you are. Somewhere in
the castle is the **exit door**. Get there and you've escaped, and the
game tells you how long it took.

The best part: **two players at once**. Both of you are in the castle
together, each with your own joystick. You can split up and explore, or
stick together, because a lot of rooms are built for two. One of you holds
the forcefield off while the other runs through. One of you rides the
trapdoor switch while the other lures the monster. It's a cooperative
puzzle game from an era that mostly didn't make those, and it's still
great.

You're going to build all of it.

## The machine: the Comet 64

You're writing this game for the **Comet 64**, a home computer from 1984.
It's a capable little machine with hard limits, and those limits are the
rules of the game we're playing. Here they are:

| Limit | What it means for the game |
|---|---|
| **64 KB of memory** | Everything the game is and knows has to fit in 65,536 bytes: the code, the castle, the screen, the monsters, the score. |
| **1 MHz processor** | Roughly a million small steps a second. We count work in **cycles**. |
| **50 frames a second** | The game gets 19,656 cycles per frame to read the joysticks, move everyone, and redraw what changed. |
| **8 hardware sprites** | The VIDEO chip can draw eight free-moving pictures over the background. Players, monsters, lasers: eight, total. |
| **4 colours per 8×8 cell** | The screen is 320×200, split into cells. Each cell picks three colours of its own plus a shared background. |
| **3 voices** | The SOUND chip plays three notes at once. Music and sound effects share them. |

Every design decision in this game comes back to that table. Why is the
castle stored as packed bytes instead of a tidy list of objects? The
first row. Why do the monsters think in such small steps? The third. Why
does the game work so hard to never need a ninth sprite? You can guess.

Treat them like a level's time limit. Nobody plays a platformer and
complains that the clock exists. The clock is what makes it a game.
Squeezing a whole castle under these numbers is the fun part, and you'll
watch yourself doing it: the machine has a **work meter** that shows how
much of each frame your code used.

You don't build the Comet 64 itself. It comes in the box: the hardware, a
browser shell that runs it on a web page, and a headless runner that
plays it from the command line and saves pictures. It also comes with a
**programmer's reference card**,
[`machine/REFERENCE.md`](../code/machine/REFERENCE.md), the way every
computer of the era came with a thick manual of addresses and registers.
You'll keep it open in a tab from Chapter 1 onward. You write the game.

## How this site works

Each chapter adds one big piece of the game and ends with it running. The
code you type is shown in full, file by file, in the order you type it.
Follow along and your project ends the chapter matching that chapter's
**checkpoint**: a complete, working copy of the game at that point, under
`code/chNN/`.

The boxes are your strategy guide:

| Box | What's in it |
|---|---|
| **Mission Briefing** | What the chapter builds, and what you'll have at the end. |
| **Power-Up!** | A technique that saves memory or time, with a name you'll remember. |
| **Byte Budget** | What the new code costs in bytes and cycles. |
| **Pro Tip** | Zig-specific advice, including the quirks of Zig 0.16. |
| **Under the Hood** | How something you'd write in JavaScript or Python actually lands in memory, and what we write instead. |
| **Secret Passage** | An optional deep dive. Skip it and nothing breaks. |
| **Game Over?** | Common mistakes, the bug each one causes, and the fix. |
| **Warp Zone** | A link to the chapter's finished checkpoint. Stuck, or want to skip ahead? Jump in here. |
| **Boss Battle** | The chapter's final stretch: the exact commands to build and run it, and what you should see. |
| **Bonus Stage** | Things to build on your own if you want to keep playing. No answer keys. |
| **Inside the Disk** | How the 1984 game handled the same problem: its real table sizes and tricks. |

Some chapters embed the checkpoint running live on the page, with
widgets around it: a live map of all 64 KB of memory, the frame budget
broken down by part of the game, and switches that turn an optimisation
off so you can see why it's there.

## What you need

- **Zig 0.16.** Download it from the Zig website and put `zig` on your
  path. `zig version` should print `0.16.0` or a later 0.16 release. Zig
  changes quickly between versions, so an older or newer release may not
  build these listings; the Pro Tip boxes point out the 0.16-specific
  bits as they come up.
- **A web browser** made in the last few years.
- **A static web server** to serve one folder. Python's built-in one is
  fine (`python3 -m http.server`), and so is any other.
- **An editor** with Zig support if you can get one (the Zig language
  server, ZLS, gives you errors as you type). Not required.

Then get the tutorial's code folder. It looks like this:

```
code/
  machine/      the Comet 64 and its reference card
  starter/      the starter kit: your game, before Chapter 1
  ch01/         the checkpoint at the end of Chapter 1
  ch02/         ...and so on
```

## Power on

Make your own copy of the starter kit, next to `machine/` so it can find
the computer:

```
cd code
cp -r starter my-creep
cd my-creep
```

Everything from here on happens inside `my-creep`. Inside it are three
files that matter:

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

The first build takes a little while. Then you should see something like
this:

```
ran 100 frames (100 calls to frame)
cycles: max 0 (0%), avg 0 (0%) of 19656
overruns: 0, loading pauses: 0
last frame: frames/frame_00099.ppm
```

A hundred frames, two seconds of game time, and your game used zero
cycles of each one. That's accurate: `frame` doesn't do anything yet. The
picture is in `frames/` as a PPM file, which most image viewers open.

Now the real thing, in a browser:

```
zig build wasm
python3 -m http.server -d web
```

`zig build wasm` compiles your game for the browser and writes the
`web/` folder: the page, the shell that runs the Comet 64, and your game as
`game.wasm`. Open <http://localhost:8000> and you'll see the Comet 64's
screen: a purple border around a black display, and a thin dark bar down
in the bottom border. That bar is the work meter, sitting empty, because
your game isn't doing any work. Click the screen to give it the keyboard
(arrows or W A S D plus Space are joystick 1).

Finally:

```
zig build test
```

That runs your game's own tests (there aren't any yet), then boots it and
plays 100 frames to make sure it gets through them. It prints nothing
when everything passes.

:::warp-zone
The starter kit is at [`code/starter/`](../code/starter/). If your copy
ever gets into a state you don't like, copy it again, or copy any
chapter's checkpoint and carry on from there.
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
