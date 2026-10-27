# Checkpoint: Chapter 9, "The Great Escape"

The game at the end of Chapter 9: a whole game, for one or two. Fire on
stick 1 starts a game for one, fire on stick 2 a game for two (player 2
in yellow; in the browser, I J K L and Return). Each game plays on a
fresh copy of the castle, staged at `$9800`. Between rooms, the castle
map shows every visited room with a blinking arrow per player, and each
player's time, kept in BCD in the castle header. Lose your last life and
it's GAME OVER; go through the way out and the final room builds itself
a piece at a time while you cheer. Training Castle rooms 18 and 19 and
the final room work, so the whole castle can be played from the title:

- **Two's Company** (18): a forcefield across the floor, its button up
  the ladder. Fire held at the button keeps the field down (1984's rule),
  so one explorer holds while the other runs; alone, press and run.
- **The Way Out** (19): ring the bell and step through the green door.

Two explorers jostle (the one below blocks the other's way down), guns
turn to the nearer, the mummy follows player 1 first, and Frankenstein
wakes for either. Each player has his own pocket, plates and conveyor
bit. The game's state lives in the castle header's spare bytes, 1984's
layout; the map, the escape and GAME OVER share seven bytes as an
`extern union`.

Keys: N and P flip rooms (on the map too); G draws the grid; Q searches
instead of reading the grid; C makes every actor check every object
every turn; X gives up a life.

```
src/main.zig         boot(), frame(), the game's modes and the engine step, whole-game tests
src/map.zig          the game's memory map, checked at compile time
src/game.zig         a whole game: starting, whose room next, lives, the screens between rooms
src/chart.zig        the castle map between rooms
src/clock.zig        each player's time, in binary-coded decimal
src/escape.zig       the escape: the final room piece by piece, and the walk
src/dice.zig         the dice: 1984's two-byte number maker, a rotate and two XORs
src/actors.zig       the actor table: slots, kinds, turns, sprite-sprite hits, flickering
src/objects.zig      the object table: slots, flags, handlers, finding by number and by actor, touching, removing
src/doors.zig        doors and doorbells: ringing, opening, walking in
src/lightning.zig    lightning machines, their bolts, and their switches
src/forcefields.zig  forcefields, their buttons and gauges
src/trapdoors.zig    trapdoors and the switches in the floor, for anyone who treads on them
src/conveyors.zig    conveyor belts and their control boxes
src/transmitter.zig  the matter transmitter: booth, lamp and pads
src/locks.zig        keys, the pocket, and locks
src/guns.zig         ray guns, their panels, and lasers
src/mummy.zig        mummies, their tombs and ankhs: waking, climbing out, following
src/frankenstein.zig Frankenstein's monsters and their alcoves: waking, choosing a way, walking
src/player.zig       the explorers: two sticks, steps, ladders, poles, doorways, jostling, deaths
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


The Boss Battle run starts a game for two, presses N eighteen times on
the map for Two's Company, plays it for two (one holds, one runs), then
walks both through the Way Out: two escapes, GAME OVER, and the title:

```
zig build run -- --frames 3500 --press 20:f:5@2 --press 40:f:3 --press 40:f:3@2 --key 60:N --key 75:N --key 90:N --key 105:N --key 120:N --key 135:N --key 150:N --key 165:N --key 180:N --key 195:N --key 210:N --key 225:N --key 240:N --key 255:N --key 270:N --key 285:N --key 300:N --key 315:N --press 345:l:52 --press 345:l:52@2 --press 397:u:60 --press 460:r:46 --press 506:f:400 --press 515:l:182@2 --press 697:f:4@2 --press 701:l:60@2 --press 761:ur:4@2 --press 910:l:46 --press 956:d:100 --press 1056:l:250 --press 1310:ur:4 --press 1430:f:3 --press 1430:f:3@2 --press 1462:l:240 --press 1462:l:240@2 --press 1702:f:4 --press 1702:f:4@2 --press 1712:l:60 --press 1712:l:60@2 --press 1774:ur:4 --press 1774:ur:4@2 --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
