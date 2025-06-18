
ROM_DOAKEY = $FF49	; $B7C2

tapebuf = $0340 ; tape buffer

s_lo         = $9f
s_hi         = $a0
t_lo         = $a1
t_hi         = $a2

; F1=1525, F2=1578, F3=1546
; 21
; $35

key_install:
		ldy #0
-		lda basicsys,y
		sta tapebuf,y
		iny
		cpy #basicsysend-basicsys
		bne -

		; correct SYS address
		ldx RAM_CURBNK	; 0=BASIC, 1=function (F1), 2=C1 (F2), 3=C2 (F3)
		lda basissysaddr1-1,x
		sta tapebuf+5
		lda basissysaddr2-1,x
		sta tapebuf+6

		; install warmstart trampoline code
		lda basic_trampoline_offs-1,x
		pha
		tay
		ldx #0
-		lda basic_trampoline,x
		sta $05f5,y
		inx
		iny
		cpx #(basic_trampoline_end-basic_trampoline)
		bne -
		pla
		tay
		iny
		ldx RAM_CURBNK
		txa
		sta $05f5,y

		; install function key definition
		ldx RAM_CURBNK
		dex
		stx $76 			; keynum 0-7 (0=F1, 7=F8)
		lda #<tapebuf
		sta $22 			; index
		lda #>tapebuf
		sta $23 			; index+1
		lda #(basicsysend-basicsys)
		sta FETARG			; A register argument
		lda #<ROM_DOAKEY
		sta LNGJMP
		lda #>ROM_DOAKEY
		sta LNGJMP+1
		lda #%00000011		; status reg
		sta FETSRG
		lda RAM_CURBNK		; caller bank (current)
		ldx #0				; target bank (ROM)
		jsr ROM_ILNGJMP
		rts

basic_trampoline:
		ldx #$01			; 0=BASIC, 1=function (F1), 2=C1 (F2), 3=C2 (F3)
		lda #<$8003
		sta LNGJMP
		lda #>$8003
		sta LNGJMP+1
		sta FETSRG
		lda RAM_CURBNK
		jmp ROM_ILNGJMP
basic_trampoline_end:

basicsys:
		!text "SYS1525:"
		!text " BURSTCART"
basicsysend:

; F1=1525, F2=1578, F3=1546
basissysaddr1:
		!byte '2', '7', '4'
basissysaddr2:
		!byte '5', '8', '6'

basic_trampoline_offs:
		!byte 0, (1578-1525), (1546-1525)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

startup_screen:
		jsr ROM_CINT		; initialize screen editor

		lda #$2e
		sta TED_BACK
		sta TED_BORDER

		lda #$ff
		sta $ff0c
		sta $ff0d           ; hide cursor

		lda #<startup_screen_txt
		ldy #>startup_screen_txt
		jsr print_msg_always
		cli

keys:
-		jsr ROM_GETIN
		beq -
		cmp #$31		; 1
		beq +
		cmp #$32		; 2
		beq +
		cmp #$33		; 3
		beq +
		jmp keys
+		and #$0f
		pha
		lda #147		; clear screen
		jsr ROM_CHROUT
		lda #144		; color black
		jsr ROM_CHROUT
		jsr ROM_IOINIT
		sei
		pla
		rts

startup_screen_txt:

		!byte 147
		!byte 5 ; white
		;      1234567890123456789012345678901234567890
		!text "           BURSTCART ROM V1.0",13,13
		!text "        (C) BY YTM/ELYSIUM 2025",13,13
		!fill 40, 163
		!byte 13,13,13
		!text "         1. NORMAL RESET",13,13
		!text "         2. DIRECTORY BROWSER",13,13
		!text "         3. INSTALL FASTLOAD",13
		!byte 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; tool load handler

dirbrowser_loadrun:
	lda #$10
	sta $053b
	lda #$00
	sta $053c
	sta $07f8
	sta $07f9

	sei
	lda RAM_CURBNK
	ora #%00001000		; enable kernal in top half
	tax
	sta $fdd0,x  		; cart1/2 lo, cart1/2 hi
	lda TED_FF06		; switch blank: 2 Mhz
	and #$EF
	sta TED_FF06
	lda #$ff
	sta $ff0c
	sta $ff0d           ; hide cursor

	lda #<dirbrowser
	sta s_lo
	lda #>dirbrowser
	sta s_hi
	lda #<$1001			; BASIC start
	sta t_lo
	lda #>$1001
	sta t_hi

	ldx #0
	ldy #0
-	lda (s_lo),y
	sta (t_lo),y
	iny
	bne -
	inc s_hi
	inc t_hi
	inx
	cpx #(1 + (>dirbrowserend-dirbrowser))
	bne -

	ldx RAM_CURBNK
	sta $fdd0,x 		; cart1/2 lo, kernal

;--- copy trampoline-code to tape-buffer
trampolin_cpy:
	ldx #(trampolin_end-trampolin)
-	lda trampolin,x
	sta tapebuf,x
	dex
	bpl -
	jmp tapebuf

;--- trampoline-code
trampolin:
	!pseudopc tapebuf {
	sei
	lda #$00
	sta $02fe
	sta $02ff
	ldx #$00         ; basic , kernal
	sta $fdd0,x      ; function rom off
	stx $fb
;	cli
;	jsr $802e        ; init Basic RAM

;	ldx #15			;  restore color palette
;-	lda $e143,x
;	sta $0113,x
;	dex
;	bpl -

	lda #$10
	sta $053b
	jsr $d888	; clear screen
	lda #$00	; clear keybuffer
	sta $ef
	lda #$10
	sta $053b
	jsr $8818        ; prg link
	jsr $8bbe        ; prg mode
	lda TED_FF06	 ; screen on
	ora #$10
	sta TED_FF06
	jmp $8bea		; run BASIC code
	} ; pseudopc
trampolin_end:
