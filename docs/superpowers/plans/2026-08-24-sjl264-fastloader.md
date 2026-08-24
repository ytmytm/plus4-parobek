# SJL264 Fastloader Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a ROM-safe SJL264-style Jiffy load path to Parobek for SD2IEC / drive-JiffyDOS, with host-JiffyDOS and datasette gates, plus VICE smoke scripts.

**Architecture:** After burst fails, read the drive error channel once into `$0200`, then choose SD2IEC→SJL, else 1541 parallel, else drive-JIFFYDOS→SJL, else ROM. Host kernal `JIFFYDOS` skips SJL and skips DOS-wedge install. Timing-critical receive runs from ROM without self-mod (SpeedDOS-style).

**Tech Stack:** ACME 6502, GNU make, VICE `xplus4`, existing Parobek LOAD/`load_status` contract.

## Global Constraints

- No self-modifying code in the shipped loader path (ROM-safe).
- SJL loads **one file only** — no directory, commands, F1 toggle, or `$0801` overlay.
- `load_status`: `$80` = not handled → ROM; `$00` = OK; other = error (do not double-load via ROM).
- IEC order: burst → SD2IEC+SJL → parallel → drive-JD+SJL → ROM.
- Host JD: never SJL; no Parobek DOS wedge; LOAD hook still installed for burst/TCBM/parallel.
- Datasette blocks **only** SJL; re-check every SJL attempt; continue to parallel then ROM.
- One error-channel status read per IEC attempt after burst; no `UI` command.
- Stay under `$C000` for executable Parobek code (existing `!error` guard).
- Branch: `feature-sjl264`. Spec: `docs/superpowers/specs/2026-08-24-sjl264-fastloader-design.md`.

## File map

| File | Responsibility |
|------|----------------|
| `third_party/sjl264/` | Unpacked upstream reference (read-only) |
| `src/sjl-detect.asm` | `iec_read_status`, `scan_status_for`, `datasette_blocks_sjl` |
| `src/sjl-loader.asm` | `SJL_load` wrapper, messages, `shared_rom_check`, jump to highcode |
| `src/sjl-loader-highcode.asm` | Jiffy receive loop (no self-mod) |
| `src/host-jd-detect.asm` | Scan host kernal for `JIFFYDOS`; set `host_jd` flag |
| `src/burstcart.asm` | `iec_load` dispatcher; `install_fastload` wedge gate; `host_jd` in lowmem |
| `src/Makefile` | Add new sources to `SRCS` |
| `tests/vice/roms.env.example` | Paths to stock/JD host+drive ROMs |
| `tests/vice/run-matrix.sh` | Smoke matrix driver |
| `README.md` | Document new IEC path |

---

### Task 1: Reference tree + lowmem `host_jd` + host scan + wedge skip

**Files:**
- Create: `third_party/sjl264/` (unpack from `SJL264-0.3-180107.tar.bz2`)
- Create: `src/host-jd-detect.asm`
- Modify: `src/burstcart.asm` (`lowmem_trampoline`, `install_fastload`)
- Modify: `src/Makefile`
- Test: `cd src && make via` (must assemble)

**Interfaces:**
- Produces: `host_jd` byte at lowmem (0 = stock host, ≠0 = host JiffyDOS); `detect_host_jiffydos` (sets `host_jd`, clobbers A/X/Y/$d0–$d2)
- Consumes: kernal mapped at `$E000–$FFFF` when called from ROM bank context after install (scan string `JIFFYDOS`)

- [ ] **Step 1: Unpack reference sources**

```bash
cd /home/maciej/Maciejdev/plus4/burstcart/parobek/plus4-burstcart
mkdir -p third_party
tar xjf SJL264-0.3-180107.tar.bz2 -C third_party
mv third_party/SJL264-0.3-180107 third_party/sjl264
printf '%s\n' 'Upstream SJL264 Light 0.3 (BSZ) — reference only, not assembled into Parobek.' > third_party/sjl264/README.md
```

Expected: `third_party/sjl264/sjl264.asm` exists.

- [ ] **Step 2: Add `host_jd` to lowmem trampoline**

In `src/burstcart.asm` inside `!pseudopc lowmem_code`, after `load_iftype`:

```asm
host_jd:	!byte 0		; <>0 = host kernal is JiffyDOS (set at install)
```

- [ ] **Step 3: Create `src/host-jd-detect.asm`**

```asm
; Scan host kernal for "JIFFYDOS". Sets host_jd (lowmem).
; Call only after lowmem trampoline is copied.
; Uses $d0/$d1 as scan pointer; does not touch the drive.

detect_host_jiffydos:
	!zone HostJD_Detect {
		lda #0
		sta host_jd
		lda #<$e000
		sta $d0
		lda #>$e000
		sta $d1
.page:
		ldy #0
.pos:
		ldx #0
-		lda .sig,x
		beq .found
		cmp ($d0),y
		bne .next
		iny
		inx
		bne -
.found:
		lda #1
		sta host_jd
		rts
.next:
		iny
		bne .pos
		inc $d1
		lda $d1
		bne .page		; wrap $E000-$FFFF then $0000 stop
		rts
.sig:
		!text "JIFFYDOS", 0
	}
```

Note: Plus/4 JiffyDOS 6.01 places the banner near `$EB7D`. Full `$E000–$FFFF` scan is fine at install (once). If page wrap to `$00` is undesirable, stop when `$d1` wraps past `$FF` after `$E000` start — implement stop as:

```asm
		inc $d1
		lda $d1
		bne .page
		rts			; scanned $E000-$FFFF
```

(When `$d1` goes `$FF`→`$00`, `bne .page` fails and we return.)

- [ ] **Step 4: Call detect and gate wedge in `install_fastload`**

After trampoline copy and LOAD vector install, before wedge install:

```asm
	jsr detect_host_jiffydos
	lda host_jd
	beq .install_wedge
	lda #<host_jd_txt
	ldy #>host_jd_txt
	jsr print_msg_always
	jmp .after_wedge
.install_wedge:
	; existing ICRNCH install block unchanged
.after_wedge:
	+InitBurst
```

Add near other messages:

```asm
host_jd_txt:
	!text "HOST JIFFYDOS, NO WEDGE",13,0
```

`!source "host-jd-detect.asm"` near other sources (after lowmem is defined — place source after `lowmem_trampoline` / before or after `iec_load` so `host_jd` label exists; ACME allows forward refs for `jsr` but `sta host_jd` needs the symbol — keep detect file sourced after the `!pseudopc` block that defines `host_jd`).

- [ ] **Step 5: Update Makefile and build**

```makefile
SRCS = burstcart.asm burst-cpld.asm burst-via.asm t2s-detect.asm host-jd-detect.asm sjl-detect.asm sjl-loader.asm
```

(For this task, create stub `sjl-detect.asm` / `sjl-loader.asm` that assemble empty if needed, or only add `host-jd-detect.asm` until Task 2.)

```bash
cd src && make clean via
```

Expected: `bin/parobek-via.bin` built, no ACME errors.

- [ ] **Step 6: Commit**

```bash
git add third_party/sjl264 src/host-jd-detect.asm src/burstcart.asm src/Makefile
git commit -m "Add host JiffyDOS detect and skip Parobek DOS wedge when present."
```

---

### Task 2: Status read + substring scan + `iec_load` dispatcher (SJL stub)

**Files:**
- Create: `src/sjl-detect.asm`
- Create: `src/sjl-loader.asm` (stub `SJL_load` that prints and sets `$80` or calls real code later)
- Modify: `src/burstcart.asm` (`iec_load`)
- Test: `cd src && make via`

**Interfaces:**
- Produces:
  - `iec_read_status` — fills `status_buffer` (`$0200`), clears unused bytes; C=0 ok, C=1 device missing
  - `scan_status_for` — input: A/Y = pointer to zero-terminated needle in ROM; C=0 found, C=1 not found
  - `status_has_sd2iec` / `status_has_jiffydos` — thin wrappers
  - `SJL_load` — for now: print `SJL264 STUB`, `lda #$80` / `sta load_status` / `rts` (or jump to ROM path)
- Consumes: `host_jd`, `par1541_detect`, `SpeedDOS_load`, `load_rom`, `print_msg`

- [ ] **Step 1: Implement `src/sjl-detect.asm`**

```asm
status_buffer = $0200

; Talk error channel, read up to 40 bytes into status_buffer. No UI.
; C=0 read attempted, C=1 device not present.
iec_read_status:
	!zone IEC_ReadStatus {
		lda #0
		sta RAM_STATUS
		ldx #40
-		dex
		sta status_buffer,x
		bne -
		jsr ROM_CLRCHN
		lda RAM_FA
		jsr ROM_LISTEN
		jsr ROM_READST
		and #%10000000
		beq +
		jsr ROM_UNLISTEN
		sec
		rts
+		lda #$6F
		jsr ROM_SECOND
		jsr ROM_UNLISTEN		; open error channel without command
		lda RAM_FA
		jsr ROM_TALK
		lda #$6F
		jsr ROM_TKSA
		ldx #0
-		jsr ROM_ACPTR
		sta status_buffer,x
		jsr ROM_READST
		and #%01000000
		bne +
		inx
		cpx #40
		bne -
+		jsr ROM_CLRCHN
		jsr ROM_UNTLK
		clc
		rts
	}

; A/Y = needle address (0-terminated). Scan status_buffer[0..39].
; C=0 found, C=1 not found. Uses $d0-$d2.
scan_status_for:
	!zone ScanStatus {
		sta $d0
		sty $d1
		lda #0
		sta $d2
.outer:
		ldy $d2
		ldx #0
-		lda ($d0),x
		beq .found
		cmp status_buffer,y
		bne .next
		iny
		inx
		bne -
.found:		clc
		rts
.next:		inc $d2
		lda $d2
		cmp #40
		bcc .outer
		sec
		rts
	}

status_has_sd2iec:
	lda #<.sig_sd2iec
	ldy #>.sig_sd2iec
	jmp scan_status_for
.sig_sd2iec:	!text "SD2IEC", 0

status_has_jiffydos:
	lda #<.sig_jd
	ldy #>.sig_jd
	jmp scan_status_for
.sig_jd:	!text "JIFFYDOS", 0
```

If LISTEN+SECOND with no payload is wrong for some drives, fall back to TALK `$6F` only (no prior LISTEN) — verify on VICE in Task 5; adjust in this file only.

- [ ] **Step 2: Stub `SJL_load` in `src/sjl-loader.asm`**

```asm
SJL_load:
	!zone SJL_Loader {
		lda #<sjl_stub_txt
		ldy #>sjl_stub_txt
		jsr print_msg
		lda #$80
		sta load_status
		rts
sjl_stub_txt:
		!text "SJL264 STUB",13,0
	}
```

- [ ] **Step 3: Replace `iec_load` body** in `burstcart.asm`

Replace the current sequence (burst → always parallel) with:

```asm
iec_load:
	lda #<iec_load_txt
	ldy #>iec_load_txt
	jsr print_msg

	lda #$80
	sta load_status
	jsr iecburst_load
	bit load_status
	bmi +
	rts
+
	jsr iec_read_status
	bcs .try_parallel		; no device → parallel attempt then ROM

	; 3) SD2IEC → SJL (unless host_jd)
	lda host_jd
	bne .try_parallel
	jsr status_has_sd2iec
	bcs .try_parallel
	jsr datasette_blocks_sjl	; Task 3: for now always clc (not blocking)
	bcs .try_parallel
	jmp SJL_load

.try_parallel:
	lda #<iec_load_txt3
	ldy #>iec_load_txt3
	jsr print_msg
	jsr par1541_detect
	sta $d0
	bit $d0
	bpl .try_drive_jd
	and #%01111111
	beq .try_drive_jd
	lda #<iec_load_txt4
	ldy #>iec_load_txt4
	jsr print_msg
	lda $d0
	jmp SpeedDOS_load

.try_drive_jd:
	lda host_jd
	bne load_rom
	jsr status_has_jiffydos
	bcs load_rom
	jsr datasette_blocks_sjl
	bcs load_rom
	jmp SJL_load
```

Until Task 3, add a temporary:

```asm
datasette_blocks_sjl:
	clc			; never blocks (placeholder)
	rts
```

in `sjl-detect.asm`.

- [ ] **Step 4: `!source` new files** from `burstcart.asm` after parallel sources; extend `Makefile` `SRCS`.

- [ ] **Step 5: Build**

```bash
cd src && make via cpld
```

Expected: both bins build.

- [ ] **Step 6: Commit**

```bash
git add src/sjl-detect.asm src/sjl-loader.asm src/burstcart.asm src/Makefile
git commit -m "Wire IEC status scan and load priority; stub SJL path."
```

---

### Task 3: Datasette gate

**Files:**
- Modify: `src/sjl-detect.asm` (`datasette_blocks_sjl`)
- Modify: `src/sjl-loader.asm` or messages in `burstcart.asm` for `DATASETTE, ROM LOAD` (print when blocking before continuing)
- Test: `make via`; VICE optional until Task 5

**Interfaces:**
- Produces: `datasette_blocks_sjl` — C=1 blocks SJL (`$01` bit 3 clear = motor-on / conflict per upstream SJL264), C=0 OK for SJL
- Consumes: CPU port `$01`

Upstream check (install + load):

```asm
lda $01
and #%00001000		; Cass. Motor on?
beq .blocked		; bit clear → conflict
```

- [ ] **Step 1: Replace placeholder**

```asm
; C=1 → do not run SJL (datasette conflict). C=0 → SJL allowed.
datasette_blocks_sjl:
	!zone DatasetteGate {
		lda $01
		and #%00001000
		beq .block
		clc
		rts
.block:
		lda #<datasette_txt
		ldy #>datasette_txt
		jsr print_msg
		sec
		rts
datasette_txt:
		!text "DATASETTE, SKIP SJL",13,0
	}
```

- [ ] **Step 2: Build and commit**

```bash
cd src && make via
git add src/sjl-detect.asm
git commit -m "Gate SJL on datasette CPU-port conflict each load."
```

---

### Task 4: Port SJL264 receive path (ROM-safe, load only)

**Files:**
- Modify: `src/sjl-loader.asm` (real wrapper)
- Create/replace: `src/sjl-loader-highcode.asm`
- Reference: `third_party/sjl264/sjl264.asm` (loader_routine + sjl_talk/sectalk/untalk/busin + transfer loop)
- Test: `make via`; then VICE Task 5 row “Stock + JD 1541”

**Interfaces:**
- Produces: working `SJL_load` setting `load_status` to `$00` / error / `$80`
- Consumes: `shared_rom_check`, `RAM_SA` / `$9D`/`$9E`, TED backups, KERNAL IEC helpers listed in `_system.ain`

- [ ] **Step 1: Map upstream to Parobek**

Port only from `loader_routine` through end of `sjl_busin` / transfer loop. Drop: BASIC install, F1, `$0801` copy, checksum, LOADING eraser, self-mod border opcode, `sjl_returnrout` stack rewrite.

Use Parobek symbols (`RAM_FA`, `RAM_SA`, `RAM_STATUS`, `ROM_*`, `TED_BORDER`, `RAM_TED_BORDER_BACKUP`). Prefer calling existing KERNAL serial helpers the way upstream does (`$e2b8` etc.) via named constants in the loader file.

- [ ] **Step 2: ROM-safe store policy**

Replace self-mod `STA (z_eal),y` ↔ `LDA` with:

```asm
		lda z_eah
		beq .skip_store		; wrapped to $0000
		cmp #$fd
		bcs .skip_store
		sta (z_eal),y		; actually: lda data / sta (z_eal),y
.skip_store:
```

Keep border flash using `RAM_TED_BORDER_BACKUP` restore on all exits (like `burst-via.asm`).

- [ ] **Step 3: Wrapper outline for `SJL_load`**

```asm
SJL_load:
	lda #<sjl_txt
	ldy #>sjl_txt
	jsr print_msg
	jsr shared_rom_check
	bcc +
	lda #4
	sta load_status
	rts
+
	; load addr in $9D/$9E; if <$0A00 → lda #$80 / sta load_status / rts (ROM)
	; screen off / single clock optional (match upstream if VICE needs it)
	; set SA path for Jiffy: secondary $61 for data after open $60
	jmp sjl_highcode		; label in sjl-loader-highcode.asm
sjl_txt:
	!text "SJL264",13,0
```

Jiffy protocol: after open on channel 0 (`$60`), bump to `$61` for JD fast load (see upstream `.ldaddrokay`). Reuse that sequence; do not invent a new handshake.

- [ ] **Step 4: Prefer execute-from-ROM**

Assemble highcode in-place in the ROM image (like `SpeedDOS_loader_VIA`). If VICE timing fails, add a fixed copy to `$0200+$40` (avoid clobbering live `status_buffer` during transfer — use `$0640+offset` free space or `$0c00` scratch); still no self-mod.

- [ ] **Step 5: Build**

```bash
cd src && make via cpld
```

Expected: size still `< $C000` executable (`!error` silent).

- [ ] **Step 6: Commit**

```bash
git add src/sjl-loader.asm src/sjl-loader-highcode.asm src/burstcart.asm
git commit -m "Port SJL264 load path as ROM-safe Parobek IEC backend."
```

---

### Task 5: VICE test matrix scripts

**Files:**
- Create: `tests/vice/roms.env.example`
- Create: `tests/vice/roms.env` (gitignored local copy)
- Create: `tests/vice/run-matrix.sh`
- Create: `tests/vice/README.md`
- Modify: `.gitignore` — add `tests/vice/roms.env`
- Test: run scripts with ROMs present

**Interfaces:**
- Produces: documented `xplus4` invocations for the four matrix rows
- Consumes: `src/bin/parobek-via.bin`, env paths to kernals and 1541 ROMs

- [ ] **Step 1: Example env**

`tests/vice/roms.env.example`:

```bash
# Copy to roms.env and edit paths.
HOST_KERNAL_STOCK=/home/maciej/Maciejdev/plus4/c16-internalfunctionrom/kicad-c16multirom/rom/sources/zimmers/kernal.318004-05.bin
HOST_BASIC_STOCK=/home/maciej/Maciejdev/plus4/c16-internalfunctionrom/kicad-c16multirom/rom/sources/zimmers/basic.318006-01.bin
HOST_KERNAL_JD=/home/maciej/Maciejdev/plus4/c16-internalfunctionrom/kicad-c16multirom/rom/sources/jiffydos/JiffyDOS_Plus4_6.01_PAL.bin
DRIVE_1541_STOCK=/home/maciej/Maciejdev/plus4/burstcart/jiffydos/dos1541ii-251968-03.bin
DRIVE_1541_JD=/home/maciej/Maciejdev/plus4/burstcart/jiffydos/JiffyDOS_1541-II.bin
PAROBEK_BIN="$(git rev-parse --show-toplevel)/src/bin/parobek-via.bin"
```

- [ ] **Step 2: Matrix script**

`tests/vice/run-matrix.sh` — `set -euo pipefail`, source `roms.env`, `make -C src via`, then for each case print the command and optionally launch:

| Case | Flags of interest | Expect (manual / log) |
|------|-------------------|------------------------|
| stock+jd1541 | `-kernal $HOST_KERNAL_STOCK -basic $HOST_BASIC_STOCK -dos1541 $DRIVE_1541_JD -c1lo $PAROBEK_BIN` | After menu “3”, load shows `SJL264` |
| stock+stock1541 | stock dos1541 | No `SJL264`; parallel or `ROM LOAD` |
| stock+jd+tape | add `-1 /path/to/empty.tap` or VICE datasette attach | `DATASETTE, SKIP SJL` then ROM/parallel |
| hostjd+jd1541 | `-kernal $HOST_KERNAL_JD` | `HOST JIFFYDOS, NO WEDGE`; no `SJL264` |

Use:

```bash
xplus4 -default -kernal "$HOST_KERNAL_STOCK" -basic "$HOST_BASIC_STOCK" \
  -dos1541 "$DRIVE_1541_JD" -c1lo "$PAROBEK_BIN" "$@"
```

Script modes: `./run-matrix.sh list` (print commands) and `./run-matrix.sh <case>` (exec one). First experiment: no CI assert required; README describes pass criteria.

- [ ] **Step 3: Ignore local env; commit**

```bash
echo 'tests/vice/roms.env' >> .gitignore
git add tests/vice .gitignore
git commit -m "Add VICE smoke matrix scripts for SJL264 paths."
```

---

### Task 6: README + design status

**Files:**
- Modify: `README.md` (new subsection under IEC / 1541)
- Modify: `docs/superpowers/specs/2026-08-24-sjl264-fastloader-design.md` status → implemented (or leave “experiment”)

- [ ] **Step 1: Document**

Under features, add:

```markdown
#### IEC JiffyDOS / SD2IEC (SJL264)

When the drive status contains `SD2IEC` or `JIFFYDOS`, Parobek uses an SJL264-derived serial fastloader (after burst, before or after parallel per priority in the design spec). Host JiffyDOS kernals skip this path and do not install the Parobek DOS wedge. A connected datasette blocks only SJL.
```

- [ ] **Step 2: Commit**

```bash
git add README.md docs/superpowers/specs/2026-08-24-sjl264-fastloader-design.md
git commit -m "Document SJL264 IEC fastloader in README."
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| ROM-safe SJL port, load only | 4 |
| Status once + SD2IEC / JIFFYDOS scan | 2 |
| IEC order burst → SD2IEC SJL → parallel → JD SJL → ROM | 2 |
| Host JD skip SJL + no wedge | 1, 2 |
| Datasette gate each SJL attempt | 3 |
| `load_status` contract | 2, 4 |
| VICE matrix | 5 |
| Reference upstream sources | 1 |
| README | 6 |

No TBD placeholders left in tasks. `datasette_blocks_sjl` / `SJL_load` / `host_jd` names are consistent across tasks.
