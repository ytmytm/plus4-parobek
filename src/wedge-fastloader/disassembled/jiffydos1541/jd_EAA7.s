; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:11:33
; Input file: /tmp/jd_EAA7.bin
; Page:       1


        .setcpu "6502"

LEA6E           := $EA6E
LEB1F           := $EB1F
        inx
        ldy     #$00
        ldx     #$00
LEAAC:  txa
        sta     $00,x
        inx
        bne     LEAAC
LEAB2:  txa
        cmp     $00,x
        bne     LEA6E
LEAB7:  inc     $00,x
        iny
        bne     LEAB7
        cmp     $00,x
        bne     LEA6E
        sty     $00,x
        lda     $00,x
        bne     LEA6E
        inx
        bne     LEAB2
LEAC9:  inc     $6F
        stx     $76
        lda     #$00
        sta     $75
        tay
        ldx     #$20
        clc
LEAD5:  dec     $76
LEAD7:  adc     ($75),y
        iny
        bne     LEAD7
        dex
        bne     LEAD5
        adc     #$00
        tax
        cmp     $76
        bne     LEB1F
        cpx     #$C0
        bne     LEAC9
        lda     #$01
        sta     $76
        inc     $6F
        ldx     #$07
        tya
        clc
        adc     $76
        .byte   $91
