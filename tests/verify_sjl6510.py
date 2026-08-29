#!/usr/bin/env python3
"""Independent verification of 6510 SJL position LUTs and timing.

Checks:
  1. Generated ROM tables match Python reference
  2. Four-table decode agrees with the 8501 fold on the shared wire model
  3. Address-byte decode and helper contracts
  4. Cycle model and post-sample path budget
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "src"))

from check_sjl6510_decode import (  # noqa: E402
    byte_pairs_lsb,
    fold_busin,
    fold_xfer,
    port_6510,
    port_8501,
)
from gen_sjl6510_luts import position_table  # noqa: E402


def parse_asm_table(name: str, text: str) -> list[int]:
    block = text.split(f"{name}:")[1]
    block = block.split("!align")[0]
    vals: list[int] = []
    for line in block.splitlines():
        m = re.search(r"!byte\s+(.+)", line)
        if m:
            for tok in m.group(1).split(","):
                vals.append(int(tok.strip().lstrip("$"), 16))
    return vals


def decode_samples(tables: list[list[int]], samples: list[int]) -> int:
    return tables[0][samples[0]] | tables[1][samples[1]] | tables[2][samples[2]] | tables[3][samples[3]]


def verify_lut_vs_8501_fold(tables: list[list[int]], fold, base_6510: int, label: str) -> None:
    """Gold: wire pairs -> 8501 fold == byte; position LUTs == byte."""
    bad_fold = []
    bad_lut = []
    for byte_val in range(256):
        pairs = byte_pairs_lsb(byte_val)
        p8501 = [port_8501(p) for p in pairs]
        if fold(*p8501, 0x0A) != byte_val:
            bad_fold.append(byte_val)
        masked = [port_6510(p, base_6510) & 0x21 for p in pairs]
        decoded = decode_samples(tables, masked)
        if decoded != byte_val:
            bad_lut.append((byte_val, masked, decoded))
    assert not bad_fold, f"{label}: 8501 fold wire model broken: {bad_fold[:5]}"
    assert not bad_lut, f"{label}: LUT mismatch: {bad_lut[:5]}"
    print(f"  {label}: 8501 fold + LUT agree on all 256 bytes")


def verify_rom_tables() -> list[list[int]]:
    asm = (ROOT / "src/gen_sjl6510_luts.asm").read_text()
    tables = [parse_asm_table(f"sjl_pair{i}_256", asm) for i in range(4)]
    assert asm.count("!align 255, 0") == 4, "every indexed LUT must be page-aligned"
    for i, table in enumerate(tables):
        assert table == position_table(i), f"sjl_pair{i}_256 asm != generator"
    print("  ROM tables match src/gen_sjl6510_luts.py")
    return tables


def verify_all_masked_quads(tables: list[list[int]]) -> None:
    """Every possible masked quad maps one-to-one to a byte."""
    decoded = set()
    for m0 in (0, 1, 32, 33):
        for m1 in (0, 1, 32, 33):
            for m2 in (0, 1, 32, 33):
                for m3 in (0, 1, 32, 33):
                    decoded.add(decode_samples(tables, [m0, m1, m2, m3]))
    assert decoded == set(range(256))
    print("  all 256 masked quads decode bijectively")


# 6502 cycle costs (NTSC/PAL 1MHz)
C = {
    "nop": 2,
    "lda_imm": 2,
    "ldx_imm": 2,
    "stx_zp": 3,
    "sta_zp": 3,
    "sta_abs": 4,
    "lda_zp": 3,
    "and_imm": 2,
    "bit_zp": 3,
    "bvc_nt": 2,
    "beq_nt": 2,
    "lsr_a": 2,
    "eor_zp": 3,
    "eor_imm": 2,
    "ldx_zp": 3,
    "beq_nt": 2,
    "cpx_imm": 2,
    "bcs_nt": 2,
    "sta_ind_y": 6,
    "inc_abs16": 2,  # inc zp 2
    "inc_zp": 2,
    "bne_nt": 2,
    "jmp": 3,
    "jsr": 6,
    "rts": 6,
    "tax": 2,
    "lda_abs": 4,
    "lda_abs_x": 4,
    "ora_zp": 3,
    "ora_abs": 4,
}


def count(ops: list[str]) -> int:
    return sum(C[o] for o in ops)


def post_sample_cycles() -> None:
    """Cycles from last sample (S3) to inc TED_BORDER — proxy for stripe width."""
    fold_8501 = [
        "eor_imm",  # eor #$0A
        "ldx_zp",
        "beq_nt",
        "cpx_imm",
        "bcs_nt",
        "sta_ind_y",
        "inc_abs16",
        "inc_zp",
        "bne_nt",
    ]
    pack_6510_tail = [
        "ldx_zp",
        "beq_nt",
        "cpx_imm",
        "bcs_nt",
        "sta_ind_y",
        "inc_abs16",
        "inc_zp",
        "bne_nt",
    ]
    # SJL_PACK_SAMPLES macro body (from asm); S0/S3 are in ZP too, while
    # their sample-time stores are forced absolute separately.
    pack_body = (
        ["ldx_zp", "lda_abs_x", "sta_zp"]  # smp0 / partial result
        + ["ldx_zp", "lda_abs_x", "ora_zp", "sta_zp"]  # smp1
        + ["ldx_zp", "lda_abs_x", "ora_zp", "sta_zp"]  # smp2
        + ["ldx_zp", "lda_abs_x", "ora_zp"]  # smp3
    )
    c8501 = count(fold_8501)
    c6510_inl = count(pack_body) + count(pack_6510_tail)
    print(f"  Post-S3 to border inc: 8501={c8501} cy, 6510={c6510_inl} cy (delta +{c6510_inl - c8501})")
    # PAL ~63us/line at 1MHz => cycles/line ~63
    for label, extra in [("8501", 0), ("6510 inline", c6510_inl - c8501)]:
        lines = (c8501 + extra) / 63
        print(f"  Full post-decode path ≈ {lines:.1f} raster lines/byte ({label})")

    # Full .transferbyte (handshake + samples + decode + store + border inc)
    hs_8501 = count(
        ["nop"] * 4
        + ["lda_imm", "ldx_imm", "stx_zp", "bit_zp", "bvc_nt", "nop", "sta_zp"]
    )
    fold_samples_8501 = count(
        ["lda_zp", "nop", "lsr_a", "lsr_a", "eor_zp", "bit_zp", "lsr_a", "lsr_a", "eor_zp", "bit_zp", "lsr_a", "lsr_a", "eor_zp", "eor_imm"]
    )
    tail = count(pack_6510_tail)
    full_8501 = hs_8501 + fold_samples_8501 + c8501
    hs_6510 = count(
        ["nop"] * 4
        + ["lda_imm", "ldx_imm", "stx_zp", "lda_zp", "and_imm", "beq_nt", "sta_zp"]
    )
    samples_6510 = count(
        ["lda_zp", "and_imm", "sta_abs", "lda_zp", "and_imm", "sta_zp", "nop", "lda_zp", "and_imm", "sta_zp", "nop", "lda_zp", "and_imm", "sta_abs"]
    )
    full_6510 = hs_6510 + samples_6510 + c6510_inl
    print(f"  Full byte loop: 8501={full_8501} cy (~{full_8501/63:.1f} lines), 6510={full_6510} cy (~{full_6510/63:.1f} lines), ratio {full_6510/full_8501:.2f}x")


def main() -> None:
    print("=== 6510 SJL independent verification ===\n")

    print("[1] ROM tables")
    tables = verify_rom_tables()

    print("\n[2] LUT vs 8501 gold wire model")
    verify_lut_vs_8501_fold(tables, fold_xfer, 0x02, "xfer")
    verify_lut_vs_8501_fold(tables, fold_busin, 0x00, "busin")
    verify_all_masked_quads(tables)

    print("\n[3] Address bytes for $1000 load (busin)")
    def busin_byte(b: int) -> int:
        pairs = byte_pairs_lsb(b)
        masked = [port_6510(p, 0) & 0x21 for p in pairs]
        return decode_samples(tables, masked)

    lo = busin_byte(0x00)
    hi = busin_byte(0x10)
    assert lo == 0x00 and hi == 0x10, f"busin $1000 address got ${hi:02x}${lo:02x}"
    print("  busin decodes $00,$10 for load address $1000")

    print("\n[4] Subprocess contract tests")
    for script in (
        "check_sjl6510_decode.py",
        "check_sjl6510_cycles.py",
        "check_sjl6510_busin_cycles.py",
        "check_iec_helpers_6510.py",
    ):
        subprocess.run([sys.executable, str(ROOT / "tests" / script)], check=True)

    print("\n[5] Cycle budget (stripe height)")
    post_sample_cycles()

    print("\n=== ALL CHECKS PASSED ===")


if __name__ == "__main__":
    main()
