
HYPA0600:
        ldx     #<HYPALOAD_060E
        ldy     #>HYPALOAD_060E
        stx     RAM_ILOAD
        sty     RAM_ILOAD+1
        rts

ROM_LOAD:
        jmp     LF40C

HYPALOAD_060E:
        sta     $93
        lda     RAM_FA
        cmp     #$04
        bcc     ROM_LOAD
        lda     RAM_FNLEN
        beq     ROM_LOAD
        lda     #RAM_FNADR
        sta     a07DF
        jsr     RAM_RLUDES
        cmp     #'$'
        beq     ROM_LOAD
        ldx     #<E0633
        ldy     #>E0633
        stx     RAM_ISTOP
        sty     RAM_ISTOP+1
        jmp     LF06B

E0633:  pla                     ; XXX entrypoint
        pla
        ldx     #<EF265
        ldy     #>EF265
        stx     RAM_ISTOP
        sty     RAM_ISTOP+1
        jsr     L077C
        lda     #$01
        ldx     #DEV1551
        ldy     #$0F
        jsr     SETLFS
        lda     #$05
        ldx     #<HYPA0400      ; M-E, $0303
        ldy     #>HYPA0400
        jsr     SETNAM
        jsr     OPEN
        jmp     E0455

        brk
        brk
        brk
        brk

L065E:  lda     $9E             ; executed after load
        adc     #$00
        sta     $9E
        lda     $9D
        sta     $2D
        lda     $9E
        sta     $2E
        lda     $D0
        sta     TED_BORDER
        ldx     $9D
        ldy     $9E
        rts

        ldx     $9D             ; $0676 not referenced, NOT USED
        ldy     $9E
        rts

L067B:  pla                     ; executed after load, before 65e
        pha
        tay
        dey
        lda     ($9D),y
        cmp     #$FF
        bne     L068C
        pla
        tya
        pha
        lda     #$00
        sta     ($9D),y
L068C:  lda     #$1B
        sta     TED_FF06
        sta     BANK_ROM
        jmp     L06D3

E0697:  tya                     ; XXX entrypoint
        pha
        lda     #$00
        sta     ($9D),y
        tay
        sta     BANK_RAM
        dey
        sty     TCBM_DEV8_3
        ldy     #$40
        sty     TCBM_DEV8_2
        ldy     #$1B
        jmp     L067B

        brk

E06B0:  sei                     ; XXX entrypoint
        sta     BANK_RAM
        lda     #$0B
        sta     TED_FF06
        ldy     #$00
        ldy     $9F
        ldy     #$1C
        ldy     $A0
        ldy     #$00
        sty     TCBM_DEV8_2
        sty     TCBM_DEV8_3
        ldx     #$00
        rts

        brk
        brk
        brk
        brk
        eor     $31,x
        brk

L06D3:  nop
        nop
        cli
        pla
        clc
        adc     #$01
        sta     $9D
        jmp     L065E

        rts

E06E0:  lda     #<HYPADRVCODE            ; XXX entrypoint
        ldx     #>HYPADRVCODE
        sta     $03
        stx     $04
        lda     #$00
        ldx     #$03
        sta     $05
        stx     $06
L06F0:  lda     #DEV1551
        jsr     LISTEN
        lda     #$6F
        jsr     SECOND
        lda     #'M'
        jsr     CIOUT
        lda     #'-'
        jsr     CIOUT
        lda     #'W'
        jsr     CIOUT
        ldy     #$00
        lda     $05
        jsr     CIOUT
        lda     $06
        jsr     CIOUT
        lda     #$1E
        jsr     CIOUT
-       jsr     L076E
        nop
        nop
        iny
        cpy     #$1E
        bcc     -
        jsr     UNLISTEN
        clc
        lda     $03
        adc     #$1E
        sta     $03
        bcc     +
        inc     $04
+       clc
        lda     $05
        ldx     $06
        adc     #$1E
        sta     $05
        bcc     +
        inc     $06
+       cpx     #$06
        bcc     L06F0
        cmp     #$00
        bcc     L06F0
        lda     #DEV1551
        jsr     LISTEN
        lda     #$6F
        jsr     SECOND
        lda     #'M'
        jsr     CIOUT
        lda     #'-'
        jsr     CIOUT
        lda     #'E'
        jsr     CIOUT
        lda     #$00
        jsr     CIOUT
        lda     #$03
        jsr     CIOUT
        jsr     UNLISTEN
        rts

L076E:  sei
        sta     BANK_RAM
        lda     ($03),y
        sta     BANK_ROM
        cli
        jsr     CIOUT
        rts

L077C:  jsr     LEF3B
        jsr     LF211
        jsr     E045B
        lda     TED_BORDER
        sta     $D0
        lda     #$01
        jsr     CLOSE
        rts

        lda     $D0                     ; 0790 - restore colors, not referenced, NOT USED
        sta     TED_BORDER
        jmp     L8703

        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk
        brk

RAM_RLUDES:                     ; ROM routine, always present
        php
        sei
        sta     BANK_RAM
a07DF = *+1
        lda     ($A1),y
        sta     BANK_ROM
        plp
        rts

        clc
        brk
        brk
        !byte   $27
        brk
        brk
        ora     $1000
        brk
        brk
        brk
        brk
        brk
        brk
        !byte   $04
        bmi     L07F8
        brk
L07F8:  !byte   $80
        brk
        !byte   $04
        clc
        !byte   $04
        !byte   $03
