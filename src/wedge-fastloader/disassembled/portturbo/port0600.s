
; tu jest listen/second/ciout/unlisten bez jumptable

; zp
; D1
; D4 (nawet nie odczytany?)

ROM_IACPTR           	= $EC8B ; ACPTR
ROM_ICIOUT           	= $ECDF ; CIOUT
ROM_ITALK           	= $EDFA ; TALK
ROM_ITKSA           	= $EE1A ; TKSA
ROM_ILISTEN         	= $EE2C ; LISTEN
ROM_ISECOND         	= $EE4D	; SECOND
LEF0C           	= $EF0C
ROM_IUNLISTEN           = $EF23 ; UNLISTEN
LF005           = $F005
eF160           = $F160	; print 'SEARCHING'
eF189           = $F189 ; print 'LOADING'
LF215           = $F215
LF27C           = $F27C
LFBB7           = $FBB7
LFBC1           = $FBC1

INSTALL:ldx     #<NEWLOAD
        ldy     #>NEWLOAD
        stx     RAM_ILOAD
        sty     RAM_ILOAD+1
        rts

ROMLOAD:jmp     $F04C

NEWLOAD:sta     RAM_VERFCK
        lda     RAM_FA
        cmp     #$04
        bcc     ROMLOAD
        lda     RAM_FNLEN
        beq     ROMLOAD
        lda     #RAM_FNADR
        sta     a07DF
        ldy     #$00
        jsr     RAM_RLUDES
        cmp     #'$'
        beq     ROMLOAD
        lda     RAM_FA
        sta     RAM_LA
        jsr     eF160
        jsr     LEF0C
        ldx     RAM_SA
        stx     $D4
        lda     #$60
        sta     RAM_SA
        jsr     LF005
        lda     RAM_FA
        jsr     ROM_ITALK
        lda     RAM_SA
        jsr     ROM_ITKSA
        jsr     ROM_IACPTR
        lda     RAM_STATUS
        lsr
        lsr
        bcc     +
        jmp     LF27C

+	jsr     eF189
        lda     #<EPAR41_DRV_0300
        sta     $D1
L065A:  jsr     L06B0
        lda     #'W'
        jsr     ROM_ICIOUT
        lda     $D1
        jsr     ROM_ICIOUT
        lda     #>EPAR41_DRV_0300
        jsr     ROM_ICIOUT
        lda     #$20	; batch size
        jsr     ROM_ICIOUT
        ldy     $D1
        clc
        lda     $D1
        adc     #$20	; batch size
        sta     $D1
-	sei
        sta     RAM_SELECT
        lda     EPAR41_DRVCODE_TGT,y
        sta     ROM_SELECT
        cli
        jsr     ROM_ICIOUT
        iny
        cpy     $D1
        bne     -
        jsr     ROM_IUNLISTEN
        lda     $D1
        bne     L065A
        jsr     L06B0
        lda     #'E'
        jsr     ROM_ICIOUT
        lda     #<EPAR41_DRV_038F
        jsr     ROM_ICIOUT
        lda     #>EPAR41_DRV_038F
        jsr     ROM_ICIOUT
        jsr     ROM_IUNLISTEN
        sei
        sta     RAM_SELECT
        jmp     L06D8

L06B0:  lda     RAM_FA
        jsr     ROM_ILISTEN
        lda     #$6F
        jsr     ROM_ISECOND
        lda     #'M'
        jsr     ROM_ICIOUT
        lda     #'-'
        jmp     ROM_ICIOUT

L06C4:  sta     ROM_SELECT
        cli
        php
        jsr     LFBB7
        lda     #$0F
        sta     $00
        jsr     LF215
        jsr     LFBC1
        plp
        rts

L06D8:  jsr     FASTLOAD
        jmp     L06C4

