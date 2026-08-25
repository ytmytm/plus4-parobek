
; detect if that's a 1541
; detect if it has parallel cable connected and which interface is used on local end: PPI, PIO, CIA or VIA

; because of multiple M-R/M-W commands it's not possible to detect cable with DolphinDOS ROM

; return flags in A:
; %1xxxxxxx - device is 1541
; %xxxxxxx1 - YTM's 1541 TrackCache ROM (supports SpeedDOS loader out of the box) https://github.com/ytmytm/1541-RAMBOardII
; %x1xxxxxx - parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
; %xx1xxxxx - parallel cable connected to PIO at piobase $FD10 (6529)
; %xxx1xxxx - parallel cable connected to CIA at ciabase $FD90 (6526)
; %xxxx1xxx - parallel cable connected to VIA at viabase $FDA0 (6522)

!set par1541_debug = 0 ; 0 - no debug, 1 - debug

par1541_detect:
        !zone PAR1541_Detect {

            lda #$80            ; device is not 1541 or no parallel cable connected -> fall back on ROM
		    sta load_status

            lda #<.cbminfo
            sta $d0
            lda #>.cbminfo
            sta $d1
            lda #6
            sta $d2
            jsr .send_command

            lda RAM_FA
            jsr ROM_TALK
            lda #$6F
            jsr ROM_TKSA
            jsr ROM_ACPTR
            pha
            jsr ROM_ACPTR
            pha
            jsr ROM_UNTLK

            pla
            tax
            pla
            cmp #'5'
            bne .not_1541
            cpx #'4'
            beq +
.not_1541:  lda #0              ; not 1541
            rts

+
; now check if there's a parallel cable connected and where
;
; Open-bus trap: on Plus/4, unmapped I/O like $FE00/$FD10 often returns the
; same value twice (lda/cmp "presence") and can echo recent bus data, so a
; bare PPI/PIO probe false-positives a cable. That selected SpeedDOS, uploaded
; to $0303, and JAMed the drive with no cable present. Only probe host chips
; that exist for this Burstcart build; still require $55+$AA readback.

            lda #0
            sta $d3             ; PPI match count
            sta $d4             ; PIO
            sta $d5             ; CIA
            sta $d6             ; VIA

!if burst = 1 {
            ; CIA Burstcart: only CIA parallel makes sense
            lda ciabase+3
            cmp ciabase+3
            bne .par_no_hostchip
            inc $d5
            lda #$00
            sta ciabase+3       ; set port B to input
            jmp .par_host_ok
.par_no_hostchip:
            lda #$80            ; 1541 but no parallel host chip
            rts
.par_host_ok:
}

!if burst = 2 {
            ; VIA Burstcart: only VIA parallel makes sense
            lda viabase
            cmp viabase
            bne .par_no_hostchip
            inc $d6
            lda #$00
            sta viabase+3       ; set port A to input (same as on 1541 side)
            jmp .par_host_ok
.par_no_hostchip:
            lda #$80
            rts
.par_host_ok:
}

!if burst = 3 {
            ; CPLD: allow PPI/PIO without open-bus "present" vote (counts
            ; start at 0; $55+$AA below must both match → need 2). Also try
            ; CIA/VIA if those chips decode.
            lda #$90
            sta ppibase+3
            lda #$ff
            sta piobase
            lda ciabase+3
            cmp ciabase+3
            bne .par_cpld_via
            inc $d5
            lda #$00
            sta ciabase+3
.par_cpld_via:
            lda viabase
            cmp viabase
            bne .par_host_ok
            inc $d6
            lda #$00
            sta viabase+3
.par_host_ok:
}

            !if par1541_debug = 1 {
                lda #<.via1output_txt
                ldy #>.via1output_txt
                jsr print_msg
            }

            lda #<.via1output
            sta $d0
            lda #>.via1output
            sta $d1
            lda #7
            sta $d2
            jsr .send_command

            !if par1541_debug = 1 {
                lda #<.via1_test55_txt
                ldy #>.via1_test55_txt
                jsr print_msg
            }

            lda #<.via1test55
            sta $d0
            lda #>.via1test55
            sta $d1
            lda #7
            sta $d2
            jsr .send_command
;875c
            jsr delay

!if burst = 3 {
            lda ppibase
            cmp #$55
            bne +
            inc $d3
+           lda piobase
            cmp #$55
            bne +
            inc $d4
+
}
!if burst = 1 {
            lda ciabase+1
            cmp #$55
            bne +
            inc $d5
+
}
!if burst = 2 {
            lda viabase+1
            cmp #$55
            bne +
            inc $d6
+
}
!if burst = 3 {
            lda ciabase+1
            cmp #$55
            bne +
            inc $d5
+           lda viabase+1
            cmp #$55
            bne +
            inc $d6
+
}

            !if par1541_debug = 1 {
                lda #<.via1_testaa_txt
                ldy #>.via1_testaa_txt
                jsr print_msg
            }

            lda #<.via1testAA
            sta $d0
            lda #>.via1testAA
            sta $d1
            lda #7
            sta $d2
            jsr .send_command

            jsr delay

!if burst = 3 {
            lda ppibase
            cmp #$aa
            bne +
            inc $d3
+           lda piobase
            cmp #$aa
            bne +
            inc $d4
+
}
!if burst = 1 {
            lda ciabase+1
            cmp #$aa
            bne +
            inc $d5
+
}
!if burst = 2 {
            lda viabase+1
            cmp #$aa
            bne +
            inc $d6
+
}
!if burst = 3 {
            lda ciabase+1
            cmp #$aa
            bne +
            inc $d5
+           lda viabase+1
            cmp #$aa
            bne +
            inc $d6
+
}

            !if par1541_debug = 1 {
                lda #<.via1_input_txt
                ldy #>.via1_input_txt
                jsr print_msg
            }

            lda #<.via1input
            sta $d0
            lda #>.via1input
            sta $d1
            lda #7
            sta $d2
            jsr .send_command

            !if par1541_debug = 1 {
                lda $d3
                sta $0c00+40
                lda $d4
                sta $0c00+41
                lda $d5
                sta $0c00+42
                lda $d6
                sta $0c00+43
            }

            ; gather results — only interfaces probed for this build can win
            lda #$80
!if burst = 3 {
            ldx #2              ; PPI/PIO: $55+$AA only
            cpx $d3
            bne +
            ora #%01000000
+           cpx $d4
            bne +
            ora #%00100000
+           ldx #3              ; CIA/VIA: present+$55+$AA
            cpx $d5
            bne +
            ora #%00010000
+           cpx $d6
            bne +
            ora #%00001000
+
}
!if burst = 1 {
            ldx #3
            cpx $d5
            bne +
            ora #%00010000      ; CIA only
+
}
!if burst = 2 {
            ldx #3
            cpx $d6
            bne +
            ora #%00001000      ; VIA only
+
}
            sta $d7

; check if YTM's 1541 TrackCache ROM is installed - 'RAM' at $a000
; only if it's CIA or VIA because hardware handshake is required
            and #%00011000
            beq +

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
            !if par1541_debug = 1 {
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
            inc $d7
+           lda $d7
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

!if par1541_debug = 1 {
.ppi_present:
    !text "PPI"
    !byte $0d, 00
.pio_present:
    !text "PIO"
    !byte $0d, 00
.cia_present:
    !text "CIA"
    !byte $0d, 00
.via_present:
    !text "VIA"
    !byte $0d, 00
.no_parallel:
    !text "NO PARALLEL INTERFACE",13,0

.via1output_txt:
    !text "VIA OUTPUT",13,0
.via1_test55_txt:
    !text "VIA TEST 55",13,0
.via1_testaa_txt:
    !text "VIA TEST AA",13,0
.via1_input_txt:
    !text "VIA INPUT",13,0
}

.cbminfo:	; gets CBM drive info at $e5c5 in drive ROM
	!text "M-R"
	!word $e5c5
	!byte 2

.trackcache_rom:    ; check if YTM's 1541 TrackCache ROM is installed - 'RAM' at $a000
    !text "M-R"
    !word $a000
    !byte 3 ; 'RAM'

.via1output:
    !text "M-W"
    !word $1803
    !byte 1
    !byte $ff

.via1test55:
    !text "M-W"
    !word $1801
    !byte 1
    !byte $55

.via1testAA:
    !text "M-W"
    !word $1801
    !byte 1
    !byte $aa

.via1input:
    !text "M-W"
    !word $1803
    !byte 1
    !byte $00

        } ; zone