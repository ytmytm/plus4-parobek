#!/usr/bin/env python3
"""Run the AMAUROTE matrix with randomized drive RPM and wobble timing."""
from __future__ import annotations

import argparse
import csv
import importlib.util
import random
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "run-hackjunk-headless.py"

# Same bounds enforced by run-hackjunk-headless.py.
RPM_MIN = 28000
RPM_MAX = 32000
WOBBLE_FREQUENCY_MAX = 10000
WOBBLE_AMPLITUDE_MAX = 2000


def load_base_cases() -> list[tuple[str, str, str, str, str, str, str, str, int, bool]]:
    spec = importlib.util.spec_from_file_location(
        "run_headless_matrix",
        SCRIPT_DIR / "run-headless-matrix.py",
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load run-headless-matrix.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return [
        case for case in module.cases()
        if case[7] == "AMAUROTE" and not case[9]
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run AMAUROTE matrix cases with randomized drive RPM and wobble "
            "settings to stress timing-sensitive loaders."
        ),
    )
    parser.add_argument("--build", action="store_true", help="build VICE before running the matrix")
    parser.add_argument("--boot-wait", type=float, default=30.0)
    parser.add_argument("--load-timeout", type=float, default=180.0,
                        help="AMAUROTE loads can be slow on stock 1581 (default: 180)")
    parser.add_argument("--realtime", action="store_true", help="run the matrix at real speed")
    parser.add_argument("--retries", type=int, default=1, help="retries after a failed case (default: 1)")
    parser.add_argument("--variants", type=int, default=8,
                        help="random timing variants per matrix case (default: 8)")
    parser.add_argument("--seed", type=int, default=42,
                        help="RNG seed for timing variant generation (default: 42)")
    return parser.parse_args()


def timing_variants(count: int, rng: random.Random) -> list[tuple[int, int, int, int]]:
    """Return (vice_seed, rpm, wobble_frequency, wobble_amplitude) tuples."""
    variants = []
    for index in range(count):
        vice_seed = rng.randint(0, 2**31 - 1)
        rpm = rng.randint(RPM_MIN, RPM_MAX)
        wobble_frequency = rng.randint(0, WOBBLE_FREQUENCY_MAX)
        wobble_amplitude = rng.randint(0, WOBBLE_AMPLITUDE_MAX)
        variants.append((vice_seed, rpm, wobble_frequency, wobble_amplitude))
    return variants


def main() -> int:
    args = parse_args()
    if args.retries < 0:
        raise SystemExit("--retries must be non-negative")
    if args.variants < 1:
        raise SystemExit("--variants must be at least 1")
    if args.build:
        subprocess.run([str(SCRIPT_DIR / "build-hackjunk-vice.sh")], check=True)

    base_matrix = load_base_cases()
    rng = random.Random(args.seed)
    matrix: list[tuple[
        tuple[str, str, str, str, str, str, str, str, int, bool],
        tuple[int, int, int, int],
    ]] = []
    for case in base_matrix:
        for timing in timing_variants(args.variants, rng):
            matrix.append((case, timing))

    details = []
    failures = []
    performance = []
    started = time.monotonic()
    total = len(matrix)
    for index, ((cpu, host_rom, drive, drive_rom, drive_ram, hardware, cart_bank,
                 filename, device_number, expect_missing),
                (vice_seed, rpm, wobble_frequency, wobble_amplitude)) in enumerate(matrix, 1):
        ram_label = f" ram={drive_ram}" if drive_ram != "off" else ""
        label = (
            f"cpu={cpu} host={host_rom} drive={drive}/{drive_rom}{ram_label} "
            f"hardware={hardware} cart={cart_bank} file={filename} device={device_number} "
            f"seed={vice_seed} rpm={rpm} wobble_f={wobble_frequency} wobble_a={wobble_amplitude}"
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
            "--seed", str(vice_seed),
            "--drive-rpm", str(rpm),
            "--drive-wobble-frequency", str(wobble_frequency),
            "--drive-wobble-amplitude", str(wobble_amplitude),
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
            f"[{index:04d}/{total}] {status} {label} "
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
            "vice_seed": vice_seed,
            "drive_rpm": rpm,
            "drive_wobble_frequency": wobble_frequency,
            "drive_wobble_amplitude": wobble_amplitude,
            "matrix_rng_seed": args.seed,
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
    summary = SCRIPT_DIR / f"out/matrix-results-randomized-{mode}.txt"
    performance_csv = SCRIPT_DIR / f"out/matrix-performance-randomized-{mode}.csv"
    summary.parent.mkdir(exist_ok=True)
    summary.write_text("\n".join(details))
    with performance_csv.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=performance[0].keys())
        writer.writeheader()
        writer.writerows(performance)
    print(
        f"\nRandomized matrix: {total - len(failures)}/{total} passed "
        f"({len(base_matrix)} cases x {args.variants} variants) in {duration:.1f}s",
    )
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
