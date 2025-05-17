
;; detect tcbm2sd device from 'TCBM2SD' string existing in reset string

status_buffer = $0fc0 ; $0fc0 to make it visible in status line on screen (XXX DEBUG)

; return C=0 - device is TCBM2SD, C=1 - device is not TCBM2SD (IEC or 1551)

t2sd_detect:
        !zone TCBM2SD_Detect {

	lda RAM_FNLEN		; preserve the filename length
	pha
	lda RAM_SA		; same with secondary address
	sta RAM_ZPVEC1		; temp

	lda #0
	sta RAM_FNLEN		; no filename for command channel
	lda #15
	sta RAM_SA		; secondary address 15 == command channel
	lda #CMD_CHANNEL
	sta RAM_LA		; logical file number (15 might be in use)
	jsr ROM_OPEN
	sta ErrNo+1
        lda RAM_ZPVEC1	; restore secondary address
        sta RAM_SA
	pla
	sta RAM_FNLEN		; restore filename length
        bcs detect_t2sd_2       ; error
	ldx #CMD_CHANNEL
	jsr ROM_CHKOUT		; command channel as output
	sta ErrNo+1
	bcs detect_t2sd_2       ; error

        lda #'U'                ; soft reset
        jsr ROM_CHROUT
        lda #'I'
        jsr ROM_CHROUT
;	jsr ROM_CLRCHN		; clear channels	 ; XXX needed?

        ldx #CMD_CHANNEL        ; file number
        jsr ROM_CHKIN

        ldx #0                  ; read status message
-       jsr ROM_READST
        bne detect_t2sd_2
        jsr ROM_CHRIN
        sta status_buffer,x     ; message line
        inx
        cpx #40                 ; one line at most
        bne -

detect_t2sd_2:
        jsr ROM_CLRCHN
        lda #CMD_CHANNEL        ; channel
        jsr ROM_CLOSE

        ; search for signature
        lda #<status_buffer
        sta $d0
        lda #>status_buffer
        sta $d1
        ldy #0      ; check start
        sty $d2

detect_t2sd_sigloop1:
        ldy $d2
        ldx #0
-       lda detect_t2sd_signature,x
        beq detect_t2sd_detected
        cmp ($d0),y
        bne detect_t2sd_signext
        iny
        inx
        bne -

detect_t2sd_detected:
        ;; TCBM2SD detected
        clc
        rts

detect_t2sd_signext:            ; next character
        inc $d2
        lda $d2
        cmp #40-7-5
        bne detect_t2sd_sigloop1
        ;; TCBM2SD not detected
        sec
        rts

detect_t2sd_signature:
        !text "TCBM2SD", 0

        ; XXX unused
detect_1551_signature:
        !text "TDISK", 0
}

