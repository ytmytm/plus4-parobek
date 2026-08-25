# fast1541iec: reuse SJL264 JD receive

Date: 2026-08-25  
Branch: `feature-fast1541iec`  
Parent: [fast1541iec design](2026-08-25-fast1541iec-design.md), [protocol](2026-08-25-fast1541iec-protocol.md)

## Goal

Stop maintaining a duplicate Plus/4 JD receive loop for stock-1541 serial fastload.
Drive still uploads a JD LOAD–shaped sender; host receives only through SJL264’s
proven timed path. Clean comments/tests to match that status quo. Expected side
effect: end load-time screen/cursor corruption (cursor jumping home after
`LOADING` from `shared_rom_check`).

## Status quo (before this change)

| Side | Role |
|------|------|
| `fast1541iec-drivecode.asm` | JD sender @ `$0300` (literal `J_FF2D` / `P_FF8D` / `A_FFA3` / `A_FFDE` / EOI) |
| `fast1541iec-loader.asm` | Wrapper: `shared_rom_check`, M-R T/S, CLOSE, M-W, seed `$20/$21`, TED blank + 1 MHz, frame wait, M-E |
| `fast1541iec-loader-highcode.asm` | **Duplicate** of SJL `.loadloop` / `.transferbyte` with private busy-sync and restore |
| `sjl-loader-highcode.asm` | Canonical JD receive (also used for SD2IEC / drive JD) |

Protocol on the wire stays `PROTOCOL=jiffy2bit`. Only the host entry changes.

## Decision

**Approach A:** After `M-E`, jump into a shared SJL entry at the timed transfer.
Do **not** issue `TALK/$61`. Drivecode keeps starting after `DelayC64` as today.

Rejected:

- **B** — Make drive wait for real `$61` then use full SJL from `.ldaddrokay` (larger drive change).
- **C** — Keep a thin fast1541iec stub that only busy-syncs then jumps to `.loadloop` (still a second host file / setup path).

## Architecture

```
fast1541iec_load
  → shared_rom_check   ; SEARCHING, open $60, ACPTR addr → $9D/$9E, LOADING, C=0
  → UNTALK, M-R $18/$19, CLOSE
  → M-W drivecode @ $0300, M-W seed $20/$21
  → TED FF06 blank, FF13 1 MHz, wait one frame (FF1C bit0 toggle twice)
  → M-E $0300
  → jmp SJL_jd_transfer

SJL_load (unchanged externally)
  → … address phase, TALK/$61 …
  → falls into same transfer body as SJL_jd_transfer
```

### New label: `SJL_jd_transfer`

Public entry in `sjl-loader-highcode.asm` used by fast1541iec after M-E.

**Preconditions (caller guarantees):**

- `$9D`/`$9E` hold the final load address (from `shared_rom_check`, including SA=0 relocate).
- `$9E >= $0A` already enforced by the fast1541iec wrapper (same floor as SJL).
- `RAM_TED_*_BACKUP` and `RAM_SA_BACKUP` already set; screen blanked; 1 MHz forced.
- Drive JD sender is running (post–M-E); no host `TALK/$61`.

**Body:**

1. `sei`; set CPU port like SJL motor-ok path: `$01 = %00001000`, `$00 = %00011111`.
2. Do **not** re-print `LOADING` (already done in `shared_rom_check`).
3. `ldy #0`; `ldx #231` delay; enter existing `.loadloop` / `.transferbyte` / `.loadendover`.
4. After EOI: `ROM_SET_STATUS_HELPER` as in SJL; set `load_status`; return via `sjl_restore` with the same C/`X`/`Y` (`$9D`/`$9E`) convention.
5. **Do not** call `sjl_untalk` or `ROM_IEC_CLOSE_SETUP` from `SJL_jd_transfer`: the wrapper already `CLOSE`d channel 0 before M-W/M-E, and there was no `$61` TALK. Full `SJL_highcode` keeps untalk+close after its `$61` session.

Normal `SJL_highcode` continues to perform address phase + `$61`, then shares the identical transfer instructions (one copy only).

## Files

| Action | File |
|--------|------|
| Modify | `src/sjl-loader-highcode.asm` — add `SJL_jd_transfer`; share transfer/cleanup |
| Modify | `src/fast1541iec-loader.asm` — `jmp SJL_jd_transfer`; drop `!source` of highcode; refresh header comments |
| Delete | `src/fast1541iec-loader-highcode.asm` |
| Modify | `src/fast1541iec-drivecode.asm` — comments only if they claim a private host receiver |
| Modify | `tests/check_fast1541iec_error_paths.py` — drop duplicate `.loadloop` identity assert; assert wrapper jumps to `SJL_jd_transfer` and drive JD shape remains |
| Optional comment pass | `src/fast1541iec-detect.asm`, design/protocol docs cross-links |

## Error handling

Unchanged semantics:

- `shared_rom_check` fail → `load_status=$04`, C=1 (wrapper).
- M-W / M-E IEC error → `load_status=$04`, C=1.
- Transfer EOI / timeout → same `load_status` / C as SJL after `.loadendover`.
- No `$80` ROM fallback from this path once M-E succeeded (same as current fast1541iec).

## Testing

- Contract: `tests/check_fast1541iec_error_paths.py` updated as above.
- Smoke: `./tests/vice/run-matrix.sh stock+stock1541` — menu `3`, `LOAD"HELLO",8`:
  - Message `1541 SERIAL`
  - Cursor remains after `LOADING` (does not jump home)
  - HELLO bytes at `$1001` match drive buffer payload (no partial corruption)

Regression: `stock+jd1541` still prints `SJL264` and loads via full SJL path.

## Out of scope

- Drive sender protocol / `$61` wait
- Changing `shared_rom_check`
- Sound / VICE matrix flags (separate change)
- Parallel / burst / host-JD gates
