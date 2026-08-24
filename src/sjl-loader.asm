
SJL_load:
	!zone SJL_Loader {
		lda #<sjl_stub_txt
		ldy #>sjl_stub_txt
		jsr print_msg
		lda #$80
		sta load_status
		rts
sjl_stub_txt:
		!text "SJL264 STUB",13,0
	}
