; Scan host kernal for "JIFFYDOS". Sets host_jd (lowmem).
; Call only after lowmem trampoline is copied.
; Uses $d0-$d3: $d0/$d1 candidate pointer, $d2/$d3 compare pointer.
; Candidates $E000..$FFF8 only (8-byte needle; >=$FFF9 would wrap into ZP).
; Does not touch the drive.

detect_host_jiffydos:
	!zone HostJD_Detect {
		lda #0
		sta host_jd
		lda #<$e000
		sta $d0
		lda #>$e000
		sta $d1
.loop:
		lda $d1
		cmp #$ff
		bne .scan
		lda $d0
		cmp #$f9
		bcs .done
.scan:
		ldx #0
		lda $d0
		sta $d2
		lda $d1
		sta $d3
.byte:
		lda .sig,x
		beq .found
		ldy #0
		cmp ($d2),y
		bne .next
		inc $d2
		bne .bp_ok
		inc $d3
.bp_ok:
		inx
		bne .byte
.found:
		lda #1
		sta host_jd
		rts
.next:
		inc $d0
		bne .loop
		inc $d1
		bne .loop
.done:
		rts
.sig:
		!text "JIFFYDOS", 0
	}
