; Stock 1541 serial IEC fastloader wrapper (Parobek).
; M-R $18/$19 before CLOSE (header T/S), upload drivecode, M-W T/S into
; drive $20/$21, M-E, then SJL_jd_transfer (shared SJL264 JD receive).

fast1541iec_load:
	!zone fast1541iec_Loader {
		lda #<fast1541iec_txt
		ldy #>fast1541iec_txt
		jsr print_msg

		jsr shared_rom_check
		bcc +
		jmp .fail_open
+
		lda $9e
		cmp #$0a
		bcs +
		jmp .fail_open
+
		; End shared_rom_check TALK, then snapshot T/S before CLOSE
		jsr ROM_UNTLK
		lda #'R'
		jsr iec_m_minus
		lda #$18
		jsr ROM_CIOUT
		lda #$00
		jsr ROM_CIOUT
		lda #$02
		jsr ROM_CIOUT
		jsr ROM_UNLISTEN
		lda RAM_FA
		jsr ROM_TALK
		lda #$6f
		jsr ROM_TKSA
		jsr ROM_ACPTR
		sta $07				; track
		jsr ROM_ACPTR
		sta $08				; sector
		jsr ROM_UNTLK

		lda #$01
		jsr ROM_CLOSE

		lda #<fast1541iec_drivecode
		sta $03
		lda #>fast1541iec_drivecode
		sta $04
		lda #$00
		sta $05
		lda #$03
		sta $06

.upload_loop:
		lda #$20
		jsr iec_mw_one_chunk
		bcc +
		jmp .fail
+
		clc
		lda $03
		adc #$20
		sta $03
		bcc +
		inc $04
+		clc
		lda $05
		adc #$20
		sta $05
		bcc +
		inc $06
+		lda $03
		cmp #<fast1541iec_drivecode_end
		bne .upload_loop
		lda $04
		cmp #>fast1541iec_drivecode_end
		bne .upload_loop

		; Seed drive $20/$21 with M-R'd T/S
		lda #'W'
		jsr iec_m_minus
		lda #$20
		jsr ROM_CIOUT
		lda #$00
		jsr ROM_CIOUT
		lda #$02
		jsr ROM_CIOUT
		lda $07
		jsr ROM_CIOUT
		lda $08
		jsr ROM_CIOUT
		jsr ROM_UNLISTEN
		lda RAM_STATUS
		and #$83
		beq +
		jmp .fail
+

		jsr ted_sjl_enter

		; TED only applies DEN=0 at a frame boundary.  SJL spends a full
		; command/address phase here; this M-E path did not, so display DMA
		; could still steal cycles from the supposedly cycle-counted loop.
		; Wait for FF1C bit 0 (raster bit 8) to toggle twice, guaranteeing
		; that a frame boundary has passed on both PAL and NTSC machines.
		lda $ff1c
		and #$01
		beq .wait_raster_high
.wait_raster_low:
		lda $ff1c
		and #$01
		bne .wait_raster_low
		beq .wait_second_high
.wait_raster_high:
		lda $ff1c
		and #$01
		beq .wait_raster_high
.wait_second_low:
		lda $ff1c
		and #$01
		bne .wait_second_low
		beq .screen_stable
.wait_second_high:
		lda $ff1c
		and #$01
		beq .wait_second_high
.screen_stable:

		lda #$00
		sta $d6
		lda #$03
		sta $d7
		jsr iec_me
		lda RAM_STATUS
		and #$83
		beq +
		jsr sjl_restore
		jmp .fail
+
		jmp SJL_jd_transfer

.fail_open:
		jsr ROM_UNTLK
		jsr ROM_IEC_CLOSE_SETUP
		jmp .fail

.fail:
		lda #$04
		sta load_status
		sec
		rts

fast1541iec_txt:
		!text "1541 SERIAL",13,0
	}

!source "fast1541iec-drivecode.asm"
