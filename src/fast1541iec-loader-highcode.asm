; Plus/4 SJL/Jiffy-style jiffy2bit receiver.
; The drive reads the raw file chain, so the first two transferred bytes are
; the PRG load address already consumed by shared_rom_check and are discarded.
fast1541iec_highcode:
!zone fast1541iec_LoaderHighcode {
	sei
	lda $01
	pha				; restore the caller's exact CPU-port value
	lda #%00001000
	sta $01				; release IEC outputs
	lda #%00011111
	sta $00				; IEC outputs + inputs as in SJL264
	lda #$61
	sta RAM_SA
	lda #$02
	sta $d1				; discard raw PRG load address
	ldy #$00

.loadloop:
	lda #%00001000
	sta $01
	ldx #$00			; 16-bit bounded wait; zero means 256
	stx $d0
.wait_clk_drive:
	bit $01
	bvc .wait_clk_pending
	bmi .loadendover
	ldx #$00
	stx $d0
.wait_data_drive:
	bit $01
	bpl .wait_data_pending

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

	ldx $d1
	beq .store_byte
	dec $d1
	jmp .transferbyte

.store_byte:
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

.wait_clk_pending:
	dex
	bne .wait_clk_drive
	dec $d0
	bne .wait_clk_drive
	jmp .transfer_timeout

.wait_data_pending:
	dex
	bne .wait_data_drive
	dec $d0
	bne .wait_data_drive

.transfer_timeout:
	lda #%00000010			; serial timeout
	jsr ROM_SET_STATUS_HELPER
	jsr sjl_untalk
	jsr ROM_IEC_CLOSE_SETUP
	jmp .file_error

.loadendover:
	ldx #$64
.end_check:
	bit $01
	bvc .end_ok
	dex
	bne .end_check
	lda #%01000010			; timeout + serial end
	jsr ROM_SET_STATUS_HELPER
	jsr sjl_untalk
	jsr ROM_IEC_CLOSE_SETUP
	jmp .file_error
.end_ok:
	lda #%01000000			; serial end
	jsr ROM_SET_STATUS_HELPER
	jsr sjl_untalk
	jsr ROM_IEC_CLOSE_SETUP
	bcs .file_error

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
	sta $01
	rts
}
