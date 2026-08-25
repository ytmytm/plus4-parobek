# fast1541iec protocol choice

Date: 2026-08-25
Chosen: jiffy2bit
Locked interface: `PROTOCOL=jiffy2bit`

## Spike exit checklist
- [x] Protocol named
- [x] Bit order + EOI/ready written
- [x] ATN not used as data (confirmed)
- [x] Drivecode size / M-W budget estimate: 224 bytes @ $0300

The host highcode estimate is 96 bytes for the ready/EOI checks, four
cycle-timed samples, byte reconstruction, destination update, and timeout
exits. The 224-byte drive budget occupies `$0300-$03df` and needs seven
32-byte `M-W` commands before `M-E`.

## MegaLoad findings

MegaLoad V4 is a self-installing, compressed/relocated loader rather than a
directly reusable pair of host and drive routines. The initial program copies
pages to `$f200-$fc00`, then transforms data in those pages before use.
Consequently, apparent instructions in the original `$1410` region are packed
input, not a trustworthy disassembly of the final drive program.

The normal-IEC upload envelope is identifiable:

- Four 32-byte `M-W` commands copy runtime `$f900-$f97f` to drive
  `$0300-$037f`.
- The following `M-E` command executes at drive `$034a`.
- The installed host transfer saves `$01`, sets the Plus/4 CPU-port DDR
  `$00` to `$1f`, sets `$01` to `$c0`, and later restores the saved port
  value. This confirms direct CPU-port IEC bit-banging.
- The raw image contains several `$1800` access patterns, but they occur in
  data that is relocated/transformed. They do not establish the final
  drive-side CLK/DATA encoding.
- No reliable byte boundary, bit order, ready/EOI convention, or proof that
  ATN remains untouched mid-byte can be recovered from the static artifact
  without executing and tracing its unpacker.

MegaLoad is therefore opaque for this spike's portability requirement. Its
small 128-byte upload is useful size evidence, but it is not a safe protocol
contract for Tasks 4-5.

## Chosen transfer (host receive one byte)

This is the existing SJL/Jiffy-style receive convention on the Plus/4. IEC
inputs are CPU-port `$01` bit 6 = CLK and bit 7 = DATA. Line states below are
logical bus levels after the active-low IEC drivers: `1` means released/high
and `0` means asserted/low.

| Sample | CLK carries | DATA carries | Result positions |
|--------|-------------|--------------|------------------|
| 1 | bit 0 | bit 1 | byte bits 0-1 |
| 2 | bit 2 | bit 3 | byte bits 2-3 |
| 3 | bit 4 | bit 5 | byte bits 4-5 |
| 4 | bit 6 | bit 7 | byte bits 6-7 |

The host starts each byte with IEC outputs released (`$01=$08` in the current
SJL setup), waits for the drive's ready indication, then asserts its DATA
ready state (`$01=$09`). After the fixed drive-response delay it takes the
four cycle-spaced CLK/DATA samples and reconstructs the byte with the existing
shift/EOR sequence. Bits are therefore received least-significant pair first.

## Chosen transfer (drive send one byte)

The new 1541 sender uses VIA 1 port B at `$1800`: bit 3 drives CLK out and bit
1 drives DATA out. The 7406 drivers invert these outputs: a one in PB3/PB1
asserts the corresponding IEC line low, and a zero releases it high.

The sender configures DDRB `$1802=$1a`: PB1 (DATA out), PB3 (CLK out), and PB4
(ATNA) are outputs; PB0, PB2, PB5, PB6, and PB7 remain inputs. ATN is inactive
during the fast transfer, so ATNA must remain zero. Every whole-port write to
`$1800` therefore has bit 4 clear and writes zero to the latches behind all
input-configured, unrelated bits. The transfer must use only the complete
safe port images `$00`, `$02`, `$08`, and `$0a`; it must not construct an
output by reading `$1800`, because that read includes live input bits.

For a logical pair `CLK,DATA`, where one means released/high and zero means
asserted/low, the complete `$1800` images are:

| Logical CLK,DATA | `$1800` image | PB3 CLK out | PB1 DATA out |
|------------------|---------------|-------------|--------------|
| `0,0` | `$0a` | 1 (assert) | 1 (assert) |
| `0,1` | `$08` | 1 (assert) | 0 (release) |
| `1,0` | `$02` | 0 (release) | 1 (assert) |
| `1,1` | `$00` | 0 (release) | 0 (release) |

Each payload phase selects one of those four complete images. Phase 1 uses
byte bits 0 and 1 as logical CLK and DATA; phase 2 uses bits 2 and 3; phase 3
uses bits 4 and 5; and phase 4 uses bits 6 and 7. Equivalently, after
extracting the named pair as `c,d`, write `((c ^ 1) << 3) |
((d ^ 1) << 1)`. Thus the fixed masks are:

| Output phase | CLK source | DATA source | Complete `$1800` expression |
|--------------|------------|-------------|------------------------------|
| 1 | bit 0 | bit 1 | `((~byte & $01) << 3) | (~byte & $02)` |
| 2 | bit 2 | bit 3 | `((~byte & $04) << 1) | ((~byte & $08) >> 2)` |
| 3 | bit 4 | bit 5 | `((~byte & $10) >> 1) | ((~byte & $20) >> 4)` |
| 4 | bit 6 | bit 7 | `((~byte & $40) >> 3) | ((~byte & $80) >> 6)` |

All expressions are byte-masked and produce only `$00/$02/$08/$0a`, so PB4
and every unrelated latch stay at their fixed safe zero value. There is no
per-pair acknowledgement; the four phases are cycle-timed after the
byte-start handshake.

## Handshake / EOI

The complete non-payload images are:

| State | Drive action | `$1800` |
|-------|--------------|---------|
| idle / released | release CLK and DATA, ATNA inactive | `$00` |
| data-byte announce | release CLK, assert DATA | `$02` |
| data-byte ready | release CLK and DATA | `$00` |
| EOI arm | assert CLK, release DATA | `$08` |
| EOI present | release CLK and DATA | `$00` |
| EOI confirm / handoff | assert CLK, release DATA | `$08` |

For a data byte, the drive writes `$02`. In `.loadloop` the host writes
`$01=$08`, polls CPU-port input bit 6 until CLK is high, and tests input bit 7;
DATA low selects the data path. The drive then writes `$00`; the host waits
for DATA high, pulses its DATA output low with `$01=$09`, and checks CLK. The
drive keeps CLK released through that check and then emits the four timed
payload images. The next byte follows the same ready/probe timing; if the
drive is not ready at the host's probe, asserting CLK makes the host branch
back to `.loadloop`.

EOI uses that probe branch explicitly; releasing both lines without first
forcing the branch is not sufficient:

1. After the fourth phase of the final byte, write EOI-arm `$08` (CLK low,
   DATA released). At the next host `$01=$09` probe, CPU-port bit 6 is clear,
   so `bvc .loadloop` is taken.
2. Wait until the host has released its DATA output (`$01=$08`; drive PB0
   reads DATA high), then write EOI-present `$00`.
3. The host's `.wait_clk_drive` sees CPU-port bit 6 set (CLK high), and its
   immediately following `bmi .loadendover` sees bit 7 set (DATA high).
4. Hold `$00` for 16 drive CPU cycles. This covers the host polling/branch
   path, then write EOI-confirm `$08`. The host's bounded `.end_check` polls
   CPU-port bit 6 and accepts EOI only when CLK has become low.
5. Keep DATA released and CLK asserted while leaving the fast sender. Normal
   DOS IEC handling then owns the port and handles the host's UNTALK/close,
   including any later ATNA change required by normal ATN arbitration.

If CLK does not fall during `.end_check`, the host reports serial-end error.
DATA must stay released throughout EOI; `$02` would be interpreted as another
data-byte announce instead of end of file.

ATN is used only by normal IEC TALK/secondary-address/UNTALK arbitration
before and after the fast transfer. Neither timed payload pairs nor ready/EOI
states use ATN as a data bit. PB4 is nevertheless part of every `$1800`
whole-port write and is explicitly held at its inactive zero value for the
entire fast-transfer interval.

## Why not the alternatives

`megaload` was preferred in principle and has an attractive 128-byte upload,
but the available V4 artifact stores the operative block in transformed
runtime pages. Static analysis cannot document its final bit order and
EOI/ready behavior or prove the shared-bus ATN constraint. That fails the
binding portability/opacity gate.

`serial1bit` is easier to tolerate across CPU timing variations because every
bit is handshaken, but it halves the useful line width and requires a larger,
slower host/drive state machine. It remains the fallback if hardware testing
shows that the cycle-timed two-bit sender is unreliable on supported
replacement CPUs.

`jiffy2bit` is selected because the repository already contains the
Plus/4-specific, ROM-resident receive loop and its `$00/$01` timing. Only a
stock-1541 sender and wrapper are needed, the transfer uses CLK/DATA alone,
and the least-significant-pair-first wire contract is independently described
by the JiffyDOS/Open ROMs and pagetable references.
