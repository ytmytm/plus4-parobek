
;SpeedDOS+ (40)	$F800-$F9AB
;executed from f7e5
;sent from f733 (slowly: 512 bytes via M-W)
;executed from f784 (m-'e',3,3)

; NOTE: uses h/w handshake, but not the same as dolphindos?
; NOTE: need to check par1541 drivecode for handshake with IEC lines (state change, not level)

; par1541_interface = 1,2 -> s/w handshake (PPI,PIO)
; par1541_interface = 3,4 -> h/w handshake (CIA,VIA)

!pseudopc $0300 {

; $E0 command start ($0300) - change track
            JMP .L0361		; only on track change

; M-E command start ($0303)

            LDX #$FF		;// <--- START, $18/19 has file starting t&s
            STX $1803		;// PA out
            INX
            STX $0F
            LDA #$0B        ; CA2 pulse output on PA write
            STA $180C		; hardware handshake
            LDA #$02
            STA $1800       ; software handshake

.L0310      JSR .L049E		;// setup halftrack sequence
.L0313      LDA $18
            STA $06
            LDA #$E0		;// execute at $0300 (spinup + position head)
            STA $00
.L031B      LDA $00
            BMI .L031B
            CMP #$01
            BEQ .L0333		;// no error = end of file?
            CMP #$10
            BEQ .L0310		;// different track, run again? (any other error would return immediatly from within IRQ routine?)

            LDX $0F		    ;// reaction to error - seek halftrack up once, down twice, up twice, down twice, up once and retry; but how it knows when to stop?
            INC $0F
            LDA .halftrack_sequence,X	    ;// 01 FF FF 01 01 FF FF 01 00
            STA $02FE
            BNE .L0313		;// 00 means end of halftrack sequence - can't retry

.L0333      JSR .L049E		;// setup halftrack sequence (why again? besides, we are exiting right now)
            LDA #$00		;// 00 = end of file (0 bytes to follow)
            JSR .L0405		;// send byte
            LDA $00
            PHA
            JSR .L0405		;// send status byte, 01=no error
            INC $1803		;// PA input
            LDA $18		    ;// track & sector (header)
            PHA
            LDA $19
            PHA
            JSR $D005		;// disk init (why? to return head to directory? to bring back BAM 18,0 into buffer $0700?)
            PLA
            STA $80		    ;// current track & sector (why put it back, we're not on original track anymore)
            PLA
            STA $81
            PLA
            CMP #$01		;// error?
            BNE .L035B		;// yes
            JMP $D313		;// no: Close all channels of other drives
.L035B      CLC			    ;// error number
            ADC #$1E
            JMP $E645		;// Print error message into error buffer

.L0361      JSR .L0458		;// encode header ; called from $00 job $E0
            LDY $0D
            STY $0E
            LDX #$07
            NOP
            LDA #$06
            TAY
            JSR .L039A		;// read sector into $0700 (? and the following one to $0600)
            LDA #$07
            JSR .L041B
            JSR .L0458
            LDX #$05
            TXA
            LDY #$07
            JSR .L039A
            LDA #$05
            JSR .L041B
            CMP $0E
            BNE .L038F
            LDA #$06
            JSR .L041B
.L038F      CMP $0D
            BNE .L0361
            LDA #$07
            JSR .L041B
            BPL .L0361
.L039A      PHA			    ;// read two sectors at once? why
            TYA
            PHA
            TXA
            JSR .L03D8		;// first sector (+wait for header)
            PLA
            STA $31		    ;// target buffer #2 (was in Y)
            LDA $018D		;// encoded 
            STA $25
            LDA $018E
            STA $26
            LDA $018F
            STA $27
            JSR $F536		;// wait for header: part of read block header (90 times wait for sync and compare received data with $0024 encoded header)
            JSR .L03DD		;// read second sector
            PLA
            STA $31
            JSR $F8E0		;// decode buffer at $30/31 + $1BA-$1FF from GCR into BIN at $30/31
            JSR .L03D1
            LDY #$46
            STY $4F
            INC $34
            INC $36
            LDA #$07
            STA $31
            JSR $F8F2		;// partial decode $0700-$07FF, $0146-?? (decode second buffer?)
.L03D1      LDA $3A
            LDX $31
            STA $03,X
            RTS

.L03D8      STA $31		    ;// read sector starts here?
            JSR $F527		;// wait for header, calculate parity ($16-$19->$1A), wait 90 times for sector to arrive
.L03DD      JSR $F556		;// wait for sync before block data
.L03E0      BVC .L03E0
            CLV
            LDA $1C01
            STA ($30),Y
            INY
            BNE .L03E0
            LDA #$BA		;// $01BA-?? second half of first sector's GCR data on stack?
            TAX
            TAY
            LDA $31
            CMP #$07		;// is it $07xx buffer?
            BNE .L03F7		;// no
            LDY #$46		;// yes: $0146-?? second half of second sector's GCR data on stack?
.L03F7      BVC .L03F7
            CLV
            LDA $1C01
            STA $0100,Y
            INY
            INX
            BNE .L03F7
            RTS

.L0405:
!if ((par1541_interface = 1) or (par1541_interface = 2)) { ; PPI or PIO or VIA (test)
            STA $1801       ; send A, receive X
            LDA #$04
-           BIT $1800
            BEQ -
            LDX #0
            STX $1800
            LDX $1801
-           BIT $1800
            BNE -
            LDA #$02
            STA $1800
            RTS
}
!if ((par1541_interface = 3) or (par1541_interface = 4)) { ; CIA or VIA
            BIT $1800		;// send byte ; clear handshake
            STA $1801		;// send byte
            LDY #$E0		;// timeout
-           LDA $180D		;// wait for handshake
            AND #$10
            BNE +
            INY
            BNE -
            JMP $EAA0		;// timeout->RESET ($FFFA?)
+           RTS			    ;// ok
}

.L041B      STA $31
            TAX
            LDA $03,X
            LDY #$00
.L0422      EOR ($30),Y	    ;// sector checksum?
            INY
            BNE .L0422
            TAX
            BEQ .L042D
            JMP $F502		;// 23 READ ERROR
.L042D      TAY			    ;// next track & sector
            LDA ($30),Y
            BNE .L043B		;// non-zero track, this is not the last sector
            INY
            LDA ($30),Y	    ;// number of bytes in the last sector
            JSR .L0482		;// send it out
            JMP $F505		;// END, set status to 00 OK 00 00
.L043B      TAX			    ;// preserve next track number in X
            INY
            LDA ($30),Y
            STA $19		    ;// next sector
            LDA #$FF
            JSR .L0482		;// send out $FE bytes from current buffer
            CPX $18		    ;// next track the same?
            BEQ .L0451		;// yes: return with next sector number in A
            STX $18		    ;// no: new track
            LDA #$10		;// $10 = different track (report error back to $00), new track number in $18
            JMP $F969		;// Error entry disk controller - loop at $0303 will issue job $E0 on the new track (from $18)
.L0451      LDA #$00
            STA $0F
            LDA $19		    ;// next sector number
            RTS

; encode header to GCR
.L0458      LDY $19
            INY			    ;// current sector+1 (why?!)
            CPY $43		    ;// last sector on track?
            BNE .L0461	    ;// no
            LDY #$00	    ;// yes: roll over sector to 0
.L0461      STY $54		    ;// sector to encode
            STY $0D		    ;// sector
            LDA #$01	    ;// result in $0100+Y ($34)
            STA $31
            LDA #$00	    ;// header checksum
            EOR $16		    ;// ID1
            EOR $17		    ;// ID2
            EOR $18		    ;// track
            EOR $0D		    ;// sector
            STA $53		    ;// checksum to encode
            LDA #$8C	    ;// put GCR encoded header at $018c ($30/$31+offset from $34) (normally from F934 it goes to $0024), used at $03a4
            STA $34		    ;// encoder will use $8C as offset from $34, so result goes to $018C
            LDA $39		    ;// expected header signature (value $08)
            STA $52		    ;// to encode
            LDA $18		    ;// track to encode (will be put into $55)
            JMP $F95F	    ;// part of Convert block header to GCR code (encode header - buffer at $52/3/4/5)

; send out sector data: number of bytes, then data
.L0482      STA $0C		    ;// send out number of bytes that follow?
            STX $14         ;// preserve X (next track number) b/c software handshake destroys X
            JSR .L0405
            LDX #0
            LDY #$01		;// send out sector data
.L0489      INY
            LDA ($30),Y
!if ((par1541_interface = 1) or (par1541_interface = 2)) { ; PPI or PIO or VIA (test)
            STA $1801
            LDA #$04
-           BIT $1800
            BEQ -
            STX $1800       ; X always 0
-           BIT $1800
            BNE -
            LDA #$02
            STA $1800
}
!if ((par1541_interface = 3) or (par1541_interface = 4)) { ; CIA or VIA
            BIT $1800		;// clear flag
            STA $1801
            LDA #$10		;// wait for handshake
-           BIT $180D
            BEQ -
}
            CPY $0C		    ;// number of bytes to send
            BNE .L0489
            LDX $14         ;// restore X (next track number)
            RTS

; move head?
.L049E      LDX $0F		    ;// 0 in $0F means end of sequence
            BEQ .L04A9
.L04A2      LDA .halftrack_sequence,X	    ;// 01 FF FF 01 01 FF FF 01 00 - halftrack sequence
            BNE .L04AA
            STA $0F		    ;// 0 in $0F end of sequence, $2FE unchanged
.L04A9      RTS
.L04AA      STA $02FE
.L04AD      LDA $02FE
            BNE .L04AD
            INX			    ;// will never roll over because 0 ends the halftrack up/down sequence
            BNE .L04A2		;// this is always taken

.halftrack_sequence: ; $FB99 in SpeedDOS+ Plus 1541 ROM
            !byte $01, $FF, $FF, $01, $01, $FF, $FF, $01, $00

}
