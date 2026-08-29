#!/usr/bin/env python3
"""Run Parobek + JiffyDOS drive on the Hackjunk-patched headless VICE."""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shlex
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parents[1]
PLUS4_PAL_CLOCK_HZ = 1_773_447
DRIVE_POST_LOAD_SAMPLES = 32


def load_rom_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if re.fullmatch(r"[A-Z][A-Z0-9_]*", key) and "$(" not in value:
            values[key] = shlex.split(value)[0] if value else ""
    return values


def required_file(name: str, value: str | None) -> Path:
    if not value:
        raise SystemExit(f"Missing {name} in ROM environment")
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise SystemExit(f"Missing {name}: {path}")
    return path


def acme_label(name: str, variant: str = "via") -> int:
    labels = ROOT / f"src/labels-{variant}.txt"
    match = re.search(rf"^\s*{re.escape(name)}\s*=\s*\$([0-9a-f]+)", labels.read_text(), re.MULTILINE | re.IGNORECASE)
    if not match:
        raise SystemExit(f"Missing {name} in {labels}")
    return int(match.group(1), 16)


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def monitor_query(
    port: int,
    commands: list[str],
    timeout: float,
    *,
    wait_after_go: bool = False,
    transcript_path: Path | None = None,
    on_go_timeout: Callable[[], None] | None = None,
) -> str:
    deadline = time.monotonic() + timeout
    while True:
        try:
            sock = socket.create_connection(("127.0.0.1", port), timeout=1.0)
            break
        except OSError:
            if time.monotonic() >= deadline:
                raise TimeoutError("VICE remote monitor did not start")
            time.sleep(0.05)

    data = bytearray()
    transcript = transcript_path.open("wb") if transcript_path is not None else None

    def read_prompt(
        sock: socket.socket,
        expect_prompt: bool,
        *,
        expected_pc: str | None = None,
    ) -> None:
        response_start = len(data)
        while True:
            try:
                chunk = sock.recv(65536)
            except socket.timeout:
                if expect_prompt:
                    raise TimeoutError("VICE monitor command timed out")
                return
            if not chunk:
                return
            data.extend(chunk)
            if transcript is not None:
                transcript.write(chunk)
                transcript.flush()
            response = data[response_start:]
            prompt = (
                rb"\((?:C|8|9|10|11):\$"
                + (expected_pc.encode("ascii") if expected_pc else rb"[0-9a-fA-F]+")
                + rb"\) $"
            )
            if expect_prompt and re.search(prompt, response, re.IGNORECASE):
                return

    try:
        with sock:
            sock.settimeout(timeout)
            sock.sendall(b"\n")
            read_prompt(sock, expect_prompt=True)
            break_address: str | None = None
            break_count = 0
            recovered_go_timeout = False
            for command in commands:
                sock.sendall((command + "\n").encode("ascii"))
                break_match = re.fullmatch(r"break \$([0-9a-fA-F]+)", command)
                if break_match:
                    break_address = break_match.group(1)
                    break_count += 1
                elif command == "delete":
                    break_address = None
                    break_count = 0
                if (command.startswith("g ") and not wait_after_go) or command == "x":
                    return data.decode("latin-1", errors="replace")
                try:
                    read_prompt(
                        sock,
                        expect_prompt=command != "quit",
                        expected_pc=(
                            break_address
                            if wait_after_go and command.startswith("g ") and break_count == 1
                            else None
                        ),
                    )
                except TimeoutError:
                    if not (command.startswith("g ") and on_go_timeout and not recovered_go_timeout):
                        raise
                    recovered_go_timeout = True
                    on_go_timeout()
                    sock.settimeout(10.0)
                    read_prompt(sock, expect_prompt=True)
        return data.decode("latin-1", errors="replace")
    finally:
        if transcript is not None:
            transcript.close()


def wait_for_boot_ready(port: int, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    last_screen = ""
    while time.monotonic() < deadline:
        remaining = max(0.1, deadline - time.monotonic())
        last_screen = monitor_query(port, ["screen", "x"], timeout=remaining)
        screen = last_screen.lower()
        if re.search(r"parobek on key f[123]", screen) and "ready." in screen:
            return
        time.sleep(0.05)
    raise TimeoutError(f"Parobek did not reach READY screen:\n{last_screen}")


def cartridge_args(parobek: Path, cart_bank: str, out_dir: Path) -> list[str]:
    if cart_bank == "c1":
        return ["-c1", str(parobek)]
    if cart_bank == "c2":
        return ["-c2", str(parobek)]

    image = parobek.read_bytes()
    if len(image) != 0x8000:
        raise SystemExit(f"C0 Function ROM requires a 32 KiB image: {parobek} ({len(image)} bytes)")
    digest = hashlib.sha256(image).hexdigest()[:16]
    low = out_dir / f"function-{digest}-low.bin"
    high = out_dir / f"function-{digest}-high.bin"
    if not low.is_file() or low.read_bytes() != image[:0x4000]:
        low.write_bytes(image[:0x4000])
    if not high.is_file() or high.read_bytes() != image[0x4000:]:
        high.write_bytes(image[0x4000:])
    return ["-functionlo", str(low), "-functionhi", str(high)]


def sd2iec_1581_rom(jiffydos_rom: Path, out_dir: Path) -> Path:
    """Build a synthetic SD2IEC-identifying ROM for SJL detection tests."""
    image = bytearray(jiffydos_rom.read_bytes())
    old = b"JIFFYDOS"
    new = b"SD2IEC  "
    if image.count(old) != 1:
        raise SystemExit(
            f"Expected exactly one {old!r} signature in {jiffydos_rom}, "
            f"found {image.count(old)}"
        )
    signature_offset = image.index(old)
    image[signature_offset:signature_offset + len(old)] = new

    # A modified JiffyDOS 1581 ROM otherwise locks up during power-on. These
    # are the checksum bypasses used by the 1581 RAMBOard ROM patch.
    checksum_patches = {
        0x2BBC: (b"\xcc\x00", b"\x28\x60"),  # $ABBC: CRC-16 check
        0x2F8B: (b"\xd0\x3a", b"\xd0\x00"),  # $AF8B: additive checksum
    }
    for offset, (expected, replacement) in checksum_patches.items():
        actual = bytes(image[offset:offset + len(expected)])
        if actual != expected:
            raise SystemExit(
                f"Unexpected JiffyDOS 1581 bytes at ${offset + 0x8000:04x}: "
                f"expected {expected.hex(' ')}, found {actual.hex(' ')}"
            )
        image[offset:offset + len(expected)] = replacement

    patched = bytes(image)
    digest = hashlib.sha256(patched).hexdigest()[:16]
    output = out_dir / f"jiffydos-1581-sd2iec-{digest}.bin"
    if not output.is_file() or output.read_bytes() != patched:
        output.write_bytes(patched)
    return output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-env", type=Path, default=SCRIPT_DIR / "roms.env")
    parser.add_argument("--filename", default="HELLO", help="disk filename to LOAD")
    parser.add_argument("--device-number", type=int, default=8, help="IEC device number passed to SETLFS (default: 8)")
    parser.add_argument("--expect-device-missing", action="store_true", help="expect error 5 before loader detection")
    parser.add_argument("--cpu", choices=("8501", "6510"), default="6510")
    parser.add_argument("--host-rom", choices=("stock", "jiffydos"), default="stock")
    parser.add_argument("--drive", choices=("1541", "1551", "1581"), default="1541")
    parser.add_argument(
        "--drive-rom",
        choices=("stock", "jiffydos", "sd2iec", "ramboard"),
        default="jiffydos",
    )
    parser.add_argument(
        "--burstcart",
        choices=("none", "via", "cpld", "pio"),
        default="none",
        help="host fast-I/O hardware/cable model",
    )
    parser.add_argument(
        "--drive-ram",
        choices=("off", "on"),
        default="off",
        help="enable the 1541/1551 RAM expansion at $8000-$9fff",
    )
    parser.add_argument("--parobek-bin", type=Path, help="override the Parobek cartridge ROM")
    parser.add_argument("--cart-bank", choices=("c0", "c1", "c2"), default="c1",
                        help="attach Parobek as C0 Function ROM, C1, or C2")
    parser.add_argument("--reference-prg", type=Path, help="PRG used for byte comparison")
    parser.add_argument("--repeat", type=int, default=1, help="LOAD the file repeatedly without resetting VICE")
    parser.add_argument(
        "--load-timeout",
        type=float,
        default=120.0,
        help="maximum wall seconds to wait for LOAD completion (default: 120)",
    )
    parser.add_argument(
        "--boot-wait",
        type=float,
        default=10.0,
        help="maximum wall seconds to wait for Parobek READY screen (default: 10)",
    )
    parser.add_argument("--realtime", action="store_true", help="disable VICE warp mode")
    parser.add_argument("--seed", type=int, help="fixed VICE PRNG seed for reproducible drive timing")
    parser.add_argument("--drive-rpm", type=int, help="drive RPM times 100 (VICE default: 30000)")
    parser.add_argument("--drive-wobble-frequency", type=int, help="drive wobble frequency (VICE units)")
    parser.add_argument("--drive-wobble-amplitude", type=int, help="drive wobble amplitude (VICE units)")
    parser.add_argument(
        "--cpld-response-delay",
        type=int,
        default=0,
        help="delay each emulated CPLD response by this many host status reads",
    )
    parser.add_argument(
        "--pre-load-frames",
        type=int,
        default=0,
        help="emulated PAL frames to wait before each LOAD (default: 0)",
    )
    parser.add_argument(
        "--diagnose-timeout",
        action="store_true",
        help="interrupt a stuck LOAD, save CPU history, and attempt a snapshot",
    )
    parser.add_argument(
        "--history-lines",
        type=int,
        default=8192,
        help="CPU history records saved by --diagnose-timeout (default: 8192)",
    )
    parser.add_argument(
        "--watchdog-hits",
        type=int,
        default=0,
        help="optional ignored wait-loop hits before a diagnostic stop (default: disabled)",
    )
    parser.add_argument("--save-pre-load-snapshot", type=Path,
                        help="save a VICE snapshot immediately before LOAD")
    parser.add_argument("--load-pre-load-snapshot", type=Path,
                        help="restore a VICE snapshot immediately before LOAD")
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.repeat < 1:
        raise SystemExit("--repeat must be at least 1")
    if (args.save_pre_load_snapshot or args.load_pre_load_snapshot) and args.repeat != 1:
        raise SystemExit("pre-LOAD snapshots require --repeat 1")
    if args.load_pre_load_snapshot and not args.load_pre_load_snapshot.is_file():
        raise SystemExit(f"Missing pre-LOAD snapshot: {args.load_pre_load_snapshot}")
    if not 4 <= args.device_number <= 30:
        raise SystemExit("--device-number must be in the range 4-30")
    if args.history_lines < 10:
        raise SystemExit("--history-lines must be at least 10")
    if args.watchdog_hits < 0:
        raise SystemExit("--watchdog-hits cannot be negative")
    if not 0 <= args.pre_load_frames <= 255:
        raise SystemExit("--pre-load-frames must be in the range 0-255")
    if args.seed is not None and args.seed < 0:
        raise SystemExit("--seed cannot be negative")
    if args.drive_rpm is not None and not 28000 <= args.drive_rpm <= 32000:
        raise SystemExit("--drive-rpm must be in the range 28000-32000")
    if args.drive_wobble_frequency is not None and not 0 <= args.drive_wobble_frequency <= 50000:
        raise SystemExit("--drive-wobble-frequency must be in the range 0-50000")
    if args.drive_wobble_amplitude is not None and not 0 <= args.drive_wobble_amplitude <= 5000:
        raise SystemExit("--drive-wobble-amplitude must be in the range 0-5000")
    if not args.rom_env.is_file():
        raise SystemExit(f"Missing {args.rom_env}")
    cfg = load_rom_env(args.rom_env)
    cfg.update({key: value for key, value in os.environ.items() if key in cfg or key.startswith("HOST_") or key.startswith("DRIVE_")})

    if not args.no_build:
        subprocess.run([str(SCRIPT_DIR / "build-hackjunk-vice.sh")], check=True)

    xplus4 = required_file("XPLUS4_TEST", os.environ.get("XPLUS4_TEST", str(ROOT / "vice/build-hackjunk/src/xplus4")))
    basic = required_file("HOST_BASIC_STOCK", cfg.get("HOST_BASIC_STOCK"))
    default_parobek = "parobek-cpld.bin" if args.burstcart == "cpld" else "parobek-via.bin"
    if args.parobek_bin:
        parobek_value = str(args.parobek_bin)
    elif args.burstcart == "cpld":
        parobek_value = str(ROOT / f"src/bin/{default_parobek}")
    else:
        parobek_value = os.environ.get("PAROBEK_BIN", cfg.get("PAROBEK_BIN", str(ROOT / f"src/bin/{default_parobek}")))
    parobek = required_file("PAROBEK_BIN", parobek_value)
    out_dir = SCRIPT_DIR / "out"
    out_dir.mkdir(exist_ok=True)

    if args.cpu == "6510":
        if args.host_rom != "stock":
            raise SystemExit("The 6510 matrix only supports the patched non-JiffyDOS host KERNAL")
        kernal_default = Path(cfg.get("HOST_KERNAL_STOCK", "")).parent.parent / "6510/kernal-6510-pal.bin"
        kernal = required_file("HOST_KERNAL_6510", cfg.get("HOST_KERNAL_6510", str(kernal_default)))
        cpu_option = "-hackjunk6510"
        expected_cpu_type = 1
    else:
        kernal_key = "HOST_KERNAL_JD" if args.host_rom == "jiffydos" else "HOST_KERNAL_STOCK"
        kernal = required_file(kernal_key, cfg.get(kernal_key))
        cpu_option = "+hackjunk6510"
        expected_cpu_type = 0

    if args.drive == "1551":
        if args.drive_rom not in ("stock", "ramboard"):
            raise SystemExit("1551 supports --drive-rom stock or ramboard")
        if args.drive_rom == "ramboard" and args.drive_ram != "on":
            raise SystemExit("The RAMBOard 1551 ROM requires --drive-ram on")
        drive_key = "DRIVE_1551_RAMBOARD" if args.drive_rom == "ramboard" else "DRIVE_1551_STOCK"
        drive_rom = required_file(drive_key, cfg.get(drive_key))
        disk = required_file("DISK_IMAGE", os.environ.get("DISK_IMAGE", str(SCRIPT_DIR / "smoke-test.d64")))
        drive_args = [
            "-dos1551", str(drive_rom), "-drive8type", "1551",
            "-drive8ram8000" if args.drive_ram == "on" else "+drive8ram8000",
        ]
    elif args.drive == "1581":
        if args.drive_rom == "ramboard" or args.drive_ram != "off":
            raise SystemExit("1581 does not support the 1551 RAMBOard options")
        if args.drive_rom in ("jiffydos", "sd2iec"):
            drive_rom = required_file("DRIVE_1581_JD", cfg.get("DRIVE_1581_JD"))
            if args.drive_rom == "sd2iec":
                drive_rom = sd2iec_1581_rom(drive_rom, out_dir)
        else:
            drive_rom = required_file("DRIVE_1581_STOCK", cfg.get("DRIVE_1581_STOCK"))
        disk = required_file("DISK_IMAGE_1581", os.environ.get("DISK_IMAGE_1581", str(SCRIPT_DIR / "smoke-test.d81")))
        drive_args = ["-dos1581", str(drive_rom), "-drive8type", "1581"]
    else:
        if args.drive_rom == "sd2iec":
            raise SystemExit("The synthetic SD2IEC ROM is only supported with --drive 1581")
        if args.drive_rom == "ramboard":
            if args.drive_ram != "on":
                raise SystemExit("The RAMBOard 1541 ROM requires --drive-ram on")
            drive_key = "DRIVE_1541_RAMBOARD"
            default_ramboard = "/home/maciej/Maciejdev/15x1-ramexp-github/1541-RAMBOard-FirstBank/dos1541ii-251968-03-patched.bin"
            drive_rom = required_file(drive_key, cfg.get(drive_key, default_ramboard))
        else:
            if args.drive_ram != "off":
                raise SystemExit("1541 RAM requires --drive-rom ramboard")
            drive_key = "DRIVE_1541_JD" if args.drive_rom == "jiffydos" else "DRIVE_1541_STOCK"
            drive_rom = required_file(drive_key, cfg.get(drive_key))
        disk = required_file("DISK_IMAGE", os.environ.get("DISK_IMAGE", str(SCRIPT_DIR / "smoke-test.d64")))
        drive_args = [
            "-dos1541II", str(drive_rom), "-drive8type", "1542",
            "-drive8ram8000" if args.drive_ram == "on" else "+drive8ram8000",
        ]

    if args.burstcart == "cpld" and args.drive != "1581":
        raise SystemExit("BurstCart CPLD tests require a 1571/1581 drive")
    if args.burstcart == "pio" and args.drive != "1541":
        raise SystemExit("PIO parallel cable tests require a 1541 drive")
    if args.burstcart == "via":
        hardware_args = ["-burstcart", "1"]
        hardware_args.append("-burstcartparallel" if args.drive == "1541" else "-burstcartburst")
    elif args.burstcart == "cpld":
        hardware_args = [
            "-burstcart", "2", "-burstcartburst",
            "-burstcartcplddelay", str(args.cpld_response_delay),
        ]
    elif args.burstcart == "pio":
        hardware_args = ["-burstcart", "0", "-parallel8", "1"]
    else:
        hardware_args = ["-burstcart", "0"]

    if args.burstcart == "via" and args.drive == "1581":
        expected_path = "via burst"
    elif args.burstcart == "cpld":
        expected_path = "cpld burst"
    elif args.burstcart in ("via", "pio") and args.drive == "1541":
        expected_path = "1541/parallel"
    elif args.drive == "1551":
        expected_path = "1551 ramboard" if args.drive_rom == "ramboard" else "1551 hypaload"
    elif args.host_rom == "jiffydos":
        expected_path = "host jiffydos"
    elif args.drive_rom == "sd2iec":
        expected_path = "sd2iec, sjl264"
    elif args.drive_rom == "jiffydos":
        expected_path = "sjl264"
    elif args.drive == "1541":
        expected_path = "1541 serial"
    else:
        expected_path = "rom load"
    filename = args.filename.upper()
    if not filename.isascii() or not 1 <= len(filename) <= 16:
        raise SystemExit("--filename must be 1-16 ASCII characters")

    cart_args = cartridge_args(parobek, args.cart_bank, out_dir)
    result_parts = [
        f"cpu{args.cpu}", f"host-{args.host_rom}",
        f"drive{args.drive}-{args.drive_rom}" + (f"-ram-{args.drive_ram}" if args.drive_ram != "off" else ""),
        f"hardware-{args.burstcart}",
    ]
    if args.device_number != 8:
        result_parts.append(f"device-{args.device_number}")
    if args.cart_bank != "c1":
        result_parts.append(f"cart-{args.cart_bank}")
    if args.parobek_bin:
        result_parts.append(f"rom-{hashlib.sha256(parobek.read_bytes()).hexdigest()[:8]}")
    if args.repeat > 1:
        result_parts.append(f"repeat-{args.repeat}")
    if args.seed is not None:
        result_parts.append(f"seed-{args.seed}")
    if args.pre_load_frames:
        result_parts.append(f"delay-{args.pre_load_frames}f")
    if args.drive_rpm is not None:
        result_parts.append(f"rpm-{args.drive_rpm}")
    if args.drive_wobble_frequency is not None:
        result_parts.append(f"wobble-f-{args.drive_wobble_frequency}")
    if args.drive_wobble_amplitude is not None:
        result_parts.append(f"wobble-a-{args.drive_wobble_amplitude}")
    result_parts.extend((
        re.sub(r"[^a-z0-9]+", "-", filename.lower()).strip("-"),
        "realtime" if args.realtime else "warp",
    ))
    result_name = "-".join(result_parts)
    if args.reference_prg:
        reference = required_file("REFERENCE_PRG", str(args.reference_prg))
    else:
        reference = out_dir / f"{result_name}-disk.prg"
        reference.unlink(missing_ok=True)
        extract = subprocess.run(
            ["c1541", str(disk), "-read", filename.lower(), str(reference)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if extract.returncode or not reference.is_file():
            raise SystemExit(f"Cannot extract {filename} from {disk}:\n{extract.stdout}")
    prg = reference.read_bytes()
    if len(prg) < 3:
        raise SystemExit(f"Invalid PRG: {reference}")
    load_start = prg[0] | (prg[1] << 8)
    expected = prg[2:]
    load_end = load_start + len(expected) - 1
    if load_end > 0xffff:
        raise SystemExit(f"PRG exceeds address space: {reference}")

    memory_dumps = [
        out_dir / (
            f"{result_name}-memory.bin"
            if args.repeat == 1
            else f"{result_name}-load-{load_number}-memory.bin"
        )
        for load_number in range(1, args.repeat + 1)
    ]
    vice_log = out_dir / f"{result_name}-vice.log"
    monitor_log = out_dir / f"{result_name}-monitor.log"
    live_monitor_log = out_dir / f"{result_name}-monitor-live.log"
    diagnostic_snapshot = out_dir / (
        f"timeout-{hashlib.sha256(result_name.encode('ascii')).hexdigest()[:16]}.vsf"
    )
    diagnostic_snapshot.unlink(missing_ok=True)
    for memory_dump in memory_dumps:
        memory_dump.unlink(missing_ok=True)

    port = free_port()
    cmd = [
        str(xplus4), "-default", cpu_option, "+sound",
        *([] if args.realtime else ["-warp"]), "-console",
        *([] if args.seed is None else ["-seed", str(args.seed)]),
        *([] if args.drive_rpm is None else ["-drive8rpm", str(args.drive_rpm)]),
        *([] if args.drive_wobble_frequency is None else [
            "-drive8wobblefrequency", str(args.drive_wobble_frequency),
        ]),
        *([] if args.drive_wobble_amplitude is None else [
            "-drive8wobbleamplitude", str(args.drive_wobble_amplitude),
        ]),
        "-kernal", str(kernal), "-basic", str(basic),
        *drive_args, *hardware_args, "-drive8truedrive", "-drive9type", "0",
        *cart_args, "-8", str(disk),
        "-keybuf", "3",
        "-remotemonitor", "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
    ]
    if args.diagnose_timeout:
        live_monitor_log.unlink(missing_ok=True)
        cmd.extend(("-monchislines", str(args.history_lines)))
    with vice_log.open("wb") as log_file:
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=log_file, stderr=subprocess.STDOUT)
    try:
        wait_for_boot_ready(port, args.boot_wait)
        # The injected loader stays below the tested PRGs, at $0800-$082f.
        filename_bytes = " ".join(f"${value:02x}" for value in filename.encode("ascii"))
        commands = [
            f"> $0800 $a9 ${len(filename):02x} $a2 $20 $a0 $08 $20 $bd $ff",
            f"> $0809 $a9 $01 $a2 ${args.device_number:02x} $a0 $01 $20 $ba $ff",
            f"> $0812 $a9 $00 $a2 ${load_start & 0xff:02x} $a0 ${load_start >> 8:02x} $20 $d5 $ff $4c $1b $08",
            f"> $0820 {filename_bytes}",
            f"m ${acme_label('cpu_port_type'):04x} ${acme_label('cpu_port_type'):04x}",
        ]
        for memory_dump in memory_dumps:
            if args.pre_load_frames:
                commands.extend([
                    "delete",
                    "> $0830 "
                    f"$a2 ${args.pre_load_frames:02x} $a5 $a5 $c5 $a5 $f0 $fc "
                    "$a5 $a5 $ca $d0 $f7 $4c $40 $08",
                    "break $0840",
                    "g $0830",
                ])
            if args.load_pre_load_snapshot:
                commands.append(f'undump "{args.load_pre_load_snapshot.resolve()}"')
            commands.extend([
                "delete",
                "break $081b",
            ])
            if args.diagnose_timeout:
                trace_commands = [
                    "trace exec $874c",       # cartridge LOAD dispatcher
                    "trace exec $8783",       # IEC loader selection
                    "trace exec $8fce",       # drive classification
                    "trace exec $8ed0",       # error-channel read
                    "trace exec $8ee2",       # TALK status channel
                    "trace exec $8eee",       # secondary address 15
                    "trace exec $8efa",       # status byte input
                    "trace exec $8f0b",       # status channel complete
                    "trace exec $8f1b",       # UI drive reset
                    "trace exec $901f",       # SJL wrapper
                    "trace exec $9047",       # highcode after IEC OPEN
                    "trace exec $972e",       # TALK
                    "trace exec $97fd",       # secondary TALK
                    "trace exec $983b",       # address byte input
                    "trace exec $9195",       # timed 6510 receiver
                    "trace exec $919c",       # next drive block / resync
                    "trace exec $91b0",       # first byte after handshake
                    "trace exec $9213",       # destination page crossing
                    "trace exec $9218",       # EOI / end of load
                    "trace store $009d $009e",# destination pointer progress
                    "trace store $0001",      # host IEC output changes
                    "trace store 8:$1800",    # 1541 VIA1 IEC output changes
                    "trace store 8:$1802",    # 1541 VIA1 direction changes
                    "trace exec 8:$ff33",     # 1541 DOS error path
                    "trace exec 8:$ff50",
                ]
                if args.burstcart == "cpld":
                    trace_commands.extend([
                        f"trace exec ${acme_label('CPLDFound', 'cpld'):04x}",
                        f"trace exec ${acme_label('NotFast', 'cpld'):04x}",
                        "trace load $fd90 $fd91",
                        "trace store $fd90 $fd91",
                    ])
                commands.extend(trace_commands)
                if args.watchdog_hits:
                    wait_addresses = (0x91a0, 0x91ab, 0x9751, 0x97d3, 0x9816, 0x9887)
                    for checkpoint, address in enumerate(
                        wait_addresses,
                        start=2 + len(trace_commands),
                    ):
                        commands.extend((
                            f"break ${address:04x}",
                            f"ignore {checkpoint} +{args.watchdog_hits}",
                        ))
            if args.save_pre_load_snapshot:
                args.save_pre_load_snapshot.parent.mkdir(parents=True, exist_ok=True)
                commands.append(f'dump "{args.save_pre_load_snapshot.resolve()}"')
            commands.extend([
                "sw reset",
                "g $0800",
            ])
            if args.diagnose_timeout:
                commands.extend([
                    "r",
                    "device 8:",
                    "r",
                    "device c:",
                    "m $0000 $0005",
                    "m $0090 $009e",
                    "m 8:$0000 8:$0005",
                    "m 8:$1800 8:$180f",
                    "m 8:$1c00 8:$1c0f",
                    f'dump "{diagnostic_snapshot}"',
                    f"cpuhistory {args.history_lines} c: 8:",
                ])
            commands.extend([
                "sw",
                "screen",
                f"m ${acme_label('cpu_port_type'):04x} ${acme_label('cpu_port_type'):04x}",
                'resourceget "HackJunk6510"',
                'resourceget "BurstCartModel"',
                'resourceget "BurstCartParallelCable"',
                'resourceget "BurstCartBurstSerialCable"',
                'resourceget "Drive8ParallelCable"',
                "m $009d $009e",
                f"m ${load_start:04x} ${min(load_end, load_start + 0x2f):04x}",
                f"m ${max(load_start, load_end - 0x2f):04x} ${load_end:04x}",
                f'bsave "{memory_dump}" 0 ${load_start:04x} ${load_end:04x}',
            ])
            if args.drive != "1551":
                continue
            # Let the uploaded drive code finish its final handshake and reset.
            # Spaced samples also expose the slower ROM error blink sequence.
            commands.extend([
                "m 8:$0000 8:$0001",
                "delete",
                "> $0830 $a9 $01 $a0 $00 $a2 $00 $ca $d0 $fd $88 $d0 $f8 $38 $e9 $01 $d0 $f1 $4c $41 $08",
                "break $0841",
            ])
            for _ in range(DRIVE_POST_LOAD_SAMPLES):
                commands.extend(("g $0830", "m 8:$0000 8:$0001"))
        commands.append("quit")
        load_timed_out = False

        def enter_timeout_monitor() -> None:
            nonlocal load_timed_out
            load_timed_out = True
            proc.send_signal(signal.SIGUSR1)

        output = monitor_query(
            port,
            commands,
            timeout=args.load_timeout,
            wait_after_go=True,
            transcript_path=live_monitor_log if args.diagnose_timeout else None,
            on_go_timeout=enter_timeout_monitor if args.diagnose_timeout else None,
        )
        monitor_log.write_text(output, encoding="latin-1")
        proc.wait(timeout=5.0)
        if load_timed_out:
            print(f"TIMEOUT: LOAD did not reach its completion breakpoint", file=sys.stderr)
            print(f"monitor diagnostics: {monitor_log}", file=sys.stderr)
            print(f"VICE log: {vice_log}", file=sys.stderr)
            return 2
    except TimeoutError as error:
        print(f"TIMEOUT: {error}", file=sys.stderr)
        if args.diagnose_timeout:
            print(f"partial monitor trace: {live_monitor_log}", file=sys.stderr)
        print(f"VICE log: {vice_log}", file=sys.stderr)
        return 2
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()

    actuals = [memory_dump.read_bytes() if memory_dump.is_file() else b"" for memory_dump in memory_dumps]
    cpu_addr = acme_label("cpu_port_type")
    cpu_match = re.search(rf">C:{cpu_addr:04x}\s+([0-9a-f]{{2}})", output, re.IGNORECASE)
    cpu_type = int(cpu_match.group(1), 16) if cpu_match else None
    accepted_cpu_types = (
        (expected_cpu_type, 3)
        if args.drive == "1551" and args.cpu == "8501"
        else (expected_cpu_type,)
    )
    cpu_type_ok = args.parobek_bin is not None or cpu_type in accepted_cpu_types
    resource_match = re.search(r"HackJunk6510\s*=\s*([01])", output, re.IGNORECASE)
    resource_value = int(resource_match.group(1)) if resource_match else None
    resource_ok = resource_value == (1 if args.cpu == "6510" else 0)
    expected_burstcart_model = {"none": 0, "pio": 0, "via": 1, "cpld": 2}[args.burstcart]
    burstcart_match = re.search(r"BurstCartModel\s*=\s*([0-2])", output, re.IGNORECASE)
    burstcart_value = int(burstcart_match.group(1)) if burstcart_match else None
    burstcart_ok = burstcart_value == expected_burstcart_model
    parallel_match = re.search(r"Drive8ParallelCable\s*=\s*(\d+)", output, re.IGNORECASE)
    parallel_value = int(parallel_match.group(1)) if parallel_match else None
    expected_parallel = 5 if args.burstcart == "via" and args.drive == "1541" else (
        1 if args.burstcart == "pio" else 0
    )
    parallel_ok = parallel_value == expected_parallel
    payload_results = [actual == expected for actual in actuals]
    payload_ok = all(payload_results)
    path_count = output.lower().count(expected_path)
    cpld_fallback = args.burstcart == "cpld" and any(
        fallback in output.lower()
        for fallback in ("sjl264", "rom load", "1541 serial", "1541/parallel")
    )
    path_ok = path_count >= args.repeat and not cpld_fallback
    screen_upper = output.upper()
    kernal_device_missing = bool(re.search(
        r"\.C:081b[^\r\n]*A:05[^\r\n]*C\s+\d+",
        output,
        re.IGNORECASE,
    ))
    device_missing_ok = (
        kernal_device_missing
        and "IEC DEVICE" not in screen_upper
        and "CPLD BURST" not in screen_upper
        and "TCBM DEVICE" not in screen_upper
    ) if args.expect_device_missing else True
    if args.expect_device_missing:
        payload_ok = True
        path_ok = True
    clocks = [int(value) for value in re.findall(r"Stopwatch:\s*(\d+)", output, re.IGNORECASE)]
    clocks = clocks[-args.repeat:]
    timings = [
        (
            clock_count,
            clock_count / PLUS4_PAL_CLOCK_HZ,
            len(expected) / (clock_count / PLUS4_PAL_CLOCK_HZ),
        )
        for clock_count in clocks
    ]
    drive_samples: list[tuple[int, int, bool]] = []
    if args.drive == "1551":
        for match in re.finditer(r"(?:>8:|\.8:|8:)(?:0000)?\s+([0-9a-f]{2})\s+([0-9a-f]{2})", output, re.IGNORECASE):
            direction, data = (int(value, 16) for value in match.groups())
            port_output = (data & direction) | (~direction & 0xff)
            drive_samples.append((direction, data, not bool(port_output & 0x08)))
        drive_samples = drive_samples[-(DRIVE_POST_LOAD_SAMPLES + 1) * args.repeat:]
    samples_per_load = DRIVE_POST_LOAD_SAMPLES + 1
    drive_sample_groups = [
        drive_samples[offset:offset + samples_per_load]
        for offset in range(0, len(drive_samples), samples_per_load)
    ]
    drive_idle_ok = args.drive != "1551" or (
        len(drive_sample_groups) == args.repeat
        and all(
            len(samples) == samples_per_load and not any(sample[2] for sample in samples[1:])
            for samples in drive_sample_groups
        )
    )

    print(f"VICE: {xplus4}")
    print(f"CPU: {args.cpu}, host ROM: {args.host_rom} ({kernal})")
    drive_ram_note = f", RAM: {args.drive_ram}" if args.drive_ram != "off" else ""
    print(f"Drive: {args.drive}, ROM: {args.drive_rom}{drive_ram_note} ({drive_rom})")
    print(f"Host I/O hardware: {args.burstcart}")
    print(f"LOAD device number: {args.device_number}")
    print(f"Parobek ROM bank: {args.cart_bank.upper()}")
    print(f"HackJunk6510 resource: {resource_value} ({'OK' if resource_ok else 'FAIL'})")
    print(f"BurstCartModel resource: {burstcart_value} ({'OK' if burstcart_ok else 'FAIL'})")
    print(f"Drive8ParallelCable resource: {parallel_value} ({'OK' if parallel_ok else 'FAIL'})")
    expected_cpu_text = "/".join(str(value) for value in accepted_cpu_types)
    if args.parobek_bin:
        print(f"cpu_port_type: not checked with historical ROM (current-label value: {cpu_type})")
    else:
        print(f"cpu_port_type: {cpu_type} ({'OK' if cpu_type_ok else f'expected {expected_cpu_text}'})")
    path_note = (
        f"{'OK' if path_ok else 'FAIL'}, occurrences={path_count}"
        if args.repeat > 1
        else ("OK" if path_ok else "NOT FOUND")
    )
    if args.expect_device_missing:
        print(f"device missing before loader detection: {'OK' if device_missing_ok else 'FAIL'}")
    else:
        print(f"loader path: {expected_path} ({path_note})")
        if args.burstcart == "cpld":
            print(f"CPLD burst attempt fell back: {'YES' if cpld_fallback else 'no'}")
    for index, actual in enumerate(actuals, 1):
        prefix = f"load {index}: " if args.repeat > 1 else ""
        if args.expect_device_missing:
            print(f"{prefix}{filename} payload: not expected")
            continue
        payload_note = "OK" if payload_results[index - 1] else f"FAIL ({len(actual)}/{len(expected)} bytes)"
        print(f"{prefix}{filename} payload: {payload_note}")
        if args.drive == "1551":
            samples = drive_sample_groups[index - 1] if index <= len(drive_sample_groups) else []
            port_states = ",".join(
                f"${direction:02x}/${data:02x}"
                for direction, data in sorted({(sample[0], sample[1]) for sample in samples})
            ) or "not found"
            led_sequence = "".join("1" if sample[2] else "0" for sample in samples) or "not found"
            load_idle_ok = len(samples) == samples_per_load and not any(sample[2] for sample in samples[1:])
            print(f"{prefix}1551 post-load DDR/PORT states: {port_states}")
            print(f"{prefix}1551 LED sequence (1=on): {led_sequence}")
            print(f"{prefix}1551 idle LED: {'OK' if load_idle_ok else 'FAIL'}")
    print(f"load range: ${load_start:04x}-${load_end:04x} ({len(expected)} bytes)")
    for index in range(1, args.repeat + 1):
        prefix = f"load {index} " if args.repeat > 1 else ""
        if index <= len(timings):
            clock_count, emulated_seconds, throughput = timings[index - 1]
            print(f"{prefix}performance: {clock_count} VICE clocks = {emulated_seconds:.6f} emulated s, {throughput:.1f} bytes/s")
        else:
            print(f"{prefix}performance: stopwatch result NOT FOUND")
    print(f"monitor: {monitor_log}")
    print(f"VICE log: {vice_log}")
    timing_ok = len(timings) == args.repeat
    return 0 if (
        payload_ok and cpu_type_ok and resource_ok and burstcart_ok and parallel_ok
        and path_ok and timing_ok and drive_idle_ok and device_missing_ok
    ) else 1


if __name__ == "__main__":
    sys.exit(main())
