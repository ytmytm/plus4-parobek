; Stock 1541 serial IEC fastloader wrapper (Parobek).
; Task 3 stub: announce and return $80 so ROM load still works.

fast1541iec_load:
	!zone fast1541iec_Loader {
		lda #<fast1541iec_txt
		ldy #>fast1541iec_txt
		jsr print_msg
		lda #$80
		sta load_status
		rts

fast1541iec_txt:
		!text "1541 SERIAL",13,0
	}

!source "fast1541iec-loader-highcode.asm"
!source "fast1541iec-drivecode.asm"
