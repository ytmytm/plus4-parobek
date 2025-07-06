HYPA0400:
        !text   "M-E"
        !word   $0303

        !byte $bd, $00, $00

L0408:  jsr     E06B0
L040B:  
-       lda     TCBM_DEV8_2
        bmi     -
        lda     TCBM_DEV8_1
        bne     L0445
        lda     TCBM_DEV8
        sta     ($9D),y
        iny
        bne     +
        inc     $9E
+       sta     TED_BORDER
        eor     #$E0
        sta     TED_BORDER
-       lda     TCBM_DEV8_2
        bpl     -
        lda     TCBM_DEV8_1
        bne     L0445
        lda     TCBM_DEV8
        sta     ($9D),y
        iny
        bne     L040B
        sta     TED_BORDER
        eor     #$E0
        sta     TED_BORDER
        inc     $9E
        bne     L040B
L0445:  jmp     E0697

        jmp     E0697

        brk
        !byte $bd, $00, $00
        !byte $bd, $00, $00
        !byte $bd, $00, $00

E0455:  jsr     L0461   ; entry point XXX
        jmp     L0408

E045B:  jsr     L0461   ; entry point XXX
        jmp     E06E0

L0461:  ldx     #$03
--      ldy     #$00
-       nop
        iny
        bne     -
        dex
        bpl     --
        rts

        brk
        !byte $bd, $00
