
;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; note: this version flashes border during load, original colour is not restored (needed for debug only)

!macro InitBurst {
        ; setup CPLD
	lda #0
	sta cpldbase+1		; serial IN; clear flag
}

!macro LoadBurst {
	; our loading code
;myload_cont:
	lda cpldbase+1
	cmp cpldbase+1
	bne NotCPLD
	lda #%01000000		; serial OUT; clear flag
	sta cpldbase+1
	cmp cpldbase+1
	bne NotCPLD
	lda #8			; data to be sent and flag mask (for the following BIT)
	sta cpldbase		; (we wake up the other end so that it believes we can do burst transfers, actual data doesnt matter)
	ldy #0

-       iny
	bmi NotCPLD             ; timeout, CPLD not present or not working
	bit cpldbase+1		; (but A=8 is special because it's a mask for this bit instruction)
	bne CPLDFound
	beq -			; wait until data sent

NotCPLD:
        inc load_status
	lda #<cpld_not_present
	ldy #>cpld_not_present
	jmp print_msg

CPLDFound:
	lda #0
	sta cpldbase+1		; serial IN; clear flag

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
	bit cpldbase+1		; we should receive something by now
	bne +
	jmp NotFast		; device doesn't handle burst
+
	jsr eF189		; print LOADING, uses CHROUT will CLI again
	sei			; loader starts here
	jsr eE2B8		; serial clock on == clk line low
	lda cpldbase		; clear flag
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
	bit cpldbase+1		; wait for a byte
	beq -
ToggleClk:
        ldy cpldbase            ; get the latched byte from serial port, clear flag
	lda $01
	eor #%00000010		; toggle the old serial clock (send Ack)
	sta $01			; disk drive will start sending the next byte
	;lda cpldbase		; get the latched byte from serial port, clear flag
        tya
	rts

BCMD:	!byte $1f, $30, $55	; 'U0',$1F == Burst Fastload command
				; If $9F, Doesn't have to be a prg-file

;
cpld_not_present:
                !text "CPLD NOT PRESENT",13,0
not_burst:
		!text 13,"NOT BURST CAPABLE",13,0

}
