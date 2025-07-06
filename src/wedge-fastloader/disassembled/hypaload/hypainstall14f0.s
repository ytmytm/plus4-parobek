!to "hypaload_1551.prg",cbm

DEV1551 = 8

MEMSIZ = $37

RAM_FNLEN       = $AB
RAM_FA          = $AE
RAM_FNADR       = $AF
DRV_STARTUP     = $0303
RAM_ISTOP       = $0326
RAM_ILOAD       = $032E
HYPALOAD_060E   = $060E
;RAM_RLUDES      = $07D9
;a07DF           = $07DF
L80C2           = $80C2
L8703           = $8703
L8A7B           = $8A7B
LD88B           = $D88B
LD89A           = $D89A
EF265           = $F265
LF397           = $F397
LEF3B           = $EF3B
LF06B           = $F06B
LF211           = $F211
LF40C           = $F40C

HYPADRVCODE     = $FA80
TCBM_DEV8       = $FEF0
TCBM_DEV8_1     = $FEF1
TCBM_DEV8_2     = $FEF2
TCBM_DEV8_3     = $FEF3
TED_FF06        = $FF06
TED_BORDER      = $FF19
BANK_ROM        = $FF3E
BANK_RAM        = $FF3F
PRINT_IMM       = $FF4F
SECOND          = $FF93
CIOUT           = $FFA8
UNLISTEN        = $FFAE
LISTEN          = $FFB1
SETLFS          = $FFBA
SETNAM          = $FFBD
OPEN            = $FFC0
CLOSE           = $FFC3

        *=$1000
EHYPADRVCODE:
        !binary "hypadrv0300.bin", $280, 2

EHYPA0600:
        !if * != $1280 { !error "EHYPA0600 NOT AT $1280 *=", * }
        !pseudopc $0600 {
        !source "hypa0600.s"
        }

        !byte 0,0

EHYPA0400:
        !if * != $1480 { !error "EHYPA0400 NOT AT $1480 *=", * }
        !pseudopc $0400 {
        !source "hypa0400.s"
        }

HYPAINSTALL:
        !if * != $14F0 { !error "HYPAINSTALL NOT AT $14F0 *=", * }
        ldx     #$00
-       lda     EHYPADRVCODE,x
        sta     HYPADRVCODE,x
        lda     EHYPADRVCODE+$0100,x
        sta     HYPADRVCODE+$0100,x
        lda     EHYPA0600,x
        sta     HYPA0600,x
        lda     EHYPA0600+$0100,x
        sta     HYPA0600+$0100,x
        inx
        bne     -

        ldx     #$7F
-       lda     EHYPADRVCODE+$0200,x
        sta     HYPADRVCODE+$0200,x
        dex
        bpl     -

        ldx     #$6E
-       lda     EHYPA0400,x
        sta     HYPA0400,x
        dex
        bpl     -

        lda     #<HYPADRVCODE-1 ; pull down BASIC top adderss to protect drivecode
        sta     MEMSIZ
        lda     #>HYPADRVCODE-1
        sta     MEMSIZ+1
        jsr     L8A7B
        jsr     LD89A
        jsr     LD88B
        jsr     L80C2

        jsr     PRINT_IMM
        !byte   $0D
        !byte   " "
        !byte   $12
        !text   " HYPALOAD 1551 V4.7 "
        !byte   $92
        !text   " (C)9/7/90 CEEKAY"
        !byte   $0D
        !byte   $00

        jsr     HYPA0600
        lda     #$00            ; restore $00 at start of BASIC program area
        sta     $1000
        jsr     LF397
        jmp     L8703

        ; junk
        rts

        brk
        !byte $bd, $00, $00
        !byte $bd, $00, $00
        !byte $bd, $00, $00
        lda     $BD00,x
