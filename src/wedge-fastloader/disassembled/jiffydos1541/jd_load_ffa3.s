; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:10:35
; Input file: /tmp/jd1541_LOAD.bin
; Page:       1


        .setcpu "6502"

LFF76           := $FF76
LFFA3:  lda     ($30),y
        tax
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
LFFB8:  cpx     $1800
        beq     LFFB8
        sta     $1800
        asl     a
        and     #$0F
        nop
        sta     $1800
        ldx     $4B
        lda     $EA1D,x
        sta     $1800
        asl     a
        and     #$0F
        iny
        sta     $1800
        bne     LFFA3
        nop
        lda     $44
        sta     $1800
LFFDE:  cmp     $1800
        bcc     LFF76
        bne     LFFDE
        rts

        dec     $C8
        .byte   $8F
        sbc     $CD5F,y
        .byte   $97
        cmp     $0500
        .byte   $03
        ora     $06
        ora     $09
        ora     $0C
        ora     $0F
        ora     $01
        .byte   $FF
        ldy     #$EA
        .byte   $67
        .byte   $FE
