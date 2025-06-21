
t2sd_fastload:
        !zone TCBM2SD_Fastload {

; (same thing as in hypaload)
; copy of ROM code between F06B (load from serial) and F0A5 (where JSR FFE1 is called - test for STOP)
        LDX   RAM_SA
        JSR   $F160
        LDA   #$60
        STA   RAM_SA
        JSR   $F005
        LDA   RAM_FA
        JSR   $EDFA
        LDA   RAM_SA
        JSR   $EE1A
        JSR   $EC8B
        STA   $9D
        LDA   RAM_STATUS
        LSR
        LSR
        BCS   .LF0E8
        JSR   $EC8B
        STA   $9E
        TXA
        BNE   .LF09C
        LDA   RAM_MEMUSS
        STA   $9D
        LDA   RAM_MEMUSS+1
        STA   $9E
.LF09C  JSR   $F189
.LF09F  LDA   #$FD
        AND   RAM_STATUS
        STA   RAM_STATUS
        jmp   t2sd_can_load             ; continue our code

.LF0E8   ; JMP   LF27C                  ; print "I/O ERROR #4" 
        JMP LOADFAIL

; file exists, can load with utility command
t2sd_can_load:
        jsr ROM_UNTLK
	lda #0
	sta RAM_STATUS

	lda RAM_FA
	jsr ROM_LISTEN
	jsr ROM_READST          ; in fact that can't fail, since we reach here only if we have already detected T2SD
	and #%10000000          ; device not present?
	beq +
	jsr ROM_UNLISTEN
	lda #<tcbm2sd_load_error_txt
	ldy #>tcbm2sd_load_error_txt
	jsr print_msg
        jmp LOADFAIL

+       lda #$6F
        jsr ROM_SECOND
        lda #'U'                ; utility command
        jsr ROM_CIOUT
        lda #'0'
        jsr ROM_CIOUT
        lda #%00011111          ; fastload
        jsr ROM_CIOUT

	lda #RAM_FNADR		;filename at ($AF/$B0)
	sta a07DF
	ldy #0
-	jsr RAM_RLUDES		;RLUDES  Indirect routine
        jsr ROM_CIOUT
        iny
        cpy RAM_FNLEN
        bne -

        jsr ROM_UNLISTEN

        lda #0
        sta TCBM_DEV8_3                                   ;// ;port A DDR = input first
        sta TCBM_DEV8                                   ;// ;port A (to clear pullups?)
        sta TCBM_DEV8_2                                   ;// ;DAV=0 - WE ARE READY

        bit TCBM_DEV8_2                                   ;// ;wait for ACK low
        bmi *-3
        lda TCBM_DEV8                                   ;// ;1st byte = load addr low  // need to flip ACK after this
        tay
        ldx TCBM_DEV8_1                                   ;// STATUS
        lda #$40                                    ;// DAV=1 confirm
        sta TCBM_DEV8_2
	txa
        and #%00000011
        beq +
LOADFAIL:
        lda #4                  ; file not found (not realy, but we should not pass to ROM load)
	sta load_status		; return and don't pass to ROM load
        rts

        ; // adapted from Warpload 1551 with ACK after each data read

+       sei

-       bit TCBM_DEV8_2                                   ;// ;wait for ACK high
        bpl -
        lda TCBM_DEV8                                   ;// ;2nd byte = load addr high // need to flip ACK after this
        pha
        lda #$00                                    ;// DAV=0 confirm
        sta TCBM_DEV8_2
        lda TCBM_DEV8_1                                   ;// STATUS
        and #%00000011
        bne LOADEND                                 ;// error

        pla                     ; A=hi, Y=lo addr from file
        ldx RAM_ZPVEC1		; The secondary address - do we use load
	bne +			;  us by the caller ?
	sty RAM_MEMUSS		; We use file's load addr. -> store it.
	sta RAM_MEMUSS+1
+

LOADSTART:
        ldy #0
LOADLOOP:
        lda TCBM_DEV8_2                                   ;// ;wait for ACK low
        bmi *-3
inc TED_BORDER
        lda TCBM_DEV8
        sta (RAM_MEMUSS),y
        iny
        ldx TCBM_DEV8_1                                   ;// STATUS
        lda #$40                                    ;// DAV=1 confirm
        sta TCBM_DEV8_2
        txa                                         ;// EOI?
        and #%00000011
        bne LOADEND

        lda TCBM_DEV8_2                                   ;// ;wait for DAV high
        bpl *-3
inc TED_BORDER
        lda TCBM_DEV8                                   ;// XXX need to flip ACK after this
        sta (RAM_MEMUSS),y
        iny
        ldx TCBM_DEV8_1                                   ;// STATUS
        lda #$00                                    ;// DAV=0 confirm
        sta TCBM_DEV8_2
        txa                                         ;// EOI?
        and #%00000011
        bne LOADEND

        tya
        bne LOADLOOP
        inc RAM_MEMUSS+1
        bne LOADLOOP

LOADEND:
        lda #$40                                    ;// ;$40 = ACK (bit 6) to 1
        sta TCBM_DEV8_2
        cli

        tya                                         ;// adjust end address (Y was already increased so just take care about low byte)
        clc
        adc RAM_MEMUSS
        sta RAM_MEMUSS
        bcc LOADRET
        inc RAM_MEMUSS+1

LOADRET:
        lda #$ff                                    ;// ;port A to output (a bit delayed after ACK)
        sta TCBM_DEV8_3

        ldx RAM_MEMUSS
        ldy RAM_MEMUSS+1                                   ;// ;return end address+1 and C=0=no error
        clc                                         ;// no error
        rts

tcbm2sd_load_error_txt:
	!text "TCBM2SD LOAD ERROR",13,0

}
