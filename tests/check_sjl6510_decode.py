#!/usr/bin/env python3
"""Data-path model for SJL 6510 receive / busin folds.

Cycle timing is checked separately (check_sjl6510_cycles.py,
check_sjl6510_busin_cycles.py). This script models what the inline
lda/lsr/eor fold *outputs* when IEC serial bits appear on the port.

8501: DATA in bit 7, CLK in bit 6. Two wire bits per sample sit in
those positions; motor debris in bit 3 (base $08). xfer/busin debris
eor #$0A.

Type-1 6510: DATA in bit 0, CLK in bit 5. Same fold on raw $01 only
sees those bits; CLK-out debris is cleared with eor #$02 on xfer.
"""
from __future__ import annotations


def fold_xfer(p0: int, p1: int, p2: int, p3: int, debris: int) -> int:
    a = p0
    a = (a >> 2) & 0xFF
    a ^= p1
    a = (a >> 2) & 0xFF
    a ^= p2
    a = (a >> 2) & 0xFF
    a ^= p3
    a ^= debris
    return a & 0xFF


def fold_busin(p0: int, p1: int, p2: int, p3: int, debris: int) -> int:
    a = p0
    a = (a >> 2) & 0xFF
    a |= p1
    a = (a >> 2) & 0xFF
    a ^= p2
    a = (a >> 2) & 0xFF
    a ^= debris
    a ^= p3
    return a & 0xFF


def byte_pairs_lsb(byte_val: int) -> list[int]:
    bits = [(byte_val >> i) & 1 for i in range(8)]
    return [
        bits[0] | (bits[1] << 1),
        bits[2] | (bits[3] << 1),
        bits[4] | (bits[5] << 1),
        bits[6] | (bits[7] << 1),
    ]


def port_8501(pair: int, base: int = 0x08) -> int:
    d0, d1 = pair & 1, (pair >> 1) & 1
    return base | (d0 << 6) | (d1 << 7)


def port_6510(pair: int, base: int) -> int:
    d0, d1 = pair & 1, (pair >> 1) & 1
    # The 8501 fold sees bit 0 of each wire pair on CLK-in (P6), then bit 1
    # on DATA-in (P7). Hackjunk routes those lines to P5 and P0 respectively.
    return base | (d0 << 5) | d1


def ports_for_byte(cpu: str, byte_val: int) -> list[int]:
    pairs = byte_pairs_lsb(byte_val)
    if cpu == "8501":
        return [port_8501(p) for p in pairs]
    if cpu == "6510-xfer":
        return [port_6510(p, 0x02) for p in pairs]
    if cpu == "6510-busin":
        return [port_6510(p, 0x00) for p in pairs]
    raise ValueError(cpu)


def fold_outputs(cpu: str, fold) -> set[int]:
    outs: set[int] = set()
  # Enumerate every combination of 2-bit IEC samples on the wire.
    for i0 in range(4):
        for i1 in range(4):
            for i2 in range(4):
                for i3 in range(4):
                    pairs = (i0, i1, i2, i3)
                    if cpu.startswith("8501"):
                        ports = [port_8501(p) for p in pairs]
                        debris = 0x0A
                    elif cpu == "6510-xfer":
                        ports = [port_6510(p, 0x02) for p in pairs]
                        debris = 0x02
                    else:
                        ports = [port_6510(p, 0x00) for p in pairs]
                        debris = 0x00
                    outs.add(fold(*ports, debris))
    return outs


def roundtrip(cpu: str, fold, debris: int) -> tuple[int, list[int]]:
    bad: list[int] = []
    for byte_val in range(256):
        ports = ports_for_byte(cpu, byte_val)
        if fold(*ports, debris) != byte_val:
            bad.append(byte_val)
    return 256 - len(bad), bad


def nib(masked: int) -> int:
    masked &= 0x21
    return (masked & 1) | ((masked >> 4) & 2)


def build_pack_lut(base: int) -> list[int]:
    """Pack LUT from IEC wire pairs -> masked 6510 samples."""
    lut = [0] * 256
    for byte_val in range(256):
        pairs = byte_pairs_lsb(byte_val)
        masked = [((base | ((p & 1) << 5) | ((p >> 1) & 1)) & 0x21) for p in pairs]
        idx = nib(masked[0]) | (nib(masked[1]) << 2) | (nib(masked[2]) << 4) | (nib(masked[3]) << 6)
        lut[idx] = byte_val
    assert sorted(lut) == list(range(256))
    return lut


def main() -> None:
    ok_8501_xfer, _ = roundtrip("8501", fold_xfer, 0x0A)
    ok_8501_busin, _ = roundtrip("8501", fold_busin, 0x0A)
    ok_6510_xfer, bad_xfer = roundtrip("6510-xfer", fold_xfer, 0x02)
    ok_6510_busin, bad_busin = roundtrip("6510-busin", fold_busin, 0x00)

    outs_6510_xfer = fold_outputs("6510-xfer", fold_xfer)
    outs_6510_busin = fold_outputs("6510-busin", fold_busin)

    lut_xfer = build_pack_lut(0x02)
    lut_busin = build_pack_lut(0x00)
    ok_xfer_lut = 0
    ok_busin_lut = 0
    for byte_val in range(256):
        pairs = byte_pairs_lsb(byte_val)
        ports = [port_6510(p, 0x02) for p in pairs]
        masked = [p & 0x21 for p in ports]
        if lut_xfer[nib(masked[0]) | (nib(masked[1]) << 2) | (nib(masked[2]) << 4) | (nib(masked[3]) << 6)] == byte_val:
            ok_xfer_lut += 1
        ports_b = [port_6510(p, 0x00) for p in pairs]
        masked_b = [p & 0x21 for p in ports_b]
        idx_b = nib(masked_b[0]) | (nib(masked_b[1]) << 2) | (nib(masked_b[2]) << 4) | (nib(masked_b[3]) << 6)
        if lut_busin[idx_b] == byte_val:
            ok_busin_lut += 1

    print("8501 xfer round-trip:", ok_8501_xfer, "/256")
    print("8501 busin round-trip:", ok_8501_busin, "/256")
    print("6510 xfer pack+LUT:", ok_xfer_lut, "/256")
    print("6510 busin pack+LUT:", ok_busin_lut, "/256")
    print("6510 xfer distinct fold outputs:", len(outs_6510_xfer), sorted(outs_6510_xfer))
    if bad_xfer[:8]:
        print("6510 xfer first failures:", [hex(b) for b in bad_xfer[:8]])

    assert ok_8501_xfer == 256, "8501 xfer model must round-trip"
    assert ok_8501_busin == 256, "8501 busin model must round-trip"
    assert ok_xfer_lut == 256, "6510 xfer pack+LUT must round-trip"
    assert ok_busin_lut == 256, "6510 busin pack+LUT must round-trip"
    assert ok_6510_xfer < 256, "6510 raw fold must not round-trip (proves LUT is required)"
    assert len(outs_6510_xfer) == 16, f"expected 16 raw-fold outputs, got {len(outs_6510_xfer)}"
    print("OK: 6510 pack+LUT decode model")


if __name__ == "__main__":
    main()
