#!/usr/bin/env python3
"""Hunt intermittent CPLD-to-SJL fallbacks and replay the pre-LOAD snapshot."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "run-hackjunk-headless.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--attempts", type=int, default=200)
    parser.add_argument("--first-seed", type=int, default=10000)
    parser.add_argument("--filename", default="HELLO")
    parser.add_argument("--load-timeout", type=float, default=120.0)
    parser.add_argument("--history-lines", type=int, default=50000)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.attempts < 1:
        raise SystemExit("--attempts must be positive")

    out_dir = SCRIPT_DIR / "out/cpld-hunt"
    out_dir.mkdir(parents=True, exist_ok=True)
    candidate = out_dir / "candidate.vsf"
    common = [
        sys.executable, str(RUNNER), "--no-build",
        "--cpu", "6510", "--host-rom", "stock",
        "--drive", "1581", "--drive-rom", "jiffydos",
        "--burstcart", "cpld", "--filename", args.filename,
        "--load-timeout", str(args.load_timeout),
    ]

    for attempt in range(args.attempts):
        seed = args.first_seed + attempt
        delay = (seed * 73) % 101
        cmd = [
            *common,
            "--seed", str(seed),
            "--pre-load-frames", str(delay),
            "--save-pre-load-snapshot", str(candidate),
        ]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True)
        log = out_dir / f"attempt-{attempt + 1:04d}-seed-{seed}-delay-{delay}.txt"
        log.write_text(proc.stdout, encoding="utf-8")
        fallback = "CPLD burst attempt fell back: YES" in proc.stdout
        status = "FALLBACK" if fallback else ("PASS" if proc.returncode == 0 else "FAIL")
        print(f"[{attempt + 1:04d}/{args.attempts}] {status} seed={seed} delay={delay}", flush=True)
        if not fallback:
            continue

        hit = out_dir / f"fallback-seed-{seed}-delay-{delay}.vsf"
        shutil.copy2(candidate, hit)
        replay_log = out_dir / f"fallback-seed-{seed}-delay-{delay}-trace.txt"
        replay = subprocess.run([
            *common,
            "--seed", str(seed + 1_000_000),
            "--load-pre-load-snapshot", str(hit),
            "--diagnose-timeout",
            "--history-lines", str(args.history_lines),
        ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        replay_log.write_text(replay.stdout, encoding="utf-8")
        reproduced = "CPLD burst attempt fell back: YES" in replay.stdout
        print(f"snapshot: {hit}")
        print(f"trace replay: {'REPRODUCED' if reproduced else 'NOT REPRODUCED'} ({replay_log})")
        return 0 if reproduced else 2

    print(f"No CPLD fallback in {args.attempts} attempts. Logs: {out_dir}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
