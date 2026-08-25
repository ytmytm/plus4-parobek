; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:10:35
; Input file: /tmp/jd1541_RECV.bin
; Page:       1


        .setcpu "6502"

LE9A5           := $E9A5
LFEF3           := $FEF3
        bne     LFF81
        lda     $7A
        ora     #$03
        sta     $44
LFF81:  lda     $023E,x
        ldx     $7A
        ldy     #$FF
        stx     $1800
        bne     LFFA5
        lda     $1800
        and     #$60
        sta     $7A
        ora     #$0D
        sta     $44
        jsr     LE9A5
        eor     #$0D
        sta     $1800
        jsr     LFEF3
        lda     ($30),y
LFFA5:  tax
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     $4B
        txa
        and     #$0F
        tax
        lda     $EA1D,x
        ldx     $7A
        stx     $1800
        .byte   $EC
