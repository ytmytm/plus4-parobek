
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
    !byte	"/"	; 2 load BASIC
    !byte   "^"	; 3 load and RUN
    !byte   "_"	; 4 <- save

dos_jump_table_lo:
    !byte   <dos_status
    !byte   <dos_dir
    !byte   <dos_wedge_end
    !byte   <dos_wedge_end
    !byte   <dos_wedge_end

dos_jump_table_hi:
    !byte   >dos_status
    !byte   >dos_dir
    !byte   >dos_wedge_end
    !byte   >dos_wedge_end
    !byte   >dos_wedge_end

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
+       stx cmd_len	; store length

        jmp (cmd_vec)

dos_dir:
        lda #<$C8BC
        sta cmd_vec
        lda #>$C8BC
        sta cmd_vec+1
        lda #$80
        clc
        rts

dos_status:
        lda cmd_len
        beq dos_display_status
        ; XXX next char is digit 8,9,1? yes->set device number
        ; send command to drive
        lda RAM_FA
        beq dos_status_end
        jsr ROM_LISTEN
        lda #$6F
        jsr ROM_SECOND
        ldy #0
-       lda cmd_text,y
        jsr ROM_CIOUT
        iny
        cpy cmd_len
        bne -
        jsr ROM_UNLISTEN
        jmp dos_wedge_end

dos_display_status:
        lda RAM_FA
        beq dos_status_end
        jsr ROM_TALK
        lda #$6F
        jsr ROM_TKSA
-       jsr ROM_ACPTR
        cmp #$0D
        beq +
        jsr ROM_CHROUT
        jmp -
+       jsr ROM_CHROUT
        jsr ROM_UNTLK

dos_status_end:
        jmp dos_wedge_end

dos_wedge_end:
        lda #0
        clc
        rts

