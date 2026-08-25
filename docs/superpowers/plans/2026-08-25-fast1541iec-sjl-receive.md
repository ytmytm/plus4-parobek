# fast1541iec SJL Receive Reuse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the duplicate fast1541iec host receive loop and jump into a shared SJL264 JD transfer entry after M-E, so stock-1541 serial fastload uses one proven receiver.

**Architecture:** Extract the timed `.loadloop`…`ROM_SET_STATUS_HELPER` body into a subroutine callable from both full `SJL_highcode` (after `TALK/$61`) and new `SJL_jd_transfer` (port setup only, no untalk/close). `fast1541iec_load` keeps upload/M-E, then `jmp SJL_jd_transfer`.

**Tech Stack:** ACME 6502, GNU make, Python contract test, VICE `xplus4` smoke via `tests/vice/run-matrix.sh`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-25-fast1541iec-sjl-receive.md`
- Wire protocol unchanged (`PROTOCOL=jiffy2bit`); drivecode sender unchanged except comment cleanup.
- No `TALK/$61` on the fast1541iec path; no second `LOADING` print.
- `SJL_jd_transfer` must not call `sjl_untalk` or `ROM_IEC_CLOSE_SETUP`.
- No self-mod in ROM path; stay under `$C000`.
- Branch: `feature-fast1541iec`.

## File map

| File | Responsibility |
|------|----------------|
| `src/sjl-loader-highcode.asm` | Add `SJL_jd_transfer`; extract shared receive subroutine; full SJL keeps untalk/close |
| `src/fast1541iec-loader.asm` | After M-E, `jmp SJL_jd_transfer`; drop highcode `!source`; refresh comments |
| `src/fast1541iec-loader-highcode.asm` | **Delete** |
| `src/fast1541iec-drivecode.asm` | Comment pass only (host is SJL receive) |
| `src/Makefile` | Drop deleted highcode from dependency list |
| `tests/check_fast1541iec_error_paths.py` | Assert `jmp SJL_jd_transfer`; drop duplicate-loop identity check |

---

### Task 1: Contract test expects shared SJL entry

**Files:**
- Modify: `tests/check_fast1541iec_error_paths.py`
- Test: same file

**Interfaces:**
- Consumes: current sources (test must fail until Tasks 2–3 land)
- Produces: assertions later tasks must satisfy — wrapper contains `jmp SJL_jd_transfer`; no `fast1541iec-loader-highcode.asm`; drive JD shape unchanged

- [ ] **Step 1: Rewrite the contract test**

Replace `tests/check_fast1541iec_error_paths.py` with:

```python
#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
drive = (ROOT / "src/fast1541iec-drivecode.asm").read_text()
wrapper = (ROOT / "src/fast1541iec-loader.asm").read_text()
sjl_host = (ROOT / "src/sjl-loader-highcode.asm").read_text()
ejd = (ROOT / "docs/1541EJD.a65").read_text()


def section(source: str, start: str, end: str) -> list[str]:
    body = source.split(start, 1)[1].split(end, 1)[0]
    return [line.strip() for line in body.splitlines() if line.strip()]


# Host receive is SJL's JD transfer entry, not a private highcode copy.
assert "jmp SJL_jd_transfer" in wrapper
assert "fast1541iec-loader-highcode" not in wrapper
assert "SJL_jd_transfer:" in sjl_host
assert "sjl_jd_receive_loop:" in sjl_host
assert "jsr sjl_jd_receive_loop" in sjl_host
assert ".loadloop:" in sjl_host
assert sjl_host.count(".loadloop:") == 1

# Keep the complete JD sender shape, not a per-byte approximation.
assert "lda ($30),y" in drive
assert "cpx $1800" in drive
assert ".wait_host:" in drive
assert any(
    line.startswith("cmp $1800")
    for line in section(drive, ".wait_host:", ".do_eoi:")
)
assert "jsr $e9a5" in drive  # DataOut_H
assert "jsr $fef3" in drive  # DelayC64
assert "jsr $e9ae" in drive  # ClkOut_H
assert "jmp $e9b7" in drive  # ClkOut_L
assert ".send_byte:" not in drive
assert "$0f,$07,$0d,$05" in drive.replace(" ", "")

# Screen blanking must cross a frame boundary before timed M-E transfer.
assert "sta TED_FF06" in wrapper
assert ".wait_second_low:" in wrapper
assert ".wait_second_high:" in wrapper

for label in ("J_FF2D", "P_FF8D", "A_FFA3", "A_FFDE", "A_EA1D"):
    assert label in ejd

assert not (ROOT / "src/fast1541iec-loader-highcode.asm").exists()

print("fast1541iec JD review checks OK")
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `python3 tests/check_fast1541iec_error_paths.py`

Expected: FAIL (missing `SJL_jd_transfer` / highcode file still exists / no `jmp SJL_jd_transfer`)

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/check_fast1541iec_error_paths.py
git commit -m "$(cat <<'EOF'
Require fast1541iec to enter SJL_jd_transfer.

EOF
)"
```

---

### Task 2: Extract shared receive + add `SJL_jd_transfer`

**Files:**
- Modify: `src/sjl-loader-highcode.asm`
- Test: `tests/check_fast1541iec_error_paths.py` (still fails on wrapper/delete until Task 3)

**Interfaces:**
- Consumes: existing `.loadloop`…`.loadendover` body and `sjl_restore` / `.return_ok` / `.return_error`
- Produces:
  - `SJL_jd_transfer` — public entry; sets `$01=$08`, `$00=$1f`; `jsr sjl_jd_receive_loop`; success → `load_status=0`, `ldx $9d` / `ldy $9e`, `jmp .return_ok` (no untalk/close)
  - `sjl_jd_receive_loop` — `ldy #0`, `ldx #231` delay, `.loadloop` through `jsr ROM_SET_STATUS_HELPER`, then `rts`
  - Full `SJL_highcode` after `$61`: `jsr sjl_jd_receive_loop` then existing `sjl_untalk` / `ROM_IEC_CLOSE_SETUP` / success or `.file_error`

- [ ] **Step 1: Replace the post-`$61` transfer and add the public entry**

In `src/sjl-loader-highcode.asm`, change the header comment to note the shared entry, then replace from the `ldy #$00` / `ldx #231` block through `.file_error` with:

```asm
		; --- JD fastload phase (SA $61) ---
		lda #$61
		sta RAM_SA
		lda RAM_FA
		jsr sjl_talk
		lda #$61
		jsr sjl_sectalk

		jsr sjl_jd_receive_loop
		jsr sjl_untalk
		jsr ROM_IEC_CLOSE_SETUP
		bcs .file_error

		lda #0
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_ok

.file_error:
		lda #4
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_error

.return_ok:
		jsr sjl_restore
		clc
		rts

.return_error:
		jsr sjl_restore
		sec
		rts

; Entry for fast1541iec after M-E: address already in $9D/$9E, TED already
; blanked/1MHz, no TALK/$61. Must not untalk/close (channel already CLOSED).
SJL_jd_transfer:
		sei
		lda #%00001000
		sta $01
		lda #%00011111
		sta $00
		jsr sjl_jd_receive_loop
		lda #0
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_ok

; Timed JD receive only (delay + loadloop + EOI status). Caller handles bus teardown.
sjl_jd_receive_loop:
		ldy #$00
		ldx #231
.wait1:
		dex
		bne .wait1

.loadloop:
		lda #%00001000
		sta $01
.wait_clk_drive:
		bit $01
		bvc .wait_clk_drive
		bmi .loadendover
.wait_data_drive:
		bit $01
		bpl .wait_data_drive

.transferbyte:
		nop
		nop
		nop
		nop
		lda #%00001000
		ldx #%00001001
		stx $01
		bit $01
		bvc .loadloop
		nop
		sta $01
		lda $01
		nop
		lsr
		lsr
		eor $01
		bit $00
		lsr
		lsr
		eor $01
		bit $00
		lsr
		lsr
		eor $01
		eor #%00001010

		ldx $9e
		beq .skip_store
		cpx #$fd
		bcs .skip_store
		sta ($9d),y
.skip_store:
		inc TED_BORDER
		inc $9d
		bne .transferbyte
		inc $9e
		jmp .transferbyte

.loadendover:
		ldx #$64
.end_check:
		bit $01
		bvc .end_ok
		dex
		bne .end_check
		lda #%01000010
		!by $2c
.end_ok:
		lda #%01000000
		jsr ROM_SET_STATUS_HELPER
		rts
```

Keep `sjl_restore` and the talk/busin helpers unchanged below.

**Zone note:** `SJL_jd_transfer` and `sjl_jd_receive_loop` must be visible outside the `!zone` (place them as global labels the same way `SJL_highcode` is — if the zone makes dotted labels local, keep these two names without a leading dot and ensure ACME exports them; match how `SJL_highcode` / `sjl_restore` are declared today).

Also update the file header to:

```asm
; SJL264 receive path — ROM-resident, no self-mod.
; Sequence matches upstream loader_routine after rom_iec_open:
;   set CPU-port DDR → TALK/$60 → busin addr → UNTALK → TALK/$61 → transfer
; SJL_jd_transfer: shared JD .loadloop entry for fast1541iec (no $61).
```

- [ ] **Step 2: Assemble to verify labels resolve**

Run: `make -C src bin/parobek-via.bin`

Expected: build succeeds; no “label not found” for `SJL_jd_transfer` / `sjl_jd_receive_loop`.

- [ ] **Step 3: Commit**

```bash
git add src/sjl-loader-highcode.asm
git commit -m "$(cat <<'EOF'
Add SJL_jd_transfer shared JD receive entry.

EOF
)"
```

---

### Task 3: Point fast1541iec at SJL; delete private highcode

**Files:**
- Modify: `src/fast1541iec-loader.asm`
- Modify: `src/fast1541iec-drivecode.asm` (header comments)
- Modify: `src/burstcart.asm` (source order: SJL before fast1541iec)
- Modify: `src/Makefile`
- Delete: `src/fast1541iec-loader-highcode.asm`
- Optional comment: `src/fast1541iec-detect.asm`
- Test: `tests/check_fast1541iec_error_paths.py`

**Interfaces:**
- Consumes: `SJL_jd_transfer` from Task 2
- Produces: `fast1541iec_load` ends with `jmp SJL_jd_transfer`; no private receive file

- [ ] **Step 1: Update wrapper header and post–M-E jump**

Replace the top of `src/fast1541iec-loader.asm` comments with:

```asm
; Stock 1541 serial IEC fastloader wrapper (Parobek).
; M-R $18/$19 before CLOSE (header T/S), upload drivecode, M-W T/S into
; drive $20/$21, M-E, then SJL_jd_transfer (shared SJL264 JD receive).
```

Change the success path after M-E from `jmp fast1541iec_highcode` to:

```asm
		jmp SJL_jd_transfer
```

Remove these two lines at the bottom of the file:

```asm
!source "fast1541iec-loader-highcode.asm"
!source "fast1541iec-drivecode.asm"
```

Replace with:

```asm
!source "fast1541iec-drivecode.asm"
```

(`sjl-loader-highcode.asm` is already sourced via `sjl-loader.asm` from `burstcart.asm` before fast1541iec; do not double-source SJL here.)

- [ ] **Step 2: Fix include order in `burstcart.asm`**

Today `fast1541iec-loader.asm` is sourced **before** `sjl-loader.asm`. Move the SJL sources above fast1541iec so the shared entry is defined first:

```asm
!source "sjl-detect.asm"
!source "sjl-loader.asm"
!source "fast1541iec-detect.asm"
!source "fast1541iec-loader.asm"
```

(Keep surrounding sources otherwise unchanged; only reorder these four lines as a block relative to each other.)

ACME can resolve some forward `jmp` targets, but do not rely on that — require SJL before fast1541iec.

- [ ] **Step 3: Delete private highcode; fix Makefile**

```bash
rm src/fast1541iec-loader-highcode.asm
```

In `src/Makefile`, remove `fast1541iec-loader-highcode.asm` from the dependency list that currently includes it (keep `fast1541iec-loader.asm` and `fast1541iec-drivecode.asm`).

- [ ] **Step 4: Drivecode / detect comment pass**

`src/fast1541iec-drivecode.asm` header — ensure it says host receive is SJL, e.g.:

```asm
; Stock 1541 JD LOAD sender @ $0300 (≤256 B).
; Literal structure of docs/1541EJD.a65 J_FF2D/P_FF8D/A_FFA3:
; transform pointer/Y for the final sector, then one inline send loop until
; Y wraps. Host receives via SJL_jd_transfer (no private fast1541iec loop).
; Data buffer 1 @ $0400; host seeds first T/S in $20/$21 before M-E.
```

`src/fast1541iec-detect.asm` — keep short; no claim of a private host protocol.

- [ ] **Step 5: Run contract test — expect PASS**

Run: `python3 tests/check_fast1541iec_error_paths.py`

Expected: `fast1541iec JD review checks OK`

- [ ] **Step 6: Rebuild**

Run: `make -C src bin/parobek-via.bin`

Expected: success; `* > $C000` guard still passes.

- [ ] **Step 7: Commit**

```bash
git add src/fast1541iec-loader.asm src/fast1541iec-drivecode.asm src/Makefile \
  src/fast1541iec-detect.asm src/burstcart.asm
git add -u src/fast1541iec-loader-highcode.asm
git commit -m "$(cat <<'EOF'
Reuse SJL_jd_transfer for fast1541iec host receive.

EOF
)"
```

---

### Task 4: Smoke verify stock+stock1541

**Files:**
- Test only (no code unless smoke fails — then fix under this task and amend only if commit rules allow; otherwise new fix commit)

**Interfaces:**
- Consumes: built `parobek` bin + `tests/vice/run-matrix.sh stock+stock1541`

- [ ] **Step 1: Launch matrix cell**

Run: `./tests/vice/run-matrix.sh stock+stock1541`

Expected: VICE starts with sound disabled if `+sound` already in script; Parobek menu available.

- [ ] **Step 2: Manual smoke checklist**

In the emulator:

1. Menu option `3` (or whatever installs the LOAD hook per current README).
2. `LOAD"HELLO",8`
3. Confirm on-screen path text includes `1541 SERIAL`.
4. Confirm cursor stays after `LOADING` (does **not** jump to home).
5. Confirm program/data integrity (HELLO at `$1001` matches expected payload / no garbage).

- [ ] **Step 3: Optional SJL regression glance**

Run: `./tests/vice/run-matrix.sh stock+jd1541` — after install, `LOAD"HELLO",8` should still show `SJL264` and succeed.

- [ ] **Step 4: Commit only if Step 2–3 required code fixes**

If smoke passed with no further edits, skip commit. If fixes were needed:

```bash
git add -u
git commit -m "$(cat <<'EOF'
Fix fast1541iec/SJL handoff after smoke test.

EOF
)"
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Shared `SJL_jd_transfer` after M-E | 2, 3 |
| No TALK/$61 on fast1541iec | 2 (`SJL_jd_transfer` body), 3 |
| No untalk/close from `SJL_jd_transfer` | 2 |
| Delete `fast1541iec-loader-highcode.asm` | 3 |
| Comment/status-quo cleanup | 3 |
| Contract test update | 1, 3 |
| Smoke: SERIAL + cursor + integrity | 4 |
| Drive protocol unchanged | 2–3 (no drive logic edits) |

No TBD placeholders. Label names consistent: `SJL_jd_transfer`, `sjl_jd_receive_loop`.
