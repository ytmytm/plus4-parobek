SJL_highcode:
!zone SJL_LoaderHighcode {
		sei
		lda $01
		and #%00001000
		bne .motor_ok
		jsr ROM_UNTLK
		jsr ROM_IEC_CLOSE_SETUP
		lda #$80
		sta load_status
		jmp .return_error

.motor_ok:
		lda #$61
		sta RAM_SA
		lda #0
		sta RAM_STATUS

		lda #%00001000
		sta $01
		lda #%00011111
		sta $00

		lda RAM_FA
		jsr sjl_talk
		lda RAM_SA
		jsr sjl_sectalk

		ldy #$00
		ldx #231
.wait1:
		dex
		bne .wait1

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
		jsr sjl_untalk
		jsr ROM_IEC_CLOSE_SETUP
		bcs .file_error

		lda #0
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_ok

.file_error:
		lda #4
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_error

.return_ok:
		jsr sjl_restore
		clc
		rts

.return_error:
		jsr sjl_restore
		sec
		rts

sjl_restore:
		lda RAM_SA_BACKUP
		sta RAM_SA
		lda RAM_TED_BORDER_BACKUP
		sta TED_BORDER
		lda RAM_TED_FF06_BACKUP
		sta TED_FF06
		lda #$0f
		sta $00
		jmp ROM_CBMSER_DAT_HIZ

; TALK
sjl_talk:
		ora #$40
sjl_sendbyatn:
		sta $95
		jsr ROM_CBMSER_DAT_HIZ
		nop
		nop
		lda $01
		ora #%00000100
		sta $01

; send IEC byte
sjl_sendbyte:
		jsr ROM_CBMSER_CLK_LO
		jsr ROM_CBMSER_DAT_HIZ
		jsr ROM_CBMSER_WAIT1MS
		jsr ROM_CBMSER_READLINES
		bcc .devpres
		jmp ROM_CBMSER_DEVNOTPRES

.devpres:
		jsr ROM_CBMSER_CLK_HIZ
.waitdata:
		jsr ROM_CBMSER_READLINES
		bcc .waitdata
		jsr ROM_CBMSER_CLK_LO
		txa
		pha
		ldx #8
.lsendbits:
		nop
		nop
		nop
		bit $01
		bmi .devprescont
		pla
		tax
		jmp ROM_CBMSER_TIMEOUT
.devprescont:
		jsr ROM_CBMSER_DAT_HIZ
		ror $95
		bcs .dathi
		jsr ROM_CBMSER_DAT_LO
.dathi:
		jsr ROM_CBMSER_CLK_HIZ
		lda $01
		and #%11111110
		ora #%00000010
		sta $01
		and #%00000100
		beq .ltwobitsent
		lda $95
		ror
		ror
		cpx #2
		bne .ltwobitsent
		ldx #$1e
.lwack1:
		bit $01
		bpl .lwack2
		dex
		bne .lwack1
		beq .lcont6
.lwack2:
		bit $01
		bpl .lwack2
.lcont6:
		ldx #2
.ltwobitsent:
		dex
		bne .lsendbits
		ldx #$56
.lcont7:
		dex
		beq .ltbtimeout
		lda $01
		bmi .lcont7
		pla
		tax
		rts
.ltbtimeout:
		pla
		tax
		jmp ROM_CBMSER_TIMEOUT

; secondary talk address
sjl_sectalk:
		sta $95
		jsr sjl_sendbyte
		lda #%00001001
		sta $01
.waitclk:
		bit $01
		bvs .waitclk
		rts

; UNTALK
sjl_untalk:
		lda $01
		ora #%00000100
		sta $01
		jsr ROM_CBMSER_CLK_LO
		lda #$5f
		jsr sjl_sendbyatn
		jsr ROM_CBMSER_ATN_HIZ
		txa
		ldx #$0a
.ll2:
		dex
		bne .ll2
		tax
		jsr ROM_CBMSER_CLK_HIZ
		jmp ROM_CBMSER_DAT_HIZ

; IEC input byte
sjl_busin:
		lda $01
		cmp #%01000000
		bcc sjl_busin
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		lda #%00001000
		nop
		nop
		sta $01
		nop
		lda $00
		nop
		nop
		nop
		lda $01
		lsr
		lsr
		nop
		ora $01
		lsr
		lsr
		nop
		eor $01
		lsr
		lsr
		eor #%00001010
		nop
		eor $01
		pha
		lda #%00001001
		bit $01
		sta $01
		bvc .lend1
		bpl .lerr1
		pla
		lda #%01000010
		jmp ROM_CBMSER_SSTATSEREND
.lerr1:
		lda #%01000000
		jsr ROM_SET_STATUS_HELPER
.lend1:
		pla
		clc
		rts
}
