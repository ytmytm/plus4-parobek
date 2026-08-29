#!/usr/bin/env python3
"""Cycle model of SJL .transferbyte (8501 ref vs type-1 6510).

Reference: src/sjl-loader-highcode.asm sjl_jd_receive_loop (.transferbyte).

Bus sample is modeled on the last cycle of each read instruction (NMOS 6502).
"""
from __future__ import annotations

from dataclasses import dataclass

CYCLES = {
    "nop": 2,
    "lda_imm": 2,
    "ldx_imm": 2,
    "stx_zp": 3,
    "sta_zp": 3,
    "bit_zp": 3,
    "bvc_nt": 2,
    "beq_nt": 2,
    "lda_zp": 3,
    "lsr_a": 2,
    "ora_zp": 3,
    "eor_zp": 3,
    "eor_imm": 2,
    "and_imm": 2,
    "sta_abs": 4,
    "sta_zp": 3,
}


@dataclass
class Event:
    cycle: int
    name: str


def sample_cycle(start: int, op: str) -> int | None:
    if op in ("ldx_zp", "lda_zp", "eor_zp", "ora_zp"):
        return start + 2
    return None


def run(ops: list[tuple[str, str]]) -> list[Event]:
    t = 0
    events: list[Event] = []
    for kind, label in ops:
        sc = sample_cycle(t, kind)
        if sc is not None and label.startswith("S"):
            events.append(Event(sc, label))
        t += CYCLES[kind]
    return events


def handshake_prefix() -> list[tuple[str, str]]:
    return [
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("lda_imm", ""),
        ("ldx_imm", ""),
        ("stx_zp", "handshake"),
        ("bit_zp", "wait clk"),
        ("bvc_nt", ""),
        ("nop", "release pad"),
        ("sta_zp", "release DAT"),
    ]


def ref_8501_ops() -> list[tuple[str, str]]:
    return handshake_prefix() + [
        ("lda_zp", "S0"),
        ("nop", ""),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("eor_zp", "S1"),
        ("bit_zp", "ddr pad"),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("eor_zp", "S2"),
        ("bit_zp", "ddr pad"),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("eor_zp", "S3"),
        ("eor_imm", "debris"),
    ]


def impl_6510_ops() -> list[tuple[str, str]]:
    """6510: lda $01 samples, mask/store, pack+LUT after S3."""
    return [
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("lda_imm", ""),
        ("ldx_imm", ""),
        ("stx_zp", "handshake"),
        ("lda_zp", "wait clk"),
        ("and_imm", ""),
        ("beq_nt", ""),
        ("sta_zp", "release DAT"),
        ("lda_zp", "S0"),
        ("and_imm", ""),
        ("sta_abs", "m0"),
        ("lda_zp", "S1"),
        ("and_imm", ""),
        ("sta_zp", "m1"),
        ("nop", ""),
        ("lda_zp", "S2"),
        ("and_imm", ""),
        ("sta_zp", "m2"),
        ("nop", ""),
        ("lda_zp", "S3"),
        ("and_imm", ""),
        ("sta_abs", "m3"),
    ]


def read_cycles(events: list[Event]) -> dict[str, int]:
    return {e.name: e.cycle for e in events if e.name.startswith("S")}


def main() -> None:
    ref = read_cycles(run(ref_8501_ops()))
    impl = read_cycles(run(impl_6510_ops()))

    print("8501 reference bus-sample cycles:")
    for k in sorted(ref):
        print(f"  {k}: {ref[k]}")
    print("  gaps:", [ref["S1"] - ref["S0"], ref["S2"] - ref["S1"], ref["S3"] - ref["S2"]])

    print("\n6510 pack-sample implementation:")
    for k in sorted(impl):
        print(f"  {k}: {impl[k]} (delta {impl[k] - ref[k]:+d})")

    assert ref == impl, f"6510 reads {impl} != 8501 ref {ref}"
    print("\nOK: all four 6510 port samples match 8501 reference")


if __name__ == "__main__":
    main()
