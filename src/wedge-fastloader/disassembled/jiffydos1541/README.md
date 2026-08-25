# JiffyDOS 1541 LOAD sender reference

## VIA init: stock == JD

Compared `dos1541ii-251968-03.bin` vs `JiffyDOS_1541-II.bin`:

| Site | Both ROMs |
|------|-----------|
| `$EBE0` reset path | `LDA #$1A` / `STA $1802` |
| `$FF1A` | `STA $1802` |
| `STA $1802` sites | only those two |

JD does **not** change VIA1 DDR for LOAD. `$1802=$1A` (PB1 DATA out, PB3 CLK out, PB4 ATNA). Our sender uses the same.

## LOAD send (1541EJD) — copy these only

| Label | Role |
|-------|------|
| `P_FF8D` | `TLKACT=$1800&$60`, `WORK=TLKACT\|$0D`, DataOut_H, `eor #$0D`, DelayC64 |
| `J_FF2D` | final-sector pointer/Y transform so one inline loop always terminates on Y wrap |
| `A_FFA3`/`A_FFA5` | nibble via `A_EA1D`, `stx TLKACT`, `cpx $1800`, 4 pair writes + `nop` |
| `A_FFDE` | publish `WORK`, then spin on `cmp $1800` until the host catches up |
| `A_FF60`/`P_FF6E` | EOI: two CLK-low delays, CLK high, final delay ending CLK low |
| `A_EA1D` | 16-byte table |

Host receive: `src/sjl-loader-highcode.asm` (unchanged contract).

## Parobek `fast1541iec-drivecode`

- Job read → buffer 1 `$0400` (`$01` / `$08,$09`); code stays at `$0300`
- Host M-R `$18/$19` before CLOSE, M-W into drive `$20/$21`
- Inlined `J_FF2D` pointer transform + `P_FF8D` + `A_FFA5` + `A_EA1D`
- No per-byte subroutine or end comparison: inter-byte timing matches JD through Y wrap
- Exact `A_FFDE` sector-boundary synchronization and `P_FF6E` EOI sequence
- Host waits across a TED frame boundary after DEN=0; otherwise display DMA corrupts the cycle-counted samples
- Page end: `WORK` then next sector; file end: release then `WORK`
