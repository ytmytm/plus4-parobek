# Plus/4 "Parobek" ROM

**Parobek** is a multi-fast-loader utility ROM for the Commodore 16/116/Plus4 family.  
It automatically selects the fastest available transfer method for the attached drive and can also fall back to the original KERNAL routines when needed.

*Parobek* means *hired farmhand*. It's a pun on C128's [The Servant](https://github.com/ytmytm/c128-theservant-sd2iec). Parobek is simple and unsophisticated, but gets the work done.

---

## 1  Features

Works from any ROM bank (internal, external C1 or C2).

The function key is correctly registered and depends on the ROM's location. Function key
starts the embedded Directory Browser.

The ROM image is **32 KB** (`$8000–$FFFF`) – suitable for a 27C256 EPROM or equivalent EEPROM.

![Startup menu](media/01.startup.png)

At **Enable fastload**, Parobek probes the host once and stores two flags in the LOAD trampoline (same lifetime as the install RAM):

- **`host_jd`** — host KERNAL is JiffyDOS (banner at `$EB7D`). Parobek keeps the LOAD hook for burst / parallel / TCBM, but skips its DOS wedge and all CPU-port serial fastloads (SJL264, `1541 SERIAL`); IEC loads print `HOST JIFFYDOS` and use the host KERNAL ROM loader.
- **`cpu_port_type`** — host CPU port map (stock 8501 vs [Hackjunk 8501→6510](https://hackjunk.com/2017/06/23/commodore-16-plus-4-8501-to-6510-cpu-conversion/) with patched KERNAL). Selects SJL receive loop, parallel upload images, burst `$01` timing, and whether serial bitbang paths are allowed.

### 1.1 Fastloaders

Parobek picks a path per load from what is attached. On **IEC**, the order is **fastest first**, then fall through until one path handles the file (or KERNAL ROM load). On-screen text after `IEC DEVICE, ` shows which path won.

#### IEC selection order (fallbacks)

| Step | Condition | Path (message) |
|------|-----------|----------------|
| 1 | 1570/1571/1581 + Burstcart SRQ hardware | Burst (`VIA` / `CPLD BURST`, …) |
| 2 | Status contains `SD2IEC`, stock host kernal, datasette not blocking SJL | SJL264 (`SD2IEC, SJL264`) |
| 3 | 1541 with parallel cable | Parallel SpeedDOS (`1541/PARALLEL`) |
| 4a | Status contains `JIFFYDOS`, stock host, datasette not blocking | SJL264 (`SJL264`) |
| 4b | Host kernal is JiffyDOS | Host JD ROM load (`HOST JIFFYDOS…`); no Parobek SJL / no DOS wedge |
| 5 | stock 1541, datasette not blocking | JiffyDOS sender + SJL receiver (`1541 SERIAL`) |
| 6 | Nothing above handled the load | KERNAL (`ROM LOAD`) |

Notes:

- A connected **datasette** blocks only CPU-port bitbang paths (**SJL264** and **1541 SERIAL**) on a stock **8501** host. Burst and parallel still run.
- **Host JiffyDOS** (`host_jd`): detected at install from the `JIFFYDOS` string in the host KERNAL banner. LOAD hook stays (burst / TCBM / parallel still useful). Parobek does **not** install its DOS wedge, does **not** run SJL264 or `1541 SERIAL`, and does **not** read the IEC status channel during drive classification (avoids fragile handshake timing). IEC loads print `HOST JIFFYDOS` and fall through to the host KERNAL JiffyDOS LOAD.
- **TCBM / 1551** are chosen earlier on the TCBM bus path, not via this IEC table.

#### Host CPU (`cpu_port_type`)

| Value | Host | SJL264 / `1541 SERIAL` | Parallel upload | Burst |
|-------|------|------------------------|-----------------|-------|
| 0 | 7501/8501 (stock) | Yes (datasette gate on `$01` bit 3) | 8501 port map | Yes |
| 1 | 6510 + **patched** KERNAL (Hackjunk; `$F30C` ≠ `$0F`) | Yes — second receive loop (DATA bit 0, CLK bit 5); no datasette gate | 6510 port map (PPI/PIO/CIA/VIA images) | Yes (`$01` timing adjusted) |
| 2 | 6510 + **stock** KERNAL (`$F30C` == `$0F`) | Skipped → ROM IEC | 8501 port map (not validated on 6510 hardware) | Yes |
| 3 | Unknown port | Skipped → ROM IEC | 8501 port map | Yes |

Detection runs once at install (`detect_cpu_port_type` in `src/cpu-port-detect.asm`): DATA-out vs DATA-in polarity, then `$F30C` to split Hackjunk-patched vs stock KERNAL. The wedge `@` status read uses a dedicated 6510 ACPTR path when `cpu_port_type` ≠ 0.

#### 1570/1571/1581 (Burst)

Requires the [Burstcart](https://github.com/ytmytm/plus4-burstcart) interface.

**Burst fastloader** – C128-style fast serial over the SRQ line with a hardware shift register. Based on the [original burst loader for C64](https://a1bert.kapsi.fi/Dev/burst/) by **Pasi Ojala**.

#### IEC JiffyDOS / SD2IEC (SJL264)

When the drive status contains `SD2IEC` or `JIFFYDOS` (and the host is not already JiffyDOS), Parobek uses an **SJL264**-derived serial fastloader: cycle-timed 2-bit CLK/DATA receive on the Plus/4 CPU port, ROM-safe (no self-mod). This is the path for **drive-side** JiffyDOS (and SD2IEC reporting `JIFFYDOS` in status).

On **8501** (`cpu_port_type` 0), SJL uses the stock receive loop; a connected datasette still blocks this path. On **Hackjunk 6510 + patched KERNAL** (type 1), install retargets the receive vector to `sjl_jd_receive_loop_6510` (DATA bit 0, CLK bit 5; position-specific decode LUTs). Types 2 and 3 skip SJL and use ROM IEC.

**Sources / references**

- Upstream: [SJL264 Light](https://bsz.amigaspirit.hu/sjl264/index_en.html) (BSZ) — load-only path ported into `src/sjl-loader*.asm`
- C64 background: [SJLOAD](https://www.c64-wiki.com/wiki/SJLOAD) / JaffyDOS

#### Stock 1541 serial (`1541 SERIAL`)

For a stock 1541 **without** parallel and **without** drive JiffyDOS/SD2IEC, Parobek uploads drive code that speaks the same JiffyDOS LOAD bit timing, then receives with the shared **`SJL_jd_transfer`** entry (same loop as SJL264). CLK/DATA only — no ATN-as-data.

This path shares the same `cpu_port_type` receive vector as SJL264 (`SJL_jd_transfer`). Types 1 use the 6510 loop; types 2 and 3 are skipped (ROM IEC). Also skipped when `host_jd` is set.

**Sources / references (drive sender)**

- Disassembled 1541 JiffyDOS LOAD routines: [`docs/1541EJD.a65`](docs/1541EJD.a65) (from [Ruud Baltissen’s source codes](http://www.baltissen.org/newhtm/sourcecodes.htm)
- Protocol notes: [Open ROMs — Protocol-JiffyDOS](https://github.com/MEGA65/open-roms/blob/master/doc/Protocol-JiffyDOS.md), [pagetable 2-bit transfer](https://www.pagetable.com/?p=568)

#### 1541 with parallel cable

Loader supports PPI (8255) / PIO (6529) (software handshake) and VIA (6522) / CIA (6526) [Burstcart](https://github.com/ytmytm/plus4-burstcart) (hardware handshake). On **6510 + patched KERNAL** (type 1), Parobek uploads drive code built for the Hackjunk port map (`FASTLOAD_*_6510` / `SpeedDOS_loader_*_6510` images).

Based on **SpeedDOS parallel loader** (C64-derived). Alternate option (disabled by default): **[Port-Turbo-V1](https://plus4world.powweb.com/software/Port-Turbo_V1)**.

With hardware handshake and **[1541-RAMBOardII](https://github.com/ytmytm/1541-RAMBOardII)** drive-side RAM/ROM (faster GCR / track cache), loads are even faster.

#### 1551

Based on **[HypaLoad v4.7](https://plus4world.powweb.com/software/Hypaload_1551)**, patched for devices #8 and #9 and two-way handshake.

#### 1551 with RAMBOard

Loosely based on **[HypaLoad v4.7](https://plus4world.powweb.com/software/Hypaload_1551)** with **[1551-RAMBOard](https://github.com/ytmytm/1551-RAMBOard)** whole-track cache — about 7× stock 1551 / 27× stock 1541.

Same protocol as the 1551 fastloader; needs a RAMBOard-patched drive ROM (`RAM` at `$a000`, jumptable at `$a003`). Devices #8 and #9.

#### Load performance

Baseline **1×** = stock KERNAL **ROM LOAD** (~470 B/s) — the slowest path in the matrix (stock 1581, no fastloader). That matches the ~440 B/s class of a plain serial load; on a 1541 the `.d64` interleave matters (smoke disk uses the default **9**; interleave **6** would be optimal for JiffyDOS, but the test image is not tuned for that).

| Configuration | B/s | vs ROM load |
|---------------|----:|------------:|
| 1541 stock (1541 SERIAL) | 873 | 1.8× |
| 1541 + parallel PIO | 1885 | 4× |
| 1551 HypaLoad | 1925 | 4.1× |
| 1541 + parallel VIA | 1933 | 4.1× |
| 1541 JiffyDOS (SJL264) | 2191 | 4.6× |
| 1581 JiffyDOS (SJL264) | 3279 | 6.9× |
| 1541 + parallel VIA + RAMBOard | 3851 | 8.1× |
| 1581 + BurstCart | 4663 | 9.8× |
| 1551 HypaRAM | 5424 | 11× |

#### TCBM2SD

The **[TCBM2SD fastloader](https://github.com/ytmytm/plus4-tcbm2sd)** works on devices #8 and #9 for ultimate speed on the TCBM bus.

### 1.2 Utilities

#### DOS Wedge

Not installed when the host KERNAL is JiffyDOS. 

New commands (when installed):

| Command | Description |
|---------|-------------|
| `@` | Display current drive status |
| `@8` | Change current device number (e.g. `@9` or `@12`) |
| `$` | List directory of the current drive |
| `/` | Fast load a file (also works by placing `/` in front of a filename listed by `$` and pressing **RETURN**) |
| `←` | Save the BASIC program or memory image |
| `@Q` | Disable fastloader, re-enable with computer reset |

#### Directory Browser

Integrated Directory Browser works with and without fastloader present for maximum compatibility.

---

## 2  Building the ROM

### 2.1 Prerequisites

* [**ACME** cross-assembler](https://github.com/meonwax/acme)
* GNU `make` (optional – for the convenience target)

### 2.2 Quick Build

From the `src` directory:

```sh
cd src
make
```

The resulting binaries are written to `src/bin/`.

### 2.3 Configuration

Correct fastloader is autodetected, except for fast serial one. This is configured at ROM assembly step by setting the `burst` variable on top of the `burstcart.asm` file to one of possible values (VIA=2 is default):

```
; 1=CIA, 2=VIA, 3=CPLD
!set burst=2
```

---

## 3  Startup Menu

1. **Normal reset** – boots straight to BASIC without any cartridge hooks.
2. **Directory browser** – starts the browser **without** installing fastloaders.
3. **Enable fastload** – installs fastloader and DOS wedge (wedge omitted when host KERNAL is JiffyDOS); the directory browser becomes available on the registered function key (key depends on the ROM bank where Parobek is located).

---

## 4  Credits & Acknowledgements

Full development notes can be found in [`docs/burstc64.txt`](docs/burstc64.txt).

Hardware insights provided by the Plus/4 World community ([plus4world.powweb.com](https://plus4world.powweb.com)).