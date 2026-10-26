# Checkpoint: Chapter 5, "Ding Dong, You're Dead"

The game at the end of Chapter 5: the castle's engine. Every room has an
actor table (eight 16-byte slots at `$BD00`, one per sprite; the explorer
is the only actor so far) and an object table (32 16-byte slots at
`$BE00`, filled while the room is prepared: its doors and doorbells). Each
engine step, every other frame, the VIDEO chip's collision reports decide
which actors look through the objects, each actor takes its turn, and the
objects that asked to run do. What each kind does comes from tables of
functions, and so does preparing each kind of castle record.

Ring a doorbell (stand at it, press fire) and its door wipes open from the
bottom up, on both sides of the wall, for good. At an open door, push the
stick up and to the right: he walks in, and out of the door it leads to,
in the next room. X gives up a life: he flickers away and starts again at
the castle's start door; with no lives left it's back to the title.

Keys: N and P flip rooms; G draws the grid; Q searches instead of reading
the grid; C makes every actor check every object every turn (watch the
meter); X gives up a life.

```
src/main.zig      boot(), frame(), the game's modes and the engine step, whole-game tests
src/map.zig       the game's memory map, checked at compile time
src/actors.zig    the actor table: slots, state flags, turns, flickering, showing sprites
src/objects.zig   the object table: slots, flags, handlers, touching, the execute pass
src/doors.zig     doors and doorbells: ringing, opening, walking in
src/player.zig    the explorer: joystick, steps, ladders, poles, doorways, lives
src/grid.zig      the navigation grid: building it, reading it, and the slow search
src/sprites.zig   unpacking sprite frames; castle coordinates to sprite registers
src/debug.zig     the G, Q, C and X keys
src/castle.zig    the castle format: header, room directory, tags, records, the stream walker
src/author.zig    the castle-authoring kit: declarations in, checked castle bytes out
src/hall.zig      Chapter 3's hand-typed one-room castle, and the test that the kit matches it
src/training.zig  the Training Castle, written with the kit (bulk data)
src/room.zig      preparing a room from its object stream, a function per kind; N and P
src/screen.zig    the row table, one fat pixel, and the shape blitter
src/shapes.zig    the shape table: format, IDs, the comptime packer, recolouring
src/art.zig       every picture, drawn as text (bulk data)
src/text.zig      letters from the character ROM, with the castle's text styles
src/title.zig     the title screen
```

```
zig build run -- --frames 2300 --press 20:f:5 --press 60:l:34 --press 100:f:5 --press 160:r:20 --press 200:ur:10 --press 350:r:180 --press 540:f:5 --press 600:r:40 --press 650:ur:10 --press 840:r:176 --press 1020:u:80 --press 1100:r:60 --press 1165:f:5 --press 1220:r:30 --press 1255:ur:10 --press 1500:r:96 --press 1600:d:70 --press 1675:r:140 --press 1820:f:5 --press 1880:r:30 --press 1915:ur:10 --key 2150:X --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
