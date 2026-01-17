
; Hypaload-like loader for 1551 with RAMBoard installed
; (with Hypaload RAM code disassembled this could replace hypaload and use handshake protocol)

; input flags in A:
; %0xxxxxx1 - YTM's 1551 TrackCache ROM (supports Hypaload-like loader out of the box) https://github.com/ytmytm/1551-RAMBOard
; %0xxxxxx0 - plain 1551

HypaRAM_load:  !zone HypaRAM_Loader {

        sta RAM_ZPVEC1 ; save type of interface

        jsr shared_rom_check
        bcc +

        lda #4                         ; file not found, fall back to ROM
        sta load_status
        rts
+

        lda     TED_FF06
        sta     RAM_TED_FF06_BACKUP
        lda     TED_BORDER
        sta     RAM_TED_BORDER_BACKUP
        lda     #$01
        jsr     ROM_CLOSE       ; close file #1, opened by ROM calls above?

	lda RAM_FA
	cmp #9
	beq +
	lda     #<HypaRAM_loader_8    ; computer-side loader is common
        ldx     #>HypaRAM_loader_8
        sta     $07
        stx     $08
	jmp     .HypaRAM_InterfaceCheck
+	lda     #<HypaRAM_loader_9    ; computer-side loader is common
        ldx     #>HypaRAM_loader_9
        sta     $07
        stx     $08

.HypaRAM_InterfaceCheck:
        ldy     RAM_ZPVEC1          ; interface type?
        beq     +
        lda     #<$0300         ; M-E address of plain 1551 drivecode
        ldx     #>$0300
        sta     $d6
        stx     $d7
        jmp     .HypaRAM_SendCode

+       lda     #<$A003         ; M-E address of drivecode in ROM
        ldx     #>$A003
        sta     $d6
        stx     $d7
        jmp     .HypaRAM_SendMemoryExec

.HypaRAM_SendCode:
        lda     #<hypa1551_drivecode ; plain 1551 needs drivecode
        ldx     #>hypa1551_drivecode
        sta     $03
        stx     $04
        lda     #<hypa1551_drivecode_start  ; drive address $0300
        ldx     #>hypa1551_drivecode_start
        sta     $05
        stx     $06
        ; send bytes from ($03) to drive at ($05) $0300
.sendcodeloop:
        lda     #'W'
        jsr     .HypaRAM_SendMCommand
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
        bcc     .sendcodeloop

        ; fall through to .HypaRAM_SendMemoryExec

.HypaRAM_SendMemoryExec
        lda     #'E'
        jsr     .HypaRAM_SendMCommand
        lda     $d6
        jsr     ROM_CIOUT
        lda     $d7
        jsr     ROM_CIOUT
        jsr     ROM_UNLISTEN
        lda     #$00
        sta     load_status
        jmp     ($0007)         ; jump to loader

.HypaRAM_SendMCommand:
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

!set tcbmbase = TCBM_DEV8
HypaRAM_loader_8:
!source "ram1551-hyparam-loader-highcode.asm"

!set tcbmbase = TCBM_DEV9
HypaRAM_loader_9:
!source "ram1551-hyparam-loader-highcode.asm"
