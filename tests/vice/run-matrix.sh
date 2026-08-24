#!/usr/bin/env bash
# VICE smoke matrix for Parobek SJL264 IEC paths.
# Usage:
#   ./run-matrix.sh list              — print all case commands
#   ./run-matrix.sh <case>            — build and launch one case
#
# Requires tests/vice/roms.env (copy from roms.env.example).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
ROM_ENV="$SCRIPT_DIR/roms.env"

if [[ ! -f "$ROM_ENV" ]]; then
	echo "Missing $ROM_ENV — copy roms.env.example to roms.env and edit paths." >&2
	exit 1
fi

# shellcheck source=/dev/null
source "$ROM_ENV"

XPLUS4="${XPLUS4:-/usr/local/bin/xplus4}"
EMPTY_TAP="${EMPTY_TAP:-$SCRIPT_DIR/empty.tap}"
DISK_IMAGE="${DISK_IMAGE:-$SCRIPT_DIR/smoke-test.d64}"

# Plus/4 VICE often keeps unit #8 as 1551 from defaults/saved settings.
# -dos1541 only swaps the ROM image; drive *type* must be forced explicitly.
# ROMs in roms.env are 1541-II images → type 1542. True-drive required for JD.
DRIVE8_ARGS=(-drive8type 1542 -drive8truedrive -drive9type 0)

if [[ ! -f "$DISK_IMAGE" ]]; then
	echo "Missing disk image $DISK_IMAGE — run tests/vice/rebuild-disk.sh" >&2
	exit 1
fi

make -C "$REPO_ROOT/src" via

cmd_stock_jd1541() {
	printf '%s -default -kernal %q -basic %q -dos1541 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

cmd_stock_stock1541() {
	printf '%s -default -kernal %q -basic %q -dos1541 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_STOCK" \
		"${DRIVE8_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

cmd_stock_jd_tape() {
	printf '%s -default -kernal %q -basic %q -dos1541 %q %s -c1lo %q -8 %q -1 %q' \
		"$XPLUS4" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE" "$EMPTY_TAP"
}

cmd_hostjd_jd1541() {
	printf '%s -default -kernal %q -basic %q -dos1541 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "$HOST_KERNAL_JD" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

expect_stock_jd1541='Menu "3", then LOAD"HELLO",8 — expect SJL264'
expect_stock_stock1541='Menu "3", LOAD"HELLO",8 — no SJL264; parallel or ROM LOAD'
expect_stock_jd_tape='LOAD"HELLO",8 — DATASETTE, SKIP SJL then ROM/parallel'
expect_hostjd_jd1541='HOST JIFFYDOS, NO WEDGE; LOAD"HELLO",8 — no SJL264'

print_case() {
	local name="$1"
	local expect="$2"
	shift 2
	echo "=== $name ==="
	echo "Expect: $expect"
	echo "$*"
	echo
}

list_cases() {
	print_case stock+jd1541 "$expect_stock_jd1541" "$(cmd_stock_jd1541)"
	print_case stock+stock1541 "$expect_stock_stock1541" "$(cmd_stock_stock1541)"
	print_case stock+jd+tape "$expect_stock_jd_tape" "$(cmd_stock_jd_tape)"
	print_case hostjd+jd1541 "$expect_hostjd_jd1541" "$(cmd_hostjd_jd1541)"
}

run_case() {
	local name="$1"
	local cmd expect
	case "$name" in
	stock+jd1541)
		expect="$expect_stock_jd1541"
		cmd="$(cmd_stock_jd1541)"
		;;
	stock+stock1541)
		expect="$expect_stock_stock1541"
		cmd="$(cmd_stock_stock1541)"
		;;
	stock+jd+tape)
		expect="$expect_stock_jd_tape"
		cmd="$(cmd_stock_jd_tape)"
		;;
	hostjd+jd1541)
		expect="$expect_hostjd_jd1541"
		cmd="$(cmd_hostjd_jd1541)"
		;;
	*)
		echo "Unknown case: $name" >&2
		echo "Valid cases: stock+jd1541 stock+stock1541 stock+jd+tape hostjd+jd1541" >&2
		exit 1
		;;
	esac
	echo "=== $name ==="
	echo "Expect: $expect"
	echo "Running: $cmd"
	echo
	# shellcheck disable=SC2086
	exec $cmd
}

usage() {
	cat <<EOF
Usage: $(basename "$0") list
       $(basename "$0") <case>

Cases:
  stock+jd1541     stock host kernal + JiffyDOS 1541 drive
  stock+stock1541  stock host kernal + stock 1541 ROM
  stock+jd+tape    stock host + JiffyDOS 1541 + datasette image
  hostjd+jd1541    JiffyDOS host kernal + JiffyDOS 1541 drive

Copy roms.env.example to roms.env before running.
EOF
}

main() {
	if [[ $# -lt 1 ]]; then
		usage >&2
		exit 1
	fi

	case "$1" in
	list)
		list_cases
		;;
	-h | --help | help)
		usage
		;;
	*)
		run_case "$1"
		;;
	esac
}

main "$@"
