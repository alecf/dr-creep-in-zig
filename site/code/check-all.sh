#!/usr/bin/env bash
# Build, test and smoke-run the machine and every game project
# (starter/ and each chNN/). Exits non-zero on the first failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

step() { printf '\n== %s\n' "$*"; }

step "machine: zig build test"
(cd "$here/machine" && zig build test)

for dir in "$here"/starter "$here"/ch[0-9]*; do
  [ -f "$dir/build.zig" ] || continue
  name="$(basename "$dir")"
  step "$name: zig build"
  (cd "$dir" && zig build)
  step "$name: zig build test"
  (cd "$dir" && zig build test)
  step "$name: zig build wasm"
  (cd "$dir" && zig build wasm)
  for f in game.wasm shell.js index.html; do
    [ -s "$dir/web/$f" ] || { echo "zig build wasm did not write web/$f for $name"; exit 1; }
  done
  step "$name: headless, 100 frames"
  (cd "$dir" && zig build run -- --frames 100 --dump "$frames/$name")
  [ -s "$frames/$name/frame_00099.ppm" ] || { echo "no frame written for $name"; exit 1; }
done

step "all green"
