#!/usr/bin/env python3
"""Exercise the assembled @ status printer and verify CR normalization."""
from __future__ import annotations

import re
from pathlib import Path

from py65.devices.mpu6502 import MPU

ROOT = Path(__file__).resolve().parents[1]
RAM_FA = 0xAE
RAM_STATUS = 0x90


def load_labels(variant: str) -> dict[str, int]:
    return {
        name: int(address, 16)
        for name, address in re.findall(
            r"^\s*(\w+)\s*=\s*\$([0-9a-f]+)",
            (ROOT / f"src/labels-{variant}.txt").read_text(),
            re.MULTILINE | re.IGNORECASE,
        )
    }


def run_status(variant: str, bus: str, events: list[tuple[int, int]]) -> bytes:
    labels = load_labels(variant)
    cpu = MPU()
    cpu.memory[0x8000:0x10000] = (ROOT / f"src/bin/parobek-{variant}.bin").read_bytes()
    cpu.memory[RAM_FA] = 8
    cpu.memory[RAM_STATUS] = 0
    cpu.sp = 0xFF
    cpu.stPushWord(0x6FFF)
    cpu.pc = labels["dos_display_status"]
    output = bytearray()
    event_index = 0

    def rts() -> None:
        low = cpu.stPop()
        high = cpu.stPop()
        cpu.pc = (((high << 8) | low) + 1) & 0xFFFF

    passive_calls = {
        labels["ROM_TALK"],
        labels["ROM_TKSA"],
        labels["ROM_UNTLK"],
    }
    receiver = labels["iec_acptr"] if bus == "iec" else labels["ROM_ACPTR"]

    for _ in range(20000):
        if cpu.pc == 0x7000:
            return bytes(output)
        if cpu.pc == labels["eEDA9"]:
            if bus == "iec":
                cpu.p |= cpu.CARRY
            else:
                cpu.p &= ~cpu.CARRY
            rts()
        elif cpu.pc in passive_calls:
            rts()
        elif cpu.pc == labels["ROM_READST"]:
            cpu.a = cpu.memory[RAM_STATUS]
            rts()
        elif cpu.pc == receiver:
            if event_index >= len(events):
                raise AssertionError((variant, bus, "status reader exhausted"))
            cpu.a, cpu.memory[RAM_STATUS] = events[event_index]
            event_index += 1
            rts()
        elif cpu.pc == labels["ROM_CHROUT"]:
            output.append(cpu.a)
            rts()
        else:
            cpu.step()
    raise AssertionError((variant, bus, "status printer did not return"))


def stream(data: bytes, final_status: int = 0x40) -> list[tuple[int, int]]:
    return [
        (value, final_status if index == len(data) - 1 else 0)
        for index, value in enumerate(data)
    ]


for variant in ("via", "cpld"):
    for bus in ("iec", "tcbm"):
        # Pi1541-style EOI+NUL gets one synthesized CR.
        events = [(value, 0) for value in b"00, OK,00,00"] + [(0, 0x40)]
        assert run_status(variant, bus, events) == b"00, OK,00,00\r"

        # A CR supplied by the device is preserved, never duplicated.
        assert run_status(variant, bus, stream(b"00, OK,00,00\r")) == b"00, OK,00,00\r"
        assert run_status(variant, bus, stream(b"00, OK,00,00\r", 0)) == b"00, OK,00,00\r"

        # EOI on a regular final character and the 40-byte guard both add CR.
        assert run_status(variant, bus, stream(b"OK")) == b"OK\r"
        assert run_status(variant, bus, [(ord("X"), 0)] * 40) == b"X" * 40 + b"\r"

        # A receive error terminates a partial line cleanly, but prints
        # nothing if no status byte was accepted.
        assert run_status(variant, bus, [(ord("O"), 0), (0, 0x02)]) == b"O\r"
        assert run_status(variant, bus, [(0, 0x02)]) == b""

print("DOS status output has exactly one trailing CR (IEC/TCBM, VIA/CPLD)")
