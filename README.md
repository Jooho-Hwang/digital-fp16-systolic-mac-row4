# FP16 Systolic MAC Row (4-Stage)

A half-precision (FP16) floating-point multiply–accumulate (MAC) array, implemented in Verilog HDL.  
The design consists of **purely combinational FPMUL / FPADD cores** and a **pipelined MAC chain** of four units (systolic row).  

This repository follows a standardized structure for Verilog projects:
- Consistent directory layout (`rtl/`, `sim/`, `docs/`)
- Clear separation between combinational and sequential logic
- Unified constant definitions (`fp16_defs.vh`)

## Overview

**Key Features:**
- **FP16 IEEE 754 format** (1 sign bit, 5 exponent bits, 10 fraction bits)
- **Denormalized numbers supported** (exp=0, implicit leading 0)
- **Guard-bit rounding** (if LSB-1 == 1 → round up, else truncate)
- **Special value handling**:
  - `±Inf` and `NaN` detection
  - Zero (±0) propagation
  - Denormal → normalized conversion in operations
- **Pure combinational** FPMUL and FPADD (no clock)
- **Pipelined FP MAC** for systolic row implementation
- **4-stage MAC row** with weight preload and streaming input

## Architecture

![Block Diagram](docs/block%20diagram.png)

**Main Modules:**
1. **`fp_mul.v`** – Combinational FP16 multiplier  
   - Decoding, normalization, rounding, encoding  
   - Handles Zero, Inf, Denorm cases
2. **`fp_add.v`** – Combinational FP16 adder  
   - Operand alignment, sign-aware add/sub  
   - Normalization, rounding, special case handling
3. **`fp_mac.v`** – Minimal pipeline MAC unit  
   - Wraps FPMUL + FPADD with enable-controlled registers
4. **`mac_row4.v`** – Four MAC units in a systolic row  
   - Weight preload per unit  
   - Streaming X input, continuous output after pipeline fill

## Directory Structure

```bash
digital_fp16_systolic_mac_row4/
├─ README.md
├─ LICENSE
├─ rtl/
│ ├─ fp16_defs.vh # Common FP16 constants/macros
│ ├─ fp_mul.v # FP16 multiplier (combinational)
│ ├─ fp_add.v # FP16 adder (combinational)
│ ├─ fp_mac.v # Pipelined MAC unit
│ └─ mac_row4.v # 4-MAC systolic row
├─ sim/
│ ├─ tb_fp_mul.v # Unit testbench for fp_mul
│ ├─ tb_fp_add.v # Unit testbench for fp_add
│ ├─ tb_fp_mac.v # Testbench for pipelined MAC
│ └─ tb_mac_row4.v # Testbench for 4-MAC systolic row
└─ docs/
└─ block diagram.jpg # Architecture diagram
```

## How to Build & Run

Example with **Icarus Verilog** (`iverilog`) and **GTKWave**:

```bash
# Compile and run a unit testbench (fp_mul)
iverilog -g2012 -I rtl -o tb_fp_mul.vvp sim/tb_fp_mul.v rtl/fp_mul.v
vvp tb_fp_mul.vvp

# View waveform (if $dumpfile used in TB)
gtkwave dump.vcd

# Repeat for other testbenches: tb_fp_add.v, tb_fp_mac.v, tb_mac_row4.v
```

## How to Test

Testbench coverage:

1. tb_fp_mul
- Normalized × normalized
- Zero × anything
- Inf × finite
- Denorm × normalized
- Rounding boundary case

2. tb_fp_add
- Aligned sum
- Different signs (cancellation)
- Zero + finite, Inf + finite
- Denorm interactions

3. tb_fp_mac
- Enable sequencing
- Single MAC computation and valid signal timing

4. tb_mac_row4
- Weight preload
- Continuous X streaming
- Presentation vectors:
    ```bash
    w = {3.75, 1.76, -0.52, 0.36}
    x = {1.52, 2.75, 3.86, -1.47, 8.98, -6.52, 3.61}
    ```
- Overflow weight case

## Lessons Learned
Separating purely combinational FP cores from pipelined wrappers makes timing closure easier and the design reusable.

Using a common header (fp16_defs.vh) for constants prevents mismatches between modules.

Guard-bit rounding is simple to implement but requires careful handling of carry into the exponent.

Preloading weights and streaming inputs is an efficient approach for systolic array designs.
