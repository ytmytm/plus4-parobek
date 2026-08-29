#!/usr/bin/env python3
"""Burst loader: validate detection, ACK, and type-banner ordering."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_burst_body(path: Path) -> str:
    text = path.read_text()
    return text[text.index("!macro LoadBurst") :]


def assert_order(name: str, body: str) -> None:
    command = body.index("; Send burst command for Fastload")
    wait = body.index(".wait_burst_detect:")
    detected = body.index(".burst_detected:")

    type_print = body.index("lda #<iec_type_txt")
    if name in ("burst-cpld.asm", "burst-via.asm"):
        ack = body.index("jsr ToggleClk", detected)
        close = body.index("jsr ROM_CLOSE\t\t; Close the command channel", detected)
        assert command < wait < detected < ack < close < type_print, (
            f"{name}: the first drive response must be acknowledged before "
            "the confirmed burst banner is printed after the transfer"
        )
        critical = body[detected:close]
        assert "print_msg" not in critical and "ROM_CHROUT" not in critical, (
            f"{name}: KERNAL output must not disturb the active burst transfer"
        )
    assert "iny" in body[wait:detected] and "dex" in body[wait:detected], (
        f"{name}: burst detection must wait with a bounded timeout"
    )
    setup = body[max(0, wait - 200):wait]
    assert "ldx #0" in setup, (
        f"{name}: burst detection must retain the 65536-poll timeout"
    )


def main() -> None:
    for name in ("burst-via.asm", "burst-cpld.asm"):
        assert_order(name, load_burst_body(ROOT / "src" / name))
    print("burst message order OK")


if __name__ == "__main__":
    main()
