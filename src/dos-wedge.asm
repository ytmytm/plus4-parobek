
TXTPTR = $3b

CHRGET = $0473
CHRGOT = $0479

cmd_buffer = $0340 ; tape buffer
cmd_vec = cmd_buffer        ; (2)
cmd_len = cmd_buffer+2      ; (1)
cmd_text = cmd_buffer+3     ; (40)

cmd_table:
    !byte   "@"	; 0 command/status/device
    !byte   "$" ; 1 directory
    !byte   "/"	; 2 dload
    !byte   "_"	; 3 <- dsave

dos_jump_table_lo:
    !byte   <dos_status
    !byte   <dos_dir
    !byte   <dos_dload
    !byte   <dos_dsave

dos_jump_table_hi:
    !byte   >dos_status
    !byte   >dos_dir
    !byte   >dos_dload
    !byte   >dos_dsave

; out: A=0 return, <>0 pass to ROM
doswedge_parse:

        jsr CHRGOT
        ldx #0
-       cmp cmd_table,x
        beq +
        inx
        cpx #5
        bne -
        lda #1			; pass to ROM
        clc
        rts

        ; handle commands
+
        lda dos_jump_table_lo,x
        sta cmd_vec
        lda dos_jump_table_hi,x
        sta cmd_vec+1

inc TED_BORDER
        ; patch CHRGT to not ignore spaces
        lda #$ff
        sta $048a
        ; consume input until end of line
        ldx #0
-       jsr CHRGET
        sta cmd_text,x  ; store command text
        cmp #0
        beq +
        jsr ROM_CHROUT
        inx
        cpx #40             ; max length one line
        bne -
+       stx cmd_len	    ; store length
        lda #$20            ; restore CHRGT to ignore spaces
        sta $048a
        jmp (cmd_vec)

dos_dir:
        lda #<$C8BC
        sta cmd_vec
        lda #>$C8BC
        sta cmd_vec+1
        lda #$80
        clc
        rts

dos_filename_scan:
; scan - is there a quote?
        ldx #0
-       lda cmd_text,x
        beq +
        cmp #$22
        beq dos_filename_scan_skip_until_quote
        inx
        cpx cmd_len
        bne -
+       jmp dos_filename_scan_end

dos_filename_scan_skip_until_quote:
        ldy #0
-       inx
        lda cmd_text,x
        cmp #$22
        bne +
        lda #0
+       sta cmd_text,y
        beq dos_filename_scan_end
        iny
        bne -

dos_filename_scan_end:
        lda #$22        ; quote
        sta cmd_text-1
        lda #<(cmd_text-1)
        sta TXTPTR
        lda #>(cmd_text-1)
        sta TXTPTR+1
        rts

dos_dload:
        lda #<$C951
        sta cmd_vec
        lda #>$C951
        sta cmd_vec+1
        jsr dos_filename_scan
        lda #$80
        clc
        rts

dos_dsave:
        lda #<$C941
        sta cmd_vec
        lda #>$C941
        sta cmd_vec+1
        jsr dos_filename_scan
        lda #$80
        clc
        rts

dos_status:
        lda #0
        sta RAM_STATUS
        lda cmd_len
        beq dos_display_status
        ; if next char is a digit 8,9,1? yes->set device number
        lda cmd_text
        tay
        and #$f0
        cmp #$30
        bne dos_send_command
        tya
        and #$0f
        cmp #$01        ; 10 or 11?
        beq dos_device_number_1x
        sta RAM_FA
        rts
dos_device_number_1x:
        lda cmd_text+1
        and #$0f
        clc
        adc #10
        sta RAM_FA
        rts

        ; send command to drive
dos_send_command:
        lda RAM_FA
        beq dos_status_end
        jsr ROM_LISTEN
        jsr ROM_READST
        and #%10000000          ; device not present?
        bne dos_send_command_end
        lda #$6F
        jsr ROM_SECOND
        ldy #0
-       lda cmd_text,y
        jsr ROM_CIOUT
        iny
        cpy cmd_len
        bne -
dos_send_command_end:
        jsr ROM_UNLISTEN
        jmp dos_wedge_end

dos_display_status:
        lda RAM_FA
        beq dos_status_end
        jsr ROM_TALK
        jsr ROM_READST
        and #%10000000          ; device not present?
        bne dos_display_status_end
        lda #$6F
        jsr ROM_TKSA
-       jsr ROM_ACPTR
        bcs dos_display_status_end
        cmp #$0D
        beq +
        jsr ROM_CHROUT
        jmp -
+       jsr ROM_CHROUT
dos_display_status_end:
        jsr ROM_UNTLK

dos_status_end:
        jmp dos_wedge_end

dos_wedge_end:
        lda #0
        clc
        rts

