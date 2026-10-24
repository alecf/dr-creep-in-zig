# Starter kit

This is your game. Right now it's very small: when the Comet 64 powers
on, `boot` paints the border purple and the screen black, and `frame`,
which the machine calls fifty times a second, doesn't do anything yet.
That's where you come in.

```
src/main.zig     your game: boot() and frame()
build.zig        hooks your game up to the Comet 64
build.zig.zon    says where the Comet 64 lives (../machine)
```

The machine itself is in `../machine`. Its programmer's reference card,
[`../machine/REFERENCE.md`](../machine/REFERENCE.md), lists every address
and register your game can use.

## Play it in the browser

```
zig build wasm
python3 -m http.server -d web
```

Then open <http://localhost:8000>. `zig build wasm` writes the `web/`
folder for you: the page, the browser shell, and your game as
`game.wasm`. Click the screen to give it the keyboard.

## Run it headless

```
zig build run -- --frames 100
```

This runs your game for 100 frames with nobody watching, saves the last
picture as `frames/frame_00099.ppm`, and tells you how much of each
frame's time budget the game used. Add `--press 20:rf:30` to hold the
joystick right and fire from frame 20 for 30 frames, or `--help` for the
rest of the options.

## Test it

```
zig build test
```

This runs any `test` blocks in your game, then boots it and plays 100
frames to make sure it gets through them.

You'll need Zig 0.16.
