#!/usr/bin/env python3
"""Exercise DOS wedge wildcard loads (/pattern) on IEC and TCBM paths.

The matrix runner injects LOAD via monitor and never types ``/pattern`` on the
keyboard.  This script reuses the headless loader with filename ``A*`` so VICE
checks the same ``dos_dload`` SETNAM path that ``/A*`` uses after the wedge
parses the command (see src/dos-wedge.asm).

Note: Plus/4 BASIC treats a leading ``/`` followed by hex digits as RUN $addr
before ICRNCH, so keyboard ``/A*`` is not a reliable VICE test entry point.
The firmware fixes (consume ``/``, null-terminate cmd_text, cmd_quote buffer)
are covered here via direct wildcard LOAD.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parents[1]
RUNNER = SCRIPT_DIR / "run-hackjunk-headless.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-env", type=Path, default=SCRIPT_DIR / "roms.env")
    parser.add_argument("--load-timeout", type=float, default=120.0)
    parser.add_argument("--cpu", choices=("8501", "6510"), default="6510")
    parser.add_argument("--cart-bank", choices=("c0", "c1", "c2"), default="c1")
    parser.add_argument(
        "--case",
        choices=("1581-sd2iec", "1551-stock", "1551-ramboard", "all"),
        default="all",
    )
    parser.add_argument("--realtime", action="store_true")
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def run_hackjunk_case(
    *,
    label: str,
    cpu: str,
    cart_bank: str,
    drive: str,
    drive_rom: str,
    drive_ram: str,
    disk_arg: list[str],
    load_timeout: float,
    realtime: bool,
    no_build: bool,
    rom_env: Path,
) -> int:
    cmd = [
        sys.executable,
        str(RUNNER),
        "--rom-env",
        str(rom_env),
        "--cpu",
        cpu,
        "--cart-bank",
        cart_bank,
        "--drive",
        drive,
        "--drive-rom",
        drive_rom,
        "--drive-ram",
        drive_ram,
        "--filename",
        "A*",
        "--load-timeout",
        str(load_timeout),
        *([] if not no_build else ["--no-build"]),
        *disk_arg,
    ]
    if realtime:
        cmd.append("--realtime")
    print(f"=== {label}: /A* dos_dload path ===")
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode == 0:
        print(f"{label}: PASS")
    else:
        print(f"{label}: FAIL (exit {result.returncode})", file=sys.stderr)
    return result.returncode


def main() -> int:
    args = parse_args()

    cases: list[tuple[str, str, str, str, str, list[str]]] = []
    if args.case in ("1581-sd2iec", "all"):
        cases.append((
            "1581-sd2iec",
            args.cpu,
            "1581",
            "sd2iec",
            "off",
            [],
        ))
    if args.case in ("1551-stock", "all"):
        cases.append((
            "1551-stock",
            args.cpu,
            "1551",
            "stock",
            "on",
            [],
        ))
    if args.case in ("1551-ramboard", "all"):
        cases.append((
            "1551-ramboard",
            "8501",
            "1551",
            "ramboard",
            "on",
            [],
        ))

    results = [
        run_hackjunk_case(
            label=label,
            cpu=cpu,
            cart_bank=args.cart_bank,
            drive=drive,
            drive_rom=drive_rom,
            drive_ram=drive_ram,
            disk_arg=disk_arg,
            load_timeout=args.load_timeout,
            realtime=args.realtime,
            no_build=args.no_build,
            rom_env=args.rom_env,
        )
        for label, cpu, drive, drive_rom, drive_ram, disk_arg in cases
    ]
    return 0 if all(code == 0 for code in results) else 1


if __name__ == "__main__":
    sys.exit(main())
