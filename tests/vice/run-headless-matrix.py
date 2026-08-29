#!/usr/bin/env python3
"""Run the complete Parobek CPU/KERNAL/drive/JiffyDOS load matrix."""
from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "run-hackjunk-headless.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", action="store_true", help="build VICE before running the matrix")
    parser.add_argument("--boot-wait", type=float, default=30.0)
    parser.add_argument("--load-timeout", type=float, default=120.0)
    parser.add_argument("--realtime", action="store_true", help="run the matrix at real speed")
    parser.add_argument("--retries", type=int, default=1, help="retries after a failed case (default: 1)")
    return parser.parse_args()


def cases() -> list[tuple[str, str, str, str, str, str, str, str, int, bool]]:
    base = []
    for cpu, host_roms in (("8501", ("stock", "jiffydos")), ("6510", ("stock",))):
        for host_rom in host_roms:
            for drive in ("1541", "1581"):
                for drive_rom in ("stock", "jiffydos"):
                    for filename in ("HELLO", "AMAUROTE"):
                        base.append((cpu, host_rom, drive, drive_rom, "off", "none", filename))
    for drive_rom, drive_ram in (("stock", "off"), ("stock", "on"), ("ramboard", "on")):
        for filename in ("HELLO", "AMAUROTE"):
            base.append(("8501", "stock", "1551", drive_rom, drive_ram, "none", filename))

    # VICE has no SD2IEC model. A synthetic JiffyDOS 1581 ROM changes its
    # error-channel identification and bypasses checksums so it still boots.
    for cpu in ("8501", "6510"):
        for filename in ("HELLO", "AMAUROTE"):
            base.append((cpu, "stock", "1581", "sd2iec", "off", "none", filename))

    # Cable-specific cases use a stock host KERNAL so Parobek, rather than the
    # host's JiffyDOS LOAD vector, selects and exercises the hardware loader.
    for cpu in ("8501", "6510"):
        for hardware in ("via", "pio"):
            for drive_rom, drive_ram in (("stock", "off"), ("ramboard", "on")):
                for filename in ("HELLO", "AMAUROTE"):
                    base.append((cpu, "stock", "1541", drive_rom, drive_ram, hardware, filename))
        for hardware in ("via", "cpld"):
            for drive_rom in ("stock", "jiffydos"):
                for filename in ("HELLO", "AMAUROTE"):
                    base.append((cpu, "stock", "1581", drive_rom, "off", hardware, filename))
    matrix = [
        (*case[:-1], cart_bank, case[-1], 8, False)
        for case in base
        for cart_bank in ("c0", "c1", "c2")
    ]
    # A responding 1581 on #8 must not make a LOAD from absent #9 enter CPLD
    # detection or print an IEC/CPLD loader banner.
    matrix.append(("6510", "stock", "1581", "jiffydos", "off", "cpld", "c1", "HELLO", 9, True))
    # Likewise, a 1551 on #8 must not make absent #9 enter TCBM or IEC loader
    # detection. The KERNAL must receive device-not-present directly.
    matrix.append(("6510", "stock", "1551", "stock", "off", "none", "c1", "HELLO", 9, True))
    return matrix


def main() -> int:
    args = parse_args()
    if args.retries < 0:
        raise SystemExit("--retries must be non-negative")
    if args.build:
        subprocess.run([str(SCRIPT_DIR / "build-hackjunk-vice.sh")], check=True)

    matrix = cases()
    details = []
    failures = []
    performance = []
    started = time.monotonic()
    for index, (cpu, host_rom, drive, drive_rom, drive_ram, hardware, cart_bank, filename, device_number, expect_missing) in enumerate(matrix, 1):
        ram_label = f" ram={drive_ram}" if drive_ram != "off" else ""
        label = (
            f"cpu={cpu} host={host_rom} drive={drive}/{drive_rom}{ram_label} "
            f"hardware={hardware} cart={cart_bank} file={filename} device={device_number}"
        )
        cmd = [
            sys.executable, str(RUNNER), "--no-build",
            "--cpu", cpu, "--host-rom", host_rom,
            "--drive", drive, "--drive-rom", drive_rom,
            "--drive-ram", drive_ram,
            "--burstcart", hardware,
            "--cart-bank", cart_bank,
            "--filename", filename,
            "--device-number", str(device_number),
            "--boot-wait", str(args.boot_wait),
            "--load-timeout", str(args.load_timeout),
        ]
        if expect_missing:
            cmd.append("--expect-device-missing")
        if args.realtime:
            cmd.append("--realtime")
        case_started = time.monotonic()
        attempt_outputs = []
        for attempt in range(1, args.retries + 2):
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            attempt_outputs.append(f"--- attempt {attempt} ---\n{proc.stdout.rstrip()}")
            if proc.returncode == 0:
                break
        duration = time.monotonic() - case_started
        status = "PASS" if proc.returncode == 0 else "FAIL"
        timing = re.search(
            r"performance: (\d+) VICE clocks = ([0-9.]+) emulated s, ([0-9.]+) bytes/s",
            proc.stdout,
        )
        if timing:
            clocks, emulated_seconds, bytes_per_second = timing.groups()
            timing_summary = f", {emulated_seconds}s emulated, {bytes_per_second} B/s"
        else:
            clocks = emulated_seconds = bytes_per_second = ""
            timing_summary = ", timing unavailable"
        attempts_note = f", attempts={attempt}" if attempt > 1 else ""
        print(
            f"[{index:02d}/{len(matrix)}] {status} {label} "
            f"({duration:.1f}s wall{timing_summary}{attempts_note})",
            flush=True,
        )
        performance.append({
            "status": status,
            "cpu": cpu,
            "host_rom": host_rom,
            "drive": drive,
            "drive_rom": drive_rom,
            "drive_ram": drive_ram,
            "hardware": hardware,
            "cart_bank": cart_bank,
            "filename": filename,
            "device_number": device_number,
            "expected_device_missing": expect_missing,
            "vice_clocks": clocks,
            "emulated_seconds": emulated_seconds,
            "bytes_per_second": bytes_per_second,
            "wall_seconds": f"{duration:.3f}",
            "mode": "realtime" if args.realtime else "warp",
            "attempts": attempt,
        })
        details.append(
            f"=== {status} {label} ({duration:.1f}s, attempts={attempt}) ===\n"
            + "\n".join(attempt_outputs) + "\n"
        )
        if proc.returncode:
            failures.append(label)
            print(proc.stdout.rstrip(), flush=True)

    duration = time.monotonic() - started
    mode = "realtime" if args.realtime else "warp"
    summary = SCRIPT_DIR / f"out/matrix-results-{mode}.txt"
    performance_csv = SCRIPT_DIR / f"out/matrix-performance-{mode}.csv"
    summary.parent.mkdir(exist_ok=True)
    summary.write_text("\n".join(details))
    with performance_csv.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=performance[0].keys())
        writer.writeheader()
        writer.writerows(performance)
    print(f"\nMatrix: {len(matrix) - len(failures)}/{len(matrix)} passed in {duration:.1f}s")
    print(f"Details: {summary}")
    print(f"Performance: {performance_csv}")
    if failures:
        print("Failures:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
