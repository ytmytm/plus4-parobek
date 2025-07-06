
START:  
	ldx     #$00
-	lda     EPAR41_LOWCODE,x
        sta     EPAR41_LOWCODE_TGT,x
        lda     EPAR41_DRVCODE,x
        sta     EPAR41_DRVCODE_TGT,x
        lda     EPAR41_HIGHCODE,x
        sta     EPAR41_HIGHCODE_TGT,x
        lda     EPAR41_HIGHCODE+$0100,x
        sta     EPAR41_HIGHCODE_TGT+$0100,x
        lda     EPAR41_HIGHCODE+$0200,x
        sta     EPAR41_HIGHCODE_TGT+$0200,x
        inx
        bne     -
        jsr     EPAR41_LOWCODE_TGT
        lda     #$DD	; ??? high page for basic ???
        sta     $0534   ; memory top
        lda     #$08	; keydef len
        ldx     #$00	; key num (0=F1)
        stx     $76
        ldx     #<.L1507
        ldy     #>.L1507
        stx     $22
        sty     $23
        jsr     ROM_DOAKEY
        lda     #$00	; ???
        sta     $05EC
        sta     $05ED
        sta     $05EE
        sta     $05EF
        jmp     .L150F

.L1507:
        !text   "SYS1536"
        !byte   $0D

.L150F: jsr     L8117
        jsr     L802E
        jsr     L80C2
        jsr     ROM_PRINTIMM
        !byte   $0D
        !text   " PORT-TURBO V1 BY PIGMY"
        !byte   $0D,$0D,$00

        jmp     L8025

