#!/usr/bin/env bash
# Run the full headless GUT suite (all logic tests).
# Usage: ./run_tests.sh [extra gut args, e.g. -gselect=test_ctb.gd]
set -uo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-godot}"

# First run (or after clean checkout) the project must be imported so
# class_name registrations and .tres resources resolve headless.
if [ ! -d .godot ]; then
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1
fi

exec "$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd \
	-gdir=res://test -ginclude_subdirs -gexit "$@"
