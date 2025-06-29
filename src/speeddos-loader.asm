
;SpeedDOS+ (40)	$F800-$F9AB
;executed from f7e5
;sent from f733 (slowly: 512 bytes via M-W)
;executed from f784 (m-'e',3,3)


; input flags in A:
; %1xxxxxxx - device is 1541 (already tested)
; dispatch code, CIA/VIA could use h/w handshake
; %x1xxxxxx - parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
; %xx1xxxxx - parallel cable connected to PIO at piobase $FD10 (6529)
; %xxx1xxxx - parallel cable connected to CIA at ciabase $FD90 (6526)
; %xxxx1xxx - parallel cable connected to VIA at viabase $FDA0 (6522)

SpeedDOS_load:  !zone SpeedDOS_Loader {
    // detect parallel cable (par1541-detect)
    // receive data, handshake over IEC lines like par1541-loader

        sta RAM_ZPVEC1 ; save type of interface

        jsr shared_rom_check
        bcc +

        lda #4                         ; file not found, fall back to ROM
        sta load_status
        rts
+

        lda     TED_BORDER
        sta     RAM_TED_BORDER_BACKUP
        lda     #$01
        jsr     ROM_CLOSE       ; close file #1, opened by ROM calls above?

        lda RAM_ZPVEC1
        tay
        and #%01000000
        beq +
        lda     #<SpeedDOS_drivecode_PPI
        ldx     #>SpeedDOS_drivecode_PPI
        sta     $03
        stx     $04
        lda     #<SpeedDOS_loader_PPI
        ldx     #>SpeedDOS_loader_PPI
        sta     $07
        stx     $08
        jmp     .SpeedDOS_SendCode

+       tya
        and #%00100000
        beq +
        lda     #<SpeedDOS_drivecode_PIO
        ldx     #>SpeedDOS_drivecode_PIO
        sta     $03
        stx     $04
        lda     #<SpeedDOS_loader_PIO
        ldx     #>SpeedDOS_loader_PIO
        sta     $07
        stx     $08
        jmp     .SpeedDOS_SendCode

+       tya
        and #%00010000
        beq +
        lda     #<SpeedDOS_drivecode_CIA
        ldx     #>SpeedDOS_drivecode_CIA
        sta     $03
        stx     $04
        lda     #<SpeedDOS_loader_CIA
        ldx     #>SpeedDOS_loader_CIA
        sta     $07
        stx     $08
        jmp     .SpeedDOS_SendCode

+       tya
        and #%00001000
        beq +
        lda     #<SpeedDOS_drivecode_VIA
        ldx     #>SpeedDOS_drivecode_VIA
        sta     $03
        stx     $04
        lda     #<SpeedDOS_loader_VIA
        ldx     #>SpeedDOS_loader_VIA
        sta     $07
        stx     $08

.SpeedDOS_SendCode:
        ; send 512 bytes from ($03) to drive at ($05) $0300
        lda     #$00                    ; drive address 0300
        ldx     #$03
        sta     $05
        stx     $06
.sendcodeloop:
        lda     #'W'
        jsr     .SpeedDOS_SendMCommand
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
+       cpx     #$05            ; send 2 pages ($0300-$04FF)
        bcc     .sendcodeloop

        lda     #'E'
        jsr     .SpeedDOS_SendMCommand
        lda     #$03
        jsr     ROM_CIOUT
        lda     #$03
        jsr     ROM_CIOUT
        jsr     ROM_UNLISTEN
        lda     #$00
        sta     load_status
        jmp     ($0007)         ; jump to loader

.SpeedDOS_SendMCommand:
        pha
        lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jsr     ROM_CIOUT
        pla
        jmp     ROM_CIOUT

}

; PPI version
!set par1541_interface = 1
SpeedDOS_drivecode_PPI:
!zone SpeedDOS_drivecode_PPI {
!source "speeddos-drivecode.asm"
}
SpeedDOS_drivecode_PPI_END:
SpeedDOS_loader_PPI:
!source "speeddos-loader-highcode.asm"

; PIO version
!set par1541_interface = 2
SpeedDOS_drivecode_PIO:
!zone SpeedDOS_drivecode_PIO {
!source "speeddos-drivecode.asm"
}
SpeedDOS_drivecode_PIO_END:
SpeedDOS_loader_PIO:
!source "speeddos-loader-highcode.asm"

; CIA version
!set par1541_interface = 3
SpeedDOS_drivecode_CIA:
!zone SpeedDOS_drivecode_CIA {
!source "speeddos-drivecode.asm"
}
SpeedDOS_drivecode_CIA_END:
SpeedDOS_loader_CIA:
!source "speeddos-loader-highcode.asm"

; VIA version
!set par1541_interface = 4
SpeedDOS_drivecode_VIA:
!zone SpeedDOS_drivecode_VIA {
!source "speeddos-drivecode.asm"
}
SpeedDOS_drivecode_VIA_END:
SpeedDOS_loader_VIA:
!source "speeddos-loader-highcode.asm"
