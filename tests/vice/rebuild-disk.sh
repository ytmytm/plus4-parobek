#!/usr/bin/env bash
# Rebuild smoke-test.d64 / smoke-test.d81 from hello.bas (BASIC 3.5 / Plus4).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

petcat -w3 -f -o hello.prg -- hello.bas

AMAUROTE_PRG="${AMAUROTE_PRG:-$HOME/Maciejdev/plus4/amaurote/amaurote/output/amaurote-intro-plain.prg}"

write_image() {
	local type="$1"
	local image="$2"
	rm -f "$image"
	c1541 -format "parobek,sj" "$type" "$image" \
		-attach "$image" \
		-write hello.prg hello
	if [[ -f "$AMAUROTE_PRG" ]]; then
		c1541 -attach "$image" -write "$AMAUROTE_PRG" amaurote
	else
		echo "Warning: missing $AMAUROTE_PRG — disk has HELLO only" >&2
	fi
	c1541 -attach "$image" -dir
	echo "Wrote $SCRIPT_DIR/$image"
}

write_image d64 smoke-test.d64
write_image d81 smoke-test.d81
