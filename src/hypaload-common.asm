
; this is based on disassembled Hypaload v4.7

; NOTE: this doesn't work in VICE, can be tested on YaPe
; NOTE: too many bytes sent to the drive, drivecode is shorter by at least 32 bytes
; NOTE: can be optimized and cleaned up

        !zone Hypaload_Common {

Hypaload_SendDriveCode:
        lda     #<HYPADRVCODE
        ldx     #>HYPADRVCODE
        sta     $03
        stx     $04
        lda     #$00                    ; drive address 0300
        ldx     #$03
        sta     $05
        stx     $06
.L06F0: lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jsr     ROM_CIOUT
        lda     #'W'
        jsr     ROM_CIOUT
        ldy     #$00
        lda     $05
        jsr     ROM_CIOUT
        lda     $06
        jsr     ROM_CIOUT
        lda     #$1E            ; chunk size
        jsr     ROM_CIOUT
-       lda     ($03),y         ; this must be in ROM, in lower 16k
        jsr     ROM_CIOUT
        iny
        cpy     #$1E
        bcc     -
        jsr     ROM_UNLISTEN
        clc
        lda     $03
        adc     #$1E            ; next chunk address
        sta     $03
        bcc     +
        inc     $04
+       clc
        lda     $05
        ldx     $06
        adc     #$1E            ; next chunk address
        sta     $05
        bcc     +
        inc     $06
+       cpx     #$06            ; send 3 pages ($0300-$05FF)
        bcc     .L06F0
        cmp     #$00
        bcc     .L06F0

        ; common M-E $03xx (xx in A)
        lda     #$00            ; M-E $0300
Hypaload_MemoryExec:
        pha
        lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jsr     ROM_CIOUT
        lda     #'E'
        jsr     ROM_CIOUT
        pla
        jsr     ROM_CIOUT
        lda     #$03
        jsr     ROM_CIOUT
        jmp     ROM_UNLISTEN        ; run code at $03xx

HYPADRVCODE:
        !binary "hypadrv0300.bin", $280, 2

        }