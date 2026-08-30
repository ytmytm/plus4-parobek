#!/usr/bin/env python3
"""Compare two VICE diagnose monitor logs at IEC tracepoints."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

TRACE_RE = re.compile(
    r"^\s*(?:#(\d+)\s+)?(?:C:|8:)\s*([0-9A-Fa-f]{4})\s+.*?(trace exec|trace store)\s+(\$[0-9A-Fa-f]+|\d+:\$[0-9A-Fa-f]+)",
    re.IGNORECASE,
)
HIT_RE = re.compile(
    r"^\s*(?:#(\d+)\s+)?(?:C:|8:)\s*([0-9A-Fa-f]{4})\s+",
    re.IGNORECASE,
)


def extract_hits(path: Path) -> list[tuple[int | None, str, str, str]]:
    hits: list[tuple[int | None, str, str, str]] = []
    for line in path.read_text(encoding="latin-1", errors="replace").splitlines():
        match = TRACE_RE.search(line)
        if match:
            seq = int(match.group(1)) if match.group(1) else None
            pc = match.group(2).upper()
            kind = match.group(3).lower()
            target = match.group(4).upper()
            hits.append((seq, pc, kind, target))
    return hits


def first_pc_after(path: Path, addrs: set[str]) -> str | None:
    for line in path.read_text(encoding="latin-1", errors="replace").splitlines():
        match = HIT_RE.match(line)
        if match and match.group(2).upper() in addrs:
            return match.group(2).upper()
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pass_log", type=Path)
    parser.add_argument("fail_log", type=Path)
    args = parser.parse_args()

    pass_hits = extract_hits(args.pass_log)
    fail_hits = extract_hits(args.fail_log)
    pass_targets = {target for _, _, _, target in pass_hits}
    fail_targets = {target for _, _, _, target in fail_hits}

    print(f"pass trace events: {len(pass_hits)}")
    print(f"fail trace events: {len(fail_hits)}")
    print(f"only in pass: {sorted(pass_targets - fail_targets)[:20]}")
    print(f"only in fail: {sorted(fail_targets - pass_targets)[:20]}")

    for label, hits in (("pass", pass_hits), ("fail", fail_hits)):
        print(f"\n{label} first 12 trace hits:")
        for hit in hits[:12]:
            print(f"  {hit}")

    for name, addr in (
        ("iec_acptr", "8783"),
        ("acptr_8501", "8823"),
        ("kernal_acptr", "8A95"),
        ("drive_class", "8FCE"),
        ("status_complete", "8F0B"),
    ):
        pass_pc = first_pc_after(args.pass_log, {addr})
        fail_pc = first_pc_after(args.fail_log, {addr})
        print(f"{name}: pass last@{pass_pc or '-'} fail last@{fail_pc or '-'}")

    shared = sorted(pass_targets & fail_targets)
    diverged = []
    for target in shared:
        p = next((h for h in pass_hits if h[3] == target), None)
        f = next((h for h in fail_hits if h[3] == target), None)
        if p and f and p[1] != f[1]:
            diverged.append((target, p[1], f[1]))
    if diverged:
        print("\nSame tracepoint, different PC:")
        for target, p_pc, f_pc in diverged[:20]:
            print(f"  {target}: pass={p_pc} fail={f_pc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
