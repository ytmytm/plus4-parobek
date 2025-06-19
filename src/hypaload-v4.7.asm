
; this is based on disassembled Hypaload v4.7

; NOTE: this doesn't work in VICE, can be tested on YaPe
; NOTE: too many bytes sent to the drive, drivecode is shorter by at least 32 bytes
; NOTE: can be optimized and cleaned up
; NOTE: commands go to current device (RAM_FA), but I/O fixed to #8 (TCBM_DEV8_x)

LEF3B           = $EF3B
LF211           = $F211
EF265           = $F265

TED_FF06        = $FF06

; copy of ROM code between F06B (load from serial) and F0A5 (where JSR FFE1 is called - test for STOP)
        LDX   RAM_SA
        JSR   $F160
        LDA   #$60
        STA   RAM_SA
        JSR   $F005
        LDA   RAM_FA
        JSR   $EDFA
        LDA   RAM_SA
        JSR   $EE1A
        JSR   $EC8B
        STA   $9D
        LDA   RAM_STATUS
        LSR
        LSR
        BCS   LF0E8
        JSR   $EC8B
        STA   $9E
        TXA
        BNE   LF09C
        LDA   RAM_MEMUSS
        STA   $9D
        LDA   RAM_MEMUSS+1
        STA   $9E
LF09C   JSR   $F189
LF09F   LDA   #$FD
        AND   RAM_STATUS
        STA   RAM_STATUS
        jmp   L077C                     ; continue our code

LF0E8   ; JMP   LF27C                   ; print "I/O ERROR #4" 
        lda #4
        sta load_status
        rts

; JSR L077C inline
L077C:  jsr     LEF3B
        jsr     LF211
;        jsr     E045B

E045B:  jsr     L0461   ; entry point XXX
        jsr     E06E0   ; send drivecode

        lda     TED_BORDER
        sta     $D0
        lda     #$01
        jsr     ROM_CLOSE       ; close file #1, opened by ROM calls above?

        lda     #$03
        jsr     HYPA_MEMORYEXEC ; M-E $0303

;        jmp     E0455
E0455:  jsr     L0461   ; entry point XXX
        ;jmp     L0408

L0408:  ;jsr     E06B0
E06B0:  sei                     ; XXX entrypoint
        lda     #$0B
        sta     TED_FF06
        ldy     #$00            ; $9F/A0 are not used, but are set to $1C00
        ldy     $9F
        ldy     #$1C
        ldy     $A0
        ldy     #$00            ; TCBM I/O input setup
        sty     TCBM_DEV8_2
        sty     TCBM_DEV8_3
        ldx     #$00
;        rts

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
L0445:  ;jmp     E0697

E0697:  tya                     ; XXX entrypoint
        pha
        lda     #$00
        sta     ($9D),y
        tay
        dey
        sty     TCBM_DEV8_3
        ldy     #$40
        sty     TCBM_DEV8_2
        ldy     #$1B
;        jmp     L067B

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
;        jmp     L06D3

L06D3:  nop
        nop
        cli
        pla
        clc
        adc     #$01
        sta     $9D
;        jmp     L065E

L065E:  lda     $9E             ; executed after load
        adc     #$00
        sta     $9E
        lda     $9D
        sta     $2D
        lda     $9E
        sta     $2E
        lda     $D0             ; restore colors
        sta     TED_BORDER
        ldx     $9D             ; load address
        ldy     $9E
        rts

E06E0:  lda     #<HYPADRVCODE            ; XXX entrypoint
        ldx     #>HYPADRVCODE
        sta     $03
        stx     $04
        lda     #$00                    ; drive address 0300
        ldx     #$03
        sta     $05
        stx     $06
L06F0:  lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jsr     ROM_CIOUT
        lda     #'W'
        jsr     ROM_CIOUT
        ldy     #$00
        lda     $05
        jsr     ROM_CIOUT
        lda     $06
        jsr     ROM_CIOUT
        lda     #$1E            ; chunk size
        jsr     ROM_CIOUT
-       lda     ($03),y         ; this must be in ROM, in lower 16k
        jsr     ROM_CIOUT
        iny
        cpy     #$1E
        bcc     -
        jsr     ROM_UNLISTEN
        clc
        lda     $03
        adc     #$1E            ; next chunk address
        sta     $03
        bcc     +
        inc     $04
+       clc
        lda     $05
        ldx     $06
        adc     #$1E            ; next chunk address
        sta     $05
        bcc     +
        inc     $06
+       cpx     #$06            ; send 3 pages ($0300-$05FF)
        bcc     L06F0
        cmp     #$00
        bcc     L06F0

        ; common M-E $03xx (xx in A)
        lda     #$00            ; M-E $0300
HYPA_MEMORYEXEC:
        pha
        lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jsr     ROM_CIOUT
        lda     #'E'
        jsr     ROM_CIOUT
        pla
        jsr     ROM_CIOUT
        lda     #$03
        jsr     ROM_CIOUT
        jsr     ROM_UNLISTEN        ; initialize $0300
        rts

L0461:  ldx     #$03
--      ldy     #$00
-       nop
        iny
        bne     -
        dex
        bpl     --
        rts

HYPADRVCODE:
        !binary "hypadrv0300.bin", $280, 2
