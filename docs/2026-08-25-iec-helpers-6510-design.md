# IEC helper extract + 6510 SJL receive

Date: 2026-08-25  
Branch: `feature-fast1541iec`  
Locked: `cpu_port_type` in lowmem trampoline (same lifetime as `host_jd`); option **A** — type 1 gets a second SJL receive loop; type 2/3 skip SJL and 1541 SERIAL.

## Goal

1. Deduplicate IEC memory-command / TED enter-leave patterns used on the long stock-1541 serial path (and SpeedDOS upload) without changing loader priority or calling `UI` twice.
2. Make SJL264 (and `SJL_jd_transfer` used by fast1541iec) work on a Hackjunk 8501→6510 host with **patched** KERNAL; detect once at install.

## Non-goals

- Burst, parallel handshake, TCBM/1551 protocol changes.
- Type 2 (6510 + **stock** KERNAL) serial bitbang.
- Table-driven `iec_load` (priority stays as today).
- Deleting `par1541_load` unless it is a one-line disable.
- Merging SJL bitbang talk with KERNAL `ROM_TALK`.

## IEC priority (unchanged)

`burst → SD2IEC SJL → parallel SpeedDOS → drive-JD SJL / host-JD ROM → 1541 SERIAL → ROM`

`iec_note_drive_class` still: current status, then **at most one** `UI` if sticky `iec_drive_flags` bits 0–1 are still clear.

## `cpu_port_type` (siziolib values)

Stored in the `$0640` trampoline next to `host_jd`, copied at `install_fastload`.

| Value | Meaning | SJL / 1541 SERIAL |
|-------|---------|-------------------|
| 0 | Native 7501/8501 | As today (datasette gate on `$01` bit 3) |
| 1 | 6510 + patched KERNAL (`$F30C` ≠ `$0F`; Hackjunk `$0E`) | Second receive loop; skip datasette gate |
| 2 | 6510 + stock KERNAL (`$F30C` == `$0F`) | Skip; ROM IEC |
| 3 | Unknown | Skip; ROM IEC |

Detection: siziolib `detect_cpu_port_type` (`detect/detect.inc`): DATA-out vs DATA-in follow test; else bits 7–6 clear and bit 5 idle high → 6510; then `$F30C` vs `%00001111` to split type 1 vs 2. Run once after trampoline install. Do not re-probe `$01` every LOAD.

References: [Hackjunk 8501→6510](https://hackjunk.com/2017/06/23/commodore-16-plus-4-8501-to-6510-cpu-conversion/), [siziolib](https://github.com/iszell/siziolib).

## Port map (IEC)

Open-collector IEC: 1 in `$01` = line pulled low for outputs.

| Signal | 8501 `$01` | Hackjunk type 1 `$01` |
|--------|------------|------------------------|
| DATA out | bit 0 | bit 3 |
| CLK out | bit 1 | bit 1 |
| ATN out | bit 2 | bit 2 |
| Cassette motor | bit 3 | gone (jumper/diode) |
| CLK in | bit 6 (`BIT` → V) | bit 5 |
| DATA in | bit 7 (`BIT` → N) | bit 0 |

Type 1 DDR restore is `$0E`, not `$0F`. Never `$00=$1F` on type 1 (makes DATA in an output).

## Shared IEC helpers

Used by `fast1541iec-loader.asm` and `speeddos-loader.asm` (HypaRAM only if the same LISTEN/`M-`/UNLISTEN shape applies without extra state).

| Helper | Contract |
|--------|----------|
| `iec_m_minus` | A = letter after `M-` (`W`/`E`/`R`). LISTEN `RAM_FA`, `$6F`, send `M`, `-`, A. Clobbers A. Caller sends address/payload and UNLISTEN. |
| `iec_mw_upload` | Src `($03)`, drive dst `($05)`, chunk length in A. Loop until caller-defined end (fast1541iec: src hits `fast1541iec_drivecode_end`; SpeedDOS: two pages `$0300–$04FF`). After each chunk: UNLISTEN; if `RAM_STATUS & $83` → C=1. |
| `iec_me` | Exec address in `$d6/$d7` (or agreed ZP). `iec_m_minus` with `E`, send lo/hi, UNLISTEN. Optional status check same `$83` mask. |

Keep `par1541-detect.asm` `.send_command` (`($d0)` + length `$d2`) — fixed M-R/M-W probe strings, not an upload loop.

**TED:** extract enter/leave used by SJL + fast1541iec (border, `$FF06` blank, `$FF13` 1 MHz). On fast1541iec, any `.fail` **after** TED enter must leave via restore (today M-E fail at `fast1541iec-loader.asm` ~160–189 can leave screen off / 1 MHz). Raster-frame wait stays in the fast1541iec wrapper (M-E path has no SJL command phase).

## SJL 6510 receive

One source file, two generated loops with **matching cycle counts between samples**:

- `sjl_jd_receive_loop` — current 8501 `BIT $01` V/N (bits 6/7).
- `sjl_jd_receive_loop_6510` — sample DATA bit 0 and CLK bit 5; replace `eor #%00001010` with a type-1 fold; busy-wait in `SJL_jd_transfer` must not use `bvs` (V is still bit 6).

Install writes a **RAM vector** in the trampoline (e.g. `sjl_receive_vec`) to the chosen loop. `SJL_highcode` and `SJL_jd_transfer` `jsr` through that vector.

Sendbyte: ATN/CLK ROM helpers are the same addresses on type 1; `DAT_HIZ`/`DAT_LO` are patched to bit 3. Prefer those ROM helpers for **output**. **Input** polls (`bmi`/`bpl`/`bvs`/`bvc` on `$01`) stay in the type-specific loop / sendbyte wait.

Restore:

- Type 0: `$00=$0F`, `ORA #%00001000` as today.
- Type 1: `$00=$0E`, do not `ORA #$08`.

`datasette_blocks_sjl`: if `cpu_port_type ≠ 0`, C=0 (allow). Type 0 unchanged.

Type 2/3: `iec_load` skips `jmp SJL_load` and `jmp fast1541iec_load` (same idea as `host_jd` skipping SJL).

Drivecode (`fast1541iec-drivecode.asm`) unchanged.

## Error handling

- Type 2/3: `load_status=$80`, ROM path; optional short message later, not required.
- Helper M-W/M-E fail: existing `load_status=$04` / C=1 on fast1541iec; SpeedDOS keeps its current fail behaviour.
- Detection must not leave `$01` wedged (save/restore around probe, as siziolib).

## Testing

- Source contract: trampoline contains `cpu_port_type`; type 2/3 has no path into `SJL_load`/`fast1541iec_load` without a skip; type 1 loop present; `iec_send_ui` still only from `iec_note_drive_class`.
- VICE type 0: `stock+stock1541` (`1541 SERIAL`) and `stock+jd1541` (`SJL264`).
- Type 1: real Hackjunk hardware (no VICE model).

## Files

| File | Change |
|------|--------|
| `src/burstcart.asm` | `cpu_port_type`, `sjl_receive_vec`; install detect; skip SJL/serial on 2/3 |
| `src/host-jd-detect.asm` or new `src/cpu-port-detect.asm` | `detect_cpu_port_type` |
| `src/sjl-detect.asm` | datasette gate respects `cpu_port_type` |
| `src/sjl-loader-highcode.asm` | second loop; restore branches; vector jsr |
| `src/fast1541iec-loader.asm` | use helpers; TED fail restore |
| `src/speeddos-loader.asm` | use helpers |
| `README.md` | 6510 type 1 note; type 2 ROM fallback |

## Out of scope recap

Burst/parallel/TCBM; type 2 serial; mask-table inner loop; `par1541_detect` string command merger.
