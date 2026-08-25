; Shared IEC memory-command helpers (M-W / M-E / M-R prefix) and TED enter.
; iec_mw_one_chunk clobbers ZP $09 (chunk length). Do not STA ROM for length.

iec_m_minus:
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

; A = payload length (e.g. $20 or $1E). Src ($03), dest ($05)/$06.
; C=1 if RAM_STATUS & $83 after UNLISTEN.
iec_mw_one_chunk:
	sta $09
	lda #'W'
	jsr iec_m_minus
	lda $05
	jsr ROM_CIOUT
	lda $06
	jsr ROM_CIOUT
	lda $09
	jsr ROM_CIOUT
	ldy #0
-	lda ($03),y
	jsr ROM_CIOUT
	iny
	cpy $09
	bne -
	jsr ROM_UNLISTEN
	lda RAM_STATUS
	and #$83
	beq +
	sec
	rts
+	clc
	rts

iec_me:
	lda #'E'
	jsr iec_m_minus
	lda $d6
	jsr ROM_CIOUT
	lda $d7
	jsr ROM_CIOUT
	jmp ROM_UNLISTEN

ted_sjl_enter:
	lda TED_BORDER
	sta RAM_TED_BORDER_BACKUP
	lda TED_FF06
	sta RAM_TED_FF06_BACKUP
	and #$ef
	sta TED_FF06
	lda TED_FF13
	sta RAM_TED_FF13_BACKUP
	ora #%00000010
	sta TED_FF13
	rts
