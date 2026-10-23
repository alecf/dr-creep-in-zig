# Checkpoint: Chapter 1, "It's Alive!"

The game at the end of Chapter 1: a blue border, a stone floor, and a
player sprite you steer with joystick 1. Fire picks the sprite's next
colour.

```
src/main.zig     boot() and frame()
src/map.zig      the game's memory map, checked at compile time
src/room.zig     paints the floor
src/player.zig   the player's sprite, and steering it
```

```
zig build run -- --frames 250 --press 10:l:60 --press 80:u:80 --press 170:f:5 --press 200:rf:40 --dump-every 50
zig build wasm && python3 -m http.server -d web
zig build test
```

The Comet 64's reference card is [`../machine/REFERENCE.md`](../machine/REFERENCE.md).
