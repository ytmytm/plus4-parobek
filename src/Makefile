

all:	bin/burstcart.bin

bin/burstcart.bin: burstcart.asm burst-cia.asm burst-cpld.asm burst-via.asm t2s-detect.asm
	acme burstcart.asm

run:	bin/burstcart.bin
	xplus4 -c1lo bin/burstcart-via.bin

clean:
	rm -f bin/*.bin
