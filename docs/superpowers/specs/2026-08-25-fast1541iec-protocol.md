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
1 drives DATA out. ATN input (bit 7) and ATN acknowledge output (bit 4) are
not written by the transfer loop.

| Output phase | CLK sends | DATA sends | Byte bits |
|--------------|-----------|------------|-----------|
| 1 | bit 0 | bit 1 | least-significant pair |
| 2 | bit 2 | bit 3 | next pair |
| 3 | bit 4 | bit 5 | next pair |
| 4 | bit 6 | bit 7 | most-significant pair |

For each phase the drive maps the two payload bits to the active-low VIA
output representation, writes `$1800`, and holds the state for the cycle
window expected by `SJL_highcode`. There is no per-pair acknowledgement; the
four phases are cycle-timed after the byte-start handshake.

## Handshake / EOI

Before a data byte, the drive holds DATA low and releases CLK. The host waits
for CLK high; DATA low means a byte follows. The drive then releases DATA, the
host waits for DATA high, asserts its ready state, and the four timed samples
begin.

At the byte boundary, the host returns to the ready loop. The drive waits for
that state before presenting the next byte, preventing accumulated timing
drift between bytes. The final-byte condition is sampled by the existing SJL
post-byte CLK test.

End of file is signalled at the ready boundary by the drive releasing both
CLK and DATA instead of holding DATA low. The host sees CLK high and DATA high,
enters `loadendover`, verifies that CLK drops within the bounded end check,
then performs normal IEC UNTALK/close cleanup. Timeouts or malformed end
states are transfer errors, not ROM fall-through after a partial load.

ATN is used only by normal IEC TALK/secondary-address/UNTALK arbitration
before and after the fast transfer. Neither timed payload pairs nor ready/EOI
states use ATN as a data bit.

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
