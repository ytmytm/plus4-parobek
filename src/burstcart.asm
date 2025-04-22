!to "bin/burstcart.bin",plain

;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
;

RAM_VERFCK	= $93	; 0=load, 1=verify
RAM_LA		= $AC	; logical address
RAM_FA		= $AE	; device number
RAM_FNADR	= $AF	; vector to filename
RAM_CURBNK	= $FB	; current ROM bank

RAM_ILOAD	= $032E	; LOAD vector

LNGJMP		= $05F0	; Long jump address
FETARG		= $05F2	; Long jump accumulator
FETXRG		= $05F3	; Long jump x register
FETSRG		= $05F4	; Long jump status register 

RAM_RLUDES	= $07D9 ; read from (e07DF),y from RAM
a07DF		= $07DF ; zp address of vector for RLUDES

ROM_ILNGJMP	= $FCFA ; jumptable to LONGJMP ($FC89)
eF160		= $F160	; print 'SEARCHING'

; ?detect if CIA is present at CIABASE
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

	; welcome message
+	ldx #0
-	lda startup_txt,x
	beq +
	jsr $ffd2
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
	} ; pseudopc

lowmem_trampoline_end:

; OUT:
; load_status = 0 - loaded, then:
; A=error code (if C=1) or C=0
; X/Y last byte loaded
; load_status = 1 - not loaded, pass back to ROM
;
myload:
	sta RAM_VERFCK	;VERFCK  Flag:  0 = load,  1 = verify
	lda #0
	sta load_status
	lda RAM_FA	;FA      Current device number
	cmp #4
	bcc +		;less than 4 - tape
	lda #RAM_FNADR	;filename at ($AF/$B0)?
	sta a07DF
	ldy #0
	jsr RAM_RLUDES	;RLUDES  Indirect routine downloaded
	cmp #'$'	;if '$' then ROM load
	bne myload_cont
+	inc load_status	; pass back to ROM code
	rts

	; our loading code
myload_cont:
+	lda RAM_FA	;FA      Current device number
	sta RAM_LA	;LA      Current logical fiie number
	jsr eF160	;print "SEARCHING"
; detect burst ? detect drive type ?
	inc load_status	; fake return to ROM
	rts

startup_txt:
	!text " VEC INSTALLED",13,0

	; anything above $C000 comes from KERNAL (see coldstart)

!fill ($10000-*), $ff

