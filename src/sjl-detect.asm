
; IEC error-channel classify for SD2IEC / JiffyDOS.
; Same shape as pi1551_detect / t2sd_detect: TALK $6F, read buffer, scan;
; UI (pi1551) only if the current message has no signature.

; Wedge (@ / $) uses cmd_text ($0343), not $0200 (BASIC BUF).
; iec_load uses status_buffer ($0200).

iec_st_ptr	= $d0
iec_st_ptrh	= $d1
iec_st_off	= $d2

; $d0/$d1 = buffer. Clear 40 bytes, TALK ch15, read up to 40.
; C=0 talked, C=1 device not present.
iec_fill_status:
	!zone FillStatus {
		lda #0
		sta RAM_STATUS
		ldy #40
-		dey
		sta (iec_st_ptr),y
		bne -
		jsr ROM_CLRCHN
		lda RAM_FA
		beq .fail
		jsr ROM_TALK
		jsr ROM_READST
		and #%11000000
		bne .fail
		lda #$6F
		jsr ROM_TKSA
		jsr ROM_READST
		and #%11000000
		bne .fail_untalk
		ldy #0
-		jsr ROM_ACPTR
		sta (iec_st_ptr),y
		jsr ROM_READST
		and #%01000000
		bne .ok
		iny
		cpy #40
		bne -
.ok:
		jsr ROM_CLRCHN
		jsr ROM_UNTLK
		clc
		rts
.fail_untalk:
		jsr ROM_UNTLK
.fail:
		jsr ROM_CLRCHN
		sec
		rts
	}

; Soft-reset the drive so the ident string returns. Same UI as pi1551_detect.
iec_send_ui:
	jsr ROM_CLRCHN
	lda RAM_FA
	jsr ROM_LISTEN
	jsr ROM_READST
	and #%10000000
	bne +
	lda #$6F
	jsr ROM_SECOND
	lda #'U'
	jsr ROM_CIOUT
	lda #'I'
	jsr ROM_CIOUT
+	jmp ROM_UNLISTEN

; Scan $d0/$d1 for JIFFYDOS / SD2IEC (t2sd_detect loop). OR sticky flags.
iec_or_drive_flags:
	lda #0
	sta iec_st_off
.jd_outer:
	ldy iec_st_off
	ldx #0
-	lda iec_sig_jd,x
	beq .jd_hit
	cmp (iec_st_ptr),y
	bne .jd_next
	iny
	inx
	bne -
.jd_hit:
	lda iec_drive_flags
	ora #%00000010
	sta iec_drive_flags
	jmp .sd
.jd_next:
	inc iec_st_off
	lda iec_st_off
	cmp #40
	bne .jd_outer
.sd:
	lda #0
	sta iec_st_off
.sd_outer:
	ldy iec_st_off
	ldx #0
-	lda iec_sig_sd,x
	beq .sd_hit
	cmp (iec_st_ptr),y
	bne .sd_next
	iny
	inx
	bne -
.sd_hit:
	lda iec_drive_flags
	ora #%00000001
	sta iec_drive_flags
	rts
.sd_next:
	inc iec_st_off
	lda iec_st_off
	cmp #40
	bne .sd_outer
	rts

iec_sig_jd:	!text "JIFFYDOS", 0
iec_sig_sd:	!text "SD2IEC", 0

iec_point_cmd:
	lda #<cmd_text
	sta iec_st_ptr
	lda #>cmd_text
	sta iec_st_ptrh
	rts

iec_point_0200:
	lda #<status_buffer
	sta iec_st_ptr
	lda #>status_buffer
	sta iec_st_ptrh
	rts

; Fill + scan using cmd_text. Used from @.
iec_note_wedge:
	jsr iec_point_cmd
	jsr iec_fill_status
	bcs +
	jsr iec_or_drive_flags
	clc
+	rts

; Fill cmd_text, scan, print. @ must not touch $0200.
iec_print_drive_status:
	jsr iec_note_wedge
	bcs +
	ldy #0
-	lda (iec_st_ptr),y
	beq +
	jsr ROM_CHROUT
	iny
	cpy #40
	bne -
+	rts

; LOAD path: current status, then UI if still unclassified
; (directory "$" is ROM-only and does not classify).
iec_note_drive_class:
	jsr iec_point_0200
	jsr iec_fill_status
	bcs .try_ui
	jsr iec_or_drive_flags
	lda iec_drive_flags
	and #%00000011
	bne .ok
.try_ui:
	jsr iec_send_ui
	jsr iec_point_0200
	jsr iec_fill_status
	bcs .fail
	jsr iec_or_drive_flags
.ok:
	clc
	rts
.fail:
	sec
	rts

; C=1 → do not run SJL. C=0 → SJL allowed.
datasette_blocks_sjl:
	!zone DatasetteGate {
		lda $01
		and #%00001000
		beq .block
		clc
		rts
.block:
		lda #<datasette_txt
		ldy #>datasette_txt
		jsr print_msg
		sec
		rts
datasette_txt:
		!text "DATASETTE, SKIP SJL",13,0
	}
