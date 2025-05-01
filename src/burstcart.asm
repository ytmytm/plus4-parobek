!to "bin/burstcart.bin",plain

;--------------------------------------------------
; Commodore 16 and Plus/4 Burst cartridge 
;

RAM_ZPVEC1	= $03	; (2) temp

RAM_VERFCK	= $93	; 0=load, 1=verify
RAM_FNLEN	= $AB	; filename length
RAM_LA		= $AC	; logical address
RAM_SA		= $AD	; secondary address
RAM_FA		= $AE	; device number
RAM_FNADR	= $AF	; vector to filename
RAM_MEMUSS	= $B4	; load RAM base ($AE/AF on C64)
RAM_CURBNK	= $FB	; current ROM bank

RAM_ILOAD	= $032E	; LOAD vector

LNGJMP		= $05F0	; Long jump address
FETARG		= $05F2	; Long jump accumulator
FETXRG		= $05F3	; Long jump x register
FETSRG		= $05F4	; Long jump status register 

RAM_RLUDES	= $07D9 ; read from (e07DF),y from RAM
a07DF		= $07DF ; zp address of vector for RLUDES

ROM_ILNGJMP	= $FCFA ; jumptable to LONGJMP ($FC89)
eE2B8		= $E2B8 ; clk hi (inverted)
eF160		= $F160	; print 'SEARCHING'
eF189		= $F189 ; print 'LOADING'
ROM_OPEN	= $FFC0
ROM_CLOSE	= $FFC3
ROM_CHKOUT	= $FFC9
ROM_CLRCHN	= $FFCC
ROM_CHROUT	= $FFD2

ciabase		= $FD90

; ?detect if CIA is present at CIABASE
; install LOAD wedge
; ?detect which drive has burst
; ?1551warp for 1551?
; ?speeddos for 1541+parallel?
; ?anyfastload for 1541?
; ?quasiburst for tcbm2sd?
; ?embedded directory browser (one for tcbm2sd)
	; ?setup TOD clock (50Hz)
	; ?display clock in top right in directory browser?

lowmem_code 	= $0610	; our bank number and trampoline into ROM

		*=$8000
; header
		jmp coldstart	; coldstart, install
		jmp warmstart	; warmstart, run from basic
!by $09			; module-nr, $00=empty, $01=autostart
!by $43,$42,$4d		; module-nr., "CBM"

coldstart:
	lda RAM_CURBNK
	and #$03		; enable kernal in top half so we don't care about IRQ
	tax			; (if we want top half, set $FFFE/F to FCB3 - Kernal paged IRQ; then need own eF160 etc.)
	sta RAM_CURBNK
	sta buf_ourbank
	sta $fdd0,x

warmstart:
	; install trampoline
	ldx #2			; skip over buffers
-	lda lowmem_trampoline,x
	sta lowmem_code,x
	inx
	cpx #lowmem_trampoline_end-lowmem_trampoline
	bne -
	
	; install LOAD vector
	lda RAM_ILOAD
	cmp #<myloadlow
	beq +			; already installed
	sta loadrom+1
	lda RAM_ILOAD+1
	sta loadrom+2
	lda #<myloadlow
	sta RAM_ILOAD
	lda #>myloadlow
	sta RAM_ILOAD+1

	; welcome message
+	ldx #0
-	lda startup_txt,x
	beq +
	jsr $ffd2
	inx
	bne -
+	rts

lowmem_trampoline:
	!pseudopc lowmem_code {
buf_ourbank:	!byte 0		; our bank number: internal/external1/external2
load_status:	!byte 0		; 0 = go to ROM routine for load, !=0 = return

myloadlow:
	sta RAM_VERFCK		; remember A
	sta FETARG
	stx FETXRG
	lda #%00000100		; status reg: C=0, I=1
	sta FETSRG
	lda #<myload
	sta LNGJMP
	lda #>myload
	sta LNGJMP+1
	lda RAM_CURBNK		; caller bank (current)
	ldx buf_ourbank		; target bank (our ROM)
	jsr ROM_ILNGJMP
	lda load_status		; did we load or not?
	bne +			; no, continue in original (Kernal) code
	ldx FETXRG		; restore state and return
	lda FETSRG
	pha
	lda FETARG
	plp
	rts
+	lda RAM_VERFCK		; stored A
loadrom:
	jmp $F04C		; -> F04C
	} ; pseudopc

lowmem_trampoline_end:

; OUT:
; load_status = 0 - loaded, then:
; A=error code (if C=1) or C=0
; X/Y last byte loaded
; load_status = 1 - not loaded, pass back to ROM
;
myload:
	lda RAM_VERFCK		;VERFCK  Flag:  0 = load,  1 = verify
	sta load_status 	; will be 0 for load, not 0 for verify
	cmp #0			; load or verify?
	beq +
	rts			; pass back to ROM code
+	stx RAM_MEMUSS		; load addr
	sty RAM_MEMUSS+1
	lda RAM_FA		;FA      Current device number
	cmp #4
	bcc +			;less than 4 - tape
	lda #RAM_FNADR		;filename at ($AF/$B0)?
	sta a07DF
	ldy #0
	jsr RAM_RLUDES		;RLUDES  Indirect routine downloaded
	cmp #'$'		;if '$' then ROM load
	bne myload_cont
+	inc load_status		; pass back to ROM code
	rts

	; our loading code
myload_cont:
	ldy #1
	sty ciabase+4		; set clock rate to the fastest possible
	dey
	sty ciabase+5
	lda #$c1		; start timer A, serial OUT, TOD 50Hz
	sta ciabase+14
	bit ciabase+13		; clear interrupt register
	lda #8			; data to be sent and interrupt mask (following BIT)
	sta ciabase+12		; (we wake up the other end so that it believes we can do burst transfers, actual data doesnt matter)
-	bit ciabase+13		; (but 8 is special because it's a mask for this bit instruction)
	beq -			; wait until data sent XXX this will lockup if there is no CIA --> add timeout via Y register

	lda #$81
	sta ciabase+14		; start timer A, serial IN, TOD 50Hz

	jsr eF160		;print "SEARCHING"

	lda RAM_FNLEN		; preserve the filename length
	pha
	lda RAM_SA		; same with secondary address
	sta RAM_ZPVEC1		; temp

	lda #0
	sta RAM_FNLEN		; no filename for command channel
	lda #15
	sta RAM_SA		; secondary address 15 == command channel
	lda #239
	sta RAM_LA		; logical file number (15 might be in use)
	jsr ROM_OPEN
	sta ErrNo+1
	pla
	sta RAM_FNLEN		; restore filename length
	bcs ErrNo		; "device not present", "too many open files", "file already open"
	; Send burst command for Fastload
	ldx #239
	jsr ROM_CHKOUT		; command channel as output
	sta ErrNo+1
	bcs NoDev		; "device not present" or other errors

	lda #8
	bit ciabase+13		; we should receive something by now
	beq NotFast

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

	sei
	jsr eE2B8		; serial clock on == clk line low
	bit ciabase+13		; clear interrupt register
	jsr ToggleClk		; toggle clock

	jsr HandleStat		; get initial status
	pha			; keep it

	jsr eF189		; print LOADING, uses CHROUT will CLI again
	sei

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
	lda #239
	jsr ROM_CLOSE		; Close the command channel
	clc			; carry clear -> no error indicator
	bcc End

FileNotFound:
	pla			; Pop the return address
	pla
	jsr eE2B8		; Serial clock on (the normal value)
	lda #4			; File not found
	sta ErrNo+1
NoDev:	lda #239
	jsr ROM_CLOSE		; Close the command channel
ErrNo:	lda #5			; Device not present
	sec			; carry set -> error indicator
End:	ldx RAM_MEMUSS		; Loader returns the end address,
	ldy RAM_MEMUSS+1	;  so get it into regs..
	cli
	rts			; Return from the loader
				; load_status = 0 so do nothing more

NotFast:			; device doesn't handle burst
	lda #239
	jsr ROM_CLOSE
	jsr ROM_CLRCHN		; close file
	inc load_status		; return and pass to ROM load
	rts

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
sta $ff19 ; XXX flash border
	ldy #0
	sta (RAM_MEMUSS),y	; Store the byte
	inc RAM_MEMUSS
	bne +
	inc RAM_MEMUSS+1
+	dex			; X= number of bytes to receive
	bne GetAndStore
	rts

GetByte:
	lda #8
-	bit ciabase+13		; wait for a byte
	beq -
ToggleClk:
	lda $01
	eor #%00000010		; toggle the old serial clock (send Ack)
	sta $01			; disk drive will start sending the next byte
	lda ciabase+12		; get the latched byte from serial port
	rts

BCMD:	!byte $1f, $30, $55	; 'U0',$1F == Burst Fastload command
				; If $9F, Doesn't have to be a prg-file

;

startup_txt:
	!text " VEC INSTALLED",13,0

	; anything above $C000 comes from KERNAL (see coldstart)

!fill ($10000-*), $ff

