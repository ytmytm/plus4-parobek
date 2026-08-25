# Task 4 Report: fast1541iec upload and jiffy2bit transfer

**Branch:** `feature-fast1541iec`  
**Base:** `f168d4a`  
**Status:** DONE_WITH_CONCERNS

## Summary

Replaced the fast1541iec stubs with a seven-chunk `M-W` upload, `M-E $0300`,
a stock-1541 DOS job reader, and the Plus/4 SJL/Jiffy-style two-bit receive
loop. The normal EOF path implements the binding `$08 -> $00 -> $08` EOI
sequence and all drive `$1800` writes keep ATNA clear.

## Implementation

- `fast1541iec-loader.asm`
  - Uses `shared_rom_check` for file lookup and load-address selection.
  - Closes logical file 1 following the existing SpeedDOS pattern.
  - Uploads exactly 224 bytes to `$0300-$03df` as seven 32-byte `M-W`
    commands, checks IEC timeout/device status, then executes `M-E $0300`.
  - Saves the TED border, disables the screen, and forces 1 MHz before
    entering the timed receiver.
- `fast1541iec-drivecode.asm`
  - Uses AAY1541's documented buffer-4 API: job `$04`, T/S `$0e/$0f`,
    buffer `$0700`, and READ jobcode `$80` (success `$01`).
  - Follows the file chain beginning at DOS `$18/$19`.
  - Converts each least-significant-first bit pair through the complete safe
    `$0a/$02/$08/$00` VIA image table.
  - Arms CLK while preparing each byte so a premature host probe returns to
    `.loadloop`; timed output stores are spaced 9/10/10 drive cycles.
- `fast1541iec-loader-highcode.asm`
  - Reuses the SJL/Jiffy `$00/$01` handshake and reconstruction sequence.
  - Discards the raw sector stream's first two PRG load-address bytes.
  - Rejects initial addresses below `$0a00`; during transfer it skips page
    `$00` and pages at/above `$fd`, returns the end address in X/Y, and
    restores TED, RAM SA, CPU-port DDR, and the exact saved `$01`.
  - Sets `load_status=$00` on clean EOF or `4` on host serial/close error.

## References checked

- AAY1541 job-code and buffer table (`$04`, `$0e/$0f`, `$0700`, `$80`).
- siziolib `serial_1bit_1541.asm`, `serial_1bit_core.inc`, `core.inc`, and
  `loadercode/serial_1bit.inc` for 1541 VIA and Plus/4 CPU-port conventions.
- In-repo SpeedDOS disk/file flow and SJL highcode timing/EOI structure.

## Verification

- Test-first static protocol check: initially failed on the stubs, then passed
  after implementation (upload calls, VIA setup/images, host store, bounded
  EOI confirmation).
- `cd src && make -B via && make via`: pass, ACME exit 0.
- Drive image labels: `$995f-$9a3f`, exactly `$e0` (224) ROM bytes; executable
  cartridge guard below `$c000` passes.
- `git diff --check`: pass.
- `timeout 15s ./tests/vice/run-matrix.sh stock+stock1541`: VICE launched with
  the configured stock ROM and disk, then timed out because the smoke requires
  manual menu selection and `LOAD"HELLO",8`.

## Self-review and concerns

- Confirmed no timed payload or handshake state uses ATN as data; PB4 is zero
  in every complete output image.
- Confirmed normal EOF follows arm `$08`, present `$00` for more than 16 drive
  cycles, then confirm `$08`, matching host `.loadendover/.end_check`.
- Confirmed generated labels remain below `$c000` and unrelated untracked
  SJL/archive/label files are outside commit scope.
- Remaining risk: no completed interactive VICE or hardware transfer was
  possible, so cycle alignment is assembled and reasoned but not empirically
  validated.
- Remaining risk: a drive READ-job error currently terminates with normal EOI
  because the binding wire protocol defines no drive-to-host error status;
  such an error can therefore appear as a short successful load.

## Correctness fixes before review

- A failed drive READ job now enters `.read_error`, continuously holding CLK
  asserted with the safe `$08` VIA image. It can no longer run the successful
  EOI sequence or appear to the host as a clean short load.
- A host EOI-confirmation timeout now records serial timeout/end status, closes
  the IEC channel, and unconditionally returns through `.file_error` with
  `load_status=$04` and carry set. Clean confirmed EOI behavior is unchanged.
- Test-first static error-path check: failed before the fixes on the READ-job
  branch and host timeout fall-through, then passed after both fixes.
- `cd src && make -B via`: pass, ACME exit 0; the drivecode remains within the
  enforced 224-byte `$0300-$03df` upload budget.

## Critical/Important review fixes

- Successful last-sector transfer now branches explicitly to `.send_eoi`;
  mid-file sectors still branch to `.read_sector`, while a non-`$01` READ-job
  result still hangs in `.read_error` with CLK held at `$08`.
- Upload, channel, and `M-E` failures now return `load_status=$04` with carry
  set. The committed fast1541iec path no longer requests the ROM double-load
  fallback status `$80`.
- Test-first static checks failed on both reviewed paths before the changes and
  passed afterward.
- `cd src && make via` and a forced `make -B via` rebuild pass; ACME exits 0.
