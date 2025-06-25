
; input flags in A:
; %1xxxxxxx - device is 1541
; %x1xxxxxx - parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
; %xx1xxxxx - parallel cable connected to PIO at piobase $FD10 (6529)
; %xxx1xxxx - parallel cable connected to CIA at ciabase $FD90 (6526)
; %xxxx1xxx - parallel cable connected to VIA at viabase $FDA0 (6522)

RAM_MSIZ = $0533     ; BASIC top

LFBB7           = $FBB7        ; store X/Y/Z to temp
LFBC1           = $FBC1        ; restore X/Y/Z from temp
LF215           = $F215

TED_FF1D        = $FF1D

; memory layout
trampoline_buffer = $0340   ; tape buffer
GCR_SECTOR_BUFFER	= $DE00 ; decoded sector; drivecode + $0100
GCR_TRACK_BUFFER	= GCR_SECTOR_BUFFER+$0100 ; 21*$0146 (DF00-F9BD)

par1541_load:
; this is common part
        !zone PAR1541_Loader {

        sta RAM_ZPVEC1 ; save type of interface

        jsr shared_rom_check
        bcc +

        lda #4                         ; file not found, fall back to ROM
        sta load_status
        rts
+
        ;jsr     LEF3B
        ;jsr     LF211

        lda RAM_MSIZ+1
        cmp #>GCR_SECTOR_BUFFER
        beq .ram_moved

        ; lower memory top
        lda #>GCR_SECTOR_BUFFER
        sta RAM_MSIZ+1

        ; the only part of L802E we need to copy
        LDX   #$02
-       LDA   $0532,x                 ; copy start of memory pointer to
        STA   $36,x                   ; end of string storage
        STA   $32,x                   ; and end of arrays.
        DEX    
        BNE   -                

        ;jsr     L8117   ; initialize vectors
        ;jsr     L802E   ; initalize BASIC
        ;jsr     L80C2   ; poweron message
        ;jmp     L8025   ; start BASIC interpreter

        lda #<.ram_moved_txt
        ldy #>.ram_moved_txt
        jsr print_msg

.ram_moved:
        lda     TED_BORDER
        sta     RAM_TED_BORDER_BACKUP

        lda     #<EPAR41_DRV_0300
        sta     $D1
.SendDrvCodeLoop:
        jsr     .SendMCommand
        lda     #'W'
        jsr     ROM_CIOUT
        lda     $D1
        jsr     ROM_CIOUT
        lda     #>EPAR41_DRV_0300
        jsr     ROM_CIOUT
        lda     #$20	; batch size
        jsr     ROM_CIOUT
        ldy     $D1
        clc
        lda     $D1
        adc     #$20	; batch size
        sta     $D1
-       lda     EPAR41_DRVCODE,y
        jsr     ROM_CIOUT
        iny
        cpy     $D1
        bne     -
        jsr     ROM_UNLISTEN
        lda     $D1
        bne     .SendDrvCodeLoop

        lda #$00
        sta load_status
        jsr .prepare_fastload

        ; M-E EPAR41_DRV_038F
        jsr     .SendMCommand
        lda     #'E'
        jsr     ROM_CIOUT
        lda     #<EPAR41_DRV_038F
        jsr     ROM_CIOUT
        lda     #>EPAR41_DRV_038F
        jsr     ROM_CIOUT
        jsr     ROM_UNLISTEN

        jsr     trampoline_buffer ; this is the trampoline

        php
        jsr     LFBB7   ; store X/Y/Z to temp
        lda     #$0F
        sta     $00
        jsr     LF215
        lda     RAM_TED_BORDER_BACKUP
        sta     TED_BORDER
        jsr     LFBC1   ; restore X/Y/Z from temp
        plp
        rts

; %x1xxxxxx - parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
; %xx1xxxxx - parallel cable connected to PIO at piobase $FD10 (6529)
; %xxx1xxxx - parallel cable connected to CIA at ciabase $FD90 (6526)
; %xxxx1xxx - parallel cable connected to VIA at viabase $FDA0 (6522)

.prepare_fastload:
        lda RAM_ZPVEC1
        tay
        and #%01000000
        beq +
        lda #<FASTLOAD_PPI
        ldx #>FASTLOAD_PPI
        sta $d0
        stx $d1
        lda #<FASTLOAD_PPI_END
        ldx #>FASTLOAD_PPI_END
        sta $d2
        stx $d3
        jmp .fastload_copy
+       tya
        and #%00100000
        beq +
        lda #<FASTLOAD_PIO
        ldx #>FASTLOAD_PIO
        sta $d0
        stx $d1
        lda #<FASTLOAD_PIO_END
        ldx #>FASTLOAD_PIO_END
        sta $d2
        stx $d3
        jmp .fastload_copy
+       tya
        and #%00010000
        beq +
        lda #<FASTLOAD_CIA
        ldx #>FASTLOAD_CIA
        sta $d0
        stx $d1
        lda #<FASTLOAD_CIA_END
        ldx #>FASTLOAD_CIA_END
        sta $d2
        stx $d3
        jmp .fastload_copy
+       tya
        and #%00001000
        beq +
        lda #<FASTLOAD_VIA
        ldx #>FASTLOAD_VIA
        sta $d0
        stx $d1
        lda #<FASTLOAD_VIA_END
        ldx #>FASTLOAD_VIA_END
        sta $d2
        stx $d3

.fastload_copy:

        lda #<EPAR41_HIGHCODE_TGT
        ldx #>EPAR41_HIGHCODE_TGT
        sta $d4
        stx $d5

        ldy #0
-       lda ($d0),y
        sta ($d4),y
        inc $d0
        bne +
        inc $d1
+       inc $d4
        bne +
        inc $d5
+       lda $d0
        cmp $d2
        bne -
        lda $d1
        cmp $d3
        bne -

        ldy #0
-       lda .trampoline,y
        sta trampoline_buffer,y
        iny
        cpy #.trampoline_end-.trampoline
        bne -

        rts
;-------------------------------

.trampoline:
        !pseudopc trampoline_buffer {
            sei
            sta     RAM_SELECT
            jsr     EPAR41_HIGHCODE_TGT
            sta     ROM_SELECT
            cli
            rts
        }
.trampoline_end:

;-------------------------------

.SendMCommand:
        lda     RAM_FA
        jsr     ROM_LISTEN
        lda     #$6F
        jsr     ROM_SECOND
        lda     #'M'
        jsr     ROM_CIOUT
        lda     #'-'
        jmp     ROM_CIOUT

;-------------------------------

; there would be a lot of code duplication here, but we have space in ROM

EPAR41_HIGHCODE_TGT = $f9be

FASTLOAD_PIO:
!set par1541_interface = 1
	!pseudopc EPAR41_HIGHCODE_TGT {
	!source "par1541-loader-highcode.asm"
	}
FASTLOAD_PIO_END:

FASTLOAD_PPI:
!set par1541_interface = 2
	!pseudopc EPAR41_HIGHCODE_TGT {
	!source "par1541-loader-highcode.asm"
	}
FASTLOAD_PPI_END:

FASTLOAD_CIA:
!set par1541_interface = 3
	!pseudopc EPAR41_HIGHCODE_TGT {
	!source "par1541-loader-highcode.asm"
	}
FASTLOAD_CIA_END:

FASTLOAD_VIA:
!set par1541_interface = 4
	!pseudopc EPAR41_HIGHCODE_TGT {
	!source "par1541-loader-highcode.asm"
	}
FASTLOAD_VIA_END:

;-------------------------------

.ram_moved_txt:
        !text   "RAM MOVED"
        !byte   $0D,$00
;-------------------------------

EPAR41_DRV_0300 = $0300 ; drive code at $0300
EPAR41_DRV_038F = $038F ; startup address
EPAR41_DRVCODE:
        !binary "par41drv0300.bin"


        } ; zone