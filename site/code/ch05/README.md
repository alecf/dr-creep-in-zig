# Checkpoint: Chapter 4, "Creaky Floorboards"

The game at the end of Chapter 4: the explorer walks the Training Castle's
walkways, climbs its ladders and slides down its poles. Every room's
navigation grid (one byte per screen cell at `$C800`, a bit for each way
out) is built while the room is drawn, and each step he takes reads one
byte of it. He moves on the castle's own coordinates (X = fat pixel + 16),
converted for the VIDEO chip with the ninth X bit in `$D010`, so he reaches
the right-hand edge of the screen. He appears in each room's first doorway.

Keys: N and P flip rooms; G draws the grid over the room; S makes the
explorer search the castle for his way instead of reading the grid (watch
the meter).

```
src/main.zig      boot(), frame(), the game's modes, whole-game tests
src/map.zig       the game's memory map, checked at compile time
src/grid.zig      the navigation grid: building it, reading it, and the slow search
src/player.zig    the explorer: joystick, steps, ladders, poles and pictures
src/sprites.zig   unpacking sprite frames; castle coordinates to sprite registers
src/debug.zig     the G and S switches: the grid view and the search
src/castle.zig    the castle format: header, room directory, tags, records, the stream walker
src/author.zig    the castle-authoring kit: declarations in, checked castle bytes out
src/hall.zig      Chapter 3's hand-typed one-room castle, and the test that the kit matches it
src/training.zig  the Training Castle, written with the kit (bulk data)
src/room.zig      drawing a room from its object stream (and its grid); N and P
src/screen.zig    the row table, one fat pixel, and the shape blitter
src/shapes.zig    the shape table: format, IDs, the comptime packer, recolouring
src/art.zig       every picture, drawn as text (bulk data)
src/text.zig      letters from the character ROM, with the castle's text styles
src/title.zig     the title screen
```

```
zig build run -- --frames 1000 --press 20:f:5 --key 60:N --key 100:N --press 120:r:176 --press 300:u:80 --press 390:r:130 --key 530:N --press 560:r:96 --press 660:d:80 --press 750:r:220 --dump-every 10
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
