; da65 V2.19 - Git dcdf7ade0
; Created:    2026-08-25 13:50:25
; Input file: megaload_v4.prg
; Page:       1


        .setcpu "6502"

L0123           := $0123
L012C           := $012C
L0138           := $0138
L0146           := $0146
L0155           := $0155
L0310           := $0310
L0403           := $0403
L044D           := $044D
L0483           := $0483
L0496           := $0496
L0512           := $0512
L0537           := $0537
L05DA           := $05DA
L061F           := $061F
L069C           := $069C
L07D9           := $07D9
L3456           := $3456
L3631           := $3631
L4D12           := $4D12
L5942           := $5942
L8025           := $8025
L8030           := $8030
L88C7           := $88C7
LE645           := $E645
LECDF           := $ECDF
LEE2C           := $EE2C
LEE4D           := $EE4D
LEF23           := $EF23
LF04C           := $F04C
LF06B           := $F06B
LF215           := $F215
LF24B           := $F24B
LF50A           := $F50A
LF556           := $F556
LF7E6           := $F7E6
LF969           := $F969
LF980           := $F980
LF9B9           := $F9B9
LFA00           := $FA00
LFA4A           := $FA4A
LFA93           := $FA93
LFAE8           := $FAE8
LFAFF           := $FAFF
LFBC7           := $FBC7
LFC74           := $FC74
LFE00           := $FE00
LFF30           := $FF30
LFF49           := $FF49
LFF4F           := $FF4F
        asl     a:$10
        brk
        .byte   $9E
        .byte   $34
        .byte   $31
L1008:  and     ($32),y
        .byte   $42
        eor     $43,y
        brk
        brk
L1010:  ldx     $2D
        ldy     $2E
        stx     $5A
        sty     $5B
        ldx     #$93
        ldy     #$10
        stx     $5F
        sty     $60
        lda     #$00
        sta     $58
        lda     #$FD
        sta     $59
        jsr     L88C7
        sei
        sta     $FF3F
        ldx     #$56
L1031:  lda     L103D,x
        sta     L0123,x
        dex
        bpl     L1031
        jmp     L0138

L103D:  lda     ($58),y
        inc     $58
        bne     L1045
        inc     $59
L1045:  rts

        sta     ($2D),y
        inc     $2D
        bne     L104E
        inc     $2E
L104E:  bit     $FF19
        rts

        ldx     #$01
        ldy     #$10
        stx     $2B
        sty     $2C
        .byte   $86
L105B:  and     $2E84
        inc     $59
L1060:  ldy     #$00
        lda     $59
        cmp     #$FD
        beq     L108C
        jsr     L0123
        cmp     #$FD
        beq     L1075
        jsr     L012C
        jmp     L0146

L1075:  jsr     L0123
        tax
        bne     L1081
        lda     $0152
        jmp     L0155

L1081:  jsr     L0123
L1084:  jsr     L012C
        dex
        bne     L1084
        beq     L1060
L108C:  sta     $FF3E
        cli
        jmp     L1234

        .byte   $0B
        bpl     L105B
        .byte   $07
        .byte   $9E
        .byte   $34
        .byte   $36
L109A:  rol     $30,x
        sbc     a:$06,x
        jmp     L0483

        ldy     #$1F
L10A4:  lda     $0300,y
        jsr     L044D
        lda     $0320,y
        jsr     L044D
        lda     $0340,y
        jsr     L044D
        lda     $0360,y
        jsr     L044D
        lda     $0380,y
        jsr     L044D
        lda     $03A0,y
        jsr     L044D
        lda     $03C0,y
        jsr     L044D
        lda     $03E0,y
        jsr     L044D
        lda     $01BA,y
        jsr     L044D
        lda     $01DA,y
        jsr     L044D
        dey
        bpl     L10A4
        lda     $1C00
        eor     #$08
        sta     $1C00
        rts

        tax
L10ED:  bit     $1800
        bpl     L10ED
        lda     #$10
        sta     $1800
L10F7:  bit     $1800
        bmi     L10F7
        txa
        sbc     $4A04,x
        nop
        sta     $1800
        asl     a
        and     #$0F
        nop
        sta     $1800
        txa
        and     #$0F
        nop
        .byte   $8D
L1110:  brk
        clc
        asl     a
        and     #$0F
        nop
        sta     $1800
        lda     #$0F
        nop
        nop
        sta     $1800
        rts

        lda     #$EE
        sta     $1C0C
        jsr     LFE00
        lda     #$00
        sta     $09
        lda     $08
        jsr     LF24B
        sta     $C2
L1134:  jsr     LF556
L1137:  bvc     L1137
        clv
        lda     $1C01
        cmp     #$52
        bne     L1134
        ldx     #$00
L1143:  bvc     L1143
        clv
        lda     $1C01
        sta     $0301,x
        inx
        cpx     #$05
        bne     L1143
        jsr     LF556
L1154:  bvc     L1154
        clv
        lda     $1C01
        sta     $0300,x
        inx
        cpx     #$0A
        bne     L1154
        lda     #$00
        sta     $34
        sta     $30
        lda     #$03
        sta     $31
        jsr     LF7E6
        ldx     $09
        lda     $54
        sta     $0760,x
        jsr     LF7E6
        ldx     $09
        lda     $53
        sta     $0700,x
        lda     $54
        sta     $0720,x
        inc     $09
        lda     $C2
        cmp     $09
        beq     L1190
        jmp     L0496

L1190:  ldy     #$00
L1192:  ldx     #$FF
        tya
L1195:  inx
        cmp     $0760,x
        bne     L1195
        txa
        sta     $0780,y
        iny
        cpy     $C2
        bcc     L1192
        ldx     $0F
        lda     #$80
        sta     $C3
        ldy     #$00
        sty     $09
        sty     $C4
        iny
        lda     $0780,x
        tax
        tya
        sta     $0740,x
        lda     $0700,x
        cmp     $08
        bne     L11C7
        lda     $0720,x
        tax
        jmp     L0512

L11C7:  stx     $0F
        cmp     #$00
        bne     L11D1
        lda     #$40
        sta     $C4
L11D1:  sty     $0E
        lda     #$00
        tax
L11D6:  lda     $0740,x
        bne     L11E4
        inx
        cpx     $C2
        bcc     L11D6
        ldx     #$00
        beq     L11D6
L11E4:  stx     $0A
        lda     $0760,x
        sta     $09
        lda     #$03
        sta     $31
        jsr     LF50A
L11F2:  bvc     L11F2
        clv
        lda     $1C01
        sta     ($30),y
        iny
        bne     L11F2
        ldy     #$BA
L11FF:  bvc     L11FF
        clv
        lda     $1C01
        sta     $0100,y
        iny
        bne     L11FF
        lda     #$00
        .byte   $85
L120E:  rol     $85,x
L1210:  .byte   $34
        lda     #$0D
        sta     $0C
L1215:  jsr     LF7E6
        ldx     $36
        lda     $52
        sta     $02FF,x
        lda     $53
        sta     $0300,x
        lda     $54
        sta     $0301,x
        lda     $55
        sta     $0302,x
        txa
        clc
        adc     #$04
        sta     $36
L1234:  dec     $0C
        bne     L1215
        ldx     #$02
L123A:  lda     $01FA,x
        sta     $0334,x
        dex
        bpl     L123A
        ldx     $0A
        lda     $0740,x
        dec     $0E
        bne     L124E
        ora     $C4
L124E:  ora     $C3
        tax
        dex
        stx     $0337
        lda     #$00
        ldx     $0A
        sta     $0740,x
        sta     $C3
        jsr     L0403
        lda     $0E
        beq     L1273
        lda     $0A
        clc
        adc     #$05
        cmp     $C2
        bcc     L1270
        sbc     $C2
L1270:  jmp     L0537

L1273:  lda     #$01
        jmp     LF969

        cli
        lda     #$12
        sta     $1C07
        lda     #$0F
        sta     $1800
        ldx     #$00
        txa
        sta     $C4
L1288:  sta     $0700,x
        inx
        bne     L1288
        lda     $18
        ldx     $19
L1292:  sta     $08
        stx     $0F
        lda     #$E0
        sta     $01
L129A:  lda     $01
        bmi     L129A
        cmp     #$01
        bne     L12AE
        ldy     $0F
        ldx     $0720,y
        lda     $0700,y
        bne     L1292
        beq     L12BD
L12AE:  sei
        lda     #$20
        sta     $0337
        jsr     L0403
        jsr     L061F
        jmp     LE645

L12BD:  lda     #$01
        sta     $1C
        rts

        sei
        ldx     #$00
L12C5:  lda     L1010,x
        sta     $F200,x
        lda     L1110,x
        sta     $F300,x
        lda     L1210,x
        sta     $F400,x
        lda     L1310,x
        sta     $F500,x
        lda     L1410,x
        sta     $F900,x
        lda     L1510,x
        sta     LFA00,x
        lda     L1610,x
        sta     $FB00,x
        lda     L1710,x
        sta     $FC00,x
        lda     $17CD,x
        sta     $0600,x
        inx
        bne     L12C5
        lda     #$F2
        sta     $0534
        stx     $05EC
        stx     $05ED
        stx     $05EE
        stx     $05EF
        .byte   $20
L1310:  dec     $20F2
        brk
        asl     $20
        .byte   $17
        sta     ($20,x)
        rol     $2080
        .byte   $C2
        .byte   $80
        jsr     L1339
        jsr     LFF4F
        ora     ($20),y
        jsr     L4D12
        eor     $47
        eor     ($4C,x)
        .byte   $4F
        eor     ($44,x)
        jsr     L3456
        .byte   $92
        jsr     L5942
        .byte   $20
        .byte   $50
L1339:  eor     #$47
        eor     $5359
        .byte   $4F
        lsr     $54
        jsr     L3631
        rol     $3530
        rol     $3931
        sec
        and     $0D,y
        cli
        jmp     L8025

        sbc     a:$4C,x
        sbc     $A008,x
        sbc     $5008,x
        sbc     $0A08,x
        sbc     $0508,x
        .byte   $53
        eor     $2053,y
        and     ($35),y
        .byte   $33
        rol     $0D,x
        lda     #$09
        ldx     #$00
        stx     $76
        ldx     #$30
        ldy     #$13
        stx     $22
        sty     $23
        jmp     LFF49

        sbc     a:$06,x
        sbc     $2008,x
        sbc     L1008,x
        sbc     $0208,x
        sbc     $0108,x
        sbc     a:$20,x
        sbc     $8008,x
        sbc     $4008,x
        sbc     $0808,x
        sbc     $0408,x
        sbc     a:$61,x
        ora     ($00,x)
        .byte   $04
        .byte   $02
        .byte   $03
        php
        .byte   $0C
        brk
        bpl     L13A6
L13A6:  rti

        jsr     L8030
        cpy     #$A0
        brk
L13AD:  bit     $1800
        bpl     L13AD
        lda     #$10
        sta     $1800
L13B7:  bit     $1800
        bmi     L13B7
        sty     $1800
        nop
        ldy     $1800
        lda     $0300,y
        nop
        ldy     $1800
        ora     $0302,y
        nop
        nop
        ldy     $1800
        ora     $0308,y
        nop
        nop
        ldy     $1800
        ora     $030A,y
        ldy     #$0F
        sty     $1800
        ldy     #$00
        rts

        sei
        lda     #$0F
        sta     $1800
        ldx     #$00
L13ED:  jsr     L0310
        sta     $0400,x
        inx
        bne     L13ED
L13F6:  jsr     L0310
        sta     $0500,x
        inx
        bne     L13F6
L13FF:  jsr     L0310
        sta     $0600,x
        inx
        cpx     #$24
        bne     L13FF
        jmp     L05DA

        sbc     a:$0E,x
L1410:  tay
        lda     #$04
        sta     $01
L1415:  bit     $01
        bpl     L1415
        lda     #$00
        sta     $01
        nop
        nop
        tya
        and     #$03
        sta     $01
        sbc     $EA06,x
        tya
        lsr     a
        lsr     a
        and     #$03
        sta     $01
        nop
        nop
        tya
        sbc     $4A04,x
        and     #$03
        sta     $01
        sbc     $EA03,x
        tya
        sbc     $4A06,x
        sta     $01
        rts

        ldx     #$00
L1444:  lda     $F200,x
        jsr     LF980
        inx
        bne     L1444
L144D:  lda     $F300,x
        jsr     LF980
        inx
        bne     L144D
L1456:  lda     $F400,x
        jsr     LF980
        inx
        cpx     #$24
        bne     L1456
        rts

        sbc     a:$27,x
        ldx     #$1F
L1467:  jsr     LFA4A
        sta     $F600,x
        jsr     LFA4A
        sta     $F620,x
        jsr     LFA4A
        sta     $F640,x
        jsr     LFA4A
        sta     $F660,x
        jsr     LFA4A
        sta     $F680,x
        jsr     LFA4A
        sta     $F6A0,x
        jsr     LFA4A
        sta     $F6C0,x
        jsr     LFA4A
        sta     $F6E0,x
        jsr     LFA4A
        sta     $F700,x
        jsr     LFA4A
        sta     $F720,x
        dex
        bpl     L1467
        .byte   $AD
        .byte   $19
L14A8:  .byte   $FF
        eor     #$F0
        sta     $FF19
        rts

        lda     #$04
        sta     $01
L14B3:  bit     $01
        bpl     L14B3
        lda     #$00
        sta     $01
        sbc     $EA15,x
        ldy     a:$01
        lda     $F500,y
        sbc     $EA05,x
        ldy     a:$01
        ora     $F508,y
        sbc     $EA05,x
        ldy     a:$01
        ora     $F510,y
        sbc     $EA05,x
        ldy     a:$01
        ora     $F518,y
        rts

        txa
        clc
        adc     $9E
        sta     $DF
        txa
        asl     a
        sta     $E0
        lda     $9D
L14EC:  sec
        sbc     $E0
        sta     $DE
        bcs     L14F5
        dec     $DF
L14F5:  rts

        .byte   $80
        brk
        .byte   $10
L14F9:  .byte   $FF
        cpy     #$40
        .byte   $50
L14FD:  .byte   $FF
        .byte   $FF
        jsr     LFF30
        beq     L1564
        .byte   $70
L1505:  .byte   $FF
        bcc     L14A8
        .byte   $B0
L1509:  .byte   $FF
        bne     L14EC
        php
        brk
        ora     ($FF,x)
L1510:  .byte   $0C
        .byte   $04
        ora     $FF
        .byte   $FF
        .byte   $02
        .byte   $03
        .byte   $FF
        .byte   $0F
        asl     $07
        .byte   $FF
        ora     #$0A
        .byte   $0B
        .byte   $FF
        ora     L120E
        .byte   $93
        .byte   $0D
        .byte   $0D
L1526:  ldx     #$05
L1528:  lda     $F73D,x
        sta     $F63D,x
        dex
        bpl     L1528
        lda     $41
        bne     L157E
        lda     #$FE
        sta     $61
        ldx     #$02
L153B:  lda     $F634,x
        sta     $F740,x
        dex
        bpl     L153B
        ldx     #$00
        stx     $41
        stx     $42
        ldy     #$30
        lda     $F641,x
        sbc     $4A03,x
        sta     $E0
        lda     $F641,x
        and     #$07
        lsr     a
        eor     $F642,x
        and     #$3F
        eor     $F642,x
        .byte   $FD
        .byte   $03
L1564:  rol     a
        tax
        lda     $FAB6,x
        ldx     $E0
        ora     $FAA0,x
        iny
        sta     ($DE),y
        eor     $42
        sta     $42
        lda     $41
        clc
        adc     #$05
        sta     $41
        bcs     L1526
L157E:  tax
        lda     $F63D,x
        lsr     a
        and     #$1F
        sta     $E0
        lda     $F63E,x
        ror     a
        sbc     $4A03,x
        tax
        lda     $FAB6,x
        ldx     $E0
        ora     $FAA0,x
        iny
        cpy     $61
        beq     L15F6
        sta     ($DE),y
        eor     $42
        sta     $42
        ldx     $41
        lda     $F63F,x
        asl     a
        lda     $F63E,x
        rol     a
        and     #$1F
        sta     $E0
        lda     $F63F,x
        lsr     a
        lsr     a
        and     #$1F
        tax
        lda     $FAB6,x
        ldx     $E0
        ora     $FAA0,x
        iny
        sta     ($DE),y
        eor     $42
        sta     $42
        ldx     $41
        lda     $F640,x
        and     #$E0
        asl     a
        eor     $F63F,x
        and     #$FC
        eor     $F63F,x
        sbc     $2A03,x
        sta     $E0
        lda     $F640,x
        and     #$1F
        tax
        lda     $FAB6,x
        ldx     $E0
        ora     $FAA0,x
        iny
        sta     ($DE),y
        eor     $42
        sta     $42
        ldx     $41
        jmp     LFAFF

L15F6:  sta     $3F
        ldx     #$09
        lda     $42
L15FC:  eor     $F600,x
        eor     $F60A,x
        eor     $F614,x
        eor     $F61E,x
        eor     $F628,x
        dex
        bpl     L15FC
        .byte   $4D
        .byte   $32
L1610:  inc     $85,x
        .byte   $42
        rts

        lda     $01
        sta     $FF40
        lda     $FF19
        sta     $FF41
        lda     #$1F
        sta     $00
        lda     #$C0
        sta     $01
        ldy     #$03
        lda     $FF06
        and     #$EF
        sta     $FF06
L1631:  cpy     $FF1D
        bne     L1631
        dey
        bne     L1631
        jsr     LF9B9
        lda     #$FF
        sta     $DB
        sta     $93
        lda     $9D
        sec
        sbc     #$02
        sta     $9D
        bcs     L164D
        dec     $9E
L164D:  ldy     #$00
        lda     ($9D),y
        pha
        iny
        lda     ($9D),y
        pha
        lda     $9D
        sta     $DC
        lda     $9E
        sta     $DD
L165E:  jsr     LFA00
        lda     $F637
        sta     $E1
        bpl     L167A
        ldx     $DB
        inx
        jsr     LFA93
        lda     $DE
        sta     $9D
        lda     $DF
        sta     $9E
        lda     #$00
        sta     $DB
L167A:  lda     $E1
        and     #$20
        beq     L1688
        stx     $3F
        inx
        stx     $40
        jmp     LFC74

L1688:  lda     $E1
        and     #$3F
        cmp     $DB
        bcc     L1692
        sta     $DB
L1692:  tax
        jsr     LFA93
        lda     $F600
        bne     L16AA
        lda     #$02
        sta     $DE
        lda     #$F8
        sta     $DF
        ldy     $F601
        dey
        sty     $F800
L16AA:  ldy     #$31
L16AC:  lda     $F602,y
        sta     ($DE),y
        dey
        bpl     L16AC
        jsr     LFAE8
        lda     $3F
        cmp     $42
        bne     L16C1
        bit     $E1
        bvc     L165E
L16C1:  lda     $FF40
        sta     $01
        lda     $FF41
        sta     $FF19
        lda     $FF06
        ora     #$10
        sta     $FF06
        ldx     $DB
        jsr     LFA93
        ldy     $F800
        dey
L16DD:  lda     $F802,y
        sta     ($DE),y
        dey
        cpy     #$FF
        bne     L16DD
        lda     $DE
        clc
        adc     $F800
        sta     $9D
        lda     $DF
        adc     #$00
        sta     $9E
        ldy     #$01
        pla
        sta     ($DC),y
        dey
        pla
        sta     ($DC),y
        lda     $3F
        cmp     $42
        clc
        bne     L1706
        .byte   $24
L1706:  sec
        lda     #$1D
        rts

        ldx     #$0E
        ldy     #$06
        .byte   $8E
        .byte   $2E
L1710:  .byte   $03
        sty     $032F
        rts

L1715:  jmp     LF04C

        sta     $93
        lda     $AE
        cmp     #$04
        bcc     L1715
        lda     $AB
        beq     L1715
        lda     #$AF
        sta     $07DF
        jsr     L07D9
        cmp     #$24
        beq     L1715
        ldx     #$33
        ldy     #$06
        stx     $0326
        sty     $0327
        jmp     LF06B

        pla
        pla
        ldx     #$65
        ldy     #$F2
        stx     $0326
        sty     $0327
        ldy     #$00
L174B:  jsr     L069C
        lda     #$57
        jsr     LECDF
        tya
        jsr     LECDF
        lda     #$03
        jsr     LECDF
        lda     #$20
        tax
        jsr     LECDF
L1762:  sei
        sta     $FF3F
        lda     $F900,y
        sta     $FF3E
        cli
        jsr     LECDF
        iny
        dex
        bne     L1762
        jsr     LEF23
        cpy     #$80
        bne     L174B
        jsr     L069C
        lda     #$45
        jsr     LECDF
        lda     #$4A
        jsr     LECDF
        lda     #$03
        jsr     LECDF
        jsr     LEF23
        sei
        sta     $FF3F
        jsr     LFBC7
        sta     $FF3E
        cli
        bcs     L17A1
        jsr     LF215
        clc
L17A1:  ldx     $9D
        ldy     $9E
        rts

        lda     $AE
        jsr     LEE2C
        lda     #$6F
        jsr     LEE4D
        lda     #$4D
        jsr     LECDF
        lda     #$2D
        jmp     LECDF

