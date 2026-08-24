# Task 4 Report: Port SJL264 receive path (ROM-safe, load only)

**Branch:** `feature-sjl264`  
**Commit:** `ef7b7ec` - Port SJL264 receive path as ROM-safe loader backend.  
**Status:** DONE

## Summary

Replaced the `SJL264 STUB` path with a real, load-only SJL264 receive implementation split into a wrapper (`SJL_load`) and ROM-resident highcode (`SJL_highcode`). The new path keeps Parobek's `load_status` contract, uses `shared_rom_check`, honors ROM-safety limits (`$0000` wrap and `$FD00+` skip-store), and restores TED/UI state on every return path.

## Changes

### `src/sjl-loader.asm`

- Replaced stub with real `SJL_load` wrapper.
- Calls `shared_rom_check`; returns `load_status=4` on file-not-found.
- Enforces load-only ROM-safe gate: if load address high byte `< $0A`, closes serial context and returns `load_status=$80` (fall back to ROM).
- Backs up `TED_BORDER` and `TED_FF06`, turns screen off, and jumps to highcode.
- Sources `sjl-loader-highcode.asm`.

### `src/sjl-loader-highcode.asm` (new)

- Added `SJL_highcode` receive loop, plus `sjl_talk`, `sjl_sectalk`, `sjl_untalk`, and `sjl_busin` helper ports from upstream.
- Uses JD data channel secondary address `$61` after the ROM setup/open phase.
- Ported timing-critical byte transfer loop with no self-modifying code.
- Replaced opcode patching with explicit store policy:
  - skip store when `$9E == $00` (wrap to `$0000`)
  - skip store when `$9E >= $FD` (ROM / I/O range)
- Preserves border activity (`inc TED_BORDER`) and restores `RAM_TED_BORDER_BACKUP` + `RAM_TED_FF06_BACKUP` on all exits.
- Restores `RAM_SA` from `RAM_SA_BACKUP`, sets `load_status=0` on success, `4` on SJL transfer/close error, `$80` on not-handled motor conflict.

### `src/burstcart.asm`

- Added named KERNAL serial helper equates from `_system.ain` (`ROM_CBMSER_*`, `ROM_IEC_*_SETUP`, `ROM_SET_STATUS_HELPER`) used by SJL code.

### `src/Makefile`

- Added `sjl-loader-highcode.asm` to `SRCS` so `make via cpld` tracks the new source dependency.

## Verification

```bash
cd src && make via cpld
```

Result: **pass** (ACME exit code 0 for both targets).  
Executable limit guard (`!if * > $C000`) remains silent/passing.

Sample symbols from `labels-via.txt`:

- `SJL_load = $A457`
- `SJL_highcode = $A495`
- `sjl_talk = $A565`
- `sjl_untalk = $A5F4`

All executable entry points remain below `$C000`.

## Self-review (timing/protocol fidelity vs ROM-safety)

### What matches upstream intent

- Kept upstream receive-path structure and protocol helpers (`talk/sectalk/untalk/busin`).
- Preserved the JD transfer handshake and status/EOI handling shape.
- Preserved load-address semantics from `shared_rom_check` + existing `RAM_SA` flow.

### ROM-safety and project constraints

- **No self-modifying code**: removed opcode pokes and self-mod border restore.
- **Load-only**: no BASIC installer/F1/checksum patch/overlay/LOADING eraser behaviors.
- **ROM-executed highcode**: runs in-place from cartridge image; no runtime RAM copy.
- **Store-guard policy**: explicit address checks replace write-opcode mutation.

### Concerns / follow-ups

1. **Cycle margin risk**: transfer loop timing is ported from upstream but now executes in a different assembled context; this may need VICE/hardware validation (Task 5) and possibly a fixed RAM copy of just the hot loop if edges appear.
2. **Fallback cleanup assumptions**: the `$80` not-handled paths now issue `UNTLK` + internal close setup before returning to ROM fallback; this is intentional but should be confirmed against all host-drive states.
3. **Uncommitted build artifacts**: `src/bin/parobek-via.bin`, `src/bin/parobek-cpld.bin`, and generated labels were rebuilt locally but intentionally left out of commit scope.

## Critical Task 4 follow-up (review fix)

- Added missing `jsr sjl_untalk` in `src/sjl-loader-highcode.asm` immediately before switching to JD data SA `$61` and reissuing `sjl_talk`/`sjl_sectalk`.
- This enforces the required `UNTALK -> TALK $61` transition after `shared_rom_check` has already consumed the load address.
- Verified return paths remain unchanged: both `.return_ok` and `.return_error` call `sjl_restore`, which restores `RAM_SA`, `TED_BORDER`, `TED_FF06`, and serial line state through `ROM_CBMSER_DAT_HIZ`.
- Rebuilt with `cd src && make via cpld` (pass).
