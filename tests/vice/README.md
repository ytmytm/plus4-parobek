# VICE smoke matrix (SJL264)

Manual smoke tests for Parobek IEC fastloader paths under VICE `xplus4`. These scripts document expected `xplus4` invocations for four host × drive × datasette combinations. No automated pass/fail assertions yet — verify behavior visually in the emulator.

## Setup

1. Install VICE with `xplus4` (expected at `/usr/local/bin/xplus4`).
2. Copy the example env and edit ROM paths if needed:

```bash
cp tests/vice/roms.env.example tests/vice/roms.env
```

3. Ensure host kernal, BASIC, and 1541 ROM files exist at the paths in `roms.env`.
4. Build Parobek (the matrix script runs `make -C src via` automatically).

Optional: set `XPLUS4` or `EMPTY_TAP` in `roms.env` to override defaults.

## Usage

List all cases and their commands:

```bash
./tests/vice/run-matrix.sh list
```

Launch one case (opens VICE interactively):

```bash
./tests/vice/run-matrix.sh stock+jd1541
./tests/vice/run-matrix.sh stock+stock1541
./tests/vice/run-matrix.sh stock+jd+tape
./tests/vice/run-matrix.sh hostjd+jd1541
```

## Matrix

| Case | Host | Drive | Datasette | Pass criteria (manual) |
|------|------|-------|-----------|------------------------|
| `stock+jd1541` | Stock kernal | JiffyDOS 1541 | — | After menu option **3**, a LOAD shows **SJL264** |
| `stock+stock1541` | Stock kernal | Stock 1541 | — | No **SJL264**; parallel fastload or **ROM LOAD** |
| `stock+jd+tape` | Stock kernal | JiffyDOS 1541 | Attached (`-1 empty.tap`) | **DATASETTE, SKIP SJL** then ROM/parallel load |
| `hostjd+jd1541` | JiffyDOS host kernal | JiffyDOS 1541 | — | **HOST JIFFYDOS, NO WEDGE**; no **SJL264** |

## Notes

- Every case forces **`-drive8type 1542 -drive8truedrive -drive9type 0`**. Setting `-dos1541` alone is not enough: Plus/4 VICE often leaves unit #8 as a **1551** from defaults or saved settings, so the wrong bus (TCBM) would be used.
- Drive type `1542` is CBM 1541-II (matches the stock/`JiffyDOS_1541-II` ROM images in `roms.env.example`).
- `stock+jd+tape` attaches `tests/vice/empty.tap` by default (zero-byte placeholder; VICE accepts it for datasette attach).
- `PAROBEK_BIN` in `roms.env.example` resolves via `git rev-parse --show-toplevel`.
- `tests/vice/roms.env` is gitignored; do not commit local paths.
