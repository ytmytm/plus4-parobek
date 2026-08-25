; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:10:35
; Input file: /tmp/jd1541_SEND.bin
; Page:       1


        .setcpu "6502"

L40A0           := $40A0
LE9C9           := $E9C9
LFC43           := $FC43
LFC65           := $FC65
LFC87           := $FC87
        lda     $98
        bne     LFBC8
LFBC5:  .byte   $4C
LFBC6:  cmp     #$E9
LFBC8:  lda     $1800
        and     #$04
        sta     $1800
LFBD0:  bit     $1800
        bne     LFBD0
        pha
        pla
        lda     $1800
        asl     a
        pha
        pla
        ora     $1800
        and     #$0F
        tax
        ldy     $7A
        lda     $1800
        asl     a
        pha
        pla
        ora     $1800
        and     #$0F
        ora     LFC08,x
        sta     $85
        lda     $1800
        ora     #$02
        sta     $1800
        bmi     LFBC5
        and     #$04
        bne     LFC05
        sty     $F8
LFC05:  lda     $85
        rts

LFC08:  brk
        .byte   $80
        jsr     L40A0
        cpy     #$60
        cpx     #$10
        bcc     LFC43
        bcs     LFC65
        bne     LFC87
        beq     LFBC6
        .byte   $0C
        .byte   $1C
        and     #$1F
        ora     #$C0
        sta     $1C0C
        lda     #$FF
        sta     $1C03
        rts

        lda     #$FF
        ldx     #$05
        bit     $55A9
LFC2F:  bvc     LFC2F
        clv
        sta     $1C01
        dex
        bne     LFC2F
        rts

        plp
        sty     $0628
        ldx     $3D
        lda     $39
