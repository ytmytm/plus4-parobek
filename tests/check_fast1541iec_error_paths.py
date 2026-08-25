#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
drive = (ROOT / "src/fast1541iec-drivecode.asm").read_text()
wrapper = (ROOT / "src/fast1541iec-loader.asm").read_text()
sjl_host = (ROOT / "src/sjl-loader-highcode.asm").read_text()
ejd = (ROOT / "docs/1541EJD.a65").read_text()


def section(source: str, start: str, end: str) -> list[str]:
    body = source.split(start, 1)[1].split(end, 1)[0]
    return [line.strip() for line in body.splitlines() if line.strip()]


# Host receive is SJL's JD transfer entry, not a private highcode copy.
assert "jmp SJL_jd_transfer" in wrapper
assert "fast1541iec-loader-highcode" not in wrapper
assert "SJL_jd_transfer:" in sjl_host
assert "sjl_jd_receive_loop:" in sjl_host
assert "jsr sjl_jd_receive_loop" in sjl_host
assert ".loadloop:" in sjl_host
assert sjl_host.count(".loadloop:") == 1

# Keep the complete JD sender shape, not a per-byte approximation.
assert "lda ($30),y" in drive
assert "cpx $1800" in drive
assert ".wait_host:" in drive
assert any(
    line.startswith("cmp $1800")
    for line in section(drive, ".wait_host:", ".do_eoi:")
)
assert "jsr $e9a5" in drive  # DataOut_H
assert "jsr $fef3" in drive  # DelayC64
assert "jsr $e9ae" in drive  # ClkOut_H
assert "jmp $e9b7" in drive  # ClkOut_L
assert ".send_byte:" not in drive
assert "$0f,$07,$0d,$05" in drive.replace(" ", "")

# Screen blanking must cross a frame boundary before timed M-E transfer.
assert "sta TED_FF06" in wrapper
assert ".wait_second_low:" in wrapper
assert ".wait_second_high:" in wrapper

for label in ("J_FF2D", "P_FF8D", "A_FFA3", "A_FFDE", "A_EA1D"):
    assert label in ejd

assert not (ROOT / "src/fast1541iec-loader-highcode.asm").exists()

print("fast1541iec JD review checks OK")
