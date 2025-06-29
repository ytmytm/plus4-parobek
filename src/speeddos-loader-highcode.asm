
; par1541_interface = 1 (PPI)
; par1541_interface = 2 (PIO)
; par1541_interface = 3 (CIA)
; par1541_interface = 4 (VIA)

        !if par1541_interface = 1 { ; PPI
                !set parallel_port = ppibase
        }
        !if par1541_interface = 2 { ; PIO
                !set parallel_port = piobase
        }
        !if par1541_interface = 3 { ; CIA
                !set parallel_port = ciabase+1
        }
        !if par1541_interface = 4 { ; VIA
                !set parallel_port = viabase+1
        }

!zone SpeedDOS_LoaderHighcode {

        lda     #$00		; initial state
        sta     $01
        ; set port to input
        !if par1541_interface = 1 { ; PPI
                lda #$90
                sta ppibase+3
        }
        !if par1541_interface = 2 { ; PIO
                lda #$ff
                sta piobase
        }
        !if par1541_interface = 3 { ; CIA
                lda #$00
                sta ciabase+3
        }
        !if par1541_interface = 4 { ; VIA
                lda #$00
                sta viabase+3
        }
;        lda     TED_FF06	; screen off
;        and     #$EF
;        sta     TED_FF06
        ldy     #$04
-       cpy     TED_FF1D	; some kind of delay
        bne     -
        dey
        bne     -

        sei                             ; f794
        jsr .SpeedDOS_GetParallelByte
        pha
        jsr .SpeedDOS_GetParallelByte   ; skip over load address
        jsr .SpeedDOS_GetParallelByte
        pla
        tax
        dex                             ; skip over load address
        dex
        txa
        jmp .LF7AF

.LF7A5: ; test for STOP key
        ; if yes -> F7D5
        jsr .SpeedDOS_GetParallelByte   ; number of bytes that follows
.LF7AF: tax
        beq .LF7CC                       ; end of file or error
        dex
        stx $d0
        ldy #0
.LF7B5:
        ; inline GetParallelByte
!if (par1541_interface = 1) { ; PPI
        jsr .SpeedDOS_GetParallelByte
}
!if (par1541_interface = 3) { ; CIA
        lda     #$10
-       bit     ciabase+13
        beq     -
        lda     parallel_port
}
        sta ($9D),y
        inc $9d
        bne +
        inc $9e
+       dec $d0
        bne .LF7B5                       ; next byte from sector
        beq .LF7A5                       ; next sector

.LF7CC:                                  ; end of file or error
        jsr .SpeedDOS_GetParallelByte   ; get error code
        cmp #$01
        beq .loadok
.loaderr:
        sta load_status
        jsr .loadok                     ; restore colors, screen
        lda #$04                        ; or any other error code?
        sta load_status
        rts
.loadok:
        lda     RAM_TED_BORDER_BACKUP             ; restore colors
        sta     TED_BORDER
        lda     TED_FF06	; screen on
        ora     #$10
        sta     TED_FF06

        ldx     $9D             ; load address
        ldy     $9E
        clc
        rts

.SpeedDOS_GetParallelByte:              ; f7da
inc TED_BORDER
!if (par1541_interface = 1) {
	lda     #$02
        sta     $01
-       bit     $01
        bpl     -
        ldx     parallel_port
        lda     #$00
        sta     $01
-       bit     $01
        bmi     -
        txa
        rts
}

!if (par1541_interface = 3) {
        lda     #$10
-       bit     ciabase+13
        beq     -
        lda     parallel_port
        rts
}

}
