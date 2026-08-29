#!/usr/bin/env python3
"""1551 HypaRAM host teardown matches release-v1.1 (YaPe-proven baseline)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
hi = (ROOT / "src/ram1551-hyparam-loader-highcode.asm").read_text()
drv = (ROOT / "src/hypa1551-drivecode.asm").read_text()
bc = (ROOT / "src/burstcart.asm").read_text()

end = hi.split(".load_end:")[1]

# v1.1 .load_end: leave DAV=1, DDR=output, no CLRCHN / dual-port idle / detect cache.
assert "ldx     #$ff" in end
assert "stx     tcbmbase+3" in end
assert "ldx     #$40" in end
assert "stx     tcbmbase+2" in end
assert ".wait_drv" not in end
assert "ROM_CLRCHN" not in end
assert "tcbm1551_cached" not in end
assert "TCBM_KERN8" not in end

# @ and shared_rom_check select the bus before TALK and keep separate direct
# receiver calls so the test itself cannot perturb either handshake.
wedge = (ROOT / "src/dos-wedge.asm").read_text()
assert "iec_print_drive_status" not in wedge.split("dos_display_status:")[1].split("dos_status_end:")[0]
status = wedge.split("dos_display_status:")[1].split("dos_status_end:")[0]
assert status.count("jsr eEDA9") == 1
assert status.count("jsr ROM_ACPTR") == 1
assert status.count("jsr iec_acptr") == 1

shared = bc.split("shared_rom_check:")[1].split("}")[0]
assert shared.count("JSR   ROM_ACPTR") == 2
assert shared.count("JSR   iec_acptr") == 2
assert shared.index("JSR   eEDA9") < shared.index("JSR   ROM_TALK")

# Plain 1551 drive exit: soft reset vector (unchanged from v1.1).
assert "jmp     (LFFFC)" in drv

print("1551 v1.1-aligned contracts OK")
