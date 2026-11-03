# Checkpoint: Chapter 10, "Things That Go Bump"

The game at the end of Chapter 10: the Training Castle with sound. The
Comet 64's SOUND chip now has its speaker, and the game drives it with a
little interpreter that runs at the top of every frame. The title screen
plays "The Creep Waltz" on three voices, round and round; the escape
gets a fanfare and GAME OVER a slow fall. In the castle, every machine
has a voice: doors creak higher as they open, a death beeps lower with
every flash, and switches, forcefields, trapdoors, belts, the matter
transmitter, keys, guns, the mummy and Frankenstein's monster each have
their sound. Effects take over the music's interpreter, and an effect
never interrupts anything already playing.

Keys: N and P flip rooms (on the map too); G draws the grid; Q searches
instead of reading the grid; C makes every actor check every object
every turn; X gives up a life.

```
src/main.zig         boot(), frame(), the game's modes and the engine step, whole-game tests
src/sound.zig        the sound driver: one interpreter for music and sound effects, and what may interrupt what
src/tunes.zig        the notes' frequencies, the composer, every tune and sound effect
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

The Boss Battle run plays the title waltz for a few seconds, then
Chapter 9's game for two (Two's Company, the Way Out, two escapes, GAME
OVER and the title), and saves the sound as a WAV file:

```
zig build run -- --frames 3780 --press 300:f:5@2 --press 320:f:3 --press 320:f:3@2 --key 340:N --key 355:N --key 370:N --key 385:N --key 400:N --key 415:N --key 430:N --key 445:N --key 460:N --key 475:N --key 490:N --key 505:N --key 520:N --key 535:N --key 550:N --key 565:N --key 580:N --key 595:N --press 625:l:52 --press 625:l:52@2 --press 677:u:60 --press 740:r:46 --press 786:f:400 --press 795:l:182@2 --press 977:f:4@2 --press 981:l:60@2 --press 1041:ur:4@2 --press 1190:l:46 --press 1236:d:100 --press 1336:l:250 --press 1590:ur:4 --press 1710:f:3 --press 1710:f:3@2 --press 1742:l:240 --press 1742:l:240@2 --press 1982:f:4 --press 1982:f:4@2 --press 1992:l:60 --press 1992:l:60@2 --press 2054:ur:4 --press 2054:ur:4@2 --dump-every 10 --wav creep.wav
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
