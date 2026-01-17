
; Drivecode for 1551 without RAMBOard, based on HypaLoad v4.7, but with full handshake protocol to keep the same receiver code as with RAMBOard

; 1551 DOS routines
LE781           = $E781
LF145           = $F145
LF388           = $F388
LF52C           = $F52C
LF560           = $F560
LFFFC           = $FFFC

hypa1551_drivecode:
        !pseudopc $0300 {
hypa1551_drivecode_start:
; copy t&s of first sector of the file to $0202/3
        lda     $1A
        sta     $0202
        lda     $1B
        sta     $0203

.L0306: sei			; t&s of 1st sector is in $0202/3 now
        tsx
        stx     $3B
        lda     $01
        ora     #$04
        and     #$F7
        sta     $01
        jsr     .L0475		; read and decode any header to get current track number
        dec     $4003

; main loop, go back here after reading and transfering sector (until the last one)
.L0318: jsr     .L03E4		; move header to track
        lda     $0202		; copy desired t&s to $1a/1b (header space)
        sta     $1A
        lda     $0203
        sta     $1B
        jsr     LF52C		; compute required header ($18-$1B) checksum into $1C, encode, wait for header to arrive
        jsr     LF560		; wait for sync before sector data

.L032E: bit     $01		; sector read & gcr decode, copied from ROM, store into $0600 - BUFPNT ignored
        bpl     .L032E
        lda     $4001
        sta     $FA
        and     #$F8
        tax
        lda     $F70C,x
        sta     $F9
        lda     $FA
        and     #$07
        sta     $FA
.L0345: bit     $01
        bpl     .L0345
        lda     $4001
        sta     $FB
        jmp     .L0388

        pha
        bne     .L0386
        beq     .L0386
.L0356: bit     $01
        bpl     .L0356
        lda     $4001
        sta     $FA
        and     #$F8
        tax
        lda     $F70C,x
        sta     $F9
        lda     $FA
        and     #$07
        sta     $FA
.L036D: bit     $01
        bpl     .L036D
        lda     $4001
        sta     $FB
        and     #$C0
        ora     $FA
        tax
        lda     $F70C,x
        ora     $F9
        sta     $0600,y
        iny
        beq     .L03E1		; end of buffer - 256 bytes
.L0386: lda     $FB
.L0388: and     #$3E
        tax
        lda     $F70C,x
        sta     $F9
        lda     $FB
        and     #$01
        sta     $FB
.L0396: bit     $01
        bpl     .L0396
        lda     $4001
        sta     $FC
        and     #$F0
        ora     $FB
        tax
        lda     $F70E,x
        ora     $F9
        sta     $0600,y
        iny
        lda     $FC
        and     #$0F
        sta     $FC
.L03B3: bit     $01
        bpl     .L03B3
        lda     $4001
        sta     $FD
        and     #$80
        ora     $FC
        tax
        lda     $F71C,x
        sta     $F9
        lda     $FD
        and     #$7C
        tax
        lda     $F70D,x
        ora     $F9
        sta     $0600,y
        iny
        lda     $FD
        and     #$03
        sta     $FD
.L03DA: bit     $01
        bpl     .L03DA
        jmp     .L04A2

.L03E1: jmp     .L04C2		; whole sector was read, now transfer it

; move head from current track ($29 decoded from a header) to desired ($0202)
.L03E4: lda     $0202
        cmp     $29
        bne     +
        rts
+       ldx     #$00
        sec
        sbc     $29
        beq     .L0422
        bcs     .L03F6
        eor     #$FF
        adc     #$01
        ldx     #$01
.L03F6: stx     .L03FB+1
        asl
        tax

.L03FB:	lda	#$00
        eor     $01
        sec
        rol
        and     #$03
        eor     $01
        sta     $01
        stx     .L057A
        ldy     #$04
.L040C: ldx     #$00
.L040E: lda     $4000
        lda     $4000
        dex
        bne     .L040E
        dey
        bne     .L040C
        ldx     .L057A
        dex
        bne     .L03FB
        stx     $7A

.L0422: lda     $0202		; copy desired track to $29 (but we're already there?)
        sta     $29
        sta     $79
        ldx     #$04
.L042B: cmp     $F119,x		; density zone selector
        dex
        bcs     .L042B
        txa
        asl
        asl
        asl
        asl
        asl
        sta     $38
        lda     $01
        and     #$9F
        ora     $38
        sta     $01
        rts

; read header
.L0442: lda     #$5A		; attempt counter, no error reported anyhow if reached
        sta     .L057A
.L0447: dec     .L057A
        bne     .L044C
.L044C: jsr     .L0485		; sync?
.L044F: bit     $01
        bpl     .L044F
        bit     $4000
        lda     $4001
        cmp     #$52		; header?
        bne     .L0447
        sta     $0111
        ldy     #$01
.L0462: bit     $01
        bpl     .L0462
        bit     $4000
        lda     $4001
        sta     $0111,y		; GCR-encoded header at $0111
        iny
        cpy     #$08
        bne     .L0462
        rts

; read header + decode with ROM, copy decoded track ($1A) to $29 - needed only to get current track number
.L0475: jsr     .L0442
        jsr     LF388
        lda     $1A
        sta     $29
.L047F: lda     $4002
        bmi     .L047F
        rts

; wait for sync, copy of $f560 that doesn't exit through error routine back to mainloop if timeout
.L0485: ldy     #$12
.L0487: ldx     #$FF
.L0489: lda     $4002
        and     #$40
        beq     .L0496
        dex
        bne     .L0489
        dey
        bne     .L0487
.L0496: lda     $4001
        bit     $4000
        ldy     #$00
        rts

; part of sector read & gcr decode, continued
.L04A2: lda     $4001
        sta     $FA
        and     #$E0
        ora     $FD
        tax
        lda     $F729,x
        sta     $F9
        lda     $FA
        and     #$1F
        tax
        lda     $F6FF,x
        ora     $F9
        sta     $0600,y
        iny
        jmp     .L0356

; sector read, now transfer via TCBM - there is no ack from +4 side, but it can halt transfer if $01 bit 7 would be 0?
; (or was that bit/bpl + bit/bmi real two-way handshake later patched for faster transfer?)
.L04C2: lda     $01
        eor     #$08            ; blink LED
        sta     $01
        lda     $0600		; next track==0?
        bne     .L04D7
        ldy     $0601		; yes, this is last sector - get # of last byte in buffer to read
        iny
        sty     .L04FE		; store it 
        sty     .L04EA

.L04D7: ldy     #$02            ; skip over t&s

.L04D9: 

-       lda     $4002		; wait for DAV=0
	bmi     -
        lda     $0600,y
        sta     $4000
        lda     #$14
        sta     $4002
        iny
.L04EA=*+1
	cpy	#$00		; last byte needed?
        beq     .L0504		; yes, but issue final ack

-       lda     $4002		; wait for DAV=1
	bpl     -
        lda     $0600,y
        sta     $4000
        lda     #$1C
        sta     $4002
        iny
.L04FE=*+1
	cpy	#$00		; last byte needed?
        bne     .L04D9
        jmp     .L0512		; yes, exit

.L0504:
-       lda     $4002		; wait for DAV=1 here, final ack from even byte
	bpl     -
        lda     #$FF		; reset to default state (not executed when loop exits on odd byte)
        sta     $4000
        lda     #$1C		; required after even byte, already like that after odd byte
        sta     $4002
	; fall through

; after sector transfer
.L0512: lda     $0600		; next track&sector available?
        beq     .L0523
        sta     $0202		; yes, move it $0202/3
        lda     $0601
        sta     $0203
        jmp     .L0318          ; go back to the loop to read next sector from $0202/3

; after last sector transfer
.L0523: lda     #$00
        ldx     $3B		; restore stack pointer
        txs
        pha			; push 0 (no error?)

; end of fastload, indicate no more data
.L0535: ldy     #$17
        sty     $4002
.L053A: lda     $4000		; some kind of long ack?
        iny
        bne     .L053A
        jsr     LF145		; drive init (some initial part skipped)
        pla			; pop 0 (pushed in $0523) - no error?
        beq     .L0574		; no error
        jmp     LE781		; print error into message buffer, go back to the mainloop

; exit from fastloader with no error
.L0574:  jmp     (LFFFC)		; system reset vector

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.L057A:  ;!byte 0		; storage related to head movement

        } // end of pseudopc

hypa1551_drivecode_end:
