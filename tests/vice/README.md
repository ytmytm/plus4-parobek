# VICE smoke matrix (SJL264)

Manual smoke tests and an automated headless matrix for Parobek IEC, TCBM,
parallel, and burst fastloader paths under VICE `xplus4`. The matrix verifies
loader selection, KERNAL return status, loaded payload, repeated loads, 1551
post-load state, and performance for 1541-II, 1551, and 1581 configurations.

## Setup

The tests use our own patched VICE build. A stock distribution of VICE does
not provide the Hackjunk 6510 mapping, BurstCart VIA/CPLD emulation, complete
32 KiB C1/C2 images, or the headless monitor behavior required by the runner.
Keep the VICE source tree at `vice/vice` and the corresponding standalone
patches at `vice/patches`:

- `plus4-hackjunk-6510-runtime.patch`
- `plus4-burstcart-via-cpld.patch`
- `plus4-32k-c1-c2-rom.patch`
- `headless-safe-signals-monitor.patch`
- `plus4-6529-pio-parallel-cable-description.patch` (the separate PIO naming
  patch; its description changes are already present in the BurstCart patch)

`build-hackjunk-vice.sh` does not download or patch VICE. It compiles the
already patched `vice/vice` tree into `vice/build-hackjunk` with the headless
UI. Build it with:

```bash
./tests/vice/build-hackjunk-vice.sh
```

The interactive build used for manual testing is kept separately in
`vice/build-gtk`. Both builds must come from the same patched source tree; the
system `/usr/local/bin/xplus4` fallback is useful only for cases which do not
depend on these extensions.

1. Prepare and patch the VICE source tree as described above.
2. Copy the example env and edit ROM paths if needed:

```bash
cp tests/vice/roms.env.example tests/vice/roms.env
```

3. Ensure host kernal, BASIC, and drive ROM files exist at the paths in `roms.env`.
4. Build both Parobek cartridge variants used by the headless matrix:

```bash
make -C src via
make -C src cpld
```

   The interactive `run-matrix.sh` rebuilds the VIA variant. The Python
   headless runner uses the existing files from `src/bin`; its `--no-build`
   option controls rebuilding VICE, not Parobek.
5. Build disk images (`.d64` and `.d81`):

```bash
./tests/vice/rebuild-disk.sh
```

The manual runner prefers the patched `vice/build-gtk/src/xplus4` and falls
back to `/usr/local/bin/xplus4`. Set `XPLUS4`, `EMPTY_TAP`, `DISK_IMAGE`, or
`DISK_IMAGE_1581` in `roms.env` to override defaults.

## Usage

List all cases and their commands:

```bash
./tests/vice/run-matrix.sh list
```

Launch one case (opens VICE interactively):

```bash
./tests/vice/run-matrix.sh stock+jd1541
./tests/vice/run-matrix.sh stock+stock1541
./tests/vice/run-matrix.sh stock+stock1551
./tests/vice/run-matrix.sh stock+ram1551
./tests/vice/run-matrix.sh stock+ramboard1551
./tests/vice/run-matrix.sh stock+jd+tape
./tests/vice/run-matrix.sh hostjd+jd1541
./tests/vice/run-matrix.sh stock+jd1581
./tests/vice/run-matrix.sh stock+stock1581
./tests/vice/run-matrix.sh stock+jd1581+tape
./tests/vice/run-matrix.sh hostjd+jd1581
```

### Automated Hackjunk 6510 test

Build the headless VICE variant whose Plus/4 CPU port maps IEC DATA/CLK to
Hackjunk 6510 bits 0/5, then run a JiffyDOS 1541 load and compare the loaded
memory with `hello.prg`:

```bash
./tests/vice/build-hackjunk-vice.sh
python3 tests/vice/run-hackjunk-headless.py --no-build
python3 tests/vice/run-hackjunk-headless.py --no-build --filename AMAUROTE
python3 tests/vice/run-hackjunk-headless.py --no-build --drive 1581
python3 tests/vice/run-hackjunk-headless.py --no-build --drive 1581 --filename AMAUROTE
python3 tests/vice/run-hackjunk-headless.py --no-build --drive 1581 --drive-rom sd2iec
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1551 --drive-rom stock --drive-ram off
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1551 --drive-rom stock --drive-ram on
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1551 --drive-rom ramboard --drive-ram on
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1551 --drive-rom stock --repeat 2
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1541 --drive-rom stock --burstcart via
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 8501 --drive 1541 --drive-rom ramboard --drive-ram on --burstcart pio
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1581 --drive-rom jiffydos --burstcart via
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1581 --drive-rom stock --burstcart cpld
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1581 --drive-rom jiffydos --burstcart cpld --device-number 9 --expect-device-missing
python3 tests/vice/run-hackjunk-headless.py --no-build --cart-bank c2 --cpu 6510 --drive 1541 --burstcart pio --filename AMAUROTE
python3 tests/vice/run-hackjunk-headless.py --no-build --cart-bank c0 --cpu 8501 --drive 1551 --drive-rom stock
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1541 --drive-rom jiffydos --filename AMAUROTE --seed 1
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1581 --drive-rom jiffydos --filename AMAUROTE --seed 1 --pre-load-frames 50 --drive-wobble-frequency 1000 --drive-wobble-amplitude 1000
python3 tests/vice/run-hackjunk-headless.py --no-build --cpu 6510 --drive 1541 --drive-rom jiffydos --filename AMAUROTE --diagnose-timeout
python3 tests/vice/check-hackjunk-port-reset.py
python3 tests/vice/check-plus4-32k-roms.py
```

The runner always uses the supplied Hackjunk 6510 KERNAL unchanged. Parobek
contains its own cycle-safe serial `ACPTR` for the 6510 path; non-6510 and TCBM
reads still use the KERNAL routine. `--seed` fixes the VICE PRNG, while
`--pre-load-frames` waits in emulated PAL frames before resetting the load
stopwatch. The drive RPM and wobble options are passed directly to VICE, so the
same timing case is reproducible in warp and realtime modes.

`--diagnose-timeout` enables CPU history and tracepoints. If LOAD stops making
monitor progress, the runner sends `SIGUSR1`; the patched headless VICE enters
the monitor at the next frame boundary and returns host/drive registers and
history without running allocator or shutdown code in a signal handler.

For reproducible CPLD detection diagnostics, `--cpld-response-delay N` passes
VICE resource `BurstCartCPLDResponseDelay` (`-burstcartcplddelay N`). It delays
only the first drive response after the CPLD switches from output to input.
At the current timeout boundary, `65535` still completes burst detection while
`65536` deliberately forces the normal silent fallback (and therefore makes a
test expecting the CPLD path fail).

`--save-pre-load-snapshot PATH` saves the complete machine state immediately
before LOAD; `--load-pre-load-snapshot PATH` restores it for a deterministic
replay. Snapshot runs require `--repeat 1` and preserve the complete 32 KiB
cartridge and BurstCart state. To search many timing variants and automatically
replay an observed CPLD fallback with tracing:

```bash
python3 tests/vice/hunt-cpld-fallback.py --attempts 200 --filename HELLO
```

The runner accepts `--cart-bank c0|c1|c2`. For C0 it splits the 32 KiB image
between VICE's existing `-functionlo` and `-functionhi` inputs. The patched
VICE accepts complete raw 32 KiB images through `-c1` / `c1Name`
and `-c2` / `c2Name`. The legacy `-c1lo`, `-c1hi`, `-c2lo`, and `-c2hi`
options remain available for separate 16 KiB halves. The dedicated mapping
test uses different fill bytes in each half and checks C1 and C2 independently.

Run the complete 200-case matrix: 66 hardware/ROM/file cases, each with the
Parobek ROM in C0 Function ROM, C1, and C2, plus two absent-device regressions.
It covers 8501 stock/JiffyDOS host
ROM, patched 6510 host ROM, stock/JiffyDOS 1541 and 1581 ROMs, synthetic SD2IEC
identification on the 1581, three 1551 ROM/RAM variants, BurstCart VIA/CPLD,
6529 PIO, 1541 RAMBOard, `HELLO` and `AMAUROTE`:

```bash
python3 tests/vice/run-headless-matrix.py
```

The matrix runs in warp mode by default. Add `--realtime` to validate against
wall-clock-paced emulation. Each load stops on a monitor breakpoint immediately
after KERNAL `LOAD` returns, so neither mode relies on a fixed sleep. Results
include VICE clocks, PAL emulated seconds and payload throughput; the full table
is written to `tests/vice/out/matrix-performance-warp.csv` or
`matrix-performance-realtime.csv`. A failed case is retried once by default;
the CSV records the attempt count, and `--retries 0` disables this behavior.
For 1551, the runner additionally samples the drive CPU port for roughly ten
emulated seconds after LOAD and fails if the active-low LED remains on or
blinks. `--parobek-bin` permits the same test against an older cartridge ROM.
`--repeat N` performs N consecutive LOAD operations in one VICE process, with
separate payload dumps, timings and post-load LED samples and without a machine
or drive reset between them.

`tests/vice/out/` contains only generated ROM copies, payload dumps, monitor
logs, traces, snapshots, and CSV results. It is gitignored, created on demand,
and can be removed between runs.

The absent-device regressions keep either a JiffyDOS 1581 with CPLD or a stock
1551 on unit #8, but load from unit #9. They require KERNAL error 5 with carry
set and reject loader banners, proving that the selected unit is checked before
loader and cartridge-hardware detection.

VICE has no SD2IEC drive model. The `sd2iec` drive-ROM variant copies the
JiffyDOS 1581 ROM into `tests/vice/out` and replaces its single eight-byte
`JIFFYDOS` identification with `SD2IEC` followed by two spaces. The drive
protocol remains JiffyDOS, while Parobek must classify the `73` status as
SD2IEC and select `SD2IEC, SJL264`. The generated copy also bypasses the ROM
CRC at `$ABBC` and the JiffyDOS additive checksum at `$AF8B`, using the same
two patches as the 1581 RAMBOard firmware, so the modified ROM can boot.

Exercise the DOS wedge between two real BASIC LOAD commands and finish with a
directory listing:

```bash
python3 tests/vice/run-1551-wedge-sequence.py --cpu 6510 --variant stock
python3 tests/vice/run-1551-wedge-sequence.py --cpu 6510 --variant ramboard
python3 tests/vice/run-1551-wedge-sequence.py --cpu 6510 --variant ramboard-rom
python3 tests/vice/run-1551-wedge-sequence.py --variant stock --cart-bank c0
```

The sequence is `LOAD"HELLO",8`, `@`, `LOAD"HELLO",8`, `@`, `$`. Each LOAD
gets an independent payload dump, while screen transcripts preserve both drive
status lines and the final directory.

The same `xplus4` binary selects the CPU-port mapping with `-hackjunk6510` or
`+hackjunk6510`. The corresponding `HackJunk6510` resource is also available
as a checkbox under Machine settings.

BurstCart hardware is selected with `-burstcart 0|1|2` (none, VIA, CPLD).
`-burstcartparallel` connects the VIA parallel cable to a 1541 and
`-burstcartburst` connects the burst serial cable to a 1571/1581. The same
resources are available under Machine settings. The drive-side parallel cable
resource uses `Drive8ParallelCable=5` for BurstCart VIA, distinct from
`Drive8ParallelCable=1` for the existing 6529 PIO data-only cable.

VIA and CPLD burst detection waits up to 65536 polls (about 0.65 emulated
seconds) for the first response. A missing or disconnected burst cable is a
normal configuration and falls through silently to the next applicable loader.
The `VIA BURST` or `CPLD BURST` banner is printed only after a complete,
successful burst transfer and channel close. No KERNAL screen output occurs
during the active handshake, because on the 6510 path it could disturb `$01`
and delay an ACK.

PIO/PPI and the other IEC-handshaked parallel loaders select DATA-in from `$01`
bit 7 on an 8501 and bit 0 on a HackJunk 6510. They are tested with both CPUs.
The separate clean-power-on test asserts the hardware-observed state
`PEEK(0)=14` (`$0e`), `PEEK(1)=49` (`$31`) before Parobek or a drive changes
the IEC line levels.

The test uses `HOST_KERNAL_6510` from `roms.env`; a stock 8501 KERNAL does not
drive IEC correctly with this CPU-port mapping. Unless `--reference-prg` is
supplied, the expected PRG is extracted directly
from the attached disk image with `c1541`.

## Matrix

| Case | Host | Drive | Datasette | Pass criteria (manual) |
|------|------|-------|-----------|------------------------|
| `stock+jd1541` | Stock kernal | JiffyDOS 1541 | — | Menu **3**, then `LOAD"HELLO",8` shows **SJL264** |
| `stock+stock1541` | Stock kernal | Stock 1541 | — | Menu **3**, then `LOAD"HELLO",8` shows **1541 SERIAL** then HELLO |
| `stock+stock1551` | Stock kernal | Stock 1551 | — | Menu **3**, then `LOAD"HELLO",8` shows **TCBM DEVICE, 1551 HYPALOAD** then HELLO |
| `stock+ram1551` | Stock kernal | Stock 1551 + RAMBOard RAM | — | **1551 HYPALOAD**; stock ROM has no RAMBOard signature |
| `stock+ramboard1551` | Stock kernal | RAMBOard RAM + patched ROM | — | **1551 RAMBOARD** then HELLO |
| `stock+jd+tape` | Stock kernal | JiffyDOS 1541 | Attached (`-1 empty.tap`) | **DATASETTE, SKIP SJL** then ROM/parallel |
| `hostjd+jd1541` | JiffyDOS host kernal | JiffyDOS 1541 | — | `LOAD"HELLO",8` shows **HOST JIFFYDOS** then **ROM LOAD**; no **SJL264** |
| `stock+jd1581` | Stock kernal | JiffyDOS 1581 | — | Menu **3**, then `LOAD"HELLO",8` shows **SJL264** |
| `stock+stock1581` | Stock kernal | Stock 1581 | — | `LOAD"HELLO",8` — no **SJL264**; **ROM LOAD** |
| `stock+jd1581+tape` | Stock kernal | JiffyDOS 1581 | Attached (`-1 empty.tap`) | **DATASETTE, SKIP SJL** then ROM |
| `hostjd+jd1581` | JiffyDOS host kernal | JiffyDOS 1581 | — | `LOAD"HELLO",8` shows **HOST JIFFYDOS** then **ROM LOAD**; no **SJL264** |

1541 and 1551 cases attach **`smoke-test.d64`** on unit #8; 1581 cases attach **`smoke-test.d81`**. Both contain PRG `HELLO` and, when the source exists, `AMAUROTE` (`~/Maciejdev/plus4/amaurote/amaurote/output/amaurote-cr.prg`).

## Disk images

Sources: `hello.prg`, plus optional `amaurote-cr.prg` → `c1541` via `rebuild-disk.sh` → `smoke-test.d64` and `smoke-test.d81`.

Regenerate:

```bash
./tests/vice/rebuild-disk.sh
```

## Notes

- 1541 cases force **`-drive8type 1542 -drive8truedrive -drive9type 0`** and load the DOS image with **`-dos1541II`**. Using `-dos1541` only affects classic 1541 and leaves a 1541-II on stock **DOS 2.6**.
- 1541 RAMBOard cases use **`-drive8ram8000`** plus the patched 32K `DRIVE_1541_RAMBOARD` ROM. VICE already maps the 1541-II `$8000-$9fff` RAM and accepts this ROM without an additional mapper patch.
- Drive type `1542` is CBM 1541-II (matches the stock/`JiffyDOS_1541-II` ROM images in `roms.env.example`).
- 1581 cases force **`-drive8type 1581 -drive8truedrive -drive9type 0`** and load the DOS image with **`-dos1581`**. Attach a **`.d81`**, not a `.d64`.
- 1551 cases force **`-drive8type 1551 -drive8truedrive -drive9type 0`** and load the DOS image with **`-dos1551`**. Attach a **`.d64`** (TCBM, not IEC). RAMBOard uses **`-drive8ram8000`** and `DRIVE_1551_RAMBOARD` selects its patched 32K ROM.
- `stock+jd+tape` / `stock+jd1581+tape` attach `tests/vice/empty.tap` by default (zero-byte placeholder; VICE accepts it for datasette attach).
- `PAROBEK_BIN` in `roms.env.example` resolves via `git rev-parse --show-toplevel`.
- Local `tests/vice/roms*.env` files are gitignored; keep only the tracked
  `.example` configuration files in the repository.
