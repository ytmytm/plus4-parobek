
;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; note: this version forces slow clock during CIA access (make it optional)
; note: this version flashes the border during load and restores it on every exit path

; 2026-07-26: error reporting reworked to match the VIA version.
;   - load_status is now always written (the caller presets $80 = "not handled";
;     leaving it alone after a successful load made iec_load fall through to the
;     1541/parallel test and then load the file a second time via the ROM)
;   - the old "sta ErrNo+1" self-modifying trick could never work: this macro is
;     expanded at burstcart.asm:iecburst_load, which lives in ROM at $8000+,
;     so ErrNo always returned 5 = "device not present"
;   - the secondary address is kept in load_sa, not RAM_ZPVEC1 ($03/$04, which
;     print_msg uses as its own string pointer)
;   - the load-address test had inverted polarity; per the Kernal's own code
;     (see shared_rom_check in burstcart.asm) SA!=0 means "use the address from
;     the file" and SA==0 means "relocate to the caller's address"

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
	lda TED_BORDER		; remember the border colour before anything
	sta RAM_TED_BORDER_BACKUP ;  can branch to End, which restores it

	; check if CIA is present
	lda #$00						; port B input
	sta ciabase+3
	cmp ciabase+3
	bne NotCIA

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
	lda #$80
	sta load_status		; not handled -> fall back to ROM load
	lda #<cia_not_present
	ldy #>cia_not_present
	jmp print_msg

CIAFound:
        lda #$81
	sta ciabase+14		; start timer A, serial IN, TOD 50Hz

	lda #<iec_type_txt	; append the device type to "IEC DEVICE, "
	ldy #>iec_type_txt	;  (hardware is present - this is the silent
	jsr print_msg		;   detection point, same idea as t2sd_detect)

	jsr eF160		;print "SEARCHING" ; XXX too early - will show "SEARCHING" twice if device is not burst capable

	lda RAM_FNLEN		; preserve the filename length
	pha
	lda RAM_SA		; same with secondary address
	sta load_sa		; temp (private byte, survives print_msg)

	lda #0
	sta RAM_FNLEN		; no filename for command channel
	lda #15
	sta RAM_SA		; secondary address 15 == command channel
	lda #CMD_CHANNEL
	sta RAM_LA		; logical file number (15 might be in use)
	jsr ROM_OPEN
	sta load_status
    lda load_sa		; restore secondary address
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
	sta load_status
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
	lda load_sa		; The secondary address - do we use the load
				;  address in the file or the one given to
	beq Our			;  us by the caller ?  (SA==0 -> caller's,
				;   already in RAM_MEMUSS from myload)
	stx RAM_MEMUSS		; SA!=0 -> use file's load addr. -> store it.
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
	lda #0
	sta load_status		; loaded OK - tell iec_load we handled it
	clc			; carry clear -> no error indicator
	bcc End

FileNotFound:
	pla			; Pop the return address (from HandleStat)
	pla
	jsr eE2B8		; Serial clock on (the normal value)
	lda #4			; File not found
	sta load_status
	bne NoDevClose
NoDev:
	lda #5			; Device not present
	sta load_status
NoDevClose:
	lda #CMD_CHANNEL
	jsr ROM_CLOSE		; Close the command channel
ErrNo:
	lda load_status
	sec			; carry set -> error indicator
End:
	pha			; A = error code / 0 and C = error indicator are
	php			;  return values, so keep them across the restore
	lda RAM_TED_BORDER_BACKUP
	sta TED_BORDER		; undo the border flashing
	plp
	pla
    ldx RAM_MEMUSS		; Loader returns the end address,
	ldy RAM_MEMUSS+1	;  so get it into regs..
	cli
	rts			; Return from the loader
				; load_status was set on every path above

NotFast:			; device doesn't handle burst
	lda #CMD_CHANNEL
	jsr ROM_CLOSE
	jsr ROM_CLRCHN		; close file
	lda #$80
	sta load_status		; not handled -> pass to ROM load
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
iec_type_txt:
		!text "CIA BURST",0	; no trailing CR - whatever prints next
				;  (SEARCHING, NOT BURST CAPABLE, a BASIC error)
				;  brings its own leading CR
cia_not_present:
                !text "CIA NOT PRESENT",13,0
not_burst:
		!text 13,"NOT BURST CAPABLE",13,0

}
