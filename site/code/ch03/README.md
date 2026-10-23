# Checkpoint: Chapter 2, "Ghosts in the Bitmap"

The game at the end of Chapter 2: a title screen (the castle by
moonlight under a twinkling sky), and on fire, the Entrance Hall drawn
from the shape table, with the explorer walking its floor on an animated,
double-buffered multicolour sprite.

```
src/main.zig      boot(), frame() and the game's modes
src/map.zig       the game's memory map, checked at compile time
src/screen.zig    the row table, one fat pixel, and the shape blitter
src/shapes.zig    the shape table: format, IDs, and the comptime packer
src/art.zig       every picture, drawn as text
src/text.zig      letters from the character ROM, drawn as shapes
src/sprites.zig   unpacking sprite frames into sprite blocks
src/title.zig     the title screen
src/room.zig      the Entrance Hall
src/player.zig    the explorer: walking and his walk cycle
```

```
zig build run -- --frames 300 --press 20:f:5 --press 60:r:60 --press 140:l:100 --dump-every 50
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
