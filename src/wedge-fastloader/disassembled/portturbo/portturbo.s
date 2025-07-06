
; 1 = 8255 (ppi), 2 = 6529 (pio)
!set parport_type=1

!if parport_type=1 {
!to "portturbo.prg",cbm
}
!if parport_type=2 {
!to "portturbo_6529.prg",cbm
}

RAM_STATUS  = $90       ; status
RAM_VERFCK      = $93   ; 0=load, 1=verify
RAM_MSGFLG  = $9A   ; $80=direct mode (print messages), $00=program mode (silent)
RAM_FNLEN       = $AB   ; filename length
RAM_LA	= $AC   ; logical address
RAM_SA          = $AD   ; secondary address
RAM_FA          = $AE   ; device number
RAM_FNADR       = $AF   ; vector to filename
RAM_MEMUSS      = $B4   ; load RAM base ($AE/AF on C64)
RAM_CURBNK      = $FB   ; current ROM bank  

RAM_RLUDES      = $07D9 ; read from (e07DF),y from RAM
a07DF           = $07DF ; zp address of vector for RLUDES
RAM_ILOAD       = $032E

ROM_SELECT      = $FF3E
RAM_SELECT      = $FF3F

TED_BORDER      = $FF19
TED_FF06        = $FF06
TED_FF1D        = $FF1D

L8025           = $8025
L802E           = $802E
L80C2           = $80C2
L8117           = $8117

ROM_DOAKEY = $FF49      ; $B7C2
ROM_PRINTIMM = $FF4F

;;;;;;;;;;;;;;;;;;

GCR_SECTOR_BUFFER	= $DE00 ; decoded sector; drivecode + $0100
GCR_TRACK_BUFFER	= GCR_SECTOR_BUFFER+$0100 ; 21*$0146 (DF00-F9BD)

!if parport_type=1 {
;	!source "port_ppi.s"
; PPI (Intel 8255), port A

ppi_base        = $FE00
parallel_port = ppi_base

	!macro parallel_port_input { ; must use A
		lda #$90
		sta ppi_base+3
	}
	!macro parallel_port_output { ; must use X
		ldx #$80
		stx ppi_base+3
	}
}

!if parport_type=2 {
;	!source "port_pio.s"
; PIO (MOS 6529)

pio_base	= $FD10
parallel_port = pio_base
	!macro parallel_port_input { ; must use A
		lda #$ff
		sta pio_base
	}
	!macro parallel_port_output { ; must use X
		ldx #$80	; do nothing in fact
		nop
		nop
		nop
	}
}

;;;;;;;;;;;;;;;

	* = $1001

	!word $100b

	!word 0

	!byte $9e
	!text "5306"
	!byte 0

	!byte   $00,$00,$00,$00
	!byte   $00

EPAR41_LOWCODE_TGT = $0600
EPAR41_LOWCODE:
	!if * != $1010 { !error "EPAR41_LOWCODE NOT AT $1010 *=", * }
	!pseudopc EPAR41_LOWCODE_TGT {
	!source "port0600.s"
	}

EPAR41_DRVCODE_TGT = $dd00
EPAR41_DRV_0300 = $0300
EPAR41_DRV_038F = $038F
EPAR41_DRVCODE:
	!if * != $10EE { !error "EPAR41_DRVCODE NOT AT $10EE *=", * }
        !binary "par41drv0300.bin"

EPAR41_HIGHCODE_TGT = $f9be
EPAR41_HIGHCODE:
	!if * != $11ED { !error "EPAR41_HIGHCODE NOT AT $11ED *=", * }
	!pseudopc EPAR41_HIGHCODE_TGT {
	!source "portf9be.s"
	}


EPAR41_INSTALL:
	!if * != $14BA { !error "EPAR41_INSTALL NOT AT $14BA *=", * }
	!source "port14ba.s"
