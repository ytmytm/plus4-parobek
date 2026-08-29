#!/usr/bin/env bash
# Split 32 KB Parobek into two 16 KB halves for YaPe ROM LOW/HIGH.
# Which bank (C1 or C2) is chosen later by run-matrix.sh (PAROBEK_SLOT).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
OUT_DIR="${STAGE_DIR:-/mnt/d/tmp/parobek}"
SRC_DIR="$REPO_ROOT/src/bin"

mkdir -p "$OUT_DIR"

split_rom() {
	local src="$1"
	local prefix="$2"
	if [[ ! -f "$src" ]]; then
		echo "Missing $src — run: make -C $REPO_ROOT/src via" >&2
		exit 1
	fi
	# 32 KB = LOW ($8000-$BFFF) + HIGH ($C000-$FFFF), 16 KB each.
	dd if="$src" of="$OUT_DIR/${prefix}-low.bin" bs=16384 count=1 status=none
	dd if="$src" of="$OUT_DIR/${prefix}-high.bin" bs=16384 skip=1 count=1 status=none
	echo "Split $src -> ${prefix}-{low,high}.bin (16 KB each) in $OUT_DIR"
}

make -C "$REPO_ROOT/src" via
split_rom "$SRC_DIR/parobek-via.bin" parobek-via
split_rom "$SRC_DIR/parobek-cpld.bin" parobek-cpld

echo "Done. run-matrix.sh assigns these to ROM C1 or C2 via PAROBEK_SLOT."
