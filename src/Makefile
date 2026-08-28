.PHONY: all via cpld luts clean run run-via run-cpld

LUT_GENERATOR = gen_sjl6510_luts.py
LUT_ASM = gen_sjl6510_luts.asm

SRCS = burstcart.asm burst-cpld.asm burst-via.asm \
	t2s-detect.asm host-jd-detect.asm cpu-port-detect.asm \
	iec-acptr.asm \
	sjl-detect.asm sjl-loader.asm sjl-loader-highcode.asm \
	iec-memcmd.asm fast1541iec-loader.asm fast1541iec-drivecode.asm \
	par1541-loader-highcode.asm par1541-loader-highcode-images.asm \
	speeddos-loader-highcode.asm \
	ram1551-hyparam-loader.asm ram1551-hyparam-loader-highcode.asm \
	hypa1551-drivecode.asm ram1551-detect.asm \
	$(LUT_ASM)

all: via cpld

via: bin/parobek-via.bin
cpld: bin/parobek-cpld.bin
luts: $(LUT_ASM)

$(LUT_ASM): $(LUT_GENERATOR)
	python3 $(LUT_GENERATOR)

bin/parobek-via.bin: $(SRCS)
	acme -Dburst=2 -l labels-via.txt burstcart.asm

bin/parobek-cpld.bin: $(SRCS)
	acme -Dburst=3 -l labels-cpld.txt burstcart.asm

run: run-via

run-via: bin/parobek-via.bin
	xplus4 -c1 bin/parobek-via.bin

run-cpld: bin/parobek-cpld.bin
	xplus4 -c1 bin/parobek-cpld.bin

clean:
	rm -f bin/*.bin labels-*.txt
