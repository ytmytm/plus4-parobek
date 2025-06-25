
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

        !zone PAR1541_Loader_Highcode {

;FASTLOAD:
        lda     #$00		; initial strobe
        sta     $01
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
        lda     TED_FF06	; screen off
        and     #$EF
        sta     TED_FF06
        ldy     #$04
-       cpy     TED_FF1D	; some kind of delay
        bne     -
        dey
        bne     -
        lda     #$FF		; initial track - invalid (no track in buffer)
        sta     $D0
        jsr     .GetByteParport
        sta     $D1		; track where file starts?
        jsr     .GetByteParport
        sta     $D2		; sector where file starts?
        lda     #$80		; set first sector flag in D3
        sta     $D3
.LF9F0: jsr     .ReadDecodeGCRSector ; D1/D2 = T&S
        bne     .LFA4B		; error
        bit     $D3		; first sector of the file?
        bpl     .LFA0D		; no, go ahead
        lda     GCR_SECTOR_BUFFER+2	; yes, setup load addr from file
        sta     $9D
        lda     GCR_SECTOR_BUFFER+3
        ldx     $D4		; D4=0 load from basic, D4<>0 load from file
        bne     +
        lda     RAM_MEMUSS	; load addr from basic, not file
        sta     $9D
        lda     RAM_MEMUSS+1
+       sta     $9E
.LFA0D: ldx     #$00
        lda     GCR_SECTOR_BUFFER	; last sector of file (track=0)?
        bne     +
        ldx     GCR_SECTOR_BUFFER+1	; yes, number of bytes remaining
        inx
+       stx     $D5		; keep it in D5
        ldx     #$02		; always skip over track&sector
        bit     $D3		; first sector?
        bpl     +
        ldx     #$04		; but in first sector skip also over load addr
+       ldy     #$00
-       lda     GCR_SECTOR_BUFFER,x
        sta     ($9D),y		; copy decoded data to target addr
        iny
        inx
        cpx     $D5
        bne     -
        tya
        clc
        adc     $9D
        sta     $9D
        bcc     +
        inc     $9E
+       lda     #$00		; clear first sector flag
        sta     $D3
        lda     GCR_SECTOR_BUFFER+1	; advance to next t&s in chain
        sta     $D2
        lda     GCR_SECTOR_BUFFER
        sta     $D1
        bne     .LF9F0		; loop if that wasn't last sector (track<>0)
        lda     #$00		; no error
.LFA4B: pha
        ora     #$80
        jsr     .SendByteParport
        pla
        pha
        beq     +
        lda     $D1
        jsr     .SendByteParport
        lda     $D2
        jsr     .SendByteParport
+       lda     TED_FF06	; screen on
        ora     #$10
        sta     TED_FF06
        pla
        clc
        beq     +
        sec
+       ldx     $9D		; return from LOAD with end addr in X/Y
        ldy     $9E
        lda     #$1D
        rts

;------------------------------------------------

.GetByteParport:
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

;------------------------------------------------

.SendByteParport:
        !if par1541_interface = 1 { ; PPI
                ldx #$80
                stx ppibase+3
        }
        !if par1541_interface = 2 { ; PIO
        }
        !if par1541_interface = 3 { ; CIA
                ldx #$ff
                stx ciabase+3
        }
        !if par1541_interface = 4 { ; VIA
                ldx #$ff
                stx viabase+3
        }
        sta     parallel_port
        lda     #$02
        sta     $01
-       bit     $01
        bpl     -
        lda     #$00
        sta     $01
-       bit     $01
        bmi     -
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
        rts

;------------------------------------------------

; input: A = new track, $D0 = last read track
;        reads whole track GCR data into GCR_TRACK_BUFFER area (21*$0146)
;	(d7/d8) data vector
;	d6 number of sectors (0 on output)

.ReadGCRTrack:
        cmp     $D0			; do we have that track in buffer now?
        bne     +
        rts
+       sta     $D0			; no, we must read it
        jsr     .SendByteParport		; there is some code between this and first read of data but it's ok: drive must move the head
        lda     #<GCR_TRACK_BUFFER
        sta     $D7
        lda     #>GCR_TRACK_BUFFER
        sta     $D8
        lda     $D0
        jsr     .GetNumberOfSectors
        sta     $D6			; number of sectors that will follow (seems the drive will always start with sector 0)
.LFAC4: ldy     #$00
.LFAC6:       
-	bit     $01
        bpl     -
        lda     parallel_port
        sta     ($D7),y
        iny
-       bit     $01
        bmi     -
        lda     parallel_port
        sta     ($D7),y
        iny
        bne     .LFAC6
        inc     $D8
.LFADE:
-       bit     $01
        bpl     -
        lda     parallel_port
        sta     ($D7),y
        iny
-       bit     $01
        bmi     -
        lda     parallel_port
        sta     ($D7),y
        iny
        cpy     #$46
        bne     .LFADE
        tya
        clc
        adc     $D7
        sta     $D7
        bcc     +
        inc     $D8
+       lda     TED_BORDER
        eor     #$F0
        sta     TED_BORDER
        dec     $D6			; all sectors in buffer?
        bne     .LFAC4			; not yet
	rts

;------------------------------------------------

; number of sectors per track speed zone
.LFB0D: !byte   $24,$1F,$19,$12
.LFB11: !byte   $11,$12,$13,$15

; input: A = track number
; output: A = number of sectors on track
;         X changed
.GetNumberOfSectors:
        ldx     #$04
-       cmp     .LFB0D-1,x
        dex
        bcs     -
        lda     .LFB11,x
        rts

;------------------------------------------------

-	lda     #$66			; return from LFB24 with $66? or $05 or $04?
        rts

; input: D1 = track number to read, D2 = sector to read?
; output: GCR_SECTOR_BUFFER - decoded sector
;	A = error status, 0=OK, <>0 - passed back to the drive(?)
.ReadDecodeGCRSector:
        lda     TED_BORDER		; toggle border color
        eor     #$F0
        sta     TED_BORDER
        lda     $D1
        jsr     .ReadGCRTrack
        lda     $D1
        jsr     .GetNumberOfSectors
        cmp     $D2
        beq     -
        bcc     -
        lda     $D2
        asl
        tax
        lda     .LFC61,x
        sta     $D9
        lda     .LFC61+1,x
        sta     $DA
        lda     #$00
        sta     $DD
        sta     $DB
        sta     $DC
.LFB52: ldy     $DB
        lda     ($D9),y
        tax
        lsr
        lsr
        lsr
        sta     $DE
        txa
        and     #$07
        sta     $DF
        iny
        bne     +
        inc     $DA
+       lda     ($D9),y
        asl
        rol     $DF
        asl
        rol     $DF
        lsr
        lsr
        lsr
        sta     $E0
        iny
        lda     ($D9),y
        tax
        ror
        lsr
        lsr
        lsr
        sta     $E1
        txa
        and     #$0F
        sta     $E2
        iny
        lda     ($D9),y
        tax
        asl
        rol     $E2
        lsr
        lsr
        lsr
        sta     $E3
        txa
        and     #$03
        sta     $E4
        iny
        lda     ($D9),y
        asl
        rol     $E4
        asl
        rol     $E4
        asl
        rol     $E4
        lsr
        lsr
        lsr
        sta     $E5
        iny
        sty     $DB
        ldy     $DC
        bne     +
        ldx     $DE
        lda     .LFC21,x
        ldx     $DF
        ora     .LFC41,x
        pha
        jmp     .LFBCD

+       ldx     $DE
        lda     .LFC21,x
        ldx     $DF
        ora     .LFC41,x
        sta     GCR_SECTOR_BUFFER,y
        eor     $DD
        sta     $DD
        iny
        beq     .LFC08
.LFBCD: ldx     $E0
        lda     .LFC21,x
        ldx     $E1
        ora     .LFC41,x
        sta     GCR_SECTOR_BUFFER,y
        eor     $DD
        sta     $DD
        iny
        ldx     $E2
        lda     .LFC21,x
        ldx     $E3
        ora     .LFC41,x
        sta     GCR_SECTOR_BUFFER,y
        eor     $DD
        sta     $DD
        iny
        ldx     $E4
        lda     .LFC21,x
        ldx     $E5
        ora     .LFC41,x
        sta     GCR_SECTOR_BUFFER,y
        eor     $DD
        sta     $DD
        iny
        sty     $DC
        jmp     .LFB52

.LFC08: pla
        cmp     #$07
        bne     .LFC1E
        ldx     $E0
        lda     .LFC21,x
        ldx     $E1
        ora     .LFC41,x
        eor     $DD
        beq     +
        lda     #$05
+       rts

.LFC1E: lda     #$04
        rts

; GCR nibble decoding tables

.LFC21:  !byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        !byte   $FF,$80,$00,$10,$FF,$C0,$40,$50
        !byte   $FF,$FF,$20,$30,$FF,$F0,$60,$70
        !byte   $FF,$90,$A0,$B0,$FF,$D0,$E0,$FF
.LFC41:  !byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        !byte   $FF,$08,$00,$01,$FF,$0C,$04,$05
        !byte   $FF,$FF,$02,$03,$FF,$0F,$06,$07
        !byte   $FF,$09,$0A,$0B,$FF,$0D,$0E,$FF

	; GCR_TRACK_BUFFER + $0146 * 21 sectors

.LFC61:  
	!for i, 0, 20 {
	!word GCR_TRACK_BUFFER + i * $0146
	}
        }
