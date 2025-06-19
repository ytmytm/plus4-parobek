
;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; note: this version forces slow clock during CIA access (make it optional)
; note: this version flashes border during load, original colour is not restored (needed for debug only)

; TODO: redo error reporting (Errno, load_status, etc.) like VIA version

; todo: with listen/second/acptr/unlisten we don't care about filename/channels and preserving zp values
; todo: inline GetByte in GetAndStore to save some cycles

!macro InitBurst {
        ; setup TOD
	lda #$80                       ; TOD 50Hz, serial IN, timer A stop
	sta ciabase+14
	lda #0
	sta ciabase+11                 ; TOD h
	sta ciabase+10
	sta ciabase+9
	sta ciabase+8
	lda ciabase+8                  ; load 10ths to start clock
}

!macro LoadBurst {
	; our loading code
;myload_cont:
	ldy #4
	sty ciabase+4		; set clock rate to the fastest possible
	ldy #0
	sty ciabase+5
	lda #$c1		; start timer A, serial OUT, TOD 50Hz
	sta ciabase+14
	bit ciabase+13		; clear interrupt register
	lda #8			; data to be sent and interrupt mask (following BIT)
	sta ciabase+12		; (we wake up the other end so that it believes we can do burst transfers, actual data doesnt matter)

-       iny
	bmi NotCIA              ; timeout, CIA not present or not working
	bit ciabase+13		; (but A=8 is special because it's a mask for this bit instruction)
	bne CIAFound
	beq -			; wait until data sent

NotCIA:
        inc load_status
	lda #<cia_not_present
	ldy #>cia_not_present
	jmp print_msg

CIAFound:
        lda #$81
	sta ciabase+14		; start timer A, serial IN, TOD 50Hz

	jsr eF160		;print "SEARCHING" ; XXX too early - will show "SEARCHING" twice if device is not burst capable

	lda RAM_FNLEN		; preserve the filename length
	pha
	lda RAM_SA		; same with secondary address
	sta RAM_ZPVEC1		; temp

	lda #0
	sta RAM_FNLEN		; no filename for command channel
	lda #15
	sta RAM_SA		; secondary address 15 == command channel
	lda #CMD_CHANNEL
	sta RAM_LA		; logical file number (15 might be in use)
	jsr ROM_OPEN
	sta ErrNo+1
    lda RAM_ZPVEC1	; restore secondary address
    sta RAM_SA
	pla
	sta RAM_FNLEN		; restore filename length
;	bcs ErrNo		; "device not present", "too many open files", "file already open"
        bcc +
	jmp ErrNo
+
	; Send burst command for Fastload
	ldx #CMD_CHANNEL
	jsr ROM_CHKOUT		; command channel as output
	sta ErrNo+1
;	bcs NoDev		; "device not present" or other errors
	bcc +
	jmp NoDev
+
	ldy #3
-	lda BCMD-1,y
	jsr ROM_CHROUT
	dey
	bne -
	lda #RAM_FNADR		;filename at ($AF/$B0)?
	sta a07DF
-	jsr RAM_RLUDES		;RLUDES  Indirect routine downloaded
	jsr ROM_CHROUT		; send the filename byte by byte
	iny
	cpy RAM_FNLEN		; length of filename
	bne -
	jsr ROM_CLRCHN		; clear channels	

	lda #8			; how C128 detects burst?
	bit ciabase+13		; we should receive something by now
	bne +
	jmp NotFast		; device doesn't handle burst
+
	jsr eF189		; print LOADING, uses CHROUT will CLI again
	sei			; loader starts here
	jsr eE2B8		; serial clock on == clk line low
	bit ciabase+13		; clear interrupt register
	jsr ToggleClk		; toggle clock

	jsr HandleStat		; get initial status
	pha			; keep it

	jsr GetByte		; Get the load address (low) - We assume
				; that every file is at least 2 bytes long
	tax
	jsr GetByte		; Get the load address (high)
	tay			; already in Y
	lda RAM_ZPVEC1		; The secondary address - do we use load
				;  address in the file or the one given to
	bne Our			;  us by the caller ?
	stx RAM_MEMUSS		; We use file's load addr. -> store it.
	sty RAM_MEMUSS+1
Our:	ldx #252		; We have 252 bytes left in this block
	pla			; Restore the Status
	bne Last		; If not OK, it has to be bytes left
Loop:	jsr GetAndStore		; Get X bytes and save them
	jsr HandleStat		; Handle status byte
	beq Loop		; If all was OK, loop..
Last:	tax			; Otherwise it is bytes left. Do the last..
	jsr GetAndStore		; Get X number of bytes and save them
	jsr eE2B8		; Serial clock on (the normal value)
	lda #CMD_CHANNEL
	jsr ROM_CLOSE		; Close the command channel
	clc			; carry clear -> no error indicator
	bcc End

FileNotFound:
	pla			; Pop the return address
	pla
	jsr eE2B8		; Serial clock on (the normal value)
	lda #4			; File not found
	sta ErrNo+1
NoDev:	lda #CMD_CHANNEL
	jsr ROM_CLOSE		; Close the command channel
ErrNo:	lda #5			; Device not present
	sec			; carry set -> error indicator
End:
    ldx RAM_MEMUSS		; Loader returns the end address,
	ldy RAM_MEMUSS+1	;  so get it into regs..
	cli
	rts			; Return from the loader
				; load_status = 0 so do nothing more

NotFast:			; device doesn't handle burst
	lda #CMD_CHANNEL
	jsr ROM_CLOSE
	jsr ROM_CLRCHN		; close file
	inc load_status		; return and pass to ROM load
	lda #<not_burst
	ldy #>not_burst
	jmp print_msg

HandleStat:
	jsr GetByte		; Get a byte (and toggle clk to start the
				;  transfer for next byte)
	cmp #$1f		; EOI ?
	bne +
	jmp GetByte		; Get the number of bytes to follow and RTS

+	cmp #2			; File Not Found ?
	bcs FileNotFound	; file not found or read error
	; code 0 or 1 -> OK
	ldx #254		; So, the whole block is coming
	lda #0			; No error -> Z set
	rts

GetAndStore:
	jsr GetByte		; Get a byte & toggle clk
inc TED_BORDER ; XXX flash border
	ldy #0
	sta (RAM_MEMUSS),y	; Store the byte
	inc RAM_MEMUSS
	bne +
	inc RAM_MEMUSS+1
+	dex			; X= number of bytes to receive
	bne GetAndStore
	rts

GetByte:
	lda #8			; mask for BIT
-
	bit ciabase+13		; wait for a byte
	beq -
ToggleClk:
        ldy ciabase+12          ; get the latched byte from serial port
	lda $01
	eor #%00000010		; toggle the old serial clock (send Ack)
	sta $01			; disk drive will start sending the next byte
	;lda ciabase+12		; get the latched byte from serial port
        tya
	rts

BCMD:	!byte $1f, $30, $55	; 'U0',$1F == Burst Fastload command
				; If $9F, Doesn't have to be a prg-file

;
cia_not_present:
                !text "CIA NOT PRESENT",13,0
not_burst:
		!text 13,"NOT BURST CAPABLE",13,0

}
