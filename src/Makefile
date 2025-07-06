.PHONY: all run clean

all:	bin/parobek.bin

bin/parobek.bin: burstcart.asm burst-cia.asm burst-cpld.asm burst-via.asm t2s-detect.asm
	acme -l labels.txt burstcart.asm

run:	bin/parobek.bin
	xplus4 -c1lo bin/parobek-via.bin

clean:
	rm -f bin/*.bin
