# 4-bit Array Multiplier — RTL to GDSII (SKY130, open-source tools)

Digital VLSI Design team assignment: a 4-bit × 4-bit unsigned array multiplier taken from
Verilog RTL through simulation, Yosys synthesis, OpenSTA timing and LibreLane place-and-route.

## Team

| Name | Roll number | Email | Parts |
|---|---|---|---|
| Sale Sangameshwar | 2024102017 | sangameshwar.sale@students.iiit.ac.in | A (RTL + verification), B (synthesis) |
| Palla Rithik Reddy | 2024102005 | rithik.palla@students.iiit.ac.in | C (STA), D (physical design) |

## Status

| Part | Item | Status |
|---|---|---|
| A | `rtl/full_adder.v`, `rtl/mult_array.v`, `tb/tb_mult.v` | Done |
| A | RTL simulation (IIC-OSIC-TOOLS) | `PASS: 256 vectors checked, 0 errors` |
| A | Fault-injection test (`sum = a ^ b`) | `FAIL: 256 vectors checked, 95 errors`, then restored → PASS |
| A | Hand-worked example (A = 12, B = 7) | Done, matches waveform (below) |
| A | Waveform screenshot, block diagram | To be added to `report/report.pdf` |
| B | `synth/synth.tcl`, netlist, stat report | Done |
| B | Gate-level simulation | `PASS: 256 vectors checked, 0 errors` |
| C | `sta/sta.tcl`, timing report | Done: WNS = 7.213 ns at T = 10 ns, Tmin = 2.787 ns, Fmax = 358.81 MHz |
| D | `pnr/` | In progress |

## Repository layout

```text
README.md
rtl/full_adder.v             full adder (assign statements)
rtl/mult_array.v             4x4 array multiplier, 12 full_adder instances, 16 flip-flops
tb/tb_mult.v                 exhaustive self-checking testbench (256 vectors)
synth/synth.tcl              Yosys script
synth/mult_array_netlist.v   gate-level netlist (generated)
synth/mult_array_stat.rpt    cell/area report (generated)
sta/sta.tcl                  OpenSTA script
sta/mult_array_timing.rpt    critical path report (generated)
pnr/                         Part D
report/report.pdf            final report
.dev/                        helper scripts (container launch, resource check)
```

`sim`, `gls` and `mult.vcd` are generated outputs and are git-ignored.

## Environment

| Item | Value |
|---|---|
| Host | Windows 11, WSL 2 (Ubuntu) with Docker Engine 28.5.1 |
| Image | `hpretl/iic-osic-tools:2026.10` (12.5 GB) |
| Icarus Verilog | 14.0 (devel) (s20260301-579-g15d870a5) |
| Yosys | 0.70 (git sha1 28ba3cb92) |
| OpenSTA | 3.1.0 |
| PDK | `PDK_ROOT=/foss/pdks`, `PDK=sky130A` (after `sak-pdk sky130A`) |

The repository root is mounted as `/foss/designs` in the container (`.dev/start_container.sh`),
so all files stay on the host.

Commands, in order:

```bash
# host (WSL)
.dev/preflight.sh
docker pull hpretl/iic-osic-tools:2026.10
.dev/start_container.sh                   # shell inside the container

# container
cd /foss/designs
iverilog -V | head -1
yosys -V
sta -version
echo $PDK_ROOT $PDK                       # showed "/foss/pdks ihp-sg13g2"
sak-pdk sky130A                           # select SKY130
echo $PDK_ROOT $PDK                       # now "/foss/pdks sky130A"
```

---

## Part A — RTL design and verification

### Design

**`rtl/full_adder.v`**: `sum = a ^ b ^ cin`, `cout = (a & b) | (a & cin) | (b & cin)`.

**`rtl/mult_array.v`**: ports `clk`, `rst_n`, `a[3:0]`, `b[3:0]`, `p[7:0]` (registered).

```text
a,b --> [a_r, b_r : 8 FF] --> 16 AND --> row 1 (4 FA) --> row 2 (4 FA) --> row 3 (4 FA) --> [p : 8 FF]
         edge 1                                                                              edge 2
```

- Partial products `ppi[j] = a_r[j] & b_r[i]` (16 AND gates).
- Row 0: `p[0] = pp0[0]`, `r0 = {0, pp0[3], pp0[2], pp0[1]}`.
- Row i (i = 1..3): full adder j adds `ppi[j] + r(i-1)[j] + ci[j]`, with `ci[0] = 0`;
  `p[i] = si[0]`, `ri = {ci[4], si[3], si[2], si[1]}`.
- `p[7:4] = {c3[4], s3[3], s3[2], s3[1]}`.
- 12 `full_adder` instances (`fa1_0` … `fa3_3`); no `*` operator in the RTL.
- All 16 flip-flops (`a_r`, `b_r`, `p`) are cleared by the asynchronous active-low reset `rst_n`.
  Latency is 2 cycles, throughput 1 product per cycle.

### Testbench (`tb/tb_mult.v`)

- 10 ns clock; `rst_n` low for the first 2 cycles (0–20 ns); checks `p == 0` during reset.
- Applies a new (a, b) pair **every cycle** on the falling edge, for all 256 pairs
  (vector `i`: `a = i[7:4]`, `b = i[3:0]`).
- Compares `p` with `a * b` exactly 2 cycles after each vector is applied, so a design with the
  wrong latency fails. `!==` is used so X/Z values count as errors.
- Prints one line per mismatch and one summary line, writes `mult.vcd`.

### Simulation

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```

Output:

```text
VCD info: dumpfile mult.vcd opened for output.
PASS: 256 vectors checked, 0 errors
tb/tb_mult.v:91: $finish called at 2600000 (1ps)
```

### Fault-injection test

```bash
# rtl/full_adder.v temporarily changed to:  assign sum  = a ^ b;
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
```

Output (95 mismatch lines, first four shown):

```text
MISMATCH at 560 ns: a=3 b=3 expected p=9 got p=5
MISMATCH at 590 ns: a=3 b=6 expected p=18 got p=10
MISMATCH at 600 ns: a=3 b=7 expected p=21 got p=9
MISMATCH at 640 ns: a=3 b=11 expected p=33 got p=29
...
FAIL: 256 vectors checked, 95 errors
```

The first failure is a = 3, b = 3: the first vector where a full adder sees `cin = 1`.
The file was then restored to `assign sum  = a ^ b ^ cin;` and re-run:
`PASS: 256 vectors checked, 0 errors`.

### Hand-worked example

Roll number used: **Sale Sangameshwar, 2024102017** → last digit 7 → **A = 7 + 5 = 12**, **B = 7**.

```text
          1 1 0 0     A = 12
        x 0 1 1 1     B = 7
        ---------
          1 1 0 0     pp0 = A AND b0 (b0 = 1)
        1 1 0 0       pp1 = A AND b1 (b1 = 1), shifted 1
      1 1 0 0         pp2 = A AND b2 (b2 = 1), shifted 2
    0 0 0 0           pp3 = A AND b3 (b3 = 0), shifted 3
  ---------------
  0 1 0 1 0 1 0 0     P = 84 (0x54)
```

Through the array (bits MSB → LSB; full adders j = 0..3 as (sum, carry)):

| Row | Inputs | Full adders | Outputs |
|---|---|---|---|
| 0 | pp0 = 1100 | — | p[0] = 0, r0 = 0110 |
| 1 | pp1 = 1100, r0 = 0110 | (0,0) (1,0) (0,1) (0,1) | p[1] = 0, r1 = 1001 |
| 2 | pp2 = 1100, r1 = 1001 | (1,0) (0,0) (1,0) (0,1) | p[2] = 1, r2 = 1010 |
| 3 | pp3 = 0000, r2 = 1010 | (0,0) (1,0) (0,0) (1,0) | p[3] = 0, p[7:4] = 0101 |

p = 0101 0100 = **84**.

**In the waveform** (vector index 16 × 12 + 7 = 199), read from the RTL `mult.vcd`:

```text
2020.0 ns  b = 7        a = 12, b = 7 applied (falling edge)
2025.0 ns  p = 72       edge 1: inputs captured into a_r, b_r (p still shows 12 x 6)
2030.0 ns  b = 8        next vector applied
2035.0 ns  p = 84       edge 2: product registered  -> latency = 2 cycles (20 ns)
```

In GTKWave: add `clk`, `rst_n`, `a`, `b`, `p` (Data Format → Decimal), zoom to 2000–2050 ns,
place markers at 2025 ns and 2035 ns, and screenshot.

---

## Part B — Logic synthesis with Yosys

`synth/synth.tcl` sets `$lib` to
`$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib` and runs, in order:
`read_verilog` → `synth -top mult_array -flatten` → `dfflibmap -liberty $lib` → `abc -liberty $lib`
→ `opt_clean -purge` → `tee -o synth/mult_array_stat.rpt stat -liberty $lib`
→ `write_verilog -noattr synth/mult_array_netlist.v`.

```bash
yosys -c synth/synth.tcl
```

Finished with exit code 0. The only warnings were from ABC (`The network is combinational`,
`Detected 9 multi-output cells`), which are informational.

### Gate-level simulation

```bash
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
    tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```

(The PDF wraps `synth/mult_array_netlist.v` across two lines; it is one path.)

Output:

```text
VCD info: dumpfile mult.vcd opened for output.
PASS: 256 vectors checked, 0 errors
```

### Results (from `synth/mult_array_stat.rpt`)

| Metric | Value |
|---|---|
| Total number of cells | 61 |
| Number of flip-flops | 16 (`sky130_fd_sc_hd__dfrtp_1`) |
| Total cell area (µm²) | 756.976 |
| Flip-flop area (µm²) | 16 × 25.024 = 400.384 |
| Flip-flop area (% of total) | 100 × 400.384 / 756.976 = 52.89 % |
| The 3 most-used cell types and their counts | `dfrtp_1` × 16, `nand2_1` × 7, `and2_0` × 4 and `maj3_1` × 4 (tied) |
| Netlist simulation result | `PASS: 256 vectors checked, 0 errors` |

Logic cells (excluding flip-flops): 61 − 16 = 45. Full cell list:

| Cell | Count | Area (µm²) |
|---|---|---|
| dfrtp_1 | 16 | 400.384 |
| nand2_1 | 7 | 26.275 |
| and2_0 | 4 | 25.024 |
| maj3_1 | 4 | 40.038 |
| a21oi_1 | 3 | 15.014 |
| xnor2_1 | 3 | 26.275 |
| xor3_1 | 3 | 71.318 |
| a22oi_1 | 2 | 15.014 |
| clkinv_1 | 2 | 7.507 |
| lpflow_isobufsrc_1 | 2 | 12.512 |
| nand3_1 | 2 | 10.010 |
| nand4_1 | 2 | 12.512 |
| nor2_1 | 2 | 7.507 |
| xor2_1 | 2 | 17.517 |
| a21boi_0, and3_1, and4_1, o2111ai_1, o21bai_1, o311ai_0, xnor3_1 | 1 each | 7.507, 6.256, 8.758, 8.758, 7.507, 8.758, 22.522 |

---

## Part C — Static timing analysis with OpenSTA

`sta/sta.tcl` reads the same typical-corner Liberty file, reads and links
`synth/mult_array_netlist.v`, creates `clk` with period T, sets a 1.0 ns input delay on every
input except `clk` and a 1.0 ns output delay on every output, prints the worst setup slack
(`report_worst_slack -max -digits 3`) and writes `report_checks -path_delay max -digits 3` to
`sta/mult_array_timing.rpt`. T is 10 ns unless the environment variable `STA_PERIOD` is set.

```bash
sta sta/sta.tcl                       # T = 10 ns
STA_PERIOD=2.79 sta sta/sta.tcl       # T = Tmin, rounded to 0.01 ns (this run wrote the committed report)
```

Output:

```text
Clock period T = 10.0 ns
worst slack max 7.213
Clock period T = 2.79 ns
worst slack max 0.003
```

Tmin = T − WNS = 10 − 7.213 = **2.787 ns**, Fmax = 1000 / 2.787 = **358.81 MHz**.
At T = 2.79 ns the slack is +0.003 ns, i.e. the path just fits, which confirms Tmin.

### Critical path (from `sta/mult_array_timing.rpt`)

Start point `_91_` = flip-flop **`a_r[1]`** (its D pin is `a[1]`); end point `_88_` = flip-flop
**`p[6]`** (its D pin is `fa3_3.sum`). The netlist instance names were mapped back to the RTL by
reading `synth/mult_array_netlist.v`.

| # | Instance | Cell | Delay (ns) | Arrival (ns) | Function in the array |
|---|---|---|---|---|---|
| 1 | `_91_` | dfrtp_1 | 0.398 | 0.398 | launch flip-flop `a_r[1]`, CLK → Q |
| 2 | `_37_` | clkinv_1 | 0.073 | 0.471 | `~a_r[1]`, input of the merged row-1 logic |
| 3 | `_42_` | o311ai_0 | 0.356 | 0.827 | row 1: part of `s1[1]` (fa1_1 sum, with pp0[2], pp1[1] and the fa1_0 carry folded in) |
| 4 | `_45_` | a21oi_1 | 0.153 | 0.980 | row 2: `c2[1]` = pp2[0] AND r1[0] (fa2_0 carry; a half adder because c2[0] = 0) |
| 5 | `_51_` | maj3_1 | 0.402 | 1.382 | row 2: `c2[2]` (fa2_1 carry) |
| 6 | `_58_` | xnor3_1 | 0.370 | 1.752 | row 2: `s2[2]` = r2[1] (fa2_2 sum) |
| 7 | `_61_` | maj3_1 | 0.368 | 2.119 | row 3: `c3[2]` (fa3_1 carry) |
| 8 | `_63_` | maj3_1 | 0.354 | 2.474 | row 3: `c3[3]` (fa3_2 carry) |
| 9 | `_64_` | xor3_1 | 0.178 | 2.652 | row 3: `s3[3]` = p[6] (fa3_3 sum) |
| 10 | `_88_` | dfrtp_1 | setup 0.135 | — | capture flip-flop `p[6]` |

Data arrival 2.652 ns + setup 0.135 ns = 2.787 ns = Tmin.

**Cells on the path:** 10 (2 flip-flops + 8 logic cells). All 8 logic cells implement full-adder
logic (with the AND gates of the partial products merged in by ABC). The path crosses
**7 full-adder stages** — fa1_1 → fa2_0 → fa2_1 → fa2_2 → fa3_1 → fa3_2 → fa3_3 — against the
estimate of about 2N = 8. It is slightly shorter because the first adder of each row has a
constant 0 carry-in (a half adder), and ABC folded row 0/row 1 into compound gates.

The second path group in the report, `asynchronous`, is the reset recovery check
(`rst_n` → `RESET_B` of `_82_`, slack 2.018 ns at T = 2.79 ns); it does not limit Fmax.

### Results

| Metric | Value |
|---|---|
| Worst slack at T = 10 ns (ns) | 7.213 |
| Tmin (ns) | 2.787 (rounded: 2.79) |
| Fmax (MHz) | 358.81 |
| Slack at T = Tmin = 2.79 ns (ns) | 0.003 |
| Critical path start point | `_91_` = `a_r[1]` (dfrtp_1, CLK) |
| Critical path end point | `_88_` = `p[6]` (dfrtp_1, D) |
| Number of cells on the critical path | 10 (2 flip-flops + 8 logic cells) |
| Latency (ns) = 2 × Tmin | 5.574 |
| Throughput (million results per second) | 358.81 (one result per cycle) |

---

## Log of issues and fixes

| Date | Issue | Fix |
|---|---|---|
| 2026-10-19 | Docker Desktop not running on Windows | Used the Docker Engine already running inside WSL 2 Ubuntu |
| 2026-10-19 | WSL has ~3 GB RAM (PDF asks for 8 GB for Docker); WSL briefly stopped responding while the 12.5 GB image was extracted | Enough for Parts A/B. Raise with `%UserProfile%\.wslconfig` (`[wsl2]` `memory=8GB`) before the LibreLane run |
| 2026-10-19 | Container default `PDK` was `ihp-sg13g2` | `sak-pdk sky130A` (in scripts: `source sak-pdk-script.sh sky130A`, since `sak-pdk` is a `.bashrc` alias) |
| 2026-10-19 | Mismatch lines printed times in ps but labelled "ns" (`560000 ns`) | Added `$timeformat(-9, 0, " ns", 0)` to the testbench |
| 2026-10-19 | `iverilog -V` prints "Unable to get version from ivlpp/ivl" | Harmless quirk of the devel Icarus build in the image; compilation is unaffected |
