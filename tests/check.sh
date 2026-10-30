#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.runtime/data"
export XDG_CONFIG_HOME="$PWD/.runtime/config"
export XDG_CACHE_HOME="$PWD/.runtime/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --editor --import --quit > .runtime/import.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|Compile Error' .runtime/import.log; then exit 1; fi
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tests/restart.gd -- --write
godot --headless --path . --script tests/restart.gd
godot --headless --path . --script tests/benchmark.gd
godot --headless --path . --quit-after 300
