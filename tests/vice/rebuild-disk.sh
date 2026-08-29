#!/usr/bin/env bash
# Rebuild smoke-test.d64 / .d81 for Parobek matrix (HELLO + optional AMAUROTE).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMA_SRC="${AMAUROTE_SRC:-${AMAUPROTE_SRC:-$HOME/Maciejdev/plus4/amaurote/amaurote/output/amaurote-cr.prg}}"
OUT_D64="$SCRIPT_DIR/smoke-test.d64"
OUT_D81="$SCRIPT_DIR/smoke-test.d81"
TMP_D64="$(mktemp /tmp/parobek-smoke.XXXXXX.d64)"
TMP_D81="$(mktemp /tmp/parobek-smoke.XXXXXX.d81)"

cleanup() { rm -f "$TMP_D64" "$TMP_D81"; }
trap cleanup EXIT

build_image() {
	local type="$1"
	local image="$2"
	c1541 -format "parobek,01" "$type" "$image"
	c1541 "$image" -write "$SCRIPT_DIR/hello.prg" hello
	if [[ -f "$AMA_SRC" ]]; then
		echo "Adding AMAUROTE to $type from $AMA_SRC"
		c1541 "$image" -write "$AMA_SRC" amaurote
	else
		echo "Skip AMAUROTE - set AMAUROTE_SRC or place amaurote-cr.prg at default path" >&2
	fi
}

build_image d64 "$TMP_D64"
build_image d81 "$TMP_D81"
cp -f "$TMP_D64" "$OUT_D64"
cp -f "$TMP_D81" "$OUT_D81"
c1541 "$OUT_D64" -list
c1541 "$OUT_D81" -list

STAGE="${STAGE_DIR:-/mnt/d/tmp/parobek}"
if [[ -d "$STAGE" ]]; then
	if cp -f "$OUT_D64" "$STAGE/smoke-test.d64" \
		&& cp -f "$OUT_D81" "$STAGE/smoke-test.d81"; then
		echo "Staged $STAGE/smoke-test.d64"
		echo "Staged $STAGE/smoke-test.d81"
	else
		echo "Could not stage images in $STAGE (continuing)" >&2
	fi
fi
