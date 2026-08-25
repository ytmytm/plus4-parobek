; Plus/4 fast1541iec host — same .loadloop/.transferbyte as SJL264.
; No TALK/$61: drive already running via M-E.
; Entry: wait drive WORK (CLK low) so idle bus is not mistaken for EOI.

fast1541iec_highcode:
!zone fast1541iec_LoaderHighcode {
	sei
	lda $01
	pha
	lda #%00001000
	sta $01
	lda #%00011111
	sta $00
	ldy #$00

-	bit $01				; sync: drive CLK low (busy)
	bvs -

	ldx #231
-	dex
	bne -

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
	lda #$00
	sta load_status
	jsr .restore
	ldx $9d
	ldy $9e
	clc
	rts

.file_error:
	lda #$04
	sta load_status
	jsr .restore
	ldx $9d
	ldy $9e
	sec
	rts

.restore:
	lda RAM_SA_BACKUP
	sta RAM_SA
	lda RAM_TED_BORDER_BACKUP
	sta TED_BORDER
	lda RAM_TED_FF06_BACKUP
	sta TED_FF06
	lda RAM_TED_FF13_BACKUP
	sta TED_FF13
	lda #$0f
	sta $00
	pla
	ora #%00001000
	sta $01
	rts
}
