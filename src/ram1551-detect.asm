
; detect if that's a 1551 with RAMBoard installed or plain 1551

; return flags in A:
; %0xxxxxx1 - YTM's 1551 TrackCache ROM (supports Hypaload-like loader out of the box) https://github.com/ytmytm/1551-RAMBOard
; %0xxxxxx0 - plain 1551

!set ram1551_debug = 0 ; 0 - no debug, 1 - debug

ram1551_detect:
        !zone RAM1551_Detect {

            lda #$00            ; by default device is a plain 1551 -> fall back on ROM
            sta $d3

; check if YTM's 1551 TrackCache ROM is installed - 'RAM' at $a000

            lda #<.trackcache_rom
            sta $d0
            lda #>.trackcache_rom
            sta $d1
            lda #6
            sta $d2
            jsr .send_command

            lda RAM_FA
            jsr ROM_TALK
            lda #$6F
            jsr ROM_TKSA
            jsr ROM_ACPTR
            pha             ; 'R'
            jsr ROM_ACPTR
            pha             ; 'A'
            jsr ROM_ACPTR
            pha             ; 'M'
            jsr ROM_UNTLK
            pla
            tax
            pla
            tay
            pla
            !if ram1551_debug = 1 {
            sta $0c00
            sty $0c01
            stx $0c02
            }
            cmp #'R'
            bne +
            cpy #'A'
            bne +
            cpx #'M'
            bne +
            inc $d3             ; YTM's 1551 TrackCache ROM is installed
+           lda $d3             ; return result
            rts

.send_command:
            lda RAM_FA
            jsr ROM_LISTEN
            lda #$6F
            jsr ROM_SECOND
            ldy #0
-           lda ($d0),y
            jsr ROM_CIOUT
            iny
            cpy $d2
            bne -
            jmp ROM_UNLISTEN


.trackcache_rom:    ; check if YTM's 1551 TrackCache ROM is installed - 'RAM' at $a000
    !text "M-R"
    !word $a000
    !byte 3 ; 'RAM'

        } ; zone
