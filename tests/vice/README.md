# VICE smoke matrix (SJL264)

Manual smoke tests for Parobek IEC fastloader paths under VICE `xplus4`. These scripts document expected `xplus4` invocations for host × drive × datasette combinations (1541-II and 1581). No automated pass/fail assertions yet — verify behavior visually in the emulator.

## Setup

1. Install VICE with `xplus4` (expected at `/usr/local/bin/xplus4`).
2. Copy the example env and edit ROM paths if needed:

```bash
cp tests/vice/roms.env.example tests/vice/roms.env
```

3. Ensure host kernal, BASIC, and drive ROM files exist at the paths in `roms.env`.
4. Build Parobek (the matrix script runs `make -C src via` automatically).
5. Build disk images (`.d64` and `.d81`):

```bash
./tests/vice/rebuild-disk.sh
```

Optional: set `XPLUS4`, `EMPTY_TAP`, `DISK_IMAGE`, or `DISK_IMAGE_1581` in `roms.env` to override defaults.

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
./tests/vice/run-matrix.sh stock+jd1581
./tests/vice/run-matrix.sh stock+stock1581
./tests/vice/run-matrix.sh stock+jd1581+tape
./tests/vice/run-matrix.sh hostjd+jd1581
```

## Matrix

| Case | Host | Drive | Datasette | Pass criteria (manual) |
|------|------|-------|-----------|------------------------|
| `stock+jd1541` | Stock kernal | JiffyDOS 1541 | — | Menu **3**, then `LOAD"HELLO",8` shows **SJL264** |
| `stock+stock1541` | Stock kernal | Stock 1541 | — | `LOAD"HELLO",8` — no **SJL264**; parallel or **ROM LOAD** |
| `stock+jd+tape` | Stock kernal | JiffyDOS 1541 | Attached (`-1 empty.tap`) | **DATASETTE, SKIP SJL** then ROM/parallel |
| `hostjd+jd1541` | JiffyDOS host kernal | JiffyDOS 1541 | — | `LOAD"HELLO",8` shows **HOST JIFFYDOS** then **ROM LOAD**; no **SJL264** |
| `stock+jd1581` | Stock kernal | JiffyDOS 1581 | — | Menu **3**, then `LOAD"HELLO",8` shows **SJL264** |
| `stock+stock1581` | Stock kernal | Stock 1581 | — | `LOAD"HELLO",8` — no **SJL264**; **ROM LOAD** |
| `stock+jd1581+tape` | Stock kernal | JiffyDOS 1581 | Attached (`-1 empty.tap`) | **DATASETTE, SKIP SJL** then ROM |
| `hostjd+jd1581` | JiffyDOS host kernal | JiffyDOS 1581 | — | `LOAD"HELLO",8` shows **HOST JIFFYDOS** then **ROM LOAD**; no **SJL264** |

1541 cases attach **`smoke-test.d64`** on unit #8; 1581 cases attach **`smoke-test.d81`**. Both contain PRG `HELLO` and, when the source exists, `AMAUROTE` (`~/Maciejdev/plus4/amaurote/amaurote/output/amaurote-intro-plain.prg`).

## Disk images

Sources: `hello.bas` → `petcat -w3` → `hello.prg`, plus optional `amaurote-intro-plain.prg` → `c1541` → `smoke-test.d64` and `smoke-test.d81`.

Regenerate:

```bash
./tests/vice/rebuild-disk.sh
```

## Notes

- 1541 cases force **`-drive8type 1542 -drive8truedrive -drive9type 0`** and load the DOS image with **`-dos1541II`**. Using `-dos1541` only affects classic 1541 and leaves a 1541-II on stock **DOS 2.6**.
- Drive type `1542` is CBM 1541-II (matches the stock/`JiffyDOS_1541-II` ROM images in `roms.env.example`).
- 1581 cases force **`-drive8type 1581 -drive8truedrive -drive9type 0`** and load the DOS image with **`-dos1581`**. Attach a **`.d81`**, not a `.d64`.
- `stock+jd+tape` / `stock+jd1581+tape` attach `tests/vice/empty.tap` by default (zero-byte placeholder; VICE accepts it for datasette attach).
- `PAROBEK_BIN` in `roms.env.example` resolves via `git rev-parse --show-toplevel`.
- `tests/vice/roms.env` is gitignored; do not commit local paths.
