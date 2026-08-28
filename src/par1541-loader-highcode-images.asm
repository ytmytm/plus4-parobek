; Copy-only loader images. This file is placed in C1HI ($c000-$ffff), which
; is mapped briefly while .prepare_fastload copies the selected image to RAM.

FASTLOAD_PIO:
!set par1541_interface = 1
!set cpu_port_6510 = 0
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_PIO_END:

FASTLOAD_PIO_6510:
!set par1541_interface = 1
!set cpu_port_6510 = 1
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_PIO_6510_END:

FASTLOAD_PPI:
!set par1541_interface = 2
!set cpu_port_6510 = 0
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_PPI_END:

FASTLOAD_PPI_6510:
!set par1541_interface = 2
!set cpu_port_6510 = 1
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_PPI_6510_END:

FASTLOAD_CIA:
!set par1541_interface = 3
!set cpu_port_6510 = 0
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_CIA_END:

FASTLOAD_CIA_6510:
!set par1541_interface = 3
!set cpu_port_6510 = 1
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_CIA_6510_END:

FASTLOAD_VIA:
!set par1541_interface = 4
!set cpu_port_6510 = 0
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_VIA_END:

FASTLOAD_VIA_6510:
!set par1541_interface = 4
!set cpu_port_6510 = 1
!pseudopc EPAR41_HIGHCODE_TGT {
!source "par1541-loader-highcode.asm"
}
FASTLOAD_VIA_6510_END:
