; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:10:35
; Input file: /tmp/jd1541_ff00.bin
; Page:       1


        .setcpu "6502"

LE85B           := $E85B
LE96D           := $E96D
LE9A5           := $E9A5
LE9AE           := $E9AE
LE9B7           := $E9B7
LEAA7           := $EAA7
LFB64           := $FB64
LFEE7           := $FEE7
LFEF3           := $FEF3
        sbc     #$AD
        .byte   $02
        .byte   $02
        cmp     #$2D
        beq     LFF0D
        sec
        sbc     #$2B
        bne     LFEE7
LFF0D:  sta     $23
        rts

        stx     $1803
        lda     #$02
        sta     $1800
        lda     #$1A
        sta     $1802
        jmp     LEAA7

LFF20:  lda     $1800
        and     #$01
        bne     LFF20
        lda     #$01
        sta     $1805
        rts

        lda     $31
        pha
        jsr     LE96D
        lda     #$04
LFF35:  pha
        ldy     #$01
        lda     ($30),y
        sta     $81
        tax
        dey
        lda     ($30),y
        sta     $80
        bne     LFF50
        pla
        clc
        sbc     $81
        inx
        stx     $30
        beq     LFF4F
        dec     $31
LFF4F:  pha
LFF50:  pla
        tay
        jsr     LFF8D
        lda     $80
        beq     LFF60
        jsr     LFB64
        lda     #$02
        bne     LFF35
LFF60:  sta     $30
        pla
        sta     $31
        jsr     LFF6E
        jsr     LFF6E
        jsr     LE9AE
LFF6E:  ldx     #$14
LFF70:  dex
        bne     LFF70
        jmp     LE9B7

LFF76:  jmp     LE85B

        bne     LFF81
        lda     $7A
        ora     #$03
        sta     $44
LFF81:  lda     $023E,x
        ldx     $7A
        ldy     #$FF
        stx     $1800
        bne     LFFA5
LFF8D:  lda     $1800
        and     #$60
        sta     $7A
        ora     #$0D
        sta     $44
        jsr     LE9A5
        eor     #$0D
        sta     $1800
        jsr     LFEF3
LFFA3:  lda     ($30),y
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
