; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 16:11:33
; Input file: /tmp/jd_FEF3.bin
; Page:       1


        .setcpu "6502"

LE99C           := $E99C
LE9AE           := $E9AE
LFEE7           := $FEE7
        txa
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
        rts

        stx     $1803
        lda     #$02
        sta     $1800
        lda     #$1A
        .byte   $8D
