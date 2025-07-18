
; XXX load address is already in $9D/9E from ROM check

        !zone TCBM2SD_Fastload {

        jsr shared_rom_check
        bcc +
        jmp .LOADFAIL               ; file not found, fall back to ROM

+
; file exists, can load with utility command
        jsr ROM_UNTLK
	lda #0
	sta RAM_STATUS

        lda TED_BORDER          ; backup TED_BORDER
        sta RAM_TED_BORDER_BACKUP

	lda RAM_FA
	jsr ROM_LISTEN
	jsr ROM_READST          ; in fact that can't fail, since we reach here only if we have already detected T2SD
	and #%10000000          ; device not present?
	beq +
	jsr ROM_UNLISTEN
	lda #<tcbm2sd_load_error_txt
	ldy #>tcbm2sd_load_error_txt
	jsr print_msg
        jmp .LOADFAIL

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
        sta tcbmbase+3                                   ;// ;port A DDR = input first
        sta tcbmbase                                   ;// ;port A (to clear pullups?)
        sta tcbmbase+2                                   ;// ;DAV=0 - WE ARE READY

        bit tcbmbase+2                                   ;// ;wait for ACK low
        bmi *-3
        lda tcbmbase                                   ;// ;1st byte = load addr low  // need to flip ACK after this
        tay
        ldx tcbmbase+1                                   ;// STATUS
        lda #$40                                    ;// DAV=1 confirm
        sta tcbmbase+2
	txa
        and #%00000011
        beq +
.LOADFAIL:
        lda #4                  ; file not found (not realy, but we should not pass to ROM load)
	sta load_status		; return and don't pass to ROM load
        rts

        ; // adapted from Warpload 1551 with ACK after each data read

+       sei

-       bit tcbmbase+2                                   ;// ;wait for ACK high
        bpl -
        lda tcbmbase                                   ;// ;2nd byte = load addr high // need to flip ACK after this
        pha
        lda #$00                                    ;// DAV=0 confirm
        sta tcbmbase+2
        lda tcbmbase+1                                   ;// STATUS
        and #%00000011
        bne .LOADEND                                 ;// error

        pla                     ; A=hi, Y=lo addr from file
        ldx RAM_ZPVEC1		; The secondary address - do we use load
	bne +			;  us by the caller ?
	sty RAM_MEMUSS		; We use file's load addr. -> store it.
	sta RAM_MEMUSS+1
+

.LOADSTART:
        ldy #0
.LOADLOOP:
-       lda tcbmbase+2                                   ;// ;wait for ACK low
        bmi -
inc TED_BORDER
        lda tcbmbase
        sta (RAM_MEMUSS),y
        iny
        ldx tcbmbase+1                                   ;// STATUS
        lda #$40                                    ;// DAV=1 confirm
        sta tcbmbase+2
        txa                                         ;// EOI?
        and #%00000011
        bne .LOADEND

-       lda tcbmbase+2                                   ;// ;wait for DAV high
        bpl -
inc TED_BORDER
        lda tcbmbase                                   ;// XXX need to flip ACK after this
        sta (RAM_MEMUSS),y
        iny
        ldx tcbmbase+1                                   ;// STATUS
        lda #$00                                    ;// DAV=0 confirm
        sta tcbmbase+2
        txa                                         ;// EOI?
        and #%00000011
        bne .LOADEND

        tya
        bne .LOADLOOP
        inc RAM_MEMUSS+1
        bne .LOADLOOP

.LOADEND:
        lda #$40                                    ;// ;$40 = ACK (bit 6) to 1
        sta tcbmbase+2
        cli

        tya                                         ;// adjust end address (Y was already increased so just take care about low byte)
        clc
        adc RAM_MEMUSS
        sta RAM_MEMUSS
        bcc +
        inc RAM_MEMUSS+1
+

        lda #$ff                                    ;// ;port A to output (a bit delayed after ACK)
        sta tcbmbase+3

        lda RAM_TED_BORDER_BACKUP             ; restore colors
        sta TED_BORDER

        ldx RAM_MEMUSS
        ldy RAM_MEMUSS+1                                   ;// ;return end address+1 and C=0=no error
        clc                                         ;// no error
        rts

}
