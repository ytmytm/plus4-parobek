
; detect if that's a 1541
; detect if it has parallel cable connected and which interface is used on local end: PPI, PIO, CIA or VIA
; (CIA/VIA controlled by burst type setting)

; return flags in A:
; %1xxxxxxx - device is 1541
; %x1xxxxxx - parallel cable connected to PPI at ppibase $FE00 (Intel 8255)
; %xx1xxxxx - parallel cable connected to PIO at piobase $FD10 (6529)
; %xxx1xxxx - parallel cable connected to CIA at ciabase $FD90 (6526)
; %xxxx1xxx - parallel cable connected to VIA at viabase $FDA0 (6522)

!set par1541_debug = 0 ; 0 - no debug, 1 - debug

par1541_detect:
        !zone PAR1541_Detect {

.ppibase = $fe00
.piobase = $fd10
.ciabase = $fd90
.viabase = $fda0

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

            lda #0
            sta $d3             ; PPI
            sta $d4             ; PIO
            sta $d5             ; CIA
            sta $d6             ; VIA

            ; check if PPI is connected
            lda .ppibase
            cmp .ppibase
            bne +
            inc $d3
            lda #$90
            sta .ppibase+3      ; set port A to input
            !if par1541_debug = 1 {
                lda #<.ppi_present
                ldy #>.ppi_present
                jsr print_msg
            }

+           ; check if PIO is connected
            lda .piobase
            cmp .piobase
            bne +
            inc $d4
            lda #$ff
            sta .piobase        ; set port to input
            !if par1541_debug = 1 {
                lda #<.pio_present
                ldy #>.pio_present
                jsr print_msg
            }

+           ; check if CIA is connected
            lda .ciabase+3
            cmp .ciabase+3
            bne +
            inc $d5
            lda #$00
            sta .ciabase+3      ; set port B to input
            !if par1541_debug = 1 {
                lda #<.cia_present
                ldy #>.cia_present
                jsr print_msg
            }

+           ; check if VIA is connected
            lda .viabase
            cmp .viabase
            bne +
            inc $d6
            lda #$00
            sta .viabase+3      ; set port A to input (same as on 1541 side)
            !if par1541_debug = 1 {
                lda #<.via_present
                ldy #>.via_present
                jsr print_msg
            }
+
            lda $d3
            ora $d4
            ora $d5
            ora $d6
            bne +               ; continue only if at least one interface is connected

            !if par1541_debug = 1 {
                lda #<.no_parallel
                ldy #>.no_parallel
                jsr print_msg
            }

            lda #$80            ; device is 1541 but no parallel cable connected
            rts
+

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

            lda .ppibase
            cmp #$55
            bne +
            inc $d3
+           lda .piobase
            cmp #$55
            bne +
            inc $d4
+           lda .ciabase+1
            cmp #$55
            bne +
            inc $d5
+           lda .viabase+1
            cmp #$55
            bne +
            inc $d6
+

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

            lda .ppibase
            cmp #$aa
            bne +
            inc $d3
+           lda .piobase
            cmp #$aa
            bne +
            inc $d4
+           lda .ciabase+1
            cmp #$aa
            bne +
            inc $d5
+           lda .viabase+1
            cmp #$aa
            bne +
            inc $d6
+

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

            ; gather results
            lda #$80
            ldx #3          ; 3 tests passed: port stable, $55, $aa
            cpx $d3
            bne +
            ora #%01000000  ; PPI connected
+           cpx $d4
            bne +
            ora #%00100000  ; PIO connected
+           cpx $d5
            bne +
            ora #%00010000  ; CIA connected
+           cpx $d6
            bne +
            ora #%00001000  ; VIA connected
+           rts

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