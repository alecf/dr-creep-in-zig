# Checkpoint: Chapter 6, "Flip the Switch"

The game at the end of Chapter 6: the castle's machines. One pattern runs
them all: a *control* (a switch, a button, a plate in the floor, a control
box, a booth) linked to a *device* (lightning machines, a forcefield, a
trapdoor, a conveyor belt, a set of pads), by number, never by pointer.
Training Castle rooms 4 to 8 work:

- **Lightning**: two machines with crackling bolts (actors), and a switch
  upstairs that names both machines by their place in the castle. Push the
  stick down at it to stop them, up to start them. Touch a bolt and you die.
- **Forcefields**: the field is an actor and a wall in the navigation grid.
  Its button takes it down; the gauge counts 240 engine steps back up.
- **Trapdoors**: an open trapdoor is a wall in the grid. Step onto its
  switch and it flips, once. Fall in (a belt can carry you) and you die.
- **Conveyors**: the belt carries whoever stands on it. Its control box
  stops it, and starts it again the other way. The slats move by
  recolouring cells, not by drawing.
- **The transmitter**: push up in the booth to move the lamp to the next
  pad's colour, press fire to go there.

The engine gained 1984's sprite-sprite check (per-kind `hit` handlers and
group masks) and per-kind `touch` handlers for objects.

Keys: N and P flip rooms; G draws the grid; Q searches instead of reading
the grid (and walks through forcefields and open trapdoors: the castle
alone doesn't know about them); C makes every actor check every object
every turn; X gives up a life.

```
src/main.zig         boot(), frame(), the game's modes and the engine step, whole-game tests
src/map.zig          the game's memory map, checked at compile time
src/actors.zig       the actor table: slots, kinds, turns, sprite-sprite hits, flickering
src/objects.zig      the object table: slots, flags, handlers, finding by number, touching
src/doors.zig        doors and doorbells: ringing, opening, walking in
src/lightning.zig    lightning machines, their bolts, and their switches
src/forcefields.zig  forcefields, their buttons and gauges
src/trapdoors.zig    trapdoors and the switches in the floor
src/conveyors.zig    conveyor belts and their control boxes
src/transmitter.zig  the matter transmitter: booth, lamp and pads
src/player.zig       the explorer: joystick, steps, ladders, poles, doorways, deaths
src/grid.zig         the navigation grid: building it, walls, reading it, the slow search
src/sprites.zig      unpacking sprite frames; castle coordinates to sprite registers
src/debug.zig        the G, Q, C and X keys
src/castle.zig       the castle format: header, room directory, tags, records, the stream walker
src/author.zig       the castle-authoring kit: declarations in, checked castle bytes out
src/hall.zig         Chapter 3's hand-typed one-room castle, and the test that the kit matches it
src/training.zig     the Training Castle, written with the kit (bulk data)
src/room.zig         preparing a room, a function per kind; placing, erasing and tinting; N and P
src/screen.zig       the row table, one fat pixel, the shape blitter and its eraser
src/shapes.zig       the shape table: format, IDs, the comptime packer, recolouring
src/art.zig          every picture, drawn as text (bulk data)
src/text.zig         letters from the character ROM, with the castle's text styles
src/title.zig        the title screen
```

The Boss Battle run walks rooms 4 to 8 from the Lightning room (four N
presses) to the Keys room:

```
zig build run -- --frames 2900 --press 20:f:5 --key 45:N --key 60:N --key 75:N --key 90:N --press 110:r:64 --press 180:u:80 --press 265:l:46 --press 315:d:6 --press 330:r:46 --press 380:d:80 --press 465:r:172 --press 640:f:5 --press 700:r:40 --press 760:ur:10 --press 920:l:76 --press 1000:f:5 --press 1010:l:160 --press 1172:f:5 --press 1240:l:30 --press 1272:ur:10 --press 1420:l:236 --press 1660:f:5 --press 1720:l:30 --press 1752:ur:10 --press 1900:l:124 --press 2026:f:5 --press 2034:l:112 --press 2150:f:5 --press 2210:l:30 --press 2242:ur:10 --press 2390:l:92 --press 2486:u:34 --press 2524:f:5 --press 2534:l:32 --press 2570:f:5 --press 2630:l:28 --press 2662:ur:10 --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
