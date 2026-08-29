# YaPe smoke matrix (Parobek)

Manual smoke tests under **YaPe** on Windows, launched from WSL. Mirrors
`tests/vice/run-matrix.sh` where YaPe can emulate the same hardware.

## Why YaPe?

YaPe has **native parallel 1541** (8255 / 6529 at `$FE00` / `$FD10`) for
Parobek's PPI/PIO SpeedDOS path. It does **not** emulate BurstCart VIA/CIA
parallel or 157x burst — use VICE for those.

## Staging on D:

All ROMs and disks are copied to:

| WSL | Windows (YaPe) |
|-----|----------------|
| `/mnt/d/tmp/parobek/` | `D:\tmp\parobek\` |

YaPe never sees `\\wsl.localhost\...` UNC paths. Override with `STAGE_DIR` in
`roms.env` if needed.

Parobek is a **32 KB** image, split into two **16 KB** halves (`*-low.bin` /
`*-high.bin`). `PAROBEK_SLOT` (`C1` or `C2`) selects which YaPe ROM bank gets
those halves; the other bank is cleared to `<empty>`.

## Setup

```bash
cp tests/yape/roms.env.example tests/yape/roms.env
# YAPE_EXE=/mnt/d/tmp/YaPe-Plus4/YapeWin32.exe
# STAGE_DIR=/mnt/d/tmp/parobek

chmod +x tests/yape/run-matrix.sh
./tests/vice/rebuild-disk.sh   # smoke-test.d64 / .d81
```

Start YaPe once from Explorer so `yape.ini` exists next to the exe.

## Usage

```bash
./tests/yape/run-matrix.sh list
./tests/yape/run-matrix.sh stock+stock1551
./tests/yape/run-matrix.sh hostjd+stock1551
./tests/yape/run-matrix.sh stock+stock1541+parallel
./tests/yape/run-matrix.sh restore-ini   # when done
```

`yape.ini` stays patched until `restore-ini` (async `start` would otherwise
restore too early and leave `Drive8Enabled=0`).

## Matrix

| Case | Drive8Enabled | Pass criteria (manual) |
|------|---------------|------------------------|
| `stock+jd1541` | 1 (1541 CPU) | Menu **3**, `LOAD"HELLO",8` → **SJL264** |
| `stock+stock1541` | 1 | Menu **3** → **1541 SERIAL** then HELLO |
| `stock+stock1551` | 3 (1551 CPU) | Menu **3** → **TCBM DEVICE, 1551 HYPALOAD** |
| `stock+stock1551+stock1551` | 3 + Drive9=3 | Menu **3**, `LOAD"HELLO",9` → Hypaload on device **9** |
| `stock+stock1551+stock1541` | 3 + Drive9=1 | Menu **3**, `LOAD"HELLO",8` → Hypaload; #9 stock 1541 |
| `stock+stock1551+jd1541` | 3 + Drive9=1 | Menu **3**, `LOAD"HELLO",8` → Hypaload; #9 JD 1541 |
| `hostjd+stock1551` | 3 (1551 CPU) | `LOAD"HELLO",8` → **TCBM DEVICE, 1551 HYPALOAD** (host JD does not block TCBM) |
| `stock+jd+tape` | 1 | **DATASETTE, SKIP SJL** then ROM/parallel |
| `hostjd+jd1541` | 1 | **HOST JIFFYDOS** then **ROM LOAD** |
| `stock+jd1581` | 4 (1581 CPU) | Menu **3** → **SJL264** |
| `stock+stock1581` | 4 | No **SJL264**; **ROM LOAD** |
| `stock+jd1581+tape` | 4 | **DATASETTE, SKIP SJL** then ROM |
| `hostjd+jd1581` | 4 | **HOST JIFFYDOS** then **ROM LOAD** |
| `stock+stock1541+parallel` | 5 (parallel 1541) | Menu **3** → **1541/PARALLEL** |
| `stock+jd1541+parallel` | 5 | May fail — JiffyDOS + parallel is flaky in YaPe |

`Drive8Enabled=2` / `Drive9Enabled=2` (1551 IEC) cannot run Hypaload — always use **3** for 1551 CPU. Dual-drive cases attach the same smoke `.d64` via `/DISK8` and `/DISK9`.

## Notes

- Launch sets CWD to the YaPe install dir so the patched `yape.ini` is loaded.
- Parallel + JiffyDOS 1541 is a known YaPe pain point.
- BurstCart VIA/CIA parallel: use `./tests/vice/run-matrix.sh`.
- `tests/yape/roms.env` is gitignored.
