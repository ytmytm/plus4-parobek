#!/usr/bin/env bash
# YaPe smoke matrix for Parobek (WSL -> Windows).
#
# Usage:
#   ./run-matrix.sh list
#   ./run-matrix.sh <case>
#   ./run-matrix.sh restore-ini
#
# All ROMs and disks are copied to STAGE_DIR (/mnt/d/tmp/parobek), which YaPe
# sees as D:\tmp\parobek\. Never pass \\wsl.localhost UNC paths to YaPe.
#
# YaPe Drive8Enabled / Drive9Enabled:
#   0=off  1=1541 CPU  2=1551 IEC  3=1551 CPU  4=1581 CPU  5=parallel 1541
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
ROM_ENV="${ROM_ENV:-$SCRIPT_DIR/roms.env}"
VICE_DIR="$REPO_ROOT/tests/vice"

if [[ ! -f "$ROM_ENV" ]]; then
	echo "Missing $ROM_ENV — copy roms.env.example to roms.env and edit paths." >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$ROM_ENV"

YAPE_EXE="${YAPE_EXE:-/mnt/d/tmp/YaPe-Plus4/YapeWin32.exe}"
STAGE_DIR="${STAGE_DIR:-/mnt/d/tmp/parobek}"
PAROBEK_PREFIX="${PAROBEK_PREFIX:-parobek-via}"
# YaPe cartridge bank for Parobek: C1 or C2 (LOW+HIGH = 16 KB each).
PAROBEK_SLOT="${PAROBEK_SLOT:-C1}"
DISK_IMAGE="${DISK_IMAGE:-$VICE_DIR/smoke-test.d64}"
DISK_IMAGE_1581="${DISK_IMAGE_1581:-$VICE_DIR/smoke-test.d81}"
EMPTY_TAP="${EMPTY_TAP:-$VICE_DIR/empty.tap}"

D8_1541_CPU=1
D8_1551_CPU=3
D8_1581_CPU=4
D8_1541_PARALLEL=5

win_path() { wslpath -w "$1"; }
yape_dir() { dirname "$YAPE_EXE"; }
# Basename under STAGE_DIR -> D:\tmp\parobek\<name>
d_path() { printf 'D:\\tmp\\parobek\\%s' "$(basename "$1")"; }

require_yape() {
	[[ -f "$YAPE_EXE" ]] || {
		echo "Missing YaPe: $YAPE_EXE (set YAPE_EXE in roms.env)" >&2
		exit 1
	}
}

require_file() {
	[[ -f "$1" ]] || {
		echo "Missing $1" >&2
		exit 1
	}
}

stage_file() {
	local src="$1"
	require_file "$src"
	mkdir -p "$STAGE_DIR"
	cp -f "$src" "$STAGE_DIR/$(basename "$src")"
}

stage_parobek() {
	# 32 KB image -> two 16 KB halves. Slot C1/C2 is chosen in patch_yape_ini.
	local src="$REPO_ROOT/src/bin/${PAROBEK_PREFIX}.bin"
	require_file "$src"
	mkdir -p "$STAGE_DIR"
	dd if="$src" of="$STAGE_DIR/${PAROBEK_PREFIX}-low.bin" bs=16384 count=1 status=none
	dd if="$src" of="$STAGE_DIR/${PAROBEK_PREFIX}-high.bin" bs=16384 skip=1 count=1 status=none
}

set_ini_key() {
	# Preserve CRLF that YaPe writes on Windows.
	local ini="$1" key="$2" value="$3"
	if grep -q "^${key}=" "$ini"; then
		local esc="${value//\\/\\\\}"
		esc="${esc//&/\\&}"
		sed -i "s|^${key}=.*|${key}=${esc}\r|" "$ini"
		# If the file was LF-only, the trailing \r is harmless for YaPe.
	else
		printf '%s=%s\r\n' "$key" "$value" >>"$ini"
	fi
}

backup_yape_ini() {
	local ini backup
	ini="$(yape_dir)/yape.ini"
	backup="${ini}.parobek-matrix.bak"
	if [[ -f "$ini" && ! -f "$backup" ]]; then
		cp "$ini" "$backup"
		echo "Backed up yape.ini -> $(basename "$backup")"
	fi
}

restore_yape_ini() {
	local ini backup
	ini="$(yape_dir)/yape.ini"
	backup="${ini}.parobek-matrix.bak"
	if [[ -f "$backup" ]]; then
		cp "$backup" "$ini"
		echo "Restored yape.ini from backup"
	else
		echo "No backup at $backup" >&2
		return 1
	fi
}

patch_yape_ini() {
	local drive8="$1" drive_rom="$2" host_kernal="$3" host_basic="$4"
	local drive9="${5:-0}" drive9_rom="${6:-}"
	local ini
	ini="$(yape_dir)/yape.ini"
	[[ -f "$ini" ]] || {
		echo "Missing $ini — start YaPe once from Explorer to create it." >&2
		exit 1
	}
	backup_yape_ini

	set_ini_key "$ini" "Save settings on exit" "0"
	set_ini_key "$ini" "Drive8Enabled" "$drive8"
	set_ini_key "$ini" "Drive9Enabled" "$drive9"
	set_ini_key "$ini" "Drive10Enabled" "0"
	set_ini_key "$ini" "Drive11Enabled" "0"

	set_ini_key "$ini" "ROM C0 LOW" "$(d_path "$host_basic")"
	set_ini_key "$ini" "ROM C0 HIGH" "$(d_path "$host_kernal")"

	# Parobek is one 32 KB cart: 16 KB LOW + 16 KB HIGH on C1 or C2.
	local slot="${PAROBEK_SLOT^^}"
	local low_name="${PAROBEK_PREFIX}-low.bin"
	local high_name="${PAROBEK_PREFIX}-high.bin"
	case "$slot" in
	C1)
		set_ini_key "$ini" "ROM C1 LOW" "$(d_path "$low_name")"
		set_ini_key "$ini" "ROM C1 HIGH" "$(d_path "$high_name")"
		set_ini_key "$ini" "ROM C2 LOW" "<empty>"
		set_ini_key "$ini" "ROM C2 HIGH" "<empty>"
		;;
	C2)
		set_ini_key "$ini" "ROM C1 LOW" "<empty>"
		set_ini_key "$ini" "ROM C1 HIGH" "<empty>"
		set_ini_key "$ini" "ROM C2 LOW" "$(d_path "$low_name")"
		set_ini_key "$ini" "ROM C2 HIGH" "$(d_path "$high_name")"
		;;
	*)
		echo "PAROBEK_SLOT must be C1 or C2 (got: $PAROBEK_SLOT)" >&2
		exit 1
		;;
	esac

	set_ini_key "$ini" "CustomDriveRom0" "$(d_path "$drive_rom")"
	if [[ -n "$drive9_rom" ]]; then
		set_ini_key "$ini" "CustomDriveRom1" "$(d_path "$drive9_rom")"
	else
		set_ini_key "$ini" "CustomDriveRom1" ""
	fi
	set_ini_key "$ini" "CustomDriveRom2" ""
	set_ini_key "$ini" "CustomDriveRom3" ""

	echo "Patched $ini (Drive8Enabled=$drive8 Drive9Enabled=$drive9, Parobek on ROM $slot)"
}

case_params() {
	local name="$1"
	CASE_TAPE=""
	CASE_DRIVE9=0
	CASE_DRIVE9_ROM=""
	CASE_DISK9=""
	case "$name" in
	stock+jd1541)
		CASE_DRIVE8=$D8_1541_CPU
		CASE_DRIVE_ROM="$DRIVE_1541_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+stock1541)
		CASE_DRIVE8=$D8_1541_CPU
		CASE_DRIVE_ROM="$DRIVE_1541_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+stock1551)
		CASE_DRIVE8=$D8_1551_CPU
		CASE_DRIVE_ROM="$DRIVE_1551_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	# Dual-drive: #8 = stock 1551 (Hypaload), #9 = second drive under test.
	stock+stock1551+stock1551)
		CASE_DRIVE8=$D8_1551_CPU
		CASE_DRIVE_ROM="$DRIVE_1551_STOCK"
		CASE_DRIVE9=$D8_1551_CPU
		CASE_DRIVE9_ROM="$DRIVE_1551_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_DISK9="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",9'
		;;
	stock+stock1551+stock1541)
		CASE_DRIVE8=$D8_1551_CPU
		CASE_DRIVE_ROM="$DRIVE_1551_STOCK"
		CASE_DRIVE9=$D8_1541_CPU
		CASE_DRIVE9_ROM="$DRIVE_1541_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_DISK9="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+stock1551+jd1541)
		CASE_DRIVE8=$D8_1551_CPU
		CASE_DRIVE_ROM="$DRIVE_1551_STOCK"
		CASE_DRIVE9=$D8_1541_CPU
		CASE_DRIVE9_ROM="$DRIVE_1541_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_DISK9="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	hostjd+stock1551)
		CASE_DRIVE8=$D8_1551_CPU
		CASE_DRIVE_ROM="$DRIVE_1551_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_JD"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='LOAD"HELLO",8'
		;;
	stock+jd+tape)
		CASE_DRIVE8=$D8_1541_CPU
		CASE_DRIVE_ROM="$DRIVE_1541_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='LOAD"HELLO",8'
		CASE_TAPE="$EMPTY_TAP"
		;;
	hostjd+jd1541)
		CASE_DRIVE8=$D8_1541_CPU
		CASE_DRIVE_ROM="$DRIVE_1541_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_JD"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='LOAD"HELLO",8'
		;;
	stock+jd1581)
		CASE_DRIVE8=$D8_1581_CPU
		CASE_DRIVE_ROM="$DRIVE_1581_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE_1581"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+stock1581)
		CASE_DRIVE8=$D8_1581_CPU
		CASE_DRIVE_ROM="$DRIVE_1581_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE_1581"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+jd1581+tape)
		CASE_DRIVE8=$D8_1581_CPU
		CASE_DRIVE_ROM="$DRIVE_1581_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE_1581"
		CASE_TYPE='LOAD"HELLO",8'
		CASE_TAPE="$EMPTY_TAP"
		;;
	hostjd+jd1581)
		CASE_DRIVE8=$D8_1581_CPU
		CASE_DRIVE_ROM="$DRIVE_1581_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_JD"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE_1581"
		CASE_TYPE='LOAD"HELLO",8'
		;;
	stock+stock1541+parallel)
		CASE_DRIVE8=$D8_1541_PARALLEL
		CASE_DRIVE_ROM="$DRIVE_1541_STOCK"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	stock+jd1541+parallel)
		CASE_DRIVE8=$D8_1541_PARALLEL
		CASE_DRIVE_ROM="$DRIVE_1541_JD"
		CASE_HOST_KERNAL="$HOST_KERNAL_STOCK"
		CASE_HOST_BASIC="$HOST_BASIC_STOCK"
		CASE_DISK="$DISK_IMAGE"
		CASE_TYPE='3:LOAD"HELLO",8'
		;;
	*) return 1 ;;
	esac
}

# Forward-slash Windows paths — safe in bash; Win32 accepts them.
# No nested quotes around paths (STAGE_DIR / YaPe dir have no spaces).
win_slash() { wslpath -w "$1" | tr '\\' '/'; }
d_slash() { printf 'D:/tmp/parobek/%s' "$(basename "$1")"; }

# Write a .bat under STAGE_DIR and run it — avoids nested-quote hell with cmd /c.
yape_cmd() {
	local disk_base="$1"
	local type_cmd="${2:-}"
	local tape_base="${3:-}"
	local disk9_base="${4:-}"
	local win_exe win_dir disk_win bat bat_win line
	win_exe="$(win_slash "$YAPE_EXE")"
	win_dir="$(win_slash "$(yape_dir)")"
	disk_win="$(d_slash "$disk_base")"
	bat="$STAGE_DIR/launch-yape.bat"
	bat_win="$(d_slash "$bat")"

	{
		printf '@echo off\r\n'
		printf 'cd /d %s\r\n' "$win_dir"
		line="start \"\" ${win_exe} /DISK8:${disk_win} /NOSTART"
		if [[ -n "$disk9_base" ]]; then
			line+=" /DISK9:$(d_slash "$disk9_base")"
		fi
		if [[ -n "$tape_base" ]]; then
			line+=" /TAPE:$(d_slash "$tape_base")"
		fi
		if [[ -n "$type_cmd" ]]; then
			# TYPE text: keep quotes as YaPe expects LOAD"HELLO",8
			line+=" /TYPE:${type_cmd}"
		fi
		printf '%s\r\n' "$line"
	} >"$bat"

	# Print the Windows command used to run the bat (also used by eval).
	printf 'cmd.exe /c "%s"' "$bat_win"
}

expect_stock_jd1541='Menu "3", then LOAD"HELLO",8 — expect SJL264'
expect_stock_stock1541='Menu "3", LOAD"HELLO",8 — expect 1541 SERIAL then HELLO'
expect_stock_stock1551='Menu "3", LOAD"HELLO",8 — expect TCBM DEVICE, 1551 HYPALOAD then HELLO'
expect_stock_stock1551_stock1551='Menu "3", LOAD"HELLO",9 — #8+#9 stock 1551; expect TCBM DEVICE, 1551 HYPALOAD on device 9'
expect_stock_stock1551_stock1541='Menu "3", LOAD"HELLO",8 — #8 stock 1551 Hypaload; #9 stock 1541 present (optional LOAD",9 / @9)'
expect_stock_stock1551_jd1541='Menu "3", LOAD"HELLO",8 — #8 stock 1551 Hypaload; #9 JD 1541 present (optional LOAD",9 / @9)'
expect_hostjd_stock1551='LOAD"HELLO",8 — expect TCBM DEVICE, 1551 HYPALOAD (host JD does not block TCBM)'
expect_stock_jd_tape='LOAD"HELLO",8 — DATASETTE, SKIP SJL then ROM/parallel'
expect_hostjd_jd1541='LOAD"HELLO",8 — HOST JIFFYDOS then ROM LOAD; no SJL264'
expect_stock_jd1581='Menu "3", then LOAD"HELLO",8 — expect SJL264 (1581 JD)'
expect_stock_stock1581='Menu "3", LOAD"HELLO",8 — no SJL264; ROM LOAD (stock 1581)'
expect_stock_jd1581_tape='LOAD"HELLO",8 — DATASETTE, SKIP SJL then ROM (1581 JD)'
expect_hostjd_jd1581='LOAD"HELLO",8 — HOST JIFFYDOS then ROM LOAD; no SJL264 (1581 JD)'
expect_stock_stock1541_parallel='Menu "3", LOAD"HELLO",8 — expect 1541/PARALLEL (8255 or 6529)'
expect_stock_jd1541_parallel='Menu "3", LOAD"HELLO",8 — parallel attempt; JiffyDOS drive ROM may fail'

VALID_CASES='stock+jd1541 stock+stock1541 stock+stock1551 stock+stock1551+stock1551 stock+stock1551+stock1541 stock+stock1551+jd1541 hostjd+stock1551 stock+jd+tape hostjd+jd1541 stock+jd1581 stock+stock1581 stock+jd1581+tape hostjd+jd1581 stock+stock1541+parallel stock+jd1541+parallel'

print_case() {
	local name="$1" expect="$2"
	case_params "$name"
	echo "=== $name ==="
	echo "Expect: $expect"
	echo "Drive8Enabled: $CASE_DRIVE8  Drive9Enabled: $CASE_DRIVE9"
	echo "Stage: D:\\tmp\\parobek\\"
	yape_cmd "$(basename "$CASE_DISK")" "$CASE_TYPE" \
		"${CASE_TAPE:+$(basename "$CASE_TAPE")}" \
		"${CASE_DISK9:+$(basename "$CASE_DISK9")}"
	echo
	echo
}

list_cases() {
	require_yape
	require_file "$DISK_IMAGE"
	require_file "$DISK_IMAGE_1581"
	print_case stock+jd1541 "$expect_stock_jd1541"
	print_case stock+stock1541 "$expect_stock_stock1541"
	print_case stock+stock1551 "$expect_stock_stock1551"
	print_case stock+stock1551+stock1551 "$expect_stock_stock1551_stock1551"
	print_case stock+stock1551+stock1541 "$expect_stock_stock1551_stock1541"
	print_case stock+stock1551+jd1541 "$expect_stock_stock1551_jd1541"
	print_case hostjd+stock1551 "$expect_hostjd_stock1551"
	print_case stock+jd+tape "$expect_stock_jd_tape"
	print_case hostjd+jd1541 "$expect_hostjd_jd1541"
	print_case stock+jd1581 "$expect_stock_jd1581"
	print_case stock+stock1581 "$expect_stock_stock1581"
	print_case stock+jd1581+tape "$expect_stock_jd1581_tape"
	print_case hostjd+jd1581 "$expect_hostjd_jd1581"
	print_case stock+stock1541+parallel "$expect_stock_stock1541_parallel"
	print_case stock+jd1541+parallel "$expect_stock_jd1541_parallel"
}

run_case() {
	local name="$1" cmd expect tape_base="" disk9_base=""

	require_yape
	case_params "$name" || {
		echo "Unknown case: $name" >&2
		echo "Valid: $VALID_CASES" >&2
		exit 1
	}

	case "$name" in
	stock+jd1541) expect="$expect_stock_jd1541" ;;
	stock+stock1541) expect="$expect_stock_stock1541" ;;
	stock+stock1551) expect="$expect_stock_stock1551" ;;
	stock+stock1551+stock1551) expect="$expect_stock_stock1551_stock1551" ;;
	stock+stock1551+stock1541) expect="$expect_stock_stock1551_stock1541" ;;
	stock+stock1551+jd1541) expect="$expect_stock_stock1551_jd1541" ;;
	hostjd+stock1551) expect="$expect_hostjd_stock1551" ;;
	stock+jd+tape) expect="$expect_stock_jd_tape" ;;
	hostjd+jd1541) expect="$expect_hostjd_jd1541" ;;
	stock+jd1581) expect="$expect_stock_jd1581" ;;
	stock+stock1581) expect="$expect_stock_stock1581" ;;
	stock+jd1581+tape) expect="$expect_stock_jd1581_tape" ;;
	hostjd+jd1581) expect="$expect_hostjd_jd1581" ;;
	stock+stock1541+parallel) expect="$expect_stock_stock1541_parallel" ;;
	stock+jd1541+parallel) expect="$expect_stock_jd1541_parallel" ;;
	esac

	if [[ "${SKIP_PAROBEK_BUILD:-0}" != 1 ]]; then
		make -C "$REPO_ROOT/src" via
	fi
	stage_parobek
	stage_file "$CASE_HOST_BASIC"
	stage_file "$CASE_HOST_KERNAL"
	stage_file "$CASE_DRIVE_ROM"
	stage_file "$CASE_DISK"
	if [[ -n "$CASE_DRIVE9_ROM" ]]; then
		stage_file "$CASE_DRIVE9_ROM"
	fi
	if [[ -n "$CASE_DISK9" ]]; then
		stage_file "$CASE_DISK9"
		disk9_base="$(basename "$CASE_DISK9")"
	fi
	if [[ -n "$CASE_TAPE" ]]; then
		stage_file "$CASE_TAPE"
		tape_base="$(basename "$CASE_TAPE")"
	fi

	patch_yape_ini "$CASE_DRIVE8" "$(basename "$CASE_DRIVE_ROM")" \
		"$(basename "$CASE_HOST_KERNAL")" "$(basename "$CASE_HOST_BASIC")" \
		"$CASE_DRIVE9" "${CASE_DRIVE9_ROM:+$(basename "$CASE_DRIVE9_ROM")}"

	cmd="$(yape_cmd "$(basename "$CASE_DISK")" "$CASE_TYPE" "$tape_base" "$disk9_base")"

	echo "=== $name ==="
	echo "Expect: $expect"
	echo "Drive8Enabled: $CASE_DRIVE8  Drive9Enabled: $CASE_DRIVE9"
	echo "Staged under: $STAGE_DIR  (= D:\\tmp\\parobek\\)"
	echo "Running: $cmd"
	echo
	echo "yape.ini stays patched until: $0 restore-ini"
	echo
	# Do not restore on EXIT — start returns immediately and would wipe Drive8Enabled.
	eval "$cmd"
}

usage() {
	cat <<EOF
Usage: $(basename "$0") list | restore-ini | <case>

Stages ROMs/disks to ${STAGE_DIR} (D:\\tmp\\parobek) and launches YaPe with
native D: paths. Patches yape.ini next to YapeWin32.exe
(backup: yape.ini.parobek-matrix.bak). Run restore-ini when finished.

Cases:
  stock+jd1541  stock+stock1541  stock+stock1551  hostjd+stock1551
  stock+stock1551+stock1551  stock+stock1551+stock1541  stock+stock1551+jd1541
  stock+jd+tape  hostjd+jd1541
  stock+jd1581  stock+stock1581  stock+jd1581+tape  hostjd+jd1581
  stock+stock1541+parallel  stock+jd1541+parallel

1551 cases use Drive8Enabled=3 (1551 CPU). Mode 2 (IEC) cannot run Hypaload.
Dual-drive cases also set Drive9Enabled (3=1551 CPU, 1=1541 CPU) and attach /DISK9.
stock+stock1551+stock1551 auto-types LOAD"HELLO",9 (Hypaload on device 9).
hostjd+stock1551: host JiffyDOS still uses TCBM Hypaload (TCBM is not blocked by host JD).
EOF
}

main() {
	[[ $# -ge 1 ]] || {
		usage >&2
		exit 1
	}
	case "$1" in
	list) list_cases ;;
	restore-ini)
		require_yape
		restore_yape_ini
		;;
	-h | --help | help) usage ;;
	*) run_case "$1" ;;
	esac
}

main "$@"
