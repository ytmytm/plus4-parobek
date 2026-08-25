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
assert "jsr iec_m_minus" in spd
assert "jsr ted_sjl_enter" in fast
assert sjl_det.count("iec_send_ui") == 1
assert "lda cpu_port_type" in sjl_det
assert "$f30c" in cpu.lower() or "$F30C" in cpu
print("iec helpers / 6510 contracts OK")
