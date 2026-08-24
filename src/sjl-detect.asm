
; IEC status read and substring scan for SD2IEC / JiffyDOS detection.
; status_buffer ($0200) is defined in t2s-detect.asm (first source user).

; Talk error channel, read up to 40 bytes into status_buffer. No UI.
; C=0 read attempted, C=1 device not present.
iec_read_status:
	!zone IEC_ReadStatus {
		lda #0
		sta RAM_STATUS
		ldx #40
-		dex
		sta status_buffer,x
		bne -
		jsr ROM_CLRCHN
		lda RAM_FA
		jsr ROM_LISTEN
		jsr ROM_READST
		and #%10000000
		beq +
		jsr ROM_UNLISTEN
		sec
		rts
+		lda #$6F
		jsr ROM_SECOND
		jsr ROM_UNLISTEN		; open error channel without command
		lda RAM_FA
		jsr ROM_TALK
		lda #$6F
		jsr ROM_TKSA
		ldx #0
-		jsr ROM_ACPTR
		sta status_buffer,x
		jsr ROM_READST
		and #%01000000
		bne +
		inx
		cpx #40
		bne -
+		jsr ROM_CLRCHN
		jsr ROM_UNTLK
		clc
		rts
	}

; A/Y = needle address (0-terminated). Scan status_buffer[0..39].
; C=0 found, C=1 not found. Uses $d0-$d2.
scan_status_for:
	!zone ScanStatus {
		sta $d0
		sty $d1
		lda #0
		sta $d2
.outer:
		ldy #0
		ldx $d2
.inner:
		lda ($d0),y
		beq .found
		cpx #40
		bcs .next
		cmp status_buffer,x
		bne .next
		inx
		iny
		bne .inner
		jmp .next
.found:		clc
		rts
.next:		inc $d2
		lda $d2
		cmp #40
		bcc .outer
		sec
		rts
	}

status_has_sd2iec:
	lda #<.sig_sd2iec
	ldy #>.sig_sd2iec
	jmp scan_status_for
.sig_sd2iec:	!text "SD2IEC", 0

status_has_jiffydos:
	lda #<.sig_jd
	ldy #>.sig_jd
	jmp scan_status_for
.sig_jd:	!text "JIFFYDOS", 0

; C=1 → do not run SJL (datasette conflict). C=0 → SJL allowed.
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
		jsr print_msg_always
		sec
		rts
datasette_txt:
		!text "DATASETTE, SKIP SJL",13,0
	}
