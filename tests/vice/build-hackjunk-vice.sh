#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
VICE_ROOT="${VICE_ROOT:-$REPO_ROOT/vice/vice}"
BUILD_DIR="${VICE_BUILD_DIR:-$REPO_ROOT/vice/build-hackjunk}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

if [[ ! -x "$VICE_ROOT/autogen.sh" ]]; then
	echo "Missing VICE source at $VICE_ROOT" >&2
	exit 1
fi

if [[ ! -x "$VICE_ROOT/configure" ]]; then
	(cd "$VICE_ROOT" && ./autogen.sh)
fi

mkdir -p "$BUILD_DIR"
(
    cd "$BUILD_DIR"
    env CFLAGS="-O2 -g" \
        "$VICE_ROOT/configure" \
        --enable-headlessui \
        --disable-html-docs \
        --without-alsa \
        --without-pulse \
        --without-resid \
        --without-residfp \
        --without-libcurl \
        --without-libusb
)

make -C "$BUILD_DIR" -j"$JOBS"
echo "$BUILD_DIR/src/xplus4"
