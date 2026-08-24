SJL_load:
	!zone SJL_Loader {
		lda #<sjl_txt
		ldy #>sjl_txt
		jsr print_msg

		jsr shared_rom_check
		bcc .have_file
		lda #4
		sta load_status
		rts

.have_file:
		lda $9e
		cmp #$0a
		bcs .addr_ok
		jsr ROM_UNTLK
		jsr ROM_IEC_CLOSE_SETUP
		lda #$80
		sta load_status
		rts

.addr_ok:
		lda TED_BORDER
		sta RAM_TED_BORDER_BACKUP
		lda TED_FF06
		sta RAM_TED_FF06_BACKUP
		and #$ef
		sta TED_FF06

		jmp SJL_highcode

sjl_txt:
		!text "SJL264",13,0
	}

!source "sjl-loader-highcode.asm"
