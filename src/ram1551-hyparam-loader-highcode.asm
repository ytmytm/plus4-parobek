
; tcbmbase = TCBM_DEV8

; XXX put the code here for HypaRAM
; use $9D/E as target vector, $d0 for temporary storage
; skip over load address - it was already done with Kernal in shared_rom_check

!zone HypaRAM_Loader_Highcode {

        php
        sei
        lda     TED_FF06	; screen off
        and     #$EF
        sta     TED_FF06

        ; delay for M-E to activate and setup ports on the drive side
.L0461: ldx     #$03
--      ldy     #$00
-       nop
        iny
        bne     -
        dex
        bpl     --
        ; setup for LOAD: set DAV=0, Y=0
        ldy     #$00
        sty     tcbmbase+2     ; DAV=0
        sty     tcbmbase+3     ; port DDR = $00, input only

        ; get load address (and ignore it b/c it was already done with Kernal in shared_rom_check)
-       lda     tcbmbase+2
        bmi     -
        lda     tcbmbase+1     ; status EOF?
        bne     .load_end
        lda     tcbmbase       ; read data
;        sta     $9D            ; XXX not needed
+       lda     #$40
        sta     tcbmbase+2     ; DAV=1 - acknowledge data
-       lda     tcbmbase+2
        bpl     -
        lda     tcbmbase+1
        bne     .load_end
        lda     tcbmbase
;        sta     $9E            ; XXX not needed
        ldx     #0
        stx     tcbmbase+2     ; DAV=0 - acknowledge data
        ; load address is in $9D/E already, so we can skip this
;        lda     RAM_SA
;        bne     +
;        lda     $B4
;        sta     $9D
;        lda     $B5
;        sta     $9E

; loader loop, Y must be 0 at the start
.load_loop:
-       lda     tcbmbase+2
        bmi     -
        lda     tcbmbase+1     ; status EOF?
        bne     .load_end
        lda     tcbmbase       ; read data
        sta     ($9D),y
        iny
        bne     +
        inc     $9E
+       lda     #$40
        sta     tcbmbase+2     ; DAV=1 - acknowledge data
        inc     TED_BORDER
-       lda     tcbmbase+2
        bpl     -
        lda     tcbmbase+1
        bne     .load_end
        lda     tcbmbase
        sta     ($9D),y
        lda     #$00
        sta     tcbmbase+2     ; DAV=0 - acknowledge data
        iny
        bne     .load_loop
        inc     TED_BORDER
        inc     $9E
        bne     .load_loop

 ; end of load, addr in $9D/E, offset in Y
.load_end:
        tya
        clc
        adc     #$01
        sta     $9D
        lda     $9E
        adc     #$00
        sta     $9E

        ldx     #$ff
        stx     tcbmbase+3     ; port DDR = $FF, output only
        ldx     #$40
        stx     tcbmbase+2     ; DAV=1

        lda     RAM_TED_BORDER_BACKUP             ; restore colors
        sta     TED_BORDER
        lda     RAM_TED_FF06_BACKUP
        sta     TED_FF06
        plp

        ldx     $9D             ; load address
        ldy     $9E
        clc
        rts
}
