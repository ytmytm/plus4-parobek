; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:10:52
; Input file: /tmp/jd_fe00.bin
; Page:       1


        .setcpu "6502"

L0008           := $0008
L0065           := $0065
L5344           := $5344
LCF7B           := $CF7B
LCFF1           := $CFF1
LD1A9           := $D1A9
LDFB7           := $DFB7
LE853           := $E853
LE85B           := $E85B
LE96D           := $E96D
LE99C           := $E99C
LE9A5           := $E9A5
LE9AE           := $E9AE
LE9B7           := $E9B7
LEA7D           := $EA7D
LEAA7           := $EAA7
LF11E           := $F11E
LF2B0           := $F2B0
LF6D0           := $F6D0
LF7A6           := $F7A6
LF7D1           := $F7D1
LFB64           := $FB64
LFB71           := $FB71
LFB73           := $FB73
        lda     $1C0C
        ora     #$E0
        sta     $1C0C
        lda     #$00
        sta     $1C03
        rts

        lda     $1C0C
        and     #$1F
        ora     #$C0
        sta     $1C0C
        lda     #$FF
        sta     $1C03
        lda     #$55
        sta     $1C01
        ldx     #$08
        ldy     #$00
LFE26:  .byte   $50
LFE27:  inc     $88B8,x
        bne     LFE26
        dex
        bne     LFE26
        rts

        jsr     LF7A6
        jsr     LF7D1
        jmp     LF6D0

        .byte   $BB
        jsr     LCFF1
        bne     LFE66
        jsr     LDFB7
        bne     LFE49
        cli
        jsr     LCF7B
        sei
LFE49:  and     #$07
        tax
        lda     $00,x
        bpl     LFE53
        jsr     LFB73
LFE53:  cli
        jsr     LF11E
        sei
        jsr     LD1A9
        ldx     $F9
        jsr     LFB71
        ldx     $F9
        lda     #$A0
        sta     $00,x
LFE66:  rts

        pha
        txa
        pha
        tya
        pha
        lda     $180D
        and     #$02
        beq     LFE76
        jsr     LE853
LFE76:  lda     $1C0D
        asl     a
        bpl     LFE7F
        jsr     LF2B0
LFE7F:  pla
        tay
        pla
        tax
        pla
        rti

        .byte   $12
        .byte   $04
        .byte   $04
        bcc     LFEE0
        eor     #$44
        eor     $5542
        bvc     LFEB7
        .byte   $43
        .byte   $52
        .byte   $53
        lsr     $0584
        cmp     ($F8,x)
        .byte   $1B
        .byte   $5C
        .byte   $07
        .byte   $A3
        beq     LFE27
        .byte   $23
        ora     $D0ED
        iny
        dex
        cpy     $E2CB
        .byte   $E7
        iny
        dex
        iny
        inc     $DD51
        .byte   $1C
        .byte   $9E
        .byte   $1C
        .byte   $52
        .byte   $57
        eor     ($4D,x)
        .byte   $44
LFEB7:  .byte   $53
        bvc     LFF0F
        jmp     L5344

        bvc     LFF14
        .byte   $52
        eor     $45
        .byte   $52
        .byte   $53
        eor     $4C
        eor     ($47),y
        .byte   $52
        jmp     L0008

        brk
        .byte   $3F
        .byte   $7F
        .byte   $BF
        .byte   $FF
        ora     ($12),y
        .byte   $13
        ora     $41,x
        .byte   $04
        bit     $1F
        ora     $0112,y
        .byte   $FF
        .byte   $FF
        ora     ($00,x)
LFEE0:  .byte   $03
        .byte   $04
        ora     $06
        .byte   $07
        .byte   $07
        .byte   $BB
LFEE7:  jmp     (L0065)

        sta     $1C00
        sta     $1C02
        jmp     LEA7D

LFEF3:  txa
        ldx     #$05
LFEF6:  dex
        bne     LFEF6
        tax
        rts

        jsr     LE9AE
        jmp     LE99C

        lda     $0202
        cmp     #$2D
        beq     LFF0D
        sec
        sbc     #$2B
        bne     LFEE7
LFF0D:  sta     $23
LFF0F:  rts

        stx     $1803
        .byte   $A9
LFF14:  .byte   $02
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
