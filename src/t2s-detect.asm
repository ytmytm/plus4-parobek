
;; detect tcbm2sd device from 'TCBM2SD' string existing in reset string

;; problem: 'UI' reloads sd card and exits disk image; this is ok in directory browser but not in loader
;; another way: send any command that is valid 'M-R' and check if status is 30,SYNTAX ERROR (tcbm2sd) or else (1551)

;status_buffer = $0fc0 ; $0fc0 to make it visible in status line on screen (XXX DEBUG)
status_buffer = $0340 ; tape buffer

; return C=0 - device is TCBM2SD, C=1 - device is not TCBM2SD (IEC or 1551)

t2sd_detect:
        !zone TCBM2SD_Detect {

        lda #0
        sta RAM_STATUS

        jsr ROM_CLRCHN
        lda RAM_FA
        jsr ROM_LISTEN
        jsr ROM_READST
        and #%10000000          ; device not present?
        beq +
        jsr ROM_UNLISTEN
        jmp detect_t2sd_3

+       lda #$6F
        jsr ROM_SECOND
        lda #'M'
        jsr ROM_CIOUT
        lda #'-'
        jsr ROM_CIOUT
        lda #'R'
        jsr ROM_CIOUT
        lda #$00
        jsr ROM_CIOUT           ; read from ROM
        lda #$c0
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
        bne detect_t2sd_2
        inx
        cpx #30                 ; one line at most
        bne -

detect_t2sd_2:
        jsr ROM_CLRCHN
        jsr ROM_UNTLK

detect_t2sd_3:
        ; search for signature
        lda #<status_buffer
        sta $d0
        lda #>status_buffer
        sta $d1
        ldy #0      ; check start
        sty $d2

detect_t2sd_sigloop1:
        ldy $d2
        ldx #0
-       lda detect_t2sd_signature,x
        beq detect_t2sd_detected
        cmp ($d0),y
        bne detect_t2sd_signext
        iny
        inx
        bne -

detect_t2sd_detected:
        ;; TCBM2SD detected
        clc
        rts

detect_t2sd_signext:            ; next character
        inc $d2
        lda $d2
        cmp #40-7-5
        bne detect_t2sd_sigloop1
        ;; TCBM2SD not detected
        sec
        rts

detect_t2sd_signature:
        ; !text "TCBM2SD", 0    ; 73, TCBM2SD BY YTM 2024,00,02
        !text "SYNTAX ERROR", 0 ; 30, SYNTAX ERROR

        ; XXX unused
detect_1551_signature:
        !text "TDISK", 0
}

