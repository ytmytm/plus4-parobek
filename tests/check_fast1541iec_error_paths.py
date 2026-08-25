#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
drive = (ROOT / "src/fast1541iec-drivecode.asm").read_text()
host = (ROOT / "src/fast1541iec-loader-highcode.asm").read_text()
ejd = (ROOT / "docs/1541EJD.a65").read_text()

assert "bit $1800" in drive
assert "beq -" in drive
assert "cpx $1800" not in drive  # unreliable Go-wait removed
assert "bit $1800" in drive
assert "beq -" in drive.split(".send_byte:", 1)[1]
assert "$0f,$07,$0d,$05" in drive.replace(" ", "")
assert "sta $44" in drive
assert "bne .send_page" in drive  # A_FFA3 Y-wrap
assert ".wait_clk_drive:" in host
assert ".wait_data_drive:" in host
assert "jmp .transferbyte" in host
assert "A_FFA3" in ejd and "A_EA1D" in ejd
print("fast1541iec JD review checks OK")
