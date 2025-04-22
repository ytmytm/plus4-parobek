; DASM V2.12.04 source
;
; Burst loader routine, minimal version to allow loading of programs upto 63k
; in length ($400-$ffff). Directory is loaded with the normal load routine.
;
; 1987-99 Pasi Ojala, Use where you want, but please give me some credit
;
; This program needs SRQ to be connected to CNT1 and DATA to SP1 (CIA1).
; Cassette drive won't work with those wires connected if the disk drive
; is turned on. (SRQ is connected to cassette read line.)
;
; SRQ = Bidirectional fast clock line for fast serial bus
; DATA= Slow/Fast serial data (software clocked in slow mode)

	processor 6502

	ORG $0801
	DC.B $b,8,$ef,0	; '239 SYS2061'
	DC.B $9e,$32,$30,$36,$31
	DC.B 0,0,0

install:
	; copy first block to $2a7..$2ff
	ldx #block1_end-block1-1	; Max $58
0$	lda block1,x
	sta _block1,x
	dex
	bpl 0$
	; copy second block to $334..$3ff
	ldx #block2_end-block2		; Max $cc
1$	lda block2-1,x
	sta _block2-1,x
	dex
	bne 1$

	lda $0330	; load vector
	ldx $0331
	cmp #MyLoad
	beq 3$
2$	sta OldVrfy+1	; chain the old load vector
	stx OldVrfy+2
	lda #MyLoad
	sta $0331
3$	rts

block1
#rorg $02a7
_block1
OldLoad	lda #0
OldVrfy	jmp $f4a5	; The 'normal' load.

MyLoad:	;sta $93
	cmp #0		; Is it a prg-load-operation ?
	bne OldVrfy	; If not, use the normal routine
	stx $ae		; Store the load address
	sty $af
	tay		; ldy #0
	lda ($bb),y	; Get the first char from filename
	ldy $af
	cmp #$24	; Do we want a directory ($) ?
	beq OldLoad	; Use the old routine if directory
	cmp #58		; ':'
	beq OldLoad

	; Activate Burst, the drive then knows we can handle it
	sei		; We are polling the serial reg. intr. bit
	ldy #1		; Set the clock rate to the fastest possible
	sty $dc04
	dey		; = ldy #0
	sty $dc05
	lda #$c1
	sta $dc0e	; Start TimerA, Serial Out, TOD 50Hz
	bit $dc0d	; Clear interrupt register
	lda #8		; Data to be sent, and interrupt mask
	sta $dc0c	; (actually we just wake up the other end,
0$	bit $dc0d	;  so that it believes that we can do
			;  burst transfers, data can be anything)
	beq 0$		; Then we poll the serial (data sent)
	; Clears the interrupt status

	; This program assumes you don't try to use it on a 1541
	; If you try anyway, your machine will probably lock up..

	lda #$25	; Set the normal (PAL) frequence to TimerA
	sta $dc04	; Change if you want to preserve NTSC-rate
	lda #$40
	sta $dc05
	lda #$81
	jmp LoadFile

GetByte	lda #8		; Interrupt mask for Serial Port
0$	bit $dc0d	; Wait for a byte
	beq 0$		;  (Serial port int. bit changes, hopefully)
	;ldy $dc0c	; Get the byte from Serial Port Register
ToggleClk:
	lda $dd00	; Toggle the old serial clock (=send Ack)
	eor #$10	;  so that the disk  drive will start
	sta $dd00	;  sending the next byte immediately
	;tya		; return the value in Accumulator, update flags
	lda $dc0c	; Get the byte from Serial Port Register
	rts
#rend
block1_end


block2
#rorg $0334
_block2

LoadFile:
	sta $dc0e	; Start TimerA, Serial IN, TOD 50Hz (PAL)
	;cli

	jsr $f5af	; searching for ..

	lda $b7		; Preserve the filename length
	pha
	lda $b9		; Do the same with secondary address
	sta $a5		; We store it to cassette sync countdown..
			;  No cassette routines are used anyway, as
	lda #0		;  this prg is in cassette buffer..
	sta $b7		; No filename for command channel
	lda #15
	sta $b9		; Secondary address 15 == command channel
	lda #239
	sta $b8		; Logical file number (15 might be in use?)
	jsr $ffc0	; OPEN
	sta ErrNo+1
	pla
	sta $b7		; Restore filename length
	bcs ErrNo	; "device not present",
			; "too many open files" or "file already open"
	; Send Burst command for Fastload
	ldx #239
	jsr $ffc9	; CHKOUT Set command channel as output
	sta ErrNo+1
	bcs NoDev	; "device not present" or other errors

	; Bummer, the interrupt status register bit indicating fast serial
	; will be cleared when we get here..

	ldy #3
3$	lda BCMD-1,y	; Burst Fastload command
	jsr $ffd2
	dey
	bne 3$
	; ldy #0
1$	lda ($bb),y
	jsr $ffd2	; Send the filename byte by byte
	iny
	cpy $b7		; Length of filename
	bne 1$
	jsr $ffcc	; Clear channels

	sei
	jsr $ee85	; Set serial clock on == clk line low
	bit $dc0d	; Clear intr. register
	jsr ToggleClk	; Toggle clk

	jsr HandleStat	; Get Initial status
	pha		; Store the Status

	;jsr $f5d2	; loading/verifying
	; (uses CHROUT, which does CLI, so we can't use it)

; We could add a check here..
; if we don't have at least two bytes, we cannot read load address..

; It seems that for files shorter than 252 bytes the 1581 does not count
; the loading address into the block size.

	jsr GetByte	; Get the load address (low) - We assume
			; that every file is at least 2 bytes long
	tax
	jsr GetByte	; Get the load address (high)
	tay		; already in Y
	lda $a5		; The secondary address - do we use load
			;  address in the file or the one given to
	bne Our		;  us by the caller ?
	stx $ae		; We use file's load addr. -> store it.
	sty $af
Our	ldx #252	; We have 252 bytes left in this block
	pla		; Restore the Status
	bne Last	; If not OK, it has to be bytes left
Loop	jsr GetAndStore	; Get X bytes and save them
	jsr HandleStat	; Handle status byte
	beq Loop	; If all was OK, loop..
Last	tax		; Otherwise it is bytes left. Do the last..
	jsr GetAndStore	; Get X number of bytes and save them
	jsr $ee85	; Serial clock on (the normal value)
	lda #239
	jsr $ffc3	; Close the command channel
	clc		; carry clear -> no error indicator
	bcc End

FileNotFound:
	pla		; Pop the return address
	pla
	jsr $ee85	; Serial clock on (the normal value)
	lda #4		; File not found
	sta ErrNo+1
NoDev	lda #239
	jsr $ffc3	; Close the command channel
ErrNo	lda #5		; Device not present
	sec		; carry set -> error indicator
End	ldx $ae		; Loader returns the end address,
	ldy $af		;  so get it into regs..
	cli
	rts		; Return from the loader

HandleStat:
	jsr GetByte	; Get a byte (and toggle clk to start the
			;  transfer for next byte)
	cmp #$1f	; EOI ?
	bne 0$
	jmp GetByte	; Get the number of bytes to follow and RTS
0$	cmp #2		; File Not Found ?
	bcs FileNotFound	; file not found or read error
	; code 0 or 1 -> OK
	ldx #254	; So, the whole block is coming
	lda #0		; No error -> Z set
	rts

GetAndStore:
	jsr GetByte	; Get a byte & toggle clk
	;sta $d020
	ldy #$34
	sty 1		; ROMs/IO off (hopefully no NMI:s occur..)
	ldy #0
	sta ($ae),y	; Store the byte
	ldy #$37
	sty 1		; Restore ROMs/IO (Should preserve the
			;  state, but here it doesn't..)
	inc $ae		; Increase the address
	bne 0$
	inc $af
0$	dex		; X= number of bytes to receive
	bne GetAndStore
	rts

BCMD:	dc.b $1f, $30, $55	; 'U0',$1F == Burst Fastload command
				; If $9F, Doesn't have to be a prg-file
#rend
block2_end