

all:	bin/burstcart.bin

bin/burstcart.bin: burstcart.asm
	acme burstcart.asm

run:	bin/burstcart.bin
	xplus4 -c1lo bin/burstcart.bin

clean:
	rm bin/*.bin
