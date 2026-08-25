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
DISK_IMAGE_1581="${DISK_IMAGE_1581:-$SCRIPT_DIR/smoke-test.d81}"

# VICE: +option disables a boolean resource. Keep smoke launches quiet.
VICE_COMMON_ARGS=(+sound)

# Plus/4 VICE often keeps unit #8 as 1551 from defaults/saved settings.
# Drive type must be forced. True-drive required for JD.
# For type 1542 the DOS image flag is -dos1541II (NOT -dos1541 — that only
# affects classic 1541 and leaves the 1541-II on stock "DOS 2.6").
# For type 1581 use -dos1581 and attach a .d81 (not .d64).
DRIVE8_1541_ARGS=(-drive8type 1542 -drive8truedrive -drive9type 0)
DRIVE8_1581_ARGS=(-drive8type 1581 -drive8truedrive -drive9type 0)

require_disk() {
	local image="$1"
	if [[ ! -f "$image" ]]; then
		echo "Missing disk image $image — run tests/vice/rebuild-disk.sh" >&2
		exit 1
	fi
}

make -C "$REPO_ROOT/src" via

cmd_stock_jd1541() {
	printf '%s -default %s -kernal %q -basic %q -dos1541II %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_1541_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

cmd_stock_stock1541() {
	printf '%s -default %s -kernal %q -basic %q -dos1541II %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_STOCK" \
		"${DRIVE8_1541_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

cmd_stock_jd_tape() {
	printf '%s -default %s -kernal %q -basic %q -dos1541II %q %s -c1lo %q -8 %q -1 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_1541_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE" "$EMPTY_TAP"
}

cmd_hostjd_jd1541() {
	printf '%s -default %s -kernal %q -basic %q -dos1541II %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_JD" "$HOST_BASIC_STOCK" "$DRIVE_1541_JD" \
		"${DRIVE8_1541_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE"
}

cmd_stock_jd1581() {
	printf '%s -default %s -kernal %q -basic %q -dos1581 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1581_JD" \
		"${DRIVE8_1581_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE_1581"
}

cmd_stock_stock1581() {
	printf '%s -default %s -kernal %q -basic %q -dos1581 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1581_STOCK" \
		"${DRIVE8_1581_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE_1581"
}

cmd_stock_jd1581_tape() {
	printf '%s -default %s -kernal %q -basic %q -dos1581 %q %s -c1lo %q -8 %q -1 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_STOCK" "$HOST_BASIC_STOCK" "$DRIVE_1581_JD" \
		"${DRIVE8_1581_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE_1581" "$EMPTY_TAP"
}

cmd_hostjd_jd1581() {
	printf '%s -default %s -kernal %q -basic %q -dos1581 %q %s -c1lo %q -8 %q' \
		"$XPLUS4" "${VICE_COMMON_ARGS[*]}" "$HOST_KERNAL_JD" "$HOST_BASIC_STOCK" "$DRIVE_1581_JD" \
		"${DRIVE8_1581_ARGS[*]}" "$PAROBEK_BIN" "$DISK_IMAGE_1581"
}

expect_stock_jd1541='Menu "3", then LOAD"HELLO",8 — expect SJL264'
expect_stock_stock1541='Menu "3", LOAD"HELLO",8 — expect 1541 SERIAL then HELLO'
expect_stock_jd_tape='LOAD"HELLO",8 — DATASETTE, SKIP SJL then ROM/parallel'
expect_hostjd_jd1541='LOAD"HELLO",8 — HOST JIFFYDOS then ROM LOAD; no SJL264'
expect_stock_jd1581='Menu "3", then LOAD"HELLO",8 — expect SJL264 (1581 JD)'
expect_stock_stock1581='Menu "3", LOAD"HELLO",8 — no SJL264; ROM LOAD (stock 1581)'
expect_stock_jd1581_tape='LOAD"HELLO",8 — DATASETTE, SKIP SJL then ROM (1581 JD)'
expect_hostjd_jd1581='LOAD"HELLO",8 — HOST JIFFYDOS then ROM LOAD; no SJL264 (1581 JD)'

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
	require_disk "$DISK_IMAGE"
	require_disk "$DISK_IMAGE_1581"
	print_case stock+jd1541 "$expect_stock_jd1541" "$(cmd_stock_jd1541)"
	print_case stock+stock1541 "$expect_stock_stock1541" "$(cmd_stock_stock1541)"
	print_case stock+jd+tape "$expect_stock_jd_tape" "$(cmd_stock_jd_tape)"
	print_case hostjd+jd1541 "$expect_hostjd_jd1541" "$(cmd_hostjd_jd1541)"
	print_case stock+jd1581 "$expect_stock_jd1581" "$(cmd_stock_jd1581)"
	print_case stock+stock1581 "$expect_stock_stock1581" "$(cmd_stock_stock1581)"
	print_case stock+jd1581+tape "$expect_stock_jd1581_tape" "$(cmd_stock_jd1581_tape)"
	print_case hostjd+jd1581 "$expect_hostjd_jd1581" "$(cmd_hostjd_jd1581)"
}

run_case() {
	local name="$1"
	local cmd expect
	case "$name" in
	stock+jd1541)
		require_disk "$DISK_IMAGE"
		expect="$expect_stock_jd1541"
		cmd="$(cmd_stock_jd1541)"
		;;
	stock+stock1541)
		require_disk "$DISK_IMAGE"
		expect="$expect_stock_stock1541"
		cmd="$(cmd_stock_stock1541)"
		;;
	stock+jd+tape)
		require_disk "$DISK_IMAGE"
		expect="$expect_stock_jd_tape"
		cmd="$(cmd_stock_jd_tape)"
		;;
	hostjd+jd1541)
		require_disk "$DISK_IMAGE"
		expect="$expect_hostjd_jd1541"
		cmd="$(cmd_hostjd_jd1541)"
		;;
	stock+jd1581)
		require_disk "$DISK_IMAGE_1581"
		expect="$expect_stock_jd1581"
		cmd="$(cmd_stock_jd1581)"
		;;
	stock+stock1581)
		require_disk "$DISK_IMAGE_1581"
		expect="$expect_stock_stock1581"
		cmd="$(cmd_stock_stock1581)"
		;;
	stock+jd1581+tape)
		require_disk "$DISK_IMAGE_1581"
		expect="$expect_stock_jd1581_tape"
		cmd="$(cmd_stock_jd1581_tape)"
		;;
	hostjd+jd1581)
		require_disk "$DISK_IMAGE_1581"
		expect="$expect_hostjd_jd1581"
		cmd="$(cmd_hostjd_jd1581)"
		;;
	*)
		echo "Unknown case: $name" >&2
		echo "Valid cases: stock+jd1541 stock+stock1541 stock+jd+tape hostjd+jd1541 stock+jd1581 stock+stock1581 stock+jd1581+tape hostjd+jd1581" >&2
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

Cases (1541-II / .d64):
  stock+jd1541     stock host kernal + JiffyDOS 1541 drive
  stock+stock1541  stock host kernal + stock 1541 ROM
  stock+jd+tape    stock host + JiffyDOS 1541 + datasette image
  hostjd+jd1541    JiffyDOS host kernal + JiffyDOS 1541 drive

Cases (1581 / .d81):
  stock+jd1581       stock host kernal + JiffyDOS 1581 drive
  stock+stock1581    stock host kernal + stock 1581 ROM
  stock+jd1581+tape  stock host + JiffyDOS 1581 + datasette image
  hostjd+jd1581      JiffyDOS host kernal + JiffyDOS 1581 drive

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
