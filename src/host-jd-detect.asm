; Scan host kernal for "JIFFYDOS". Sets host_jd (lowmem).
; Call only after lowmem trampoline is copied.
; Uses $d0/$d1 as scan pointer; does not touch the drive.

detect_host_jiffydos:
	!zone HostJD_Detect {
		lda #0
		sta host_jd
		lda #<$e000
		sta $d0
		lda #>$e000
		sta $d1
.page:
		ldy #0
.pos:
		ldx #0
-		lda .sig,x
		beq .found
		cmp ($d0),y
		bne .next
		iny
		inx
		bne -
.found:
		lda #1
		sta host_jd
		rts
.next:
		iny
		bne .pos
		inc $d1
		lda $d1
		bne .page
		rts
.sig:
		!text "JIFFYDOS", 0
	}
