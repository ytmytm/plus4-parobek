; Detect host JiffyDOS kernal by banner at fixed address $EB7D.
; Plus/4 JiffyDOS 6.01 PAL/NTSC: "JIFFYDOS V6.01..." (stock kernal has no match).
; Call only after lowmem trampoline is copied. Clobbers A/X. Sets host_jd.

detect_host_jiffydos:
	!zone HostJD_Detect {
		lda #0
		sta host_jd
		ldx #0
-		lda .sig,x
		beq .found
		cmp $eb7d,x
		bne .done
		inx
		bne -
.found:
		lda #1
		sta host_jd
.done:
		rts
.sig:
		!text "JIFFYDOS", 0
	}
