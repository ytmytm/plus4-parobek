# SJL264 JiffyDOS / SD2IEC fastloader port

Date: 2026-08-24  
Branch: `feature-sjl264`  
Status: approved for implementation planning  

## Goal

Port the timing-critical **load-only** path of [SJL264 Light](https://bsz.amigaspirit.hu/sjl264/index_en.html) into Parobek so IEC devices that speak JiffyDOS (status contains `JIFFYDOS`) or SD2IEC (status contains `SD2IEC`) get a fast KERNAL-compatible load, using the same patterns as existing Parobek loaders (burst, SpeedDOS, TCBM2SD).

Reference sources: `SJL264-0.3-180107.tar.bz2` in the repo root (upstream pack); C64 background [SJLOAD](https://www.c64-wiki.com/wiki/SJLOAD) / JaffyDOS.

## Non-goals

- Directory browser, DOS commands, F1 enable/disable, 16K/32K RAM installer, overlay at `$0801`
- Self-modifying code (loader must be safe to execute from ROM)
- Replacing host JiffyDOS serial protocol when the computer already has a JiffyDOS kernal
- Unifying TCBM `t2sd_detect` / `pi1551_detect` into the new IEC status helper in this experiment (optional later)

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Integration shape | Thin Parobek wrapper + ROM-safe highcode (same layout as SpeedDOS) |
| IEC priority | Burst → if drive is JD/SD2IEC then (JD+parallel → SpeedDOS, else SJL); else existing parallel → ROM |
| Host JiffyDOS | Skip SJL; do **not** install DOS wedge; still install LOAD hook for burst / TCBM / parallel |
| Datasette | Conflicts **only** with SJL; re-check every SJL attempt; message + ROM fallback |
| Status I/O | One error-channel read into `$0200`, then local substring scan |
| VICE tests | Light matrix scripts (host × drive × datasette), not full CI yet |

## Architecture

### New files

- `src/sjl-detect.asm` — read error channel once; `scan_status_for` needles `JIFFYDOS` / `SD2IEC`
- `src/sjl-loader.asm` — ROM wrapper: datasette gate, `shared_rom_check`, open/talk SA `$61` Jiffy load, set `load_status`
- `src/sjl-loader-highcode.asm` — cycle-critical receive loop **without** self-mod

Wire into `iec_load` in `burstcart.asm` after burst returns “not handled”.

### `load_status` contract (unchanged)

Caller presets `$80`. Loader must overwrite:

- `$80` — not handled → ROM load
- `$00` — loaded OK
- other — error, return with C=1 (do not fall through to a second ROM load of the same file)

### Execute from ROM

Prefer running highcode from ROM like SpeedDOS (`jmp` to assembled highcode labels). Timing-critical sections must:

- Use RAM backups already used elsewhere (`RAM_TED_BORDER_BACKUP`, TED `$FF06` / clock if needed)
- Replace SJL’s `STA (EAL),Y` ↔ `LDA` opcode poke with an explicit address check (skip store when `EAH` wraps past `$FC`)
- Drop checksum patching, LOADING-text eraser patches, and F1 switcher

If VICE proves cycle timing requires RAM, copy a **fixed** (non-self-modifying) inner loop to a known RAM trampoline — that is a copy, not self-mod.

### Datasette / CPU port

SJL bit-bangs IEC via CPU port `$00`/`$01`, which shares cassette motor/read lines. Upstream SJL264 refuses install when `$01` bit 3 indicates cassette motor/sense conflict and aborts mid-load the same way. Parobek: before each SJL attempt, if that bit indicates a connected/active datasette conflict, print a short message (e.g. `DATASETTE, ROM LOAD`) and set `load_status=$80`. Burst and parallel paths are unaffected. Re-check every load so unplugging mid-session enables SJL.

## Detection and load flow

```
myload → IEC
  → burst
  → if handled: done
  → read error channel once → status_buffer ($0200)
  → if "SD2IEC" in buffer:
        datasette? → ROM : SJL
  → else if "JIFFYDOS" in buffer:
        par1541_detect → cable? SpeedDOS : (datasette? ROM : SJL)
  → else:
        par1541_detect → cable? SpeedDOS : ROM
```

Do **not** send `UI` for this read (avoids SD image remount). Talking the error channel and draining the current status line is enough for power-up / last-status strings.

### Host JiffyDOS

At `install_fastload`, scan the host kernal ROM for the string `JIFFYDOS` (present in Plus/4 JiffyDOS 6.01 PAL/NTSC at kernal file offset corresponding to `$EB7D`; absent in Zimmers stock kernals). If found:

- Install LOAD trampoline / vector (burst, TCBM, parallel still useful)
- **Do not** install `ICRNCH` DOS wedge (host JD already provides wedge-like commands)
- Never take the SJL branch in `iec_load` (host ROM serial is already a Jiffy fastloader)

Optional print: `JIFFYDOS ROM` when skipping wedge/SJL so the user sees why.

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Verify or `$` directory | Existing `myload` skips fastloaders |
| Device &lt; 8 | Existing ROM path |
| Datasette conflict | Message + `$80` |
| Not JD/SD2IEC after status scan | Continue parallel/ROM as today |
| File not found / DNP during SJL | Non-zero `load_status`, C=1 |
| Load address below SJL-safe range | Fall back to ROM (`$80`) if we keep upstream `$0A00` floor; document if we relax it |

## Testing (VICE)

Scripts under `tests/vice/` (or `scripts/vice/`), using absolute/configurable paths to:

- Host stock: `.../kicad-c16multirom/rom/sources/zimmers/kernal.318004-05.bin` (and NTSC twin)
- Host JD: `.../rom/sources/jiffydos/JiffyDOS_Plus4_6.01_PAL.bin` (and NTSC)
- Drive stock / JD: `.../burstcart/jiffydos/` (`dos1541ii-…`, `JiffyDOS_1541-II.bin`, …)

Matrix (smoke, light asserts):

| Host | Drive | Datasette | Expect |
|------|-------|-----------|--------|
| Stock | JD 1541 | off | SJL path message / fast load |
| Stock | Stock 1541 | off | No SJL; parallel or ROM |
| Stock | JD 1541 | on | Datasette message → ROM |
| Host JD | JD 1541 | off | No SJL; no wedge install; ROM/host JD load |

Parobek image via `-c1lo bin/parobek-via.bin`. Document `xplus4` flags in script headers. Not required for CI green in the first experiment.

## Reference material

- Upstream pack: keep `SJL264-0.3-180107.tar.bz2` or unpack under `third_party/sjl264/` for browsing; do not ship the `.prg` as the runtime loader
- Drive JD ROMs and host JD/stock paths above are external to the git tree (large / non-redistributable); scripts take env vars or a local `tests/vice/roms.env`

## Success criteria

1. Stock host + JD/SD2IEC-capable drive loads a PRG via Parobek SJL without self-mod in the shipped ROM path  
2. Host JD skips SJL and does not install Parobek DOS wedge  
3. Datasette attached blocks only SJL and falls back to ROM with a clear message  
4. Burst / TCBM / parallel behaviour unchanged when those paths win  
5. VICE matrix scripts exist and document how to reproduce the four rows above  
