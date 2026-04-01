# William's Final Year Project

## OpenLane RISC-V Design
**From RV32I CPU Architecture Design to Open-Source ASIC Implementation**

This project demonstrates a complete open-source RISC-V CPU design flow, from RTL design and architectural exploration to physical implementation and GDS generation using OpenLane and the SkyWater SKY130 PDK.

---

## Project Overview

### Objectives
- Design and implement a tape-out-ready high performance RISC-V CPU

---

## Key Contributions

- Implemented and verified **four RV32I CPU architectures** in Verilog:
  - Single-cycle CPU
  - Multicycle non-pipelined CPU
  - 5-stage pipelined CPU
  - 5-stage pipelined CPU with dynamic branch prediction
- Improved pipelined CPU performance using **dynamic branch prediction**
  - 2-bit BHT
  - 16-entry BTB
- Completed **open-source RTL-to-GDS physical implementation**
  - OpenLane
  - SkyWater SKY130 PDK
- Quantified architecture trade-offs using:
  - CoreMark benchmark results
  - PPA comparison

---

## Design Methodology

### Front-End Design
- RTL implementation in Verilog
- Module-level and top-level testbench development
- Cycle-accurate simulation with Verilator
- Waveform verification using GTKWave

### Benchmarking
- Compile CoreMark
- Generate HEX
- Load instruction memory
- Simulate in Verilator
- Compute CoreMark/MHz

### Back-End Design
- Synthesis
- Floorplanning
- Placement
- Clock Tree Synthesis (CTS)
- Routing
- Signoff:
  - DRC
  - LVS
  - Timing checks

---

## CPU Architecture Evolution

Each version addressed limitations of the previous one, progressing from a simple functional baseline to a backend-feasible and higher-performance architecture.

---

### Version 1 – Single-Cycle RV32I CPU

**Description**  
Each instruction completes in one clock cycle. This version served as the baseline RTL model for functional verification and ISA validation in simulation.

**Status**
- RTL design completed
- Functional verification completed
- Simulated successfully in Verilator

**Result**
- CoreMark/MHz = **1.34**

**Limitation**
- Assumes zero-latency memory
- Not compatible with realistic SRAM timing in ASIC backend implementation

**Role in Project**
- Baseline model for functional verification and architecture comparison

---

### Version 2 – Multicycle Non-Pipelined RV32I CPU

**Description**  
To support realistic 1-cycle SRAM timing, instruction execution was divided across multiple clock cycles. This made the design compatible with SRAM macro timing and backend implementation.

**Status**
- RTL design completed
- Functional verification completed
- Successfully implemented in OpenLane

**Key Achievement**
- First version to achieve both:
  - functional correctness
  - successful physical implementation

**Results**
- Area: **1.20 mm²**
- Power: **11.9 mW**
- Fmax: **68 MHz**
- CoreMark/MHz = **0.90**

**Main Advantage**
- Lowest area and power among backend-complete versions

**Trade-off**
- Lower throughput than pipelined design

---

### Version 3 – 5-Stage Pipelined RV32I CPU

**Description**  
After establishing a backend-feasible multicycle core, the design was upgraded to a classic 5-stage pipeline:

- IF
- ID
- EX
- MEM
- WB

Pipeline registers, hazard handling, and forwarding logic were added to improve throughput and frequency.

**Implemented Features**
- 5-stage pipeline datapath
- Pipeline registers
- Hazard handling
- Forwarding logic

**Status**
- RTL design completed
- Functional verification completed
- Passed OpenLane physical implementation

**Results**
- Area: **1.24 mm²**
- Power: **26.5 mW**
- Fmax: **100 MHz**
- CoreMark/MHz = **0.83**

**Observation**
- Higher frequency and better throughput than multicycle architecture
- Control hazards reduced benchmark efficiency

---

### Version 4 – 5-Stage Pipelined RV32I CPU with Dynamic Branch Prediction

**Description**  
To reduce branch penalty in the pipelined CPU, dynamic branch prediction was added.

**Predictor Structures**
- **BHT (Branch History Table)**  
  Predicts taken/not-taken using a 2-bit saturating counter
- **BTB (Branch Target Buffer)**  
  16-entry structure storing predicted branch target addresses

**How It Works**
- During IF, the CPU checks the BHT and BTB
- If a branch is predicted taken and BTB hits, fetch redirects immediately
- On misprediction, the pipeline is flushed and the PC is corrected

**Impact**
- CoreMark/MHz improved from **0.83 → 1.02**
- Improvement: **+23%**

**Results**
- Area: **1.32 mm²**
- Power: **50.0 mW**
- Fmax: **100 MHz**
- CoreMark/MHz = **1.02**

**Trade-off**
- Better benchmark efficiency
- Increased area and power due to predictor hardware

---

## Future Work

The following versions are planned as future extensions of the project.

### Version 5 – Memory Interface and Cache Subsystem

**Planned Features**
- Instruction cache
- Data cache
- Cache controller
- External memory interface
- Improved memory hierarchy for reduced access latency

**Goal**
- Improve real-world performance beyond tightly coupled on-chip memory assumptions
- Prepare the design for more realistic system-level integration

---

### Version 6 – RV32IM Extension

**Planned Features**
- Support for the RISC-V **M extension**
- Hardware multiply and divide instructions
- Extended ALU / execution unit for arithmetic acceleration

**Goal**
- Improve computational capability
- Increase benchmark performance for arithmetic-heavy workloads

---

### Version 7 – SoC Integration

**Planned Features**
- AXI or Wishbone bus interface
- UART and peripheral integration
- On-chip communication support
- More complete embedded SoC platform around the CPU core

**Goal**
- Extend the standalone CPU core into a usable SoC system
- Support external memory and peripheral connectivity

---

### Longer-Term Research Directions

#### Out-of-Order Execution
- Explore dynamic scheduling techniques for higher IPC
- Investigate instruction windowing, register renaming, and reorder mechanisms

#### Multithreading
- Explore hardware multithreading for better pipeline utilization
- Study latency hiding and resource sharing across threads

---

## PPA Summary

| Architecture | Area | Power | Fmax | CoreMark/MHz | Backend Status |
|---|---:|---:|---:|---:|---|
| Single-Cycle | N/A | N/A | N/A | 1.34 | Simulation only |
| Multicycle Non-Pipelined | 1.20 mm² | 11.9 mW | 68 MHz | 0.90 | Passed OpenLane |
| 5-Stage Pipeline | 1.24 mm² | 26.5 mW | 100 MHz | 0.83 | Passed OpenLane |
| 5-Stage Pipeline + DBP | 1.32 mm² | 50.0 mW | 100 MHz | 1.02 | Passed OpenLane |

### Takeaway
- **Multicycle** achieves the lowest area and power among backend-complete designs
- **Pipeline** achieves the highest frequency
- **Branch prediction** recovers benchmark efficiency, at the cost of higher area and power

---



CoreMark/MHz is calculated as:

```text
(Iterations × 1,000,000) / Total ticks
