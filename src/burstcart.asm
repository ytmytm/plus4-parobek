
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

; todo: with listen/second/acptr/unlisten we don't care about filename/channels and preserving zp values
; todo: if TCBM detected check for 1551 or TCBM2SD and apply correct fastloader
; todo: register function key (according to ROM bank number) and run DIRECTORY BROWSER (TCBM2SD) when hit
; todo: inline GetByte in GetAndStore to save some cycles

RAM_ZPVEC1	= $03	; (2) temp

RAM_VERFCK	= $93	; 0=load, 1=verify
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
ROM_OPEN	= $FFC0
ROM_CLOSE	= $FFC3
ROM_CHKOUT	= $FFC9
ROM_CLRCHN	= $FFCC
ROM_CHROUT	= $FFD2

eFF06		= $FF06
eFF13		= $FF13

CMD_CHANNEL = 239 ; command channel for burst command

; ?detect if 1551 as #9 or #8 first (ROM sets flag?)
; +detect if CIA is present at CIABASE
; install LOAD wedge
; ?detect which drive has burst
; ?1551warp for 1551?
; ?speeddos for 1541+parallel?
; ?anyfastload for 1541?
; ?quasiburst for tcbm2sd?
; ?embedded directory browser (one for tcbm2sd)
	; ?setup TOD clock (50Hz)
	; ?display clock in top right in directory browser?

lowmem_code 	= $0610	; our bank number and trampoline into ROM

		*=$8000
; header
		jmp coldstart	; coldstart, install
		jmp warmstart	; warmstart, run from basic
!by $09			; module-nr, $00=empty, $01=autostart
!by $43,$42,$4d		; module-nr., "CBM"

coldstart:
	lda RAM_CURBNK
	and #$03		; enable kernal in top half so we don't care about IRQ
	tax			; (if we want top half, set $FFFE/F to FCB3 - Kernal paged IRQ; then need own eF160 etc.)
	sta RAM_CURBNK
	sta buf_ourbank
	sta $fdd0,x

warmstart:
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

	+InitBurst

	; welcome message
+	ldx #0
-	lda startup_txt,x
	beq +
	jsr ROM_CHROUT
	inx
	bne -
+	rts

lowmem_trampoline:
	!pseudopc lowmem_code {
buf_ourbank:	!byte 0		; our bank number: internal/external1/external2
load_status:	!byte 0		; 0 = go to ROM routine for load, !=0 = return

myloadlow:
	sta RAM_VERFCK		; remember A
	sta FETARG
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
	lda bufFF13		; restore slow/fast clock
	sta eFF13
	lda load_status		; did we load or not?
	bne +			; no, continue in original (Kernal) code
	ldx FETXRG		; restore state and return
	lda FETSRG
	pha
	lda FETARG
	plp
	rts
+	lda RAM_VERFCK		; stored A
loadrom:
	jmp $F04C		; -> F04C
bufFF06:
        !byte 0
bufFF13:
	!byte 0
	} ; pseudopc

lowmem_trampoline_end:

; OUT:
; load_status = 0 - loaded, then:
; A=error code (if C=1) or C=0
; X/Y last byte loaded
; load_status = 1 - not loaded, pass back to ROM
;
myload:
	lda RAM_VERFCK		;VERFCK  Flag:  0 = load,  1 = verify
	sta load_status 	; will be 0 for load, not 0 for verify
	cmp #0			; load or verify?
	beq +
	rts			; pass back to ROM code
+	stx RAM_MEMUSS		; load addr
	sty RAM_MEMUSS+1
	lda RAM_FA		;FA      Current device number
	cmp #4
	bcc +			;less than 4 - tape
	jsr eEDA9		;check if this is 8/9 TCBM device
	bcc +			;yes, fall back on ROM (in the future: fastloader for 1551/tcbm2sd)
	lda #RAM_FNADR		;filename at ($AF/$B0)?
	sta a07DF
	ldy #0
	jsr RAM_RLUDES		;RLUDES  Indirect routine downloaded
	cmp #'$'		;if '$' then ROM load
	bne myload_cont
+	inc load_status		; pass back to ROM code
	rts

myload_cont:
	+LoadBurst

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

startup_txt:
	!text " VEC INSTALLED",13,0

	; anything above $C000 comes from KERNAL (see coldstart)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_msg:

                sta RAM_ZPVEC1
		sty RAM_ZPVEC1+1
		ldy #0
-               lda (RAM_ZPVEC1),y
                beq +
		jsr ROM_CHROUT
		iny
		bne -
+               rts

!fill ($10000-*), $ff

