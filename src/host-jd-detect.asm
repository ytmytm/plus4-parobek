; Detect host JiffyDOS kernal by banner at $EB7D ("JIFFYDOS" on 6.01 PAL/NTSC).
; After trampoline is copied. Sets host_jd: skip DOS wedge; on IEC LOAD print
; HOST JIFFYDOS and fall through to ROM (no SJL). Clobbers A/X.

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
