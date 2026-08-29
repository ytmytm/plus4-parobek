#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
burst = (ROOT / "src/burstcart.asm").read_text()
sjl_det = (ROOT / "src/sjl-detect.asm").read_text()
sjl_hi = (ROOT / "src/sjl-loader-highcode.asm").read_text()
fast = (ROOT / "src/fast1541iec-loader.asm").read_text()
spd = (ROOT / "src/speeddos-loader.asm").read_text()
cpu = (ROOT / "src/cpu-port-detect.asm").read_text()
mem = (ROOT / "src/iec-memcmd.asm").read_text()
acptr = (ROOT / "src/iec-acptr.asm").read_text()

assert "cpu_port_type:" in burst
assert "sjl_receive_vec:" in burst
assert "detect_cpu_port_type" in burst
assert "lda cpu_port_type" in burst
assert "sjl_jd_receive_loop_6510:" in sjl_hi
pack = sjl_hi.split("!macro SJL_PACK_SAMPLES {")[1].split("}", 1)[0]
assert pack.count("ldx SJL_SMP") == 4
assert "\n\t\ttax" not in pack
labels = (ROOT / "src/labels-via.txt").read_text()
for table in ("sjl_pair0_256", "sjl_pair1_256", "sjl_pair2_256", "sjl_pair3_256"):
    match = re.search(rf"^\s*{table}\s*=\s*\$([0-9a-f]+)", labels, re.MULTILINE | re.IGNORECASE)
    assert match and int(match.group(1), 16) >= 0xC000, f"{table} must stay in upper ROM"
assert "iec_m_minus:" in mem
assert "iec_mw_one_chunk:" in mem
assert "iec_me:" in mem
assert "ted_sjl_enter:" in mem
assert "iec_acptr:" in acptr
assert "acptr_6510:" in acptr
assert "jmp ROM_ACPTR" in acptr
assert "lda $01\n\tcmp $01\n\tbne .wait_first_clock" in acptr
assert "jsr LCFF7" not in acptr
for source in ("fast1541iec-loader.asm", "par1541-detect.asm", "sjl-detect.asm"):
    assert "jsr ROM_ACPTR" not in (ROOT / "src" / source).read_text()
for source in ("pi1551-detect.asm", "ram1551-detect.asm", "t2s-detect.asm"):
    text = (ROOT / "src" / source).read_text()
    assert "jsr ROM_ACPTR" in text
    assert "jsr iec_acptr" not in text
wedge_status = (ROOT / "src/dos-wedge.asm").read_text().split("dos_display_status:")[1].split("dos_status_end:")[0]
assert wedge_status.count("jsr eEDA9") == 1
assert wedge_status.count("jsr iec_acptr") == 1
assert wedge_status.count("jsr ROM_ACPTR") == 1
assert wedge_status.index("jsr eEDA9") < wedge_status.index("jsr ROM_TALK")
shared = burst.split("shared_rom_check:")[1].split("}")[0]
assert shared.count("JSR   iec_acptr") == 2
assert shared.count("JSR   ROM_ACPTR") == 2
assert "JSR   eEDA9" in shared
assert shared.index("JSR   eEDA9") < shared.index("JSR   ROM_TALK")
assert "jsr iec_m_minus" in fast
assert "iec_mw_one_chunk" in spd
assert "iec_me" in spd
assert "jsr ted_sjl_enter" in fast
assert "jsr iec_mw_one_chunk" in fast
assert "jsr ted_sjl_enter" in (ROOT / "src/sjl-loader.asm").read_text()
assert sjl_det.count("jsr iec_send_ui") == 1
assert [
    p.name
    for p in (ROOT / "src").glob("*.asm")
    if "jsr iec_send_ui" in p.read_text()
] == ["sjl-detect.asm"]
# type 2/3 skip: cmp #2 must appear before SJL and 1541 SERIAL jmp paths
assert "jmp SJL_load" in burst
assert "jmp fast1541iec_load" in burst
assert "cmp #2" in burst
sjl_jmp = burst.find("jmp SJL_load")
fast_jmp = burst.find("jmp fast1541iec_load")
assert burst.find("cmp #2") < sjl_jmp
assert burst.find("cmp #2") < fast_jmp
assert "lda cpu_port_type" in sjl_det
assert "$f30c" in cpu.lower() or "$F30C" in cpu
# 8501 DATA-in (bit 7) is inverted vs DATA-out (bit 0): 1 on out pulls the
# line low, which reads as 0 on in. siziolib therefore does bpl after
# releasing bit 0 (bit7 must be 1) and bmi after pulling bit 0 (bit7 must
# be 0). Same-polarity follow misclassifies VICE xplus4 as type 3 and
# skips SJL + 1541 SERIAL (ROM LOAD).
_8501, _, _rest = cpu.partition("and #%11111110")
_probe, _, _ = _rest.partition(".not_8501:")
_br = re.findall(r"\b(bpl|bmi|bne|beq) \.not_8501\b", _probe)
assert _br, "8501 probe must branch to .not_8501"
assert _br[0] in ("bpl", "beq"), (
    "after releasing DATA-out, bit7=0 is not-8501 (siziolib bpl); "
    f"got {_br[0]}"
)
assert len(_br) >= 2 and _br[1] in ("bmi", "bne"), (
    "after pulling DATA-out, bit7=1 is not-8501 (siziolib bmi); "
    f"got {_br}"
)
# Type-1 JD: four lda $01 samples, followed by position-specific LUT decode.
jd6510 = sjl_hi.split("sjl_jd_receive_loop_6510:")[1]
xfer = jd6510.split(".transferbyte:")[1].split(".loadendover:")[0]
assert "+SJL_PACK_SAMPLES" in xfer
for position in range(4):
    assert f"sjl_pair{position}_256,x" in sjl_hi
assert "sjl_byte256" not in sjl_hi
assert "sjl_busin_byte256" not in sjl_hi
assert "eor $01" not in xfer
assert "eor #%00000010" not in xfer
assert "stx $96" not in xfer
assert "sta $9a" not in xfer.lower()
assert xfer.count("and #%00100001") == 4
assert xfer.find("+SJL_PACK_SAMPLES") > xfer.rfind("and #%00100001")

busin6510 = sjl_hi.split("sjl_busin_6510:")[1].split("sjl_restore:")[0]
assert "+SJL_PACK_SAMPLES" in busin6510
assert "eor $01" not in busin6510
assert "ora $01" not in busin6510
assert busin6510.count("lda $01") >= 4
assert "sta+2 SJL_SMP0" in xfer
assert "sta+2 SJL_SMP3" in xfer
assert "sta+2 SJL_SMP0" in busin6510
assert "sta+2 SJL_SMP1" in busin6510
assert "sta+2 SJL_SMP2" in busin6510
assert "sta+2 SJL_SMP3" in busin6510

import subprocess

subprocess.run(["python3", str(ROOT / "tests/check_sjl6510_cycles.py")], check=True)
subprocess.run(["python3", str(ROOT / "tests/check_sjl6510_busin_cycles.py")], check=True)
subprocess.run(["python3", str(ROOT / "tests/check_sjl6510_decode.py")], check=True)
print("iec helpers / 6510 contracts OK")
