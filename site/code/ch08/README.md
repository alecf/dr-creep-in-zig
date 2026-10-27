# Checkpoint: Chapter 8, "Monster Mash"

The game at the end of Chapter 8: dice, mummies and Frankenstein's
monsters. Training Castle rooms 11, 12, 13, 14 and 16 work:

- **The Mummy** (11): walk past the ankh and it flashes; the tomb's
  middle blocks fall out and the mummy climbs out, then follows player 1's
  X along his floor (never climbing). His state and position live in his
  castle record, so he's where you left him on every visit.
- **Frankenstein** (12): asleep in his alcove until you're on his level,
  in front of him. Awake, he walks corridors end to end and chooses a way
  only at junctions, the farthest direction towards you first (1984's
  rule). His alcove makes three grid cells one-way.
- **A Trap for Frank** (13): he's awake on the right-hand walkway. Step on
  the trapdoor switch below and wait: he climbs down his ladder into the
  hole.
- **Frank's Ride** (14): belts carry monsters 2 fat pixels a turn. Turn
  the belt round and he walks on the spot at its end.
- **Mummy in a Storm** (16): one throw of the switch stops the machine by
  the door and starts the one over the mummy waiting under you.

Every monster room is entered upstairs, out of the monster's reach, so it
stays winnable after a death (the castle keeps the monsters' state until
Chapter 9's clean copy). The bolts roll 1984's dice (`dice.zig`, seeds
`$C6 $57`), so every run flickers the same way.

Keys: N and P flip rooms; G draws the grid; Q searches instead of reading
the grid (and walks through forcefields, open trapdoors and alcoves: the
castle alone doesn't know about them); C makes every actor check every
object every turn; X gives up a life.

```
src/main.zig         boot(), frame(), the game's modes and the engine step, whole-game tests
src/map.zig          the game's memory map, checked at compile time
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

The Boss Battle run presses N eleven times for the Mummy room and plays
it, walks on through Frankenstein, A Trap for Frank and Frank's Ride,
presses N once in Under Fire for Mummy in a Storm, and plays that:

```
zig build run -- --frames 4060 --press 20:f:5 --key 45:N --key 60:N --key 75:N --key 90:N --key 105:N --key 120:N --key 135:N --key 150:N --key 165:N --key 180:N --key 195:N --press 315:r:62 --press 497:l:74 --press 639:r:220 --press 859:d:70 --press 929:r:24 --press 953:f:4 --press 957:r:60 --press 1017:ur:4 --press 1131:r:162 --press 1293:d:70 --press 1363:r:104 --press 1467:f:4 --press 1471:r:60 --press 1531:ur:4 --press 1646:r:146 --press 1792:d:70 --press 1862:r:32 --press 2082:l:8 --press 2090:r:8 --press 2108:r:56 --press 2164:u:70 --press 2234:r:32 --press 2266:f:4 --press 2270:r:60 --press 2330:ur:4 --press 2445:r:194 --press 2639:d:70 --press 2709:r:28 --press 2831:f:4 --press 2839:f:4 --press 3343:r:44 --press 3387:f:4 --press 3391:r:60 --press 3451:ur:4 --key 3515:N --press 3648:l:78 --press 3730:u:4 --press 3774:l:48 --press 3822:d:70 --press 3892:l:92 --press 3984:f:4 --press 3988:l:60 --press 4048:ur:4 --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
