
; 1=CIA, 2=VIA, 3=CPLD  (override from Makefile: acme -Dburst=N)
!ifndef burst {
!set burst=2
}

!if burst=1 {
	!to "bin/parobek-cia.bin",plain
	ciabase		= $FD90
	!source "burst-cia.asm"
}
!if burst=2 {
	!to "bin/parobek-via.bin",plain
	viabase		= $FDA0
	!source "burst-via.asm"
}
!if burst=3 {
	!to "bin/parobek-cpld.bin",plain
	cpldbase	= $FD90
	!source "burst-cpld.asm"
}


;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; todo: burst: inline GetByte in GetAndStore to save some cycles
; todo: tcbm2sd is problematic - DLOAD"*" will always try to load the first file (even disk image) instead of booter
;       with embedded directory browser maybe that fastloader doesn't make sense

RAM_ZPVEC1	= $03	; (2) print_msg string pointer.
			; WARNING: this is scratch, not storage - print_msg
			; overwrites it (when RAM_MSGFLG bit 7 is set), so it must
			; not be used to carry state across a loader run.
			; Use load_sa / load_iftype in the lowmem trampoline instead.

RAM_STATUS  = $90	; status
RAM_VERFCK	= $93	; 0=load, 1=verify
RAM_MSGFLG  = $9A   ; $80=direct mode (print messages), $00=program mode (silent)
RAM_FNLEN	= $AB	; filename length
RAM_LA		= $AC	; logical address
RAM_SA		= $AD	; secondary address
RAM_FA		= $AE	; device number
RAM_FNADR	= $AF	; vector to filename
RAM_MEMUSS	= $B4	; load RAM base ($AE/AF on C64)
RAM_CURBNK	= $FB	; current ROM bank

; $D0-$E6 used by detect/load code
; directory browser uses $D4 for load&run flag, but it's copied to $8F
; MAKE SURE TO NOT USE $8F FOR ANYTHING ELSE

RAM_TED_BORDER_BACKUP = $E6	; backup of TED_BORDER
RAM_TED_FF06_BACKUP = $E7	; backup of TED_FF06
RAM_SA_BACKUP = $E8	; backup of RAM_SA
RAM_TED_FF13_BACKUP = $E9	; backup of TED $FF13 (single/double clock)


RAM_ICRNCH  = $0304 ; Indirect Crunch (Tokenization Routine) 
RAM_ILOAD	= $032E	; LOAD vector

LNGJMP		= $05F0	; Long jump address
FETARG		= $05F2	; Long jump accumulator
FETXRG		= $05F3	; Long jump x register
FETSRG		= $05F4	; Long jump status register 

RAM_RLUDES	= $07D9 ; read from (e07DF),y from RAM
a07DF		= $07DF ; zp address of vector for RLUDES

ROM_ILNGJMP	= $FCFA ; jumptable to LONGJMP ($FC89)
ROM_PAGING	= $FC7B ; KERNAL ROM paging table ($00,$05,$0a,$0f)
eE2B8		= $E2B8 ; clk hi (inverted)
eEDA9		= $EDA9 ; check if device 8/9 (RAM_FA) is parallel (TCBM), C=0 --> yes
eF160		= $F160	; print 'SEARCHING'
eF189		= $F189 ; print 'LOADING'
; ???
LEF3B           = $EF3B
LF211           = $F211

TED_FF06        = $FF06
TED_FF13        = $FF13		; bit1 = single clock (SJL bitbang needs 1 MHz)
TED_BACK        = $FF15
TED_COL1        = $FF16
TED_COL2        = $FF17
TED_COL3        = $FF18
TED_BORDER      = $FF19

ROM_SECOND      = $FF93
ROM_CIOUT       = $FFA8
ROM_UNLISTEN    = $FFAE
ROM_LISTEN      = $FFB1
ROM_TALK        = $FFB4
ROM_TKSA        = $FF96
ROM_UNTLK       = $FFAB
ROM_ACPTR       = $FFA5

ROM_CINT	= $FF81
ROM_IOINIT	= $FF84
ROM_RESTOR	= $FF8A
ROM_OPEN	= $FFC0
ROM_CLOSE	= $FFC3
ROM_CHKIN	= $FFC6
ROM_CHKOUT	= $FFC9
ROM_CLRCHN	= $FFCC
ROM_CHROUT	= $FFD2

ROM_READST	= $FFB7
ROM_SETLFS	= $FFBA
ROM_SETNAM	= $FFBD
ROM_CHRIN	= $FFCF
ROM_GETIN	= $FFE4

ROM_SELECT	= $FF3E
RAM_SELECT	= $FF3F

ROM_CBMSER_DEVNOTPRES	= $E1E9
ROM_CBMSER_TIMEOUT	= $E1EE
ROM_CBMSER_SSTATSEREND	= $E1F0
ROM_CBMSER_ATN_HIZ	= $E1FC
ROM_CBMSER_CLK_HIZ	= $E2B8
ROM_CBMSER_CLK_LO	= $E2BF
ROM_CBMSER_DAT_HIZ	= $E2C6
ROM_CBMSER_DAT_LO	= $E2CD
ROM_CBMSER_READLINES	= $E2D4
ROM_CBMSER_WAIT1MS	= $E2DC

ROM_IEC_OPEN_SETUP	= $F005
ROM_IEC_CLOSE_SETUP	= $F211
ROM_SET_STATUS_HELPER	= $F41E

CMD_CHANNEL = 239 ; command channel for burst command

ppibase = $fe00	; parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
piobase = $fd10	; parallel cable connected to PIO at piobase $FD10 (6529)
ciabase = $fd90	; burst/parallel cable connected to CIA at ciabase $FD90 (6526)
viabase = $fda0	; burst/parallel cable connected to VIA at viabase $FDA0 (6522)

TCBM_DEV9       = $FEC0
TCBM_DEV8       = $FEF0
; +0 port A
; +1 port B 1/0
; +2 port C 7/6
; +3 port A DDR

lowmem_code 	= $0640	; our bank number and trampoline into ROM (must be above basic key trampoline)

		*=$8000
; header
		jmp coldstart	; coldstart, install
		jmp warmstart	; warmstart, run from basic (F-key)
!by $09			; module-nr, $00=empty, $01=autostart
!by $43,$42,$4d		; module-nr., "CBM"

!source "startup.asm"

!source "dos-wedge.asm"

coldstart:
	jsr scan_keys_for_parobek
	bcc +
	rts				; parobek already installed (function key)
+
	jsr check_if_installed
	bcc +
	rts				; already installed, just return
+
	lda RAM_CURBNK
	and #$03		; enable kernal in top half so we don't care about IRQ
	tax			; (if we want top half, set $FFFE/F to FCB3 - Kernal paged IRQ; then need own eF160 etc.)
	sta RAM_CURBNK
	sta buf_ourbank
	sta $fdd0,x
	jsr ROM_RESTOR	; restore default vectors (in case some hooks were installed: e.g. TURBO PLUS), needed?

	lda RAM_FA		; device number
	bne +
	lda #8			; default to 8
	sta RAM_FA
+
	; install function key
	jsr key_install
	; show startup screen
	jsr startup_screen
	;; come back with result in A: 1=normal, 2=browser, 3=fastload
	cmp #1
	beq normal_reset
	cmp #2
	beq run_browser
	cmp #3
	beq install_fastload
	; anything else falls through to normal_reset
normal_reset:
	jmp print_welcome		; normal reset, back to BASIC

run_browser:
;	jsr install_fastload	; we could do it here, but then some games would not work (that use LOAD but also overwrite wedge)
                            ; for fastload from directory browser simply hit '3' for fastload and then f1-f3 for directory browser

warmstart:					; warmstart runs the BASIC code after SYS
	jmp dirbrowser_loadrun

install_fastload:
	; install trampoline
	ldx #2			; skip over buffers
-	lda lowmem_trampoline,x
	sta lowmem_code,x
	inx
	cpx #lowmem_trampoline_end-lowmem_trampoline
	bne -
	
	; install LOAD vector
	lda RAM_ILOAD
	cmp #<myloadlow
	beq +			; already installed
	sta loadrom+1
	lda RAM_ILOAD+1
	sta loadrom+2
	lda #<myloadlow
	sta RAM_ILOAD
	lda #>myloadlow
	sta RAM_ILOAD+1
+

	jsr detect_host_jiffydos
	lda host_jd
	beq .install_wedge
	lda #<host_jd_txt
	ldy #>host_jd_txt
	jsr print_msg_always
	jmp .after_wedge
.install_wedge:
	; install wedge
	lda RAM_ICRNCH
	cmp #<mywedgelow
	beq +			; already installed
	sta wedgerom+1
	lda RAM_ICRNCH+1
	sta wedgerom+2
	lda #<mywedgelow
	sta RAM_ICRNCH
	lda #>mywedgelow
	sta RAM_ICRNCH+1
+
.after_wedge:
	; init VIA/CIA/CPLD and CIA TOD clock too
	+InitBurst

print_welcome:
	; welcome message
	lda #<startup_txt
	ldy #>startup_txt
	jsr print_msg_always
	lda RAM_CURBNK
	ora #'0'
	jsr ROM_CHROUT
	lda #13
	jsr ROM_CHROUT
	rts

	
	; scan function key definitions for " PAROBEK"
	; C=1 if found (another parobek instance already did key_install)
scan_keys_for_parobek:
	lda #<$0567
	sta $d5
	lda #>$0567
	sta $d6
	ldx #0				; key number 0-7

.key_loop:
	cpx #8
	bcs .not_found
	lda $055f,x
	beq .next_key

	stx $d7				; save key number
	sta $d3				; key length
	ldy #0

.pos_loop:
	tya
	clc
	adc #parobek_sig_len
	cmp $d3
	bcs .advance_ptr

	sty $d4
	ldx #0
.match:
	ldy $d4
	lda ($d5),y
	cmp parobek_sig,x
	bne .pos_next
	iny
	sty $d4
	inx
	cpx #parobek_sig_len
	bne .match
	sec
	rts

.pos_next:
	ldy $d4
	iny
	jmp .pos_loop

.advance_ptr:
	ldx $d7
	lda $055f,x
	clc
	adc $d5
	sta $d5
	bcc +
	inc $d6
+
	ldx $d7
.next_key:
	inx
	jmp .key_loop

.not_found:
	clc
	rts

parobek_sig:
	!text " PAROBEK"
parobek_sig_len = * - parobek_sig

	
	; check if we're already installed (C=1 = already installed, C=0 = not installed)
check_if_installed:
	lda RAM_ILOAD
	cmp #<myloadlow
	bne +			; not installed
	lda RAM_ILOAD+1
	cmp #>myloadlow
	bne +			; not installed
	sec
	rts
+	clc
	rts


lowmem_trampoline:
	!pseudopc lowmem_code {
buf_ourbank:	!byte 0		; our bank number: internal/external1/external2
buf_sr:         !byte 0		; status register
; load_status contract (see iec_load / myloadlow):
;   the caller presets $80 before calling a fastloader; the loader MUST
;   overwrite it to report what happened.
;     $80 (bit 7 set) = not handled, fall back to the ROM load routine
;     $00             = loaded OK, return with C=0
;     other non-zero  = error code, return with C=1
load_status:	!byte 0
load_sa:	!byte 0		; secondary address saved across a fastloader run
load_iftype:	!byte 0		; parallel interface type (PPI/PIO/CIA/VIA bitmask)
				;  from the detect code, saved across a loader run
				; both of these used to live in RAM_ZPVEC1, which is
				;  NOT safe: print_msg uses $03/$04 as its own string
				;  pointer, so any message printed between the save
				;  and the use wiped them out
host_jd:	!byte 0		; <>0 = host kernal is JiffyDOS (set at install)
iec_drive_flags: !byte 0	; sticky across loads (cleared only when trampoline
				;  is (re)installed). OR'd from error-channel scans:
				;  %xxxxxxx1 = saw "SD2IEC"
				;  %xxxxxx1x = saw "JIFFYDOS"
				; After a successful load the channel is often
				;  "00, OK" without those strings — do not clear.

myloadlow:
	sta RAM_VERFCK		; remember A
	lda RAM_VERFCK		; just want to test if it's 0 (load) or 1 (verify)
	bne loadrom			; verify, continue in original (Kernal) code
	sta FETARG
	php
	pla
	sta buf_sr
	stx FETXRG
	lda #%00000100		; status reg: C=0, I=1
	sta FETSRG
	lda #<myload
	sta LNGJMP
	lda #>myload
	sta LNGJMP+1
	lda RAM_CURBNK		; caller bank (current)
	ldx buf_ourbank		; target bank (our ROM)
	jsr ROM_ILNGJMP
	lda load_status		; did we load or not? (0=OK, C=0, $80=to ROM, else C=1)
	bmi myloadrom		; no, continue in original (Kernal) code
	ldx FETXRG			; restore state and return
	lda buf_sr
	pha
	plp
	clc
	lda load_status
	beq +
	sec					; error
+	rts

myloadrom:
	lda buf_sr			; restore status register
	pha
	lda RAM_VERFCK		; stored A
	plp
loadrom:
	jmp $F04C			; -> F04C

mywedgelow:
	lda #<doswedge_parse
	sta LNGJMP
	lda #>doswedge_parse
	sta LNGJMP+1
	lda RAM_CURBNK		; caller bank (current)
	ldx buf_ourbank		; target bank (our ROM)
	jsr ROM_ILNGJMP
	lda FETARG
	bmi wedge_run_rom
	bne wedgerom
	rts
wedge_run_rom:
	jmp (cmd_vec)		; execute ROM command in BASIC bank
wedgerom:
	jmp $8956

!if * > $06EB { !error "TRAMPOLINE CODE ABOVE $06EB *=", * }

	} ; pseudopc

lowmem_trampoline_end:

!source "host-jd-detect.asm"

; OUT:
; load_status = 0 - loaded, then:
; A=error code (if C=1) or C=0
; X/Y last byte loaded
;
myload:
	lda #0
	sta load_status
	sta RAM_STATUS
	stx RAM_MEMUSS		; load addr (actually X/Y is already stored here before ILOAD vector is called)
	sty RAM_MEMUSS+1

	lda RAM_FA			;FA      Current device number
	cmp #4
	bcc load_rom		;less than 4 - tape

	lda #RAM_FNADR		;filename at ($AF/$B0)
	sta a07DF
	ldy #0
	jsr RAM_RLUDES		;RLUDES  Indirect routine downloaded
	cmp #'$'			;if '$' then ROM load
	beq load_rom

	jsr eEDA9			;check if this is 8/9 TCBM device
	bcs +				;no, it's IEC, try using burst
	jmp tcbm_load		;yes, fastloader for 1551/tcbm2sd
+	jmp iec_load	    ;no, it's IEC, try using burst/parallel

load_rom:
	lda #<load_rom_txt
	ldy #>load_rom_txt
	jsr print_msg_always
	lda #$80
	sta load_status		; pass back to ROM code
	rts

iec_load:
	lda #<iec_load_txt
	ldy #>iec_load_txt
	jsr print_msg_always

	lda #$80
	sta load_status
	jsr iecburst_load
	bit load_status
	bmi +
	rts

+	; Refresh sticky IEC class from status when possible. Do NOT clear
	;  iec_drive_flags: after a load the channel is usually "00, OK" without
	;  JIFFYDOS/SD2IEC, and parallel detect also clobbers $0200.
	jsr iec_read_status
	bcs .try_parallel		; no device -> parallel attempt then ROM

	jsr status_has_sd2iec
	bcs +
	lda iec_drive_flags
	ora #%00000001
	sta iec_drive_flags
+	jsr status_has_jiffydos
	bcs +
	lda iec_drive_flags
	ora #%00000010
	sta iec_drive_flags
+
	; SD2IEC -> SJL (unless host_jd)
	lda host_jd
	bne .try_parallel
	lda iec_drive_flags
	and #%00000001
	beq .try_parallel
	jsr datasette_blocks_sjl	; C=1 datasette conflict → skip SJL
	bcs .try_parallel
	jmp SJL_load

.try_parallel:
	lda #<iec_load_txt3
	ldy #>iec_load_txt3
	jsr print_msg_always
	jsr par1541_detect
	sta $d0
	bit $d0
	bpl .try_drive_jd
	and #%01111111
	beq .try_drive_jd
	lda #<iec_load_txt4
	ldy #>iec_load_txt4
	jsr print_msg_always
	lda $d0
	jmp SpeedDOS_load

.try_drive_jd:
	lda host_jd
	bne .to_rom
	lda iec_drive_flags
	and #%00000010
	beq .to_rom
	jsr datasette_blocks_sjl
	bcs .to_rom
	jmp SJL_load
.to_rom:
	jmp load_rom

load_rom_txt:
	!text "ROM LOAD",13,0

iec_load_txt:
	!text "IEC DEVICE, ",0		; no CR - the burst loader appends the type
					;  (iec_type_txt) on the same line, the way
					;  tcbm_device_txt is followed by TCBM2SD /
					;  1551 HYPALOAD / 1551 RAMBOARD

iec_load_txt3:
	!text "1541/PARALLEL TEST",13,0

iec_load_txt4:
	!text "1541/PARALLEL TEST PASSED",13,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

iecburst_load:
	+LoadBurst

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!source "par1541-detect.asm"
!source "par1541-loader.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!source "speeddos-loader.asm"

!source "sjl-detect.asm"
!source "sjl-loader.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tcbm_load:
	lda #<tcbm_device_txt
	ldy #>tcbm_device_txt
	jsr print_msg

	jsr t2sd_detect
	bcc +				; not tcbm2sd, must be 1551 - pass to hypaload
	jmp drive1551_load

	; TCBM2SD fastloader here
+	lda #<tcbm2sd_fastload_txt
	ldy #>tcbm2sd_fastload_txt
	jsr print_msg

	lda RAM_FA
	cmp #9
	beq +
	jmp t2sd_fastload_8
+	jmp t2sd_fastload_9

!source "t2s-detect.asm"

!set tcbmbase = TCBM_DEV8
t2sd_fastload_8:
!source "t2s-loader.asm"

!set tcbmbase = TCBM_DEV9
t2sd_fastload_9:
!source "t2s-loader.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

drive1551_load:
	jsr pi1551_detect	; not tcbm2sd, we can check reset string for PI1551
	bcs +				; not pi1551, must be a 1551 - pass to hypaload
	jmp load_rom		; we don't have a fastloader for PI1551 yet, so fall back on ROM

+
	jsr ram1551_detect	; stock 1551 or 1551 with RAMBOard?
	pha
	bne hyparam_load	; we have a RAMBoard installed

	lda #<tcbm_1551_txt
	ldy #>tcbm_1551_txt
	jsr print_msg
	pla
	jmp HypaRAM_load	; both drives #8/#9, with or without RAMBOard served by the same code

hyparam_load:
	lda #<tcbm_1551_ram_txt
	ldy #>tcbm_1551_ram_txt
	jsr print_msg
	pla
	jmp HypaRAM_load	; both drives #8/#9, with or without RAMBOard served by the same code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!source "pi1551-detect.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; hyparam loader for 1551 with RAMBoard installed (or not)

!source "ram1551-detect.asm"

!source "ram1551-hyparam-loader.asm"

; drivecode for 1551 without RAMBoard

!source "hypa1551-drivecode.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tcbm_device_txt:
	!text "TCBM DEVICE, ",0
tcbm2sd_fastload_txt:
	!text "TCBM2SD",13,0
tcbm_1551_txt:
	!text "1551 HYPALOAD",13,0
tcbm_1551_ram_txt:
	!text "1551 RAMBOARD",13,0
tcbm2sd_load_error_txt:
	!text "TCBM2SD LOAD ERROR",13,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

startup_txt:
	!text " PAROBEK ON KEY F",0
host_jd_txt:
	!text "HOST JIFFYDOS, NO WEDGE",13,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_msg:
		bit RAM_MSGFLG
		bmi +
		rts
print_msg_always:
		sta RAM_ZPVEC1
		sty RAM_ZPVEC1+1
		ldy #0
-		lda (RAM_ZPVEC1),y
		beq +
		jsr ROM_CHROUT
		inc RAM_ZPVEC1
		bne -
		inc RAM_ZPVEC1+1
		bne -
		jmp -
+
		rts

;--------------------------------------------------

shared_rom_check:
	!zone shared_rom_check {
; copy of ROM code between F06B (load from serial) and F0A5 (where JSR FFE1 is called - test for STOP)
; will setup load address in $9D/$9E according to RAM_SA
        LDX   RAM_SA
        JSR   eF160                    ; print 'SEARCHING'
		LDA   RAM_SA
		STA   RAM_SA_BACKUP
        LDA   #$60
        STA   RAM_SA
        JSR   $F005                    ; ROM routine for load setup
        LDA   RAM_FA
        JSR   ROM_TALK                 ; ROM_TALK - TALK routine
        LDA   RAM_SA
        JSR   ROM_TKSA                 ; ROM_TKSA - TKSA routine
        JSR   ROM_ACPTR                ; ROM_ACPTR - ACPTR routine
        STA   $9D                      ; load address low byte
        LDA   RAM_STATUS
        LSR
        LSR
        BCS   .file_not_found
        JSR   ROM_ACPTR                ; ROM_ACPTR - ACPTR routine
        STA   $9E                      ; load address high byte
        TXA
        BNE   .use_file_addr
        LDA   RAM_MEMUSS               ; use caller's load address
        STA   $9D
        LDA   RAM_MEMUSS+1
        STA   $9E
.use_file_addr:
        JSR   eF189                    ; print 'LOADING'
        LDA   #$FD
        AND   RAM_STATUS
        STA   RAM_STATUS
		LDA   RAM_SA_BACKUP
		STA   RAM_SA
        clc                            ; file found, continue
        rts

.file_not_found:
		LDA   RAM_SA_BACKUP
		STA   RAM_SA
        sec                            ; file not found, fall back to ROM
        rts
	}

;--------------------------------------------------

; delay to let drive interpret command
delay:
		ldx     #$03
        ldy     #$00
-       nop
        iny
        bne     -
        dex
        bpl     -
        rts

;--------------------------------------------------

; anything above $C000 comes from KERNAL (see coldstart memory config)
; so we must fit executable code within 16k, below $C000
!if * > $C000 { !error "EXECUTABLE CODE ABOVE $C000 *=", * }

;!fill ($C000-*), $ff
		;* = $C000
		; TCBM2SD directory browser (2024-11-30)
dirbrowser:
!bin "db12b.prg",,2
dirbrowserend:

!fill ($10000-*), $ff

