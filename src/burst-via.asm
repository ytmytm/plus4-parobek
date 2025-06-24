
;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
; burst loader based on Pasi Ojala's code

; (c) 2025 by Maciej 'YTM/Elysium' Witkowiak

; note: this version flashes border during load, original colour is not restored (needed for debug only)

; todo: with listen/second/acptr/unlisten we don't care about filename/channels and preserving zp values
; todo: inline GetByte in GetAndStore to save some cycles

; regime:
; PB0: set direction 0=out, 1=in (default: input with pullup)
; out: shift out under timer 2 underflow; timer 2 counts Phi
;  in: shift in under CB1 as external clock
; data = CB2, clock = CB1

via_portb	= viabase+0
via_ddrb 	= viabase+2
via_t2lo	= viabase+8
via_t2hi	= viabase+9
via_sr 		= viabase+10
via_acr 	= viabase+11
via_ifr		= viabase+13
via_ier		= viabase+14

!macro InitBurst {
        ; setup VIA
		lda #%00000001
		sta via_portb				; PB0=1 -> SR input
		sta via_ddrb				; port B output
		sta via_portb				; PB0=1 -> SR input
		lda #%01111111
		sta via_ier					; no interrupts
		sta via_ifr
		lda via_sr					; reset sr
		lda #%00001100				; shift in under CB2
		sta via_acr
		lda via_sr					; reset sr
}

!macro LoadBurst {
	; check if VIA is present
	lda #%00000001
	sta via_ddrb				; port B output
	sta via_portb				; PB0=1 -> SR input
	cmp via_ddrb
	bne NotVIA

	; our loading code
;myload_cont:
	ldy #4
	sty via_t2lo		; set clock rate to the fastest possible
	ldy #0
	sty via_t2hi
	sty via_portb		; PB0=0 -> SR output
	lda #%01111111
	sta via_ier			; no interrupts

	lda #%00010100		; shift out under t2
	sta via_acr

	lda #%00000100		; bitmask
	sta via_sr		; trigger transmission
-       iny
	bmi NotVIA              ; timeout, VIA not present or not working
	bit via_ifr		; (but A=4 is special because it's a mask for this bit instruction)
	bne VIAFound
	beq -			; wait until data sent

NotVIA:
        lda #$80
		sta load_status
	lda #<via_not_present
	ldy #>via_not_present
	jmp print_msg

VIAFound:
	lda #%00000001
	sta via_portb		; PB0=1 -> SR input
	lda via_sr			; reset sr
	lda #%00001100		; shift in under CB2
	sta via_acr

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
	sta load_status
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

	lda #%00000100			; how C128 detects burst?
	bit via_ifr		; we should receive something by now
	bne +
	jmp NotFast		; device doesn't handle burst
+
	jsr eF160		; print "SEARCHING"
	jsr eF189		; print "LOADING", uses CHROUT will CLI again
	sei			; loader starts here
	jsr eE2B8		; serial clock on == clk line low
	bit via_ifr		; clear interrupt register
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
	lda #0
	sta load_status
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
    ldx RAM_MEMUSS		; Loader returns the end address,
	ldy RAM_MEMUSS+1	;  so get it into regs..
	cli
	rts			; Return from the loader
				; load_status = 0 so do nothing more

NotFast:			; device doesn't handle burst
	lda #CMD_CHANNEL
	jsr ROM_CLOSE
	jsr ROM_CLRCHN		; close file
	lda #$80
	sta load_status		; return and pass to ROM load
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
	lda #%00000100		; bitmask
-
	bit via_ifr			; wait for a byte
	beq -
ToggleClk:
    ldy via_sr          ; get the latched byte from serial port
	lda $01
	eor #%00000010		; toggle the old serial clock (send Ack)
	sta $01			; disk drive will start sending the next byte
	;lda via_sr		; get the latched byte from serial port
    tya
	rts

BCMD:	!byte $1f, $30, $55	; 'U0',$1F == Burst Fastload command
				; If $9F, Doesn't have to be a prg-file

;
via_not_present:
                !text "VIA NOT PRESENT",13,0
not_burst:
		!text 13,"NOT BURST CAPABLE",13,0

}
