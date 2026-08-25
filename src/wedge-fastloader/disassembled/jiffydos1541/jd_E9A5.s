; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:11:33
; Input file: /tmp/jd_E9A5.bin
; Page:       1


        .setcpu "6502"

        lda     $1800
        ora     #$02
        sta     $1800
        rts

        lda     $1800
        ora     #$08
        sta     $1800
        rts

        lda     $1800
        and     #$F7
        sta     $1800
        rts

LE9C0:  lda     $1800
        cmp     $1800
        bne     LE9C0
        rts

        lda     #$08
        sta     $4B
