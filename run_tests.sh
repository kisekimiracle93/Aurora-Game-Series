#!/usr/bin/env bash
# Run the full headless GUT suite (all logic tests).
# Usage: ./run_tests.sh [extra gut args, e.g. -gselect=test_ctb.gd]
set -uo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-godot}"

# Import before every run so new class_name scripts and .tres resources
# are registered in the headless script-class cache (cheap on this project).
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

exec "$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd \
	-gdir=res://test -ginclude_subdirs -gexit "$@"
