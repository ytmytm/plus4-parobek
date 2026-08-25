# Stock 1541 IEC serial fastloader (`fast1541iec`)

Date: 2026-08-25  
Branch: `feature-fast1541iec` (from `feature-sjl264`)  
Status: design approved — research spike next  

## Goal

Add a **serial IEC fast LOAD** for **stock 1541-class drives** (no parallel cable, no JiffyDOS/SD2IEC ROM). Upload drivecode via `M-W`/`M-E`, then transfer over CLK/DATA only. Shared IEC bus with other devices is assumed — **no ATN-as-data tricks**.

When this path does not apply or fails, fall through to the existing Parobek chain (`load_status=$80` → ROM load).

## Non-goals

- Replacing SJL for JiffyDOS / SD2IEC (keep existing SJL path)
- Replacing SpeedDOS parallel for cabled 1541
- Trackloaders, IRQ loaders, save, directory turbo
- Host JiffyDOS kernal changes
- Guaranteeing cycle-exact timing on every 6502/6510 replacement in v1 (document and harden after spike; 1-bit handshake is the last-resort compat fallback)

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Target | Stock 1541 only (1540 / 1541 / 1541C / 1541-II class via identity) |
| File prefix | `fast1541iec` (not `stock1541`) |
| Priority in `iec_load` | After burst → SD2IEC+SJL → parallel → drive-JD+SJL; **then** plain-1541 serial; else ROM |
| Gate | Only if drive looks like plain 1541 (`M-R` identity); reuse siziolib / `par1541_detect` ideas; **no `UI`** for detect |
| Protocol | Research spike first (MegaLoad V4/V6, siziolib, SJL drive-side fit); **if RE fails → 2-bit cycle-timed (Jiffy/pagetable style) reusing SJL host receive where possible**; if that fails on replacement CPUs → siziolib-style 1-bit handshake |
| Bus | CLK/DATA only; ATN only for normal IEC command arbitration |
| Datasette | `$00`/`$01` bitbang: skip like SJL when datasette conflicts |
| Sticky drivecode | Do **not** leave drivecode resident across loads unless spike proves safe with other devices on the bus |

## Approaches considered

1. **MegaLoad-derived** — native Plus/4 1541 turbo ([Megaload V4](https://plus4world.powweb.com/software/Megaload_V4)); prefer if RE shows CLK/DATA-only protocol we can port.
2. **SJL host + new 1541 2-bit sender** — fallback if RE fails; reuse Plus/4 SJL receive timing; supply drive-side sender ([JiffyDOS protocol notes](https://github.com/MEGA65/open-roms/blob/master/doc/Protocol-JiffyDOS.md), [pagetable 2-bit idea](https://www.pagetable.com/?p=568)).
3. **siziolib 1-bit** — [siziolib](https://github.com/iszell/siziolib) multi-drive handshake; slower; last-resort compat path (their 2-bit single-drive protocol is still TODO upstream).

**Recommendation:** spike → prefer (1) if clean; else (2); else (3).

## Architecture

### New files

- `src/fast1541iec-detect.asm` — plain-1541 gate (`M-R` ROM identity; reject JD/SD2IEC; factor “is 1541” from `par1541_detect` / siziolib if clean)
- `src/fast1541iec-loader.asm` — ROM wrapper: message, TED screen-off / 1 MHz as needed, `M-W`/`M-E`, set `load_status`
- `src/fast1541iec-loader-highcode.asm` — cycle-critical host receive, ROM-safe, no self-mod
- `src/fast1541iec-drivecode.asm` — uploaded 1541 side

Wire into `iec_load` in `burstcart.asm` after parallel / JD+SJL when those do not handle the load.

User-visible tag (short): `1541 SERIAL` or `FAST1541IEC` (finalize during implement).

### Research / disassembly artifacts

- `src/wedge-fastloader/disassembled/megaload/` — MegaLoad V4 (or V6 / compilation extract) in the same style as HypaLoad/Port-Turbo notes
- Optional notes under `docs/` or beside disassembly summarizing bit order and handshake
- Reference only: siziolib serial 1-bit host/drive; do not vendor the whole IRQ-loader framework

### `load_status` contract (unchanged)

Caller presets `$80`. Loader must overwrite:

- `$80` — not handled → ROM load
- `$00` — loaded OK
- other — error, return with C=1 (do not fall through to a second ROM load of the same file)

## Detection and load flow

```
myload → IEC
  1. burst
  2. status buffer: SD2IEC → SJL (unless host_jd / datasette)
  3. par1541_detect → SpeedDOS parallel
  4. status buffer: JIFFYDOS → SJL (unless host_jd / datasette)
  5. fast1541iec-detect (plain 1541 identity)
       → if yes and datasette OK: upload + serial fast load
  6. otherwise → ROM ($80)
```

Notes:

- Step 5 runs only when steps 1–4 did not handle the load.
- JD/SD2IEC never take step 5 (already claimed by SJL or host JD ROM path).
- Parallel cable still wins at step 3 when present.
- Detection uses `M-R` (and existing status needles already read earlier); do **not** send `UI`.

## Protocol selection (spike exit criteria)

Spike is done when all of the following exist:

1. Chosen protocol named (MegaLoad / 2-bit SJL-compat / 1-bit handshake)
2. Byte-level bit order and EOI/ready handshake written down
3. Confirmation that ATN is not used as a data line
4. Rough size estimate for drivecode (`M-W` budget) and host highcode

| Outcome | Choice |
|---------|--------|
| MegaLoad CLK/DATA-only and portable | MegaLoad-derived |
| MegaLoad unavailable, ATN tricks, or opaque | 2-bit (SJL host + new drive sender) |
| 2-bit fails on replacement CPUs | 1-bit siziolib-style handshake |

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Verify or `$` directory | Existing `myload` skips fastloaders |
| Not plain 1541 / probe fail | `$80` → ROM |
| `M-W` / `M-E` fail | Restore IEC; `$80` → ROM |
| Datasette blocks bitbang | Skip fast1541iec (message optional); `$80` |
| Mid-transfer timeout | Abort; untalk/close; non-zero `load_status`, C=1 |
| File not found during fast path | Non-zero `load_status`, C=1 |

## Testing (VICE)

Extend `tests/vice/` matrix:

| Case | Expect |
|------|--------|
| `stock+stock1541` | `fast1541iec` path message; `LOAD"HELLO",8` OK |
| `stock+jd1541` / `stock+jd1581` | Still SJL; not fast1541iec |
| `stock+jd+tape` | Datasette rules unchanged (SJL skip); fast1541iec also skipped if bitbang conflicts |
| Parallel present (when testable) | Parallel still wins over fast1541iec |

Primary: VICE stock 1541-II CPU. Hardware / replacement-CPU notes are follow-up after the spike.

## Success criteria

1. Stock host + stock 1541 (no parallel) loads a PRG via `fast1541iec` faster than ROM IEC  
2. JD/SD2IEC and parallel paths unchanged when they win  
3. Shared-bus safe: no ATN data protocol  
4. On detect/upload/transfer failure, clean fallback to ROM without double-load  
5. Spike artifacts + chosen protocol documented before (or as first commits of) implementation  
6. VICE smoke case for `stock+stock1541` documents the new expect string  

## Reference material

- [Megaload V4](https://plus4world.powweb.com/software/Megaload_V4) / V6 / Plus/4 Power & Pluvi compilations
- [siziolib](https://github.com/iszell/siziolib) — Plus/4 `$00`/`$01` IEC bits, 1541 `M-R` detect, serial 1-bit drivecode
- [Open ROMs JiffyDOS protocol](https://github.com/MEGA65/open-roms/blob/master/doc/Protocol-JiffyDOS.md)
- [pagetable.com fastloader notes](https://www.pagetable.com/?p=568)
- Existing Parobek: `par1541-detect.asm`, `speeddos-*.asm`, `sjl-loader*.asm`, `docs/superpowers/specs/2026-08-24-sjl264-fastloader-design.md`
