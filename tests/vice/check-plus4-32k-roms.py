#!/usr/bin/env python3
"""Verify that VICE maps both halves of raw 32 KiB C1 and C2 images."""
from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
import tempfile
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


def check_image(runner, xplus4: Path, basic: Path, kernal: Path, option: str) -> bool:
    with tempfile.TemporaryDirectory(prefix=f"vice-{option[1:]}-") as temp_dir:
        image = Path(temp_dir) / "test-32k.bin"
        image.write_bytes(bytes([0xA5]) * 0x4000 + bytes([0x5A]) * 0x4000)
        port = runner.free_port()
        selector = "$fdda" if option == "-c1" else "$fddf"
        resource = "c1Name" if option == "-c1" else "c2Name"
        cmd = [
            str(xplus4), "-default", "+sound", "-warp", "-console",
            "-kernal", str(kernal), "-basic", str(basic), "-drive8type", "0",
            option, str(image), "-remotemonitor",
            "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
        ]
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 15.0
            while True:
                output = runner.monitor_query(port, ["screen", "x"], timeout=2.0)
                if "ready." in output.lower():
                    break
                if time.monotonic() >= deadline:
                    raise TimeoutError("VICE did not reach BASIC READY")
            output = runner.monitor_query(
                port,
                [f"> {selector} $00", "m $8000 $8000", "m $c000 $c000", f'resourceget "{resource}"', "quit"],
                timeout=5.0,
            )
        finally:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5.0)

    low = re.search(r">C:8000\s+a5\b", output, re.IGNORECASE) is not None
    high = re.search(r">C:c000\s+5a\b", output, re.IGNORECASE) is not None
    named = str(image) in output
    print(f"{option}: low={'OK' if low else 'FAIL'}, high={'OK' if high else 'FAIL'}, resource={'OK' if named else 'FAIL'}")
    return low and high and named


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-env", type=Path, default=SCRIPT_DIR / "roms.env")
    parser.add_argument("--xplus4", type=Path, default=ROOT / "vice/build-hackjunk/src/xplus4")
    args = parser.parse_args()

    runner = load_runner()
    cfg = runner.load_rom_env(args.rom_env)
    xplus4 = runner.required_file("XPLUS4_TEST", str(args.xplus4))
    kernal = runner.required_file("HOST_KERNAL_STOCK", cfg.get("HOST_KERNAL_STOCK"))
    basic = runner.required_file("HOST_BASIC_STOCK", cfg.get("HOST_BASIC_STOCK"))
    ok = [check_image(runner, xplus4, basic, kernal, option) for option in ("-c1", "-c2")]
    return 0 if all(ok) else 1


if __name__ == "__main__":
    sys.exit(main())
