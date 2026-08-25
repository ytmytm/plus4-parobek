; Stock 1541 jiffy2bit sender uploaded to $0300 with M-W.
;
; AAY1541 job API used here:
;   $04     buffer-4 job queue entry
;   $0e/$0f buffer-4 track/sector
;   $80     READ SECTOR, result $01 means success
;   $0700   buffer 4
;
; $18/$19 contain the first file track/sector after shared_rom_check, as in
; the SpeedDOS loader.  VIA1 PB images are always complete writes with PB4
; (ATNA) clear: $00/$02/$08/$0a only.

fast1541iec_drivecode:
!pseudopc $0300 {
.start:
	lda #$1a
	sta $1802			; PB1 DATA, PB3 CLK, PB4 ATNA outputs
	; Keep IEC released through host UNLISTEN after M-E. Asserting CLK
	; here deadlocks KERNAL (ROM_CBMSER_READLINES) vs .wait_host_ready.
	lda #$00
	sta $1800
.wait_atn_clear:
	bit $1800			; bit7=1 while ATN asserted (inverted bus)
	bmi .wait_atn_clear

.read_sector:
	lda $18
	sta $0e
	lda $19
	sta $0f
	cli				; DOS IRQ executes the buffer job
	lda #$80			; AAY1541 READ job for buffer 4
	sta $04
.wait_job:
	lda $04
	bmi .wait_job
	sei
	cmp #$01
	bne .read_error			; never report a failed READ as clean EOF

	lda $0700			; next track
	beq .last_sector
	sta $18
	lda $0701			; next sector
	sta $19
	lda #$00			; Y wraps after byte $ff
	beq .send_sector

.last_sector:
	lda $0701			; last used data offset
	clc
	adc #$01

.send_sector:
	sta $15				; exclusive end offset
	ldy #$02
.send_loop:
	lda $0700,y
	jsr .send_byte
	iny
	cpy $15
	bne .send_loop
	lda $0700
	bne .read_sector
	beq .send_eoi

.read_error:
	lda #$08			; hold CLK asserted so host never sees EOF
	sta $1800
	bne .read_error

.send_eoi:
	lda #$08			; arm: force host probe back to loadloop
	sta $1800
	lda #$01
.wait_host_release:
	bit $1800			; PB0 is host DATA output
	beq .wait_host_release
	lda #$00			; EOI present: both lines released
	sta $1800
	ldx #$04			; hold for at least 16 drive cycles
.eoi_hold:
	dex
	bne .eoi_hold
	lda #$08			; EOI confirm: CLK asserted, DATA released
	sta $1800
	cli
	rts

; Convert four least-significant-first bit pairs to safe VIA port images,
; then synchronize with the SJL/Jiffy host probe.  The timed stores are
; spaced 9, 10, and 10 drive cycles to match the host's four samples.
.send_byte:
	sta $14
	lda #$08			; not ready while encoding
	sta $1800
	ldy #$00
.encode_pair:
	lda $14
	and #$03
	tax
	lda .pair_image,x
	sta $10,y
	lsr $14
	lsr $14
	iny
	cpy #$04
	bne .encode_pair

	lda #$02			; byte announce: CLK high, DATA low
	sta $1800
	; Hold $02 long enough that the host .loadloop sample cannot
	; miss it and only see the later $00 (CLK+DATA high = false EOI →
	; sjl_untalk while we sit in .wait_host_ready).
	ldy #$40
--	ldx #$00
-	dex
	bne -
	dey
	bne --
	lda #$00			; DATA high → host leaves .wait_data
	sta $1800
	lda #$01
-	bit $1800			; host asserts DATA with $01=$09
	bne -

	lda $10
	sta $1800
	nop
	lda $11
	sta $1800
	bit $00
	lda $12
	sta $1800
	bit $00
	lda $13
	sta $1800
	rts

; Logical CLK/DATA pairs 00,01,10,11 -> inverted PB3/PB1 images.
.pair_image:
	!byte $0a,$02,$08,$00
}

!if * > fast1541iec_drivecode+$e0 {
	!error "FAST1541IEC DRIVECODE EXCEEDS 224-BYTE M-W BUDGET"
}
!fill fast1541iec_drivecode+$e0-*, $ea
fast1541iec_drivecode_end:
