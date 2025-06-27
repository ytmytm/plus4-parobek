
; this is based on disassembled Hypaload v4.7

; NOTE: this doesn't work in VICE, can be tested on YaPe
; NOTE: too many bytes sent to the drive, drivecode is shorter by at least 32 bytes
; NOTE: can be optimized and cleaned up

        !zone Hypaload_Fastload {

        jsr shared_rom_check
        bcc +

        lda #4                         ; file not found, fall back to ROM
        sta load_status
        rts
+
        jsr     LEF3B
        jsr     LF211

        jsr     delay   ; entry point XXX
        jsr     Hypaload_SendDriveCode

        lda     TED_BORDER
        sta     RAM_TED_BORDER_BACKUP
        lda     #$01
        jsr     ROM_CLOSE       ; close file #1, opened by ROM calls above?

        lda     #$03
        jsr     Hypaload_MemoryExec ; M-E $0303

        jsr     delay   ; entry point XXX

        sei                     ; XXX entrypoint
        lda     #$0B
        sta     TED_FF06
        ;ldy     #$00            ; $9F/A0 are not used, but are set to $1C00
        ;ldy     $9F
        ;ldy     #$1C
        ;ldy     $A0
        ldy     #$00            ; TCBM I/O input setup
        sty     tcbmbase+2
        sty     tcbmbase+3
        ldx     #$00
;        rts

.L040B:  
-       lda     tcbmbase+2
        bmi     -
        lda     tcbmbase+1
        bne     .L0445
        lda     tcbmbase
        sta     ($9D),y
        iny
        bne     +
        inc     $9E
+       sta     TED_BORDER
        eor     #$E0
        sta     TED_BORDER
-       lda     tcbmbase+2
        bpl     -
        lda     tcbmbase+1
        bne     .L0445
        lda     tcbmbase
        sta     ($9D),y
        iny
        bne     .L040B
        sta     TED_BORDER
        eor     #$E0
        sta     TED_BORDER
        inc     $9E
        bne     .L040B
.L0445:

        tya
        pha
        lda     #$00
        sta     ($9D),y
        tay
        dey
        sty     tcbmbase+3
        ldy     #$40
        sty     tcbmbase+2
        ldy     #$1B

        pla
        pha
        tay
        dey
        lda     ($9D),y
        cmp     #$FF
        bne     +
        pla
        tya
        pha
        lda     #$00
        sta     ($9D),y
+       lda     #$1B
        sta     TED_FF06

        cli
        pla
        clc
        adc     #$01
        sta     $9D
        bcc     +
        inc     $9E
+
;        lda     $9D
;        sta     $2D
;        lda     $9E
;        sta     $2E
        lda     RAM_TED_BORDER_BACKUP             ; restore colors
        sta     TED_BORDER
        ldx     $9D             ; load address
        ldy     $9E
        rts

        }