# Checkpoint: Chapter 3, "Haunted Blueprints"

The game at the end of Chapter 3: the Training Castle, twenty rooms and a
final room built at compile time by the castle-authoring kit, loaded at
`$7800` in the 1984 castle format. Fire on the title opens the castle's
start room; N and P on the keyboard flip to the next and previous room.
Every room's walkways, ladders, poles, doors, doorbells and text are drawn
from its object stream.

```
src/main.zig      boot(), frame(), the game's modes, whole-game tests
src/map.zig       the game's memory map, checked at compile time
src/castle.zig    the castle format: header, room directory, tags, records, the stream walker
src/author.zig    the castle-authoring kit: declarations in, checked castle bytes out
src/training.zig  the Training Castle, written with the kit (bulk data)
src/room.zig      drawing a room from its object stream; N and P
src/screen.zig    the row table, one fat pixel, and the shape blitter
src/shapes.zig    the shape table: format, IDs, the comptime packer, recolouring
src/art.zig       every picture, drawn as text (bulk data)
src/text.zig      letters from the character ROM, with the castle's text styles
src/sprites.zig   unpacking sprite frames into sprite blocks
src/title.zig     the title screen
src/player.zig    the explorer: walking and his walk cycle
```

```
zig build run -- --frames 300 --press 20:f:5 --key 60:N --key 100:N --key 140:P --key 180:P --key 220:P --dump-every 20
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
