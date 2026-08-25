#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
burst = (ROOT / "src/burstcart.asm").read_text()
sjl_det = (ROOT / "src/sjl-detect.asm").read_text()
sjl_hi = (ROOT / "src/sjl-loader-highcode.asm").read_text()
fast = (ROOT / "src/fast1541iec-loader.asm").read_text()
spd = (ROOT / "src/speeddos-loader.asm").read_text()
cpu = (ROOT / "src/cpu-port-detect.asm").read_text()
mem = (ROOT / "src/iec-memcmd.asm").read_text()

assert "cpu_port_type:" in burst
assert "sjl_receive_vec:" in burst
assert "detect_cpu_port_type" in burst
assert "lda cpu_port_type" in burst
assert "sjl_jd_receive_loop_6510:" in sjl_hi
assert "iec_m_minus:" in mem
assert "iec_mw_one_chunk:" in mem
assert "iec_me:" in mem
assert "ted_sjl_enter:" in mem
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
# Type-1 JD fold must be inlined/fall-through: JSR into a PLA-based fold
# pops the return address as S2 and yields garbage bytes.
assert "jsr sjl_fold4" not in sjl_hi
jd6510 = sjl_hi.split("sjl_jd_receive_loop_6510:")[1]
xfer = jd6510.split(".transferbyte:")[1].split(".loadendover:")[0]
assert "jsr sjl_pair6510" in xfer
assert "eor #$00" in xfer
assert xfer.find("eor #$00") < xfer.find("sta ($9d),y")
print("iec helpers / 6510 contracts OK")
