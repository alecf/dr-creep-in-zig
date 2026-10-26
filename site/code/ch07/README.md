# Checkpoint: Chapter 7, "Lock and Load"

The game at the end of Chapter 7: keys, locks, ray guns and their lasers.
Training Castle rooms 9, 10, 15 and 17 work:

- **Keys and Locks** (9): press fire at a key and it goes in your pocket,
  a list of key numbers kept in the castle's header (`$7813`, as in 1984).
  It leaves the object table by 1984's rule: the last object moves into
  its slot. Press fire at the lock of the same colour and its door opens.
- **Ray Guns** (10): the gun slides along its track towards your row and
  fires when you're level with it. Its laser is the first short-lived
  actor: it takes the first free sprite slot, flies, and frees it. At the
  panel you steer the gun (up, down, still) and fire it yourself.
- **Under Fire** (15): the forcefield is a shield: lasers stop on it.
  Send the gun up from its panel, then take the field down and run.
- **Locked Away** (17): the key is upstairs, reached only by the
  transmitter; a pole brings you down to the lock.

A gun's whole state is one flag byte in its castle record (`castle.Gun`).
With all eight sprites busy, a gun holds its fire. Sprites now hit each
other only when their boxes share a fat pixel, so an explorer leaning on a
forcefield is safe from the lasers that die on its far side.

Keys: N and P flip rooms; G draws the grid; Q searches instead of reading
the grid (and walks through forcefields and open trapdoors: the castle
alone doesn't know about them); C makes every actor check every object
every turn; X gives up a life.

```
src/main.zig         boot(), frame(), the game's modes and the engine step, whole-game tests
src/map.zig          the game's memory map, checked at compile time
src/actors.zig       the actor table: slots, kinds, turns, sprite-sprite hits, flickering
src/objects.zig      the object table: slots, flags, handlers, finding by number, touching, removing
src/doors.zig        doors and doorbells: ringing, opening, walking in
src/lightning.zig    lightning machines, their bolts, and their switches
src/forcefields.zig  forcefields, their buttons and gauges
src/trapdoors.zig    trapdoors and the switches in the floor
src/conveyors.zig    conveyor belts and their control boxes
src/transmitter.zig  the matter transmitter: booth, lamp and pads
src/locks.zig        keys, the pocket, and locks
src/guns.zig         ray guns, their panels, and lasers
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

The Boss Battle run plays the Keys room (nine N presses), walks on
through the Ray Guns room, presses N four times for Under Fire, and N once
more for Locked Away:

```
zig build run -- --frames 4760 --press 20:f:5 --key 45:N --key 60:N --key 75:N --key 90:N --key 105:N --key 120:N --key 135:N --key 150:N --key 165:N --press 185:l:230 --press 415:f:5 --press 440:r:126 --press 566:u:70 --press 636:r:130 --press 766:f:5 --press 781:l:114 --press 895:d:70 --press 965:l:126 --press 1091:f:5 --press 1096:l:60 --press 1156:ur:10 --press 1326:r:64 --press 1390:u:70 --press 1460:l:26 --press 1506:u:464 --press 1970:f:5 --press 2015:r:26 --press 2041:d:70 --press 2111:r:172 --press 2283:f:5 --press 2288:r:60 --press 2348:ur:10 --key 2518:N --key 2533:N --key 2548:N --key 2563:N --press 2598:l:140 --press 2798:r:36 --press 2834:u:70 --press 2904:r:16 --press 2920:u:514 --press 3434:l:12 --press 3446:d:70 --press 3516:r:56 --press 3572:f:5 --press 3577:l:182 --press 3759:f:5 --press 3764:l:60 --press 3824:ur:10 --key 3994:N --press 4029:l:64 --press 4093:f:5 --press 4108:r:90 --press 4198:f:5 --press 4213:l:138 --press 4351:d:70 --press 4421:l:102 --press 4523:f:5 --press 4528:l:60 --press 4588:ur:10 --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
