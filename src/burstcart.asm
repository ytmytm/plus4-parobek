
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

; todo: burst: inline GetByte in GetAndStore to save some cycles
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

; $D0-$E6 used by detect/load code
; directory browser uses $D4 for load&run flag, but it's copied to $8F
; MAKE SURE TO NOT USE $8F FOR ANYTHING ELSE

RAM_TED_BORDER_BACKUP = $E6	; backup of TED_BORDER

RAM_ICRNCH  = $0304 ; Indirect Crunch (Tokenization Routine) 
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
; ???
LEF3B           = $EF3B
LF211           = $F211

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
	jsr print_msg
	lda #$80
	sta load_status		; pass back to ROM code
	rts

iec_load:
	lda #<iec_load_txt
	ldy #>iec_load_txt
	jsr print_msg

	lda #$80
	sta load_status
	jsr iecburst_load
	bit load_status
	bmi +			    ; was not loaded, try 1541/parallel

    lda #<iec_load_txt2
    ldy #>iec_load_txt2
    jsr print_msg
	rts

+	lda #<iec_load_txt3
    ldy #>iec_load_txt3
    jsr print_msg

	jsr par1541_detect
	sta $d0
	bit $d0
	bpl load_rom		; not 1541 -> fall back on ROM
	and #%01111111
	beq load_rom	    ; 1541 but no parallel cable -> fall back on ROM
	lda #<iec_load_txt4
    ldy #>iec_load_txt4
    jsr print_msg
	lda $d0
	jmp SpeedDOS_load
;	jmp par1541_load ; XXX

load_rom_txt:
	!text "ROM LOAD",13,0

iec_load_txt:
	!text "IEC LOAD",13,0

iec_load_txt2:
	!text "BURST LOADED",13,0

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
!source "speeddos-drivecode.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

hypa_load:
	lda #<tcbm_1551_txt
	ldy #>tcbm_1551_txt
	jsr print_msg		; HYPALOAD would start here

	lda RAM_FA
	cmp #9
	beq +
	jmp hypa_load_8
+	jmp hypa_load_9

!source "hypaload-common.asm"

!set tcbmbase = TCBM_DEV8
hypa_load_8:
!source "hypaload-v4.7.asm"

!set tcbmbase = TCBM_DEV9
hypa_load_9:
!source "hypaload-v4.7.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tcbm2sd_detect_txt:
	!text "TCBM2SD DETECTING...",13,0
tcbm2sd_fastload_txt:
	!text "TCBM2SD DETECTED",13,0
tcbm_1551_txt:
	!text "TCBM DEVICE, 1551 HYPALOAD",13,0
tcbm2sd_load_error_txt:
	!text "TCBM2SD LOAD ERROR",13,0

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

;--------------------------------------------------

shared_rom_check:
	!zone shared_rom_check {
; copy of ROM code between F06B (load from serial) and F0A5 (where JSR FFE1 is called - test for STOP)
; will setup load address in $9D/$9E according to RAM_SA
        LDX   RAM_SA
        JSR   eF160                    ; print 'SEARCHING'
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
        clc                            ; file found, continue
        rts

.file_not_found:
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

