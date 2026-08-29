; Serial ACPTR used by Parobek on a Hackjunk 6510 host.
;
; The supplied 6510 KERNAL samples CLK through JSR $CFF7 in its pre-byte
; loop.  That makes the polling interval long enough to miss a complete
; JiffyDOS clock pulse.  Keep the KERNAL ROM unchanged and use this local
; copy for Parobek's IEC reads.  TCBM devices (1551/tcbm2sd) and non-6510
; hosts continue through the KERNAL entry point.

; TCBM (eEDA9 C=0) -> ROM_ACPTR.  6510 + IEC -> acptr_6510.  Else -> ROM.
; eEDA9 selects the bus and must run only once before TALK/TKSA, not between
; consecutive ACPTR bytes.  Call it here only for 6510 IEC routing.
iec_acptr:
	lda cpu_port_type
	cmp #1
	bcc .iec_rom
	cmp #3
	bcs .iec_rom
	jsr eEDA9
	bcc .iec_rom
	jmp acptr_6510
.iec_rom:
	jmp ROM_ACPTR

acptr_6510:
	sei
	lda #0
	sta $aa			; EOI retry flag
	jsr .clk_hiz
	txa
	pha

; Wait until the talker releases CLK.  Both reads must agree.  The inline
; test is 15 cycles per stable iteration; the Hackjunk KERNAL's JSR-based
; loop takes about 26 cycles and can miss the first JiffyDOS pulse.
.wait_ready:
	lda $01
	cmp $01
	bne .wait_ready
	asl
	asl
	bpl .wait_ready

.retry:
	ldx #$20
	jsr .data_lo
.wait_first_clock:
	lda $01
	cmp $01
	bne .wait_first_clock
	asl
	asl
	bpl .byte_start
	dex
	bne .wait_first_clock

	lda $aa
	beq .eoi
	pla
	tax
	lda #$02
	jmp ROM_CBMSER_TIMEOUT

.eoi:
	jsr .data_hiz
	ldx #$40
	txa
.eoi_delay:
	dex
	bne .eoi_delay
	jsr ROM_SET_STATUS_HELPER
	inc $aa
	bne .retry

.byte_start:
	ldx #8
.wait_data:
	lda $01
	lsr			; DATA bit 0 -> C, CLK bit 5 -> bit 4
	and #$10
	beq .wait_data
	ror $a8
.wait_clock_low:
	lda $01
	cmp $01
	bne .wait_clock_low
	and #$20
	bne .wait_clock_low
	dex
	bne .wait_data
	nop
	nop

	stx $aa
	pla
	tax
	jsr .data_hiz
	lda #$40
	bit RAM_STATUS
	bvc .done
	jsr .eoi_ack
.done:
	lda $a8
	cli
	clc
	rts

.eoi_ack:
	txa
	ldx #$14
.eoi_ack_delay:
	dex
	bne .eoi_ack_delay
	tax
	jsr .clk_hiz
	jmp .data_lo

.clk_hiz:
	lda $01
	and #$fd
	sta $01
	rts

.data_lo:
	lda $01
	and #$f7
	sta $01
	rts

.data_hiz:
	lda $01
	ora #$08
	sta $01
	rts
