.PHONY: all via cpld clean run run-via run-cpld

SRCS = burstcart.asm burst-cpld.asm burst-via.asm \
	t2s-detect.asm host-jd-detect.asm cpu-port-detect.asm \
	sjl-detect.asm sjl-loader.asm sjl-loader-highcode.asm \
	iec-memcmd.asm fast1541iec-loader.asm fast1541iec-drivecode.asm

all: via cpld

via: bin/parobek-via.bin
cpld: bin/parobek-cpld.bin

bin/parobek-via.bin: $(SRCS)
	acme -Dburst=2 -l labels-via.txt burstcart.asm

bin/parobek-cpld.bin: $(SRCS)
	acme -Dburst=3 -l labels-cpld.txt burstcart.asm

run: run-via

run-via: bin/parobek-via.bin
	xplus4 -c1lo bin/parobek-via.bin

run-cpld: bin/parobek-cpld.bin
	xplus4 -c1lo bin/parobek-cpld.bin

clean:
	rm -f bin/*.bin labels-*.txt
