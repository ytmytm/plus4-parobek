; Sets cpu_port_type in the RAM trampoline. Clobbers A/X.
; 0 = 7501/8501: DATA-in bit7 is inverted vs DATA-out bit0; bit5 reads 0
; 1 = 6510, $F30C DDR init ≠ $0F (Hackjunk patched)
; 2 = 6510, $F30C == $0F (stock KERNAL)
; 3 = unknown
; Polarity matches siziolib detect/detect.inc (bpl then bmi). Same-polarity
; follow classifies VICE 8501 as type 3 and skips SJL / 1541 SERIAL.
KERNAL_CPU_DIR_INIT = $f30c

detect_cpu_port_type:
	!zone CpuPort_Detect {
	lda #0
	sta cpu_port_type
	lda $01
	pha
	; The HackJunk KERNAL signature is unambiguous and does not depend on
	; transient IEC levels during drive reset.
	lda KERNAL_CPU_DIR_INIT
	cmp #%00001111
	beq .probe_port
	lda #1
	sta cpu_port_type
	jmp .restore
.probe_port:
	lda $01
	; Release DATA-out (clear bit 0): line high → DATA-in bit7 must be 1
	and #%11111110
	sta $01
	lda $01
	bpl .not_8501
	; Pull DATA-out (set bit 0): line low → DATA-in bit7 must be 0
	ora #%00000001
	sta $01
	bit $01
	bmi .not_8501
	and #%00100000
	bne .not_8501		; 8501 bit5 stuck 0
	lda #0
	sta cpu_port_type
	jmp .restore
.not_8501:
	; 6510: bits 7-6 clear, idle CLK-in on bit 5 high
	lda $01
	and #%11000000
	bne .unknown
	lda $01
	and #%00100000
	beq .unknown
	lda #1
	sta cpu_port_type
	lda KERNAL_CPU_DIR_INIT
	cmp #%00001111
	bne .restore		; patched → type 1
	inc cpu_port_type	; type 2
	jmp .restore
.unknown:
	lda #3
	sta cpu_port_type
.restore:
	pla
	sta $01
	rts
	}
