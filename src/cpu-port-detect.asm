; Sets cpu_port_type in the RAM trampoline. Clobbers A/X.
; 0 = 7501/8501: DATA-out bit0 follows DATA-in bit7; bit5 reads 0
; 1 = 6510, $F30C DDR init ≠ $0F (Hackjunk patched)
; 2 = 6510, $F30C == $0F (stock KERNAL)
; 3 = unknown
KERNAL_CPU_DIR_INIT = $f30c

detect_cpu_port_type:
	!zone CpuPort_Detect {
	lda #0
	sta cpu_port_type
	lda $01
	pha
	; Try 8501: drive DATA-out low (clear bit 0), require bit 7 follow
	and #%11111110
	sta $01
	lda $01
	and #%10000000
	bne .not_8501		; bit7 still high while bit0 low → not 8501 DATA pair
	lda $01
	ora #%00000001
	sta $01
	lda $01
	and #%10000000
	beq .not_8501
	lda $01
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
