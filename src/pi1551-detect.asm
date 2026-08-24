
;; detect PI1551 in browser mode by checking for 'PI1551' string existing in reset string

;; eventually this should be removed, we should be able to use tcbm2sd or 1551-RAMBOard protocol in browser mode
;; (tcbm2sd support can be transparent without altering the ROM, just include "PI1551 TCBM2SD COMPAT" in the reset string) 

;; this must run *after* tcbm2sd detect to avoid exiting sd card image

; status_buffer ($0200) defined in t2s-detect.asm

; return C=0 - device is PI1551, C=1 - device is not PI1551 (1551 with or without RAMBOard)

pi1551_detect:
        !zone PI1551_Detect {

        lda #0
        sta RAM_STATUS

        jsr ROM_CLRCHN
        lda RAM_FA
        jsr ROM_LISTEN
        jsr ROM_READST
        and #%10000000          ; device not present?
        beq +
        jsr ROM_UNLISTEN
        jmp .detect_pi1551_3

+       lda #$6F
        jsr ROM_SECOND
        lda #'U'
        jsr ROM_CIOUT
        lda #'I'
        jsr ROM_CIOUT
        jsr ROM_UNLISTEN

        lda RAM_FA
        jsr ROM_TALK
        lda #$6F
        jsr ROM_TKSA

        ldx #0                  ; read status message
-       jsr ROM_ACPTR
        sta status_buffer,x     ; message line
        jsr ROM_READST
        and #%01000000          ; eoi?
        bne .detect_pi1551_2
        inx
        cpx #30                 ; one line at most
        bne -

.detect_pi1551_2:
        jsr ROM_CLRCHN
        jsr ROM_UNTLK

.detect_pi1551_3:
        ; search for signature
        lda #<status_buffer
        sta $d0
        lda #>status_buffer
        sta $d1
        ldy #0      ; check start
        sty $d2

.detect_pi1551_sigloop1:
        ldy $d2
        ldx #0
-       lda .detect_pi1551_signature,x
        beq .detect_pi1551_detected
        cmp ($d0),y
        bne .detect_pi1551_signext
        iny
        inx
        bne -

.detect_pi1551_detected:
        ;; PI1551 detected
        clc
        rts

.detect_pi1551_signext:            ; next character
        inc $d2
        lda $d2
        cmp #30                 ; one line at most
        bne .detect_pi1551_sigloop1
        ;; PI1551 not detected
        sec
        rts

.detect_pi1551_signature:
        !text "PI1551", 0
}
