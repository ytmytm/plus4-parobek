#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
highcode = (ROOT / "src/fast1541iec-loader-highcode.asm").read_text()
wrapper = (ROOT / "src/fast1541iec-loader.asm").read_text()


def section(source: str, start: str, end: str) -> str:
    assert start in source, f"missing {start} section"
    assert end in source, f"missing {end} section"
    return source.split(start, 1)[1].split(end, 1)[0]


clk_wait = section(highcode, ".wait_clk_drive:", ".wait_data_drive:")
data_wait = section(highcode, ".wait_data_drive:", ".transferbyte:")
clk_pending = section(highcode, ".wait_clk_pending:", ".wait_data_pending:")
data_pending = section(highcode, ".wait_data_pending:", ".transfer_timeout:")
timeout = section(highcode, ".transfer_timeout:", ".loadendover:")
early_cleanup = section(wrapper, ".fail_open:", ".fail:")

assert ".wait_clk_pending" in clk_wait
assert ".wait_data_pending" in data_wait
for name, pending in (("CLK", clk_pending), ("DATA", data_pending)):
    assert "dex" in pending, f"{name} wait has no bounded counter"
    assert "bne" in pending, f"{name} wait has no counter retry"
assert ".transfer_timeout" in clk_pending

assert "jsr sjl_untalk" in timeout
assert "jsr ROM_IEC_CLOSE_SETUP" in timeout
assert "jmp .file_error" in timeout

assert wrapper.count("jmp .fail_open") >= 2
assert "jsr ROM_UNTLK" in early_cleanup
assert "jsr ROM_IEC_CLOSE_SETUP" in early_cleanup
