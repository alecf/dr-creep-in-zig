#!/usr/bin/env bash
# Build the whole GitHub Pages site into $1 (default: site/_pages):
#
#   /            project homepage        (site/home/)
#   /tutorial/   the tutorial            (site/build.py)
#   /game/       the real game, as wasm  (web/ + site/game/)
#
# Needs zig 0.16 and `pip install markdown pygments`. The game page ships no
# game data: players load their own .d64 in the browser.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-site/_pages}"

rm -rf "$OUT"
mkdir -p "$OUT/game"

SITE_OUT="$OUT/tutorial" SITE_HOME="../" python3 site/build.py

zig build wasm
cp web/creep.wasm web/creep.js web/d64.js site/game/index.html "$OUT/game/"

cp site/home/index.html site/page/theme.css "$OUT/"
touch "$OUT/.nojekyll"
echo "pages site in $OUT"
