
startup_screen:
		jsr ROM_CINT		; initialize screen editor

		lda #$2e
		sta TED_BACK
		sta TED_BORDER

		lda #$ff
		sta $ff0c
		sta $ff0d           ; hide cursor

		lda #<startup_screen_txt
		ldy #>startup_screen_txt
		jsr print_msg_always
		cli

keys:
-		jsr ROM_GETIN
		beq -
		cmp #$31		; 1
		beq +
		cmp #$32		; 2
		beq +
		cmp #$33		; 3
		beq +
		jmp keys
+		and #$0f
		pha
		lda #147		; clear screen
		jsr ROM_CHROUT
		lda #144		; color black
		jsr ROM_CHROUT
		jsr ROM_IOINIT
		sei
		pla
		rts

startup_screen_txt:

		!byte 147
		!byte 5 ; white
		;      1234567890123456789012345678901234567890
		!text "           BURSTCART ROM V1.0",13,13
		!text "        (C) BY YTM/ELYSIUM 2025",13,13
		!fill 40, 163
		!byte 13,13,13
		!text "         1. NORMAL RESET",13,13
		!text "         2. DIRECTORY BROWSER",13,13
		!text "         3. INSTALL FASTLOAD",13
		!byte 0

