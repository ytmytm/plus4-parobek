#!/usr/bin/env python3
"""Assert the HackJunk 6510 CPU-port state after a clean VICE power-on."""
from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parents[1]


def load_runner():
    path = SCRIPT_DIR / "run-hackjunk-headless.py"
    spec = importlib.util.spec_from_file_location("hackjunk_runner", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-env", type=Path, default=SCRIPT_DIR / "roms.env")
    parser.add_argument("--xplus4", type=Path, default=ROOT / "vice/build-hackjunk/src/xplus4")
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()

    runner = load_runner()
    cfg = runner.load_rom_env(args.rom_env)
    xplus4 = runner.required_file("XPLUS4_TEST", str(args.xplus4))
    kernal_default = Path(cfg.get("HOST_KERNAL_STOCK", "")).parent.parent / "6510/kernal-6510-pal.bin"
    kernal = runner.required_file(
        "HOST_KERNAL_6510", cfg.get("HOST_KERNAL_6510", str(kernal_default))
    )
    basic = runner.required_file("HOST_BASIC_STOCK", cfg.get("HOST_BASIC_STOCK"))
    port = runner.free_port()
    cmd = [
        str(xplus4), "-default", "-hackjunk6510", "+sound", "-warp", "-console",
        "-kernal", str(kernal), "-basic", str(basic), "-drive8type", "0",
        "-remotemonitor", "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
    ]
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.monotonic() + args.timeout
        while True:
            output = runner.monitor_query(port, ["screen", "x"], timeout=2.0)
            if "ready." in output.lower():
                break
            if time.monotonic() >= deadline:
                raise TimeoutError("VICE did not reach the clean BASIC READY screen")
        output = runner.monitor_query(port, ["m $0000 $0001", "quit"], timeout=5.0)
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5.0)

    match = re.search(r">C:0000\s+([0-9a-f]{2})\s+([0-9a-f]{2})", output, re.IGNORECASE)
    state = tuple(int(value, 16) for value in match.groups()) if match else None
    expected = (0x0e, 0x31)
    print(f"CPU port: {state!r} ({'PASS' if state == expected else 'FAIL'})")
    if state is not None:
        print(f"PEEK(0)={state[0]} (${state[0]:02x}), PEEK(1)={state[1]} (${state[1]:02x})")
    return 0 if state == expected else 1


if __name__ == "__main__":
    sys.exit(main())
