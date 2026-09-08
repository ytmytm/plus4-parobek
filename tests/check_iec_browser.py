#!/usr/bin/env python3
"""Run the assembled status classifier and browser dispatch with py65."""
import re
from pathlib import Path

from py65.devices.mpu6502 import MPU

ROOT = Path(__file__).resolve().parents[1]

for variant in ("via", "cpld"):
    labels = {
        name: int(address, 16)
        for name, address in re.findall(
            r"^\s*(\w+)\s*=\s*\$([0-9a-f]+)",
            (ROOT / f"src/labels-{variant}.txt").read_text(),
            re.MULTILINE | re.IGNORECASE,
        )
    }
    cpu = MPU()
    rom = (ROOT / f"src/bin/parobek-{variant}.bin").read_bytes()
    cpu.memory[0x8000:0x10000] = rom

    def scan(status, previous, expected):
        cpu.memory[0x200:0x240] = [0] * 64
        cpu.memory[0x200:0x200 + len(status)] = status.encode("ascii")
        cpu.memory[0xd0:0xd2] = [0, 2]
        cpu.memory[labels["iec_drive_flags"]] = previous
        cpu.sp = 0xff
        cpu.stPushWord(0x6fff)
        cpu.pc = labels["iec_or_drive_flags"]
        for _ in range(20000):
            if cpu.pc == 0x7000:
                break
            cpu.step()
        else:
            raise AssertionError("classifier did not return")
        actual = cpu.memory[labels["iec_drive_flags"]]
        assert actual == expected, (variant, status, previous, actual, expected)

    scan("73,PI1541 V01.24,00,00\r", 0, 4)
    scan("73,PI1541 V01.24,00,00\r", 3, 4)
    scan("00, OK,00,00\r", 4, 0)  # Forces UI to recheck the current mode.
    scan("73,JIFFYDOS 5.0 1541,00,00\r", 4, 2)
    scan("73,CBM DOS V2.6 1541,00,00\r", 4, 0)
    scan("73,SD2IEC,00,00\r", 4, 1)
    scan("00, OK,00,00\r", 2, 2)
    scan(" " * 34 + "PI1541", 0, 4)
    scan(" " * 35 + "PI154", 0, 0)

    # Find the return address of the classification call in iec_load.
    start = labels["iec_load"]
    target = labels["iec_note_drive_class"]
    call = bytes((0x20, target & 0xff, target >> 8))
    offset = bytes(cpu.memory[start:start + 128]).index(call)
    cpu.pc = start + offset + 3
    cpu.p &= ~cpu.CARRY
    cpu.memory[labels["iec_drive_flags"]] = 4
    for _ in range(10):
        if cpu.pc == labels["load_rom"]:
            break
        cpu.step()
    else:
        raise AssertionError("browser did not dispatch directly to ROM LOAD")

print("IEC browser classification and ROM dispatch OK (VIA, CPLD)")
