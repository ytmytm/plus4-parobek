; SJL264-derived IEC Jiffy load — ROM wrapper (Parobek).
; Open with KERNAL $F005 on SA $60, then SJL bitbang for address + JD $61 transfer
; (same order as upstream SJL264; do NOT use KERNAL TALK/ACPTR for the address).

SJL_load:
	!zone SJL_Loader {
		lda #<sjl_txt
		ldy #>sjl_txt
		jsr print_msg

		lda RAM_SA
		sta load_sa			; original LOAD SA (0 = relocate)
		sta RAM_SA_BACKUP

		ldx RAM_SA
		jsr eF160			; SEARCHING FOR...
		lda #$60
		sta RAM_SA
		jsr ROM_IEC_OPEN_SETUP		; open channel 0 (like upstream rom_iec_open)

		lda TED_BORDER
		sta RAM_TED_BORDER_BACKUP
		lda TED_FF06
		sta RAM_TED_FF06_BACKUP
		and #$ef
		sta TED_FF06			; screen off (may allow 2 MHz)

		; SJL bitbang is cycle-counted for 1 MHz — force single clock
		lda TED_FF13
		sta RAM_TED_FF13_BACKUP
		ora #%00000010
		sta TED_FF13

		jmp SJL_highcode

sjl_txt:
		!text "SJL264",13,0
	}

!source "sjl-loader-highcode.asm"
