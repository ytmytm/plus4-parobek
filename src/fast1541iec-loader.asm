; Stock 1541 serial IEC fastloader wrapper (Parobek).
; Opens the file with the KERNAL, uploads seven 32-byte M-W chunks to $0300,
; executes them with M-E, then enters the cycle-counted jiffy2bit receiver.

fast1541iec_load:
	!zone fast1541iec_Loader {
		lda #<fast1541iec_txt
		ldy #>fast1541iec_txt
		jsr print_msg

		jsr shared_rom_check
		bcc +
		jmp .fail
+

		; Do not permit the fast receiver to overwrite KERNAL/I/O space.
		lda $9e
		cmp #$0a
		bcs +
		jmp .fail
+

		; Finish the KERNAL channel used to obtain the load address.  The
		; drive retains the file's first track/sector in $18/$19.
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
		lda #'W'
		jsr .send_m_command
		lda $05
		jsr ROM_CIOUT
		lda $06
		jsr ROM_CIOUT
		lda #$20
		jsr ROM_CIOUT
		ldy #$00
.upload_chunk:
		lda ($03),y
		jsr ROM_CIOUT
		iny
		cpy #$20
		bne .upload_chunk
		jsr ROM_UNLISTEN
		lda RAM_STATUS
		and #$83			; device absent / IEC read/write timeout
		beq +
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

		lda #'E'
		jsr .send_m_command
		lda #$00
		jsr ROM_CIOUT
		lda #$03
		jsr ROM_CIOUT
		jsr ROM_UNLISTEN
		lda RAM_STATUS
		and #$83
		beq +
		jmp .fail
+

		lda TED_BORDER
		sta RAM_TED_BORDER_BACKUP
		lda TED_FF06
		sta RAM_TED_FF06_BACKUP
		and #$ef
		sta TED_FF06
		lda TED_FF13
		sta RAM_TED_FF13_BACKUP
		ora #%00000010
		sta TED_FF13			; force 1 MHz for timed receive
		jmp fast1541iec_highcode

.send_m_command:
		pha
		lda RAM_FA
		jsr ROM_LISTEN
		lda #$6f
		jsr ROM_SECOND
		lda #'M'
		jsr ROM_CIOUT
		lda #'-'
		jsr ROM_CIOUT
		pla
		jmp ROM_CIOUT

.fail:
		lda #$04
		sta load_status
		sec
		rts

fast1541iec_txt:
		!text "1541 SERIAL",13,0
	}

!source "fast1541iec-loader-highcode.asm"
!source "fast1541iec-drivecode.asm"
