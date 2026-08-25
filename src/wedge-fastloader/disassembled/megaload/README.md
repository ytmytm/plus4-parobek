# MegaLoad V4 disassembly

Source: [Plus/4 Power 02](https://plus4world.powweb.com/software/Plus4_Power_02)
from Plus/4 World. The disk contains `MegaLoad V4`, also known as Fast Load
1541 by Gimpy.

Direct archive:
<https://plus4world.powweb.com/dl/mags/plus4_power/plus4_power_02.zip>

## Extraction

From the repository root:

```sh
curl -fL -o /tmp/plus4_power_02.zip \
  "https://plus4world.powweb.com/dl/mags/plus4_power/plus4_power_02.zip"
unzip -o /tmp/plus4_power_02.zip -d /tmp
c1541 /tmp/plus4_power_02.d64 -list
c1541 /tmp/plus4_power_02.d64 -read "megaload v4" \
  src/wedge-fastloader/disassembled/megaload/megaload_v4.prg
```

The extracted PRG is 1,979 bytes, including its two-byte `$1001` load-address
header. Its SHA-256 digest is
`d454bb8589e282f20341b594c81daedd2f80df5f5f13a7575a38da442f9d0b6d`.

## Disassembly

The initial disassembly covers the complete PRG. From this directory, generate
it with cc65 V2.19:

```sh
/usr/local/bin/da65 -i megaload_v4.info
```

`megaload_v4.info` skips the two-byte PRG header and starts disassembly at
`$1001`. Drive-code boundaries and labels remain to be refined during the
protocol-analysis spike.

## Layout (fill during spike)

- Host install / wedge:
- Host IEC receive:
- Drivecode upload (M-W addr / length):
- Drivecode entry (M-E):
- ATN used as data? (yes/no)
