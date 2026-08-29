#!/usr/bin/env python3
"""Exercise two BASIC LOADs with DOS status and directory commands in between."""
from __future__ import annotations

import argparse
import importlib.util
import os
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parents[1]
RUNNER = SCRIPT_DIR / "run-hackjunk-headless.py"


def load_runner():
    spec = importlib.util.spec_from_file_location("hackjunk_runner", RUNNER)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Cannot import {RUNNER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load_runner()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-env", type=Path, default=SCRIPT_DIR / "roms.env")
    parser.add_argument(
        "--variant",
        choices=("stock", "ramboard", "ramboard-rom"),
        required=True,
        help="1551 hardware/ROM combination",
    )
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--cpu", choices=("8501", "6510"), default="6510")
    parser.add_argument("--cart-bank", choices=("c0", "c1", "c2"), default="c1")
    parser.add_argument("--realtime", action="store_true")
    return parser.parse_args()


def wait_for_screen(port: int, predicate, timeout: float, description: str) -> str:
    deadline = time.monotonic() + timeout
    last_screen = ""
    while time.monotonic() < deadline:
        last_screen = runner.monitor_query(port, ["screen", "x"], timeout=max(0.1, deadline - time.monotonic()))
        if predicate(last_screen.lower()):
            return last_screen
        time.sleep(0.2)
    raise TimeoutError(f"Timed out waiting for {description}:\n{last_screen}")


def feed_command(port: int, command: str, timeout: float) -> None:
    escaped = command.replace("\\", "\\\\") + r"\x0d"
    runner.monitor_query(port, [f"keybuf {escaped}", "x"], timeout=timeout)


def let_command_run(realtime: bool) -> None:
    # Do not repeatedly stop both CPUs while a timing-sensitive TCBM transfer
    # is active. In warp 0.5 s is ample; realtime gets a user-like pause.
    time.sleep(2.0 if realtime else 0.5)


def screen_text(output: str) -> str:
    lines = []
    for line in output.splitlines():
        match = re.search(r"\*[A-Z]:[0-9a-f]{4}\s+(.*)$", line, re.IGNORECASE)
        if match:
            lines.append(match.group(1).rstrip())
    return "\n".join(lines)


def drive_statuses(output: str) -> list[str]:
    text = screen_text(output) or output
    return re.findall(r"\b\d{2},[^\r\n]*?,\d{2},\d{2}\b", text, re.IGNORECASE)


def main() -> int:
    args = parse_args()
    cfg = runner.load_rom_env(args.rom_env)
    cfg.update({key: value for key, value in os.environ.items() if key.startswith(("HOST_", "DRIVE_"))})

    xplus4 = runner.required_file("XPLUS4_TEST", os.environ.get("XPLUS4_TEST", str(ROOT / "vice/build-hackjunk/src/xplus4")))
    basic = runner.required_file("HOST_BASIC_STOCK", cfg.get("HOST_BASIC_STOCK"))
    if args.cpu == "6510":
        kernal_default = Path(cfg.get("HOST_KERNAL_STOCK", "")).parent.parent / "6510/kernal-6510-pal.bin"
        kernal = runner.required_file("HOST_KERNAL_6510", cfg.get("HOST_KERNAL_6510", str(kernal_default)))
        cpu_option = "-hackjunk6510"
    else:
        kernal = runner.required_file("HOST_KERNAL_STOCK", cfg.get("HOST_KERNAL_STOCK"))
        cpu_option = "+hackjunk6510"
    parobek = runner.required_file("PAROBEK_BIN", os.environ.get("PAROBEK_BIN", str(ROOT / "src/bin/parobek-via.bin")))
    disk = runner.required_file("DISK_IMAGE", os.environ.get("DISK_IMAGE", str(SCRIPT_DIR / "smoke-test.d64")))
    stock_rom = runner.required_file("DRIVE_1551_STOCK", cfg.get("DRIVE_1551_STOCK"))
    ramboard_rom = runner.required_file("DRIVE_1551_RAMBOARD", cfg.get("DRIVE_1551_RAMBOARD"))

    if args.variant == "stock":
        drive_rom, ram_option, expected_path = stock_rom, "+drive8ram8000", "1551 hypaload"
    elif args.variant == "ramboard":
        drive_rom, ram_option, expected_path = stock_rom, "-drive8ram8000", "1551 hypaload"
    else:
        drive_rom, ram_option, expected_path = ramboard_rom, "-drive8ram8000", "1551 ramboard"

    out_dir = SCRIPT_DIR / "out"
    out_dir.mkdir(exist_ok=True)
    cart_args = runner.cartridge_args(parobek, args.cart_bank, out_dir)
    prefix = out_dir / f"1551-wedge-{args.variant}-{args.cart_bank}"
    vice_log = prefix.with_name(prefix.name + "-vice.log")
    transcript = prefix.with_name(prefix.name + "-screens.txt")
    dumps = [prefix.with_name(prefix.name + f"-load-{number}.bin") for number in (1, 2)]
    for dump in dumps:
        dump.unlink(missing_ok=True)

    reference = out_dir / "1551-wedge-hello-reference.prg"
    extract = subprocess.run(
        ["c1541", str(disk), "-read", "hello", str(reference)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if extract.returncode or not reference.is_file():
        raise SystemExit(f"Cannot extract HELLO from {disk}:\n{extract.stdout}")
    prg = reference.read_bytes()
    load_start = prg[0] | (prg[1] << 8)
    expected = prg[2:]
    load_end = load_start + len(expected) - 1

    port = runner.free_port()
    cmd = [
        str(xplus4), "-default", cpu_option, "+sound",
        *([] if args.realtime else ["-warp"]), "-console",
        "-kernal", str(kernal), "-basic", str(basic),
        "-dos1551", str(drive_rom), "-drive8type", "1551", ram_option,
        "-drive8truedrive", "-drive9type", "0",
        *cart_args, "-8", str(disk), "-keybuf", "3",
        "-remotemonitor", "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
    ]
    with vice_log.open("wb") as log_file:
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=log_file, stderr=subprocess.STDOUT)

    snapshots: list[tuple[str, str]] = []
    stage = "boot"
    try:
        # Let the startup key buffer select mode 3 before remote-monitor polling.
        time.sleep(1.0)
        boot_screen = runner.monitor_query(port, ["screen", "x"], timeout=args.timeout)
        prefix.with_name(prefix.name + "-boot-screen.txt").write_text(boot_screen, encoding="latin-1")
        if not re.search(r"parobek on key f[123]", boot_screen.lower()) or "ready." not in boot_screen.lower():
            runner.wait_for_boot_ready(port, args.timeout)

        stage = "first LOAD command"
        feed_command(port, 'load"hello",8', args.timeout)
        let_command_run(args.realtime)
        stage = "first LOAD completion"
        screen = wait_for_screen(
            port,
            lambda value: expected_path in value and "loading" in value and value.count("ready.") >= 2,
            args.timeout,
            "first LOAD",
        )
        snapshots.append(('LOAD"HELLO",8 #1', screen_text(screen)))
        runner.monitor_query(port, [f'bsave "{dumps[0]}" 0 ${load_start:04x} ${load_end:04x}', "x"], timeout=args.timeout)

        stage = "first @ command"
        feed_command(port, "@", args.timeout)
        let_command_run(args.realtime)
        stage = "first @ status"
        screen = wait_for_screen(port, lambda value: len(drive_statuses(value)) >= 1, args.timeout, "first drive status")
        snapshots.append(("@ #1", screen_text(screen)))

        stage = "second LOAD command"
        feed_command(port, 'load"hello",8', args.timeout)
        let_command_run(args.realtime)
        stage = "second LOAD completion"
        screen = wait_for_screen(
            port,
            lambda value: value.count("loading") >= 2 and value.count("ready.") >= 3,
            args.timeout,
            "second LOAD",
        )
        snapshots.append(('LOAD"HELLO",8 #2', screen_text(screen)))
        runner.monitor_query(port, [f'bsave "{dumps[1]}" 0 ${load_start:04x} ${load_end:04x}', "x"], timeout=args.timeout)

        stage = "second @ command"
        feed_command(port, "@", args.timeout)
        let_command_run(args.realtime)
        stage = "second @ status"
        screen = wait_for_screen(port, lambda value: len(drive_statuses(value)) >= 2, args.timeout, "second drive status")
        snapshots.append(("@ #2", screen_text(screen)))

        stage = "$ command"
        feed_command(port, "$", args.timeout)
        let_command_run(args.realtime)
        stage = "$ directory"
        screen = wait_for_screen(
            port,
            lambda value: "hello" in value and "amaurote" in value and "blocks free" in value,
            args.timeout,
            "directory listing",
        )
        snapshots.append(("$", screen_text(screen)))
        runner.monitor_query(port, ["quit"], timeout=args.timeout)
        proc.wait(timeout=5.0)
    except TimeoutError as error:
        print(f"TIMEOUT during {stage}: {error}", file=sys.stderr)
        return 2
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()

    transcript.write_text(
        "\n\n".join(f"=== {title} ===\n{text}" for title, text in snapshots) + "\n",
        encoding="utf-8",
    )
    payload_results = [dump.is_file() and dump.read_bytes() == expected for dump in dumps]
    status_values = [drive_statuses(text)[-1] for title, text in snapshots if title.startswith("@")]
    status_results = [len(value) > 0 for value in status_values]
    directory = snapshots[-1][1].lower()
    directory_ok = "hello" in directory and "amaurote" in directory and "blocks free" in directory

    print(f"CPU: {args.cpu}, host KERNAL: {kernal}")
    print(f"Variant: {args.variant}, drive ROM: {drive_rom}, RAM: {'off' if ram_option.startswith('+') else 'on'}")
    print(f"Parobek ROM bank: {args.cart_bank.upper()}")
    print(f"Loader path: {expected_path}")
    print(f"LOAD #1 payload: {'OK' if payload_results[0] else 'FAIL'}")
    print(f"@ #1 status: {status_values[0] if status_results[0] else 'FAIL'}")
    print(f"LOAD #2 payload: {'OK' if payload_results[1] else 'FAIL'}")
    print(f"@ #2 status: {status_values[1] if status_results[1] else 'FAIL'}")
    print(f"$ directory: {'OK' if directory_ok else 'FAIL'}")
    print(f"Screens: {transcript}")
    print(f"VICE log: {vice_log}")
    return 0 if all(payload_results) and all(status_results) and directory_ok else 1


if __name__ == "__main__":
    sys.exit(main())
