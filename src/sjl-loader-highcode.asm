; SJL264 receive path — ROM-resident, no self-mod.
; Sequence matches upstream loader_routine after rom_iec_open:
;   set CPU-port DDR → TALK/$60 → busin addr → UNTALK → TALK/$61 → transfer
; SJL_jd_transfer: shared JD .loadloop entry for fast1541iec (no $61).

SJL_highcode:
!zone SJL_LoaderHighcode {
		sei

		lda cpu_port_type
		cmp #1
		beq .motor_ok_6510

		lda $01
		and #%00001000
		bne .motor_ok
		jsr ROM_IEC_CLOSE_SETUP
		lda #$80
		sta load_status
		jmp .return_error

.motor_ok:
		lda #%00001000
		sta $01			; IEC released, cass. RD driven low
		lda #%00011111
		sta $00			; DDR: ATN/CLK/DAT/cass.RD out (upstream hack)
		jmp .port_ready

.motor_ok_6510:
		lda #0
		sta $01			; IEC released; no cass. motor bit
		lda #$0e
		sta $00			; DDR: CLK/ATN/DATA out (Hackjunk; never $1F)
		; type 1: never $00=$1F (would make DATA in an output)
.port_ready:
		lda #0
		sta RAM_STATUS

		; --- address phase on channel 0 (SA $60), SJL bitbang ---
		lda RAM_FA
		jsr sjl_talk
		lda #$60
		jsr sjl_sectalk
		jsr sjl_busin
		sta $9d
		lda RAM_STATUS
		lsr
		lsr
		bcc .filefound

.filenotfound:
		jsr sjl_untalk
		jsr ROM_IEC_CLOSE_SETUP
		lda #4
		sta load_status
		jmp .return_error

.filefound:
		jsr sjl_busin
		sta $9e
		jsr sjl_untalk

		; SA==0 → relocate to caller's address
		lda load_sa
		bne .have_addr
		lda RAM_MEMUSS
		sta $9d
		lda RAM_MEMUSS+1
		sta $9e

.have_addr:
		lda $9e
		cmp #$0a
		bcs .ldaddrokay
		jsr ROM_IEC_CLOSE_SETUP
		lda #$80
		sta load_status
		jmp .return_error

.ldaddrokay:
		jsr eF189			; LOADING / VERIFYING

		; --- JD fastload phase (SA $61) ---
		lda #$61
		sta RAM_SA
		lda RAM_FA
		jsr sjl_talk
		lda #$61
		jsr sjl_sectalk

		jsr sjl_receive_vec
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

; Entry for fast1541iec after M-E: address already in $9D/$9E, TED already
; blanked/1MHz, no TALK/$61. Must not untalk/close (channel already CLOSED).
SJL_jd_transfer:
		sei
		lda cpu_port_type
		cmp #1
		beq .jd_port_6510
		lda #%00001000
		sta $01
		lda #%00011111
		sta $00
		; sync: replace busy wait full SJL gets from sjl_sectalk
.wait_busy:
		bit $01			; sync: drive CLK low (busy)
		bvs .wait_busy
		jmp .jd_go
.jd_port_6510:
		lda #0
		sta $01
		lda #$0e
		sta $00
.wait_busy_6510:
		lda $01
		and #%00100000
		bne .wait_busy_6510
.jd_go:
		jsr sjl_receive_vec
		lda #0
		sta load_status
		ldx $9d
		ldy $9e
		jmp .return_ok

; Timed JD receive only (delay + loadloop + EOI status). Caller handles bus teardown.
sjl_jd_receive_loop:
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
		rts

; Type-1 (Hackjunk 6510) JD receive. Four $01 samples (bits 0/5) are packed
; and looked up (see tests/check_sjl6510_decode.py); IEC waits use bit 0
; (DATA in) and bit 5 (CLK in).
SJL_SMP0	= $04		; S0/S3 use forced absolute stores for exact timing
SJL_SMP1	= $02		; S1/S2 use 3-cycle ZP stores
SJL_SMP2	= $03
SJL_SMP3	= $05
SJL_PACK	= SJL_SMP0	; S0 is dead when partial decode starts

!macro SJL_PACK_SAMPLES {
		ldx SJL_SMP0
		lda sjl_pair0_256,x
		sta SJL_PACK
		ldx SJL_SMP1
		lda sjl_pair1_256,x
		ora SJL_PACK
		sta SJL_PACK
		ldx SJL_SMP2
		lda sjl_pair2_256,x
		ora SJL_PACK
		sta SJL_PACK
		ldx SJL_SMP3
		lda sjl_pair3_256,x
		ora SJL_PACK
}

sjl_jd_receive_loop_6510:
!zone SJL_Receive6510 {
		ldy #$00
		ldx #231
.wait1:
		dex
		bne .wait1

.loadloop:
		lda #0
		sta $01
.wait_clk_drive:
		lda $01
		and #%00100000
		beq .wait_clk_drive
		lda $01
		lsr
		bcs .loadendover
.wait_data_drive:
		lda $01
		lsr
		bcc .wait_data_drive

.transferbyte:
		nop
		nop
		nop
		nop
		lda #0
		ldx #%00001000		; DATA out low (bit 3), CLK released
		stx $01
		lda $01
		and #%00100000
		beq .loadloop
		sta $01			; release DATA (A still 0)
		lda $01			; S0
		and #%00100001
		sta+2 SJL_SMP0		; force 4-cycle store; keeps S0/S1 gap at 9
		lda $01			; S1
		and #%00100001
		sta SJL_SMP1
		nop
		lda $01			; S2
		and #%00100001
		sta SJL_SMP2
		nop
		lda $01			; S3
		and #%00100001
		sta+2 SJL_SMP3		; force 4-cycle store; timing ends at S3
		+SJL_PACK_SAMPLES

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
		lda $01
		and #%00100000
		beq .end_ok
		dex
		bne .end_check
		lda #%01000010
		!by $2c
.end_ok:
		lda #%01000000
		jsr ROM_SET_STATUS_HELPER
		rts

}

!source "../tests/gen_sjl6510_luts.asm"

sjl_restore:
		lda RAM_SA_BACKUP
		sta RAM_SA
		lda RAM_TED_BORDER_BACKUP
		sta TED_BORDER
		lda RAM_TED_FF06_BACKUP
		sta TED_FF06
		lda RAM_TED_FF13_BACKUP
		sta TED_FF13
		lda cpu_port_type
		cmp #1
		beq .r6510
		lda #$0f
		sta $00
		; Leave $01 bit3 set so datasette_blocks_sjl does not false-trigger
		;  on the next LOAD (SJL drives that bit during the transfer).
		lda $01
		ora #%00001000
		sta $01
		jmp ROM_CBMSER_DAT_HIZ
.r6510:
		lda #$0e
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
		lda cpu_port_type
		cmp #1
		beq .lsend_d6510
		bit $01
		bmi .devprescont
		jmp .send_timeout
.lsend_d6510:
		lda $01
		lsr
		bcs .devprescont
.send_timeout:
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
		lda cpu_port_type
		cmp #1
		beq .clklo6510
		lda $01
		and #%11111110
		ora #%00000010
		sta $01
		jmp .clklo_done
.clklo6510:
		lda $01
		and #%11110111
		ora #%00000010
		sta $01
.clklo_done:
		and #%00000100
		beq .ltwobitsent
		lda $95
		ror
		ror
		cpx #2
		bne .ltwobitsent
		ldx #$1e
.lwack1:
		lda cpu_port_type
		cmp #1
		beq .lwack1_6510
		bit $01
		bpl .lwack2
		jmp .lwack1_more
.lwack1_6510:
		lda $01
		lsr
		bcc .lwack2
.lwack1_more:
		dex
		bne .lwack1
		beq .lcont6
.lwack2:
		lda cpu_port_type
		cmp #1
		beq .lwack2_6510
		bit $01
		bpl .lwack2
		jmp .lcont6
.lwack2_6510:
		lda $01
		lsr
		bcc .lwack2_6510
.lcont6:
		ldx #2
.ltwobitsent:
		dex
		bne .lsendbits
		ldx #$56
.lcont7:
		dex
		beq .ltbtimeout
		lda cpu_port_type
		cmp #1
		beq .lcont7_6510
		lda $01
		bmi .lcont7
		jmp .lcont7_done
.lcont7_6510:
		lda $01
		lsr
		bcs .lcont7
.lcont7_done:
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
		lda cpu_port_type
		cmp #1
		beq .st6510
		lda #%00001001
		sta $01
.waitclk:
		bit $01
		bvs .waitclk
		rts
.st6510:
		lda #%00001000
		sta $01
.waitclk6510:
		lda $01
		and #%00100000
		bne .waitclk6510
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
		lda cpu_port_type
		cmp #1
		beq sjl_busin_6510
.busin8501:
		lda $01
		cmp #%01000000
		bcc .busin8501
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

; Type-1 address byte: four lda $01 samples, pack + LUT (see busin cycle test).
sjl_busin_6510:
.bwait:
		lda $01
		and #%00100000
		beq .bwait
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		lda #0			; release DATA (Hackjunk DATA-out is bit 3)
		nop
		nop
		sta $01
		nop
		lda $00
		nop
		nop
		nop
		lda $01			; S0
		and #%00100001
		sta+2 SJL_SMP0		; force 4-cycle absolute store for timing
		lda $01			; S1
		and #%00100001
		sta+2 SJL_SMP1		; force 4-cycle absolute store for timing
		lda $01			; S2
		and #%00100001
		sta+2 SJL_SMP2		; force 4-cycle absolute store for timing
		lda $01			; S3
		and #%00100001
		sta+2 SJL_SMP3		; force 4-cycle absolute store for timing
		+SJL_PACK_SAMPLES
		pha
		lda #%00001000
		sta $01
		; Keep the raw port byte in X while A tests CLK and DATA separately.
		; LDX $01 cannot replace this pair: the following AND needs the same
		; sample in A, and TXA here would cost the same two cycles as TAX.
		lda $01
		tax
		and #%00100000
		beq .blend1
		txa
		lsr
		bcc .blerr1
		pla
		lda #%01000010
		jmp ROM_CBMSER_SSTATSEREND
.blerr1:
		lda #%01000000
		jsr ROM_SET_STATUS_HELPER
.blend1:
		pla
		clc
		rts

}
