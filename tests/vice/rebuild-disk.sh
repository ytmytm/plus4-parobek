#!/usr/bin/env bash
# Rebuild smoke-test.d64 from hello.bas (BASIC 3.5 / Plus4).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

petcat -w3 -f -o hello.prg -- hello.bas
rm -f smoke-test.d64
c1541 -format "parobek,sj" d64 smoke-test.d64 \
	-attach smoke-test.d64 \
	-write hello.prg hello
c1541 -attach smoke-test.d64 -dir
echo "Wrote $SCRIPT_DIR/smoke-test.d64"
