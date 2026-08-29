#!/usr/bin/env python3
"""Cycle model of SJL address-phase sjl_busin (8501 ref vs type-1 6510).

Reference: src/sjl-loader-highcode.asm sjl_busin (.busin8501 / sjl_busin_6510).
Sample = last cycle of lda/ora/eor $01 (8501) or lda $01 (6510).
"""
from __future__ import annotations

CYCLES = {
    "nop": 2,
    "lda_imm": 2,
    "sta_zp": 3,
    "bit_zp": 3,
    "lda_zp": 3,
    "lsr_a": 2,
    "ora_zp": 3,
    "eor_zp": 3,
    "eor_imm": 2,
    "and_imm": 2,
    "sta_abs": 4,
}


def run(ops: list[tuple[str, str]]) -> dict[str, int]:
    t = 0
    out: dict[str, int] = {}
    for kind, label in ops:
        if kind in ("lda_zp", "ora_zp", "eor_zp") and label.startswith("S"):
            out[label] = t + 2
        t += CYCLES[kind]
    return out


def prefix() -> list[tuple[str, str]]:
    return [
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
        ("lda_imm", ""),
        ("nop", ""),
        ("nop", ""),
        ("sta_zp", ""),
        ("nop", ""),
        ("lda_zp", ""),
        ("nop", ""),
        ("nop", ""),
        ("nop", ""),
    ]


def ref_8501() -> list[tuple[str, str]]:
    return prefix() + [
        ("lda_zp", "S0"),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("nop", ""),
        ("ora_zp", "S1"),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("nop", ""),
        ("eor_zp", "S2"),
        ("lsr_a", ""),
        ("lsr_a", ""),
        ("eor_imm", ""),
        ("eor_zp", "S3"),
    ]


def impl_6510() -> list[tuple[str, str]]:
    return prefix() + [
        ("lda_zp", "S0"),
        ("and_imm", ""),
        ("sta_abs", "m0"),
        ("lda_zp", "S1"),
        ("and_imm", ""),
        ("sta_abs", "m1"),
        ("lda_zp", "S2"),
        ("and_imm", ""),
        ("sta_abs", "m2"),
        ("lda_zp", "S3"),
    ]


def main() -> None:
    ref = run(ref_8501())
    impl = run(impl_6510())
    print("8501 busin samples:", ref)
    print("6510 busin samples:", impl)
    for k in ("S0", "S1", "S2", "S3"):
        print(f"  {k}: delta {impl[k] - ref[k]:+d}")
    assert ref == impl, f"6510 busin {impl} != 8501 ref {ref}"
    print("OK: address-phase busin samples match 8501")


if __name__ == "__main__":
    main()
