; Stock 1541 JD LOAD sender @ $0300 (≤256 B).
; Literal structure of docs/1541EJD.a65 J_FF2D/P_FF8D/A_FFA3:
; transform pointer/Y for the final sector, then one inline send loop until
; Y wraps. Host receives via SJL_jd_transfer (no private fast1541iec loop).
; Data buffer 1 @ $0400; host seeds first T/S in $20/$21 before M-E.

fast1541iec_drivecode:
!pseudopc $0300 {
.start:
	lda #$1a
	sta $1802
	lda $1800
	and #$60
	sta $7a
	ora #$0d
	sta $44
	sta $1800
	lda #$00
	sta $30
	lda #$04
	sta $31
	lda #$04			; first sector: skip link + PRG address

.read_sector:
	pha				; start offset: 4 first, 2 thereafter
	lda $44
	sta $1800
	lda $20
	sta $08
	lda $21
	sta $09
	cli
	lda #$80
	sta $01
-	lda $01
	bmi -
	sei
	cmp #$01
	beq +
	jmp .read_error
+

	; J_FF2D: obtain next T/S and transform final-sector pointer so the
	; desired byte range ends exactly when Y wraps.
	ldy #$01
	lda ($30),y
	sta $21
	tax
	dey
	lda ($30),y
	sta $20
	bne .have_y
	pla
	clc
	sbc $21
	inx
	stx $30
	beq +
	dec $31
+	pha
.have_y:
	pla
	tay

	; P_FF8D verbatim, using the stock-ROM helpers also used by JD.
	lda $1800
	and #$60
	sta $7a
	ora #$0d
	sta $44
	jsr $e9a5			; DataOut_H
	eor #$0d
	sta $1800
	jsr $fef3			; DelayC64

	; A_FFA3/A_FFA5 verbatim: no calls and no added pair delays.
.send_loop:
	lda ($30),y
	tax
	lsr
	lsr
	lsr
	lsr
	sta $4b
	txa
	and #$0f
	tax
	lda .jd_nibble,x
	ldx $7a
	stx $1800
-	cpx $1800
	beq -
	sta $1800
	asl
	and #$0f
	nop
	sta $1800
	ldx $4b
	lda .jd_nibble,x
	sta $1800
	asl
	and #$0f
	iny
	sta $1800
	bne .send_loop
	nop
	lda $44
	sta $1800
.wait_host:
	cmp $1800			; A_FFDE: do not start job/EOI early
	bcc .serial_bus
	bne .wait_host

	lda $20
	beq .do_eoi
	lda #$02
	jmp .read_sector

	; A_FF60/P_FF6E verbatim: two CLK-low delays, CLK high, then
	; one final delay ending with CLK low.  The ROM helper's RTS returns
	; through the M-E command's existing stack frame.
.do_eoi:
	lda #$00
	sta $30
	jsr .delay_clk_low
	jsr .delay_clk_low
	jsr $e9ae			; ClkOut_H
.delay_clk_low:
	ldx #$14
-	dex
	bne -
	jmp $e9b7			; ClkOut_L, then RTS

.serial_bus:
	jmp $e85b

.read_error:
	pla				; discard saved start offset
	lda $44
	sta $1800
	bne .read_error

.jd_nibble:
	!byte $0f,$07,$0d,$05,$0b,$03,$09,$01
	!byte $0e,$06,$0c,$04,$0a,$02,$08,$00
}

!if * > fast1541iec_drivecode+$100 {
	!error "FAST1541IEC DRIVECODE EXCEEDS 256-BYTE M-W BUDGET"
}
!fill fast1541iec_drivecode+$100-*, $ea
fast1541iec_drivecode_end:
