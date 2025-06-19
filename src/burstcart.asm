
; 1=CIA, 2=VIA, 3=CPLD
!set burst=2

!if burst=1 {
	!to "bin/burstcart-cia.bin",plain
	ciabase		= $FD90
	!source "burst-cia.asm"
}
!if burst=2 {
	!to "bin/burstcart-via.bin",plain
	viabase		= $FDA0
	!source "burst-via.asm"
}
!if burst=3 {
	!to "bin/burstcart-cpld.bin",plain
	cpldbase	= $FD90
	!source "burst-cpld.asm"
}


;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; BUG: status is saved to ErrNo, but that's in ROM now(!)
; BUG: ?DS$ after load error (file not found) drops to MONITOR (BRK) (only hypaload?)

; todo: burst: inline GetByte in GetAndStore to save some cycles
; todo: tcbm2sd fastloader fixed to device 8
; todo: hypaload fastloader fixed to device 8
; todo: both tcbm2sd and hypaload fastloader should be duplicated for device 9 (space is not a problem in ROM)
; todo: tcbm2sd is problematic - DLOAD"*" will always try to load the first file (even disk image) instead of booter
;       with embedded directory browser maybe that fastloader doesn't make sense

RAM_ZPVEC1	= $03	; (2) temp	; TCBM2SD fastloader target vector

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

RAM_ILOAD	= $032E	; LOAD vector

LNGJMP		= $05F0	; Long jump address
FETARG		= $05F2	; Long jump accumulator
FETXRG		= $05F3	; Long jump x register
FETSRG		= $05F4	; Long jump status register 

RAM_RLUDES	= $07D9 ; read from (e07DF),y from RAM
a07DF		= $07DF ; zp address of vector for RLUDES

ROM_ILNGJMP	= $FCFA ; jumptable to LONGJMP ($FC89)
eE2B8		= $E2B8 ; clk hi (inverted)
eEDA9		= $EDA9 ; check if device 8/9 (RAM_FA) is parallel (TCBM), C=0 --> yes
eF160		= $F160	; print 'SEARCHING'
eF189		= $F189 ; print 'LOADING'

TCBM_DEV8       = $FEF0	; ;// portA
TCBM_DEV8_1     = $FEF1	; ;// portB 1/0
TCBM_DEV8_2     = $FEF2 ; ;// portC 7/6
TCBM_DEV8_3     = $FEF3 ; ;// portA DDR

TED_FF06        = $FF06
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

CMD_CHANNEL = 239 ; command channel for burst command

; ?speeddos for 1541+parallel?
; ?anyfastload for 1541?
; ?embedded directory browser (one for tcbm2sd)

lowmem_code 	= $0640	; our bank number and trampoline into ROM (must be above basic key trampoline)

		*=$8000
; header
		jmp coldstart	; coldstart, install
		jmp warmstart	; warmstart, run from basic (F-key)
!by $09			; module-nr, $00=empty, $01=autostart
!by $43,$42,$4d		; module-nr., "CBM"

!source "startup.asm"

coldstart:
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
normal_reset:
	jmp print_welcome		; normal reset, back to BASIC
run_browser:
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

lowmem_trampoline:
	!pseudopc lowmem_code {
buf_ourbank:	!byte 0		; our bank number: internal/external1/external2
buf_sr:         !byte 0		; status register
load_status:	!byte 0		; 0 = go to ROM routine for load, !=0 = return

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
	} ; pseudopc

lowmem_trampoline_end:

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
+	jmp iecburst_load	;no, it's IEC, try using burst

load_rom:
	lda #$80
	sta load_status		; pass back to ROM code
	rts

iecburst_load:
	+LoadBurst
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!source "t2s-detect.asm"

tcbm_load:
	lda #<tcbm2sd_detect_txt
	ldy #>tcbm2sd_detect_txt
	jsr print_msg
	jsr t2sd_detect
	bcc +				; not tcbm2sd, must be 1551 - pass to hypaload
	jmp hypa_load

	; TCBM2SD fastloader here
+	lda #<tcbm2sd_fastload_txt
	ldy #>tcbm2sd_fastload_txt
	jsr print_msg

!source "t2s-loader.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hypa_load:
	lda #<tcbm_1551_txt
	ldy #>tcbm_1551_txt
	jsr print_msg		; HYPALOAD would start here

!source "hypaload-v4.7.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tcbm2sd_detect_txt:
	!text "TCBM2SD DETECTING...",13,0
tcbm2sd_fastload_txt:
	!text "TCBM2SD DETECTED",13,0
tcbm_1551_txt:
	!text "TCBM DEVICE, 1551 HYPALOAD",13,0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

startup_txt:
	!text " BURSTCART ON KEY F",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_msg:
		bit RAM_MSGFLG
		bmi +
		rts
print_msg_always:
+		sta RAM_ZPVEC1
		sty RAM_ZPVEC1+1
		ldy #0
-		lda (RAM_ZPVEC1),y
		beq +
		jsr ROM_CHROUT
		iny
		bne -
+		rts


; anything above $C000 comes from KERNAL (see coldstart memory config)
; so we must fit executable code within 16k, below $C000
!if * > $C000 { !error "EXECUTABLE CODE ABOVE $C000 *=", * }

;!fill ($C000-*), $ff
		;* = $C000
		; TCBM2SD directory browser (2024-11-30)
dirbrowser:
!bin "boot.t2sd",,2
dirbrowserend:

!fill ($10000-*), $ff

