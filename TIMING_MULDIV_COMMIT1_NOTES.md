# Timing-friendly MUL/DIV work: commit 1

This commit keeps the tested performance baseline unchanged by default:

- RV32IM combinational MUL
- 64-entry BTB/BHT
- 16-entry RAS
- CoreMark baseline from previous run: about 2.93 CoreMark/MHz

It adds an optional timing-friendly multiplier experiment enabled with:

```bash
-DENABLE_TIMING_MULDIV
```

## What is implemented

`src/rv32_muldiv_unit.v` implements the RV32M multiply subset only:

- `MUL`
- `MULH`
- `MULHSU`
- `MULHU`

The unit is synthesizable and does not use Verilog `/` or `%` operators. It uses
registered operands and a registered product to remove the 32x32 multiplier from
the normal single-cycle EX ALU result path.

Latency model:

```text
cycle N:     start=1, operands/op captured
cycle N+1:   registered operands feed multiplier, product captured
cycle N+2:   done=1, result is visible to EX/MEM
```

While the unit is active, top-level control:

- stalls PC / IF / ID
- holds ID/EX so the M instruction remains in EX
- injects bubbles into EX/MEM until `done=1`
- captures the result into EX/MEM on the done cycle

## What is not implemented yet

This first commit does not implement synthesizable DIV/REM. Keep CoreMark in
multiplier-only mode with:

```text
-march=rv32im_zicsr -mno-div
COREMARK_TAG=rv32im-timingmul-mno-div
```

The previous simulation-only combinational divider remains separate under
`ENABLE_SIM_COMB_DIV` for measurement/debug only. Do not treat that path as the
synthesizable divider.

## Main commands

Golden baseline:

```bash
./run_perf_counters.sh rv32im-mul
```

Timing-friendly registered MUL experiment:

```bash
./run_perf_counters.sh rv32im-mul-timing
```

Or run both:

```bash
./run_timing_mul_test.sh
```

Expected result: validation should pass, but CoreMark/MHz will likely be lower
than the golden one-cycle comb-MUL baseline because every multiply now has
multi-cycle latency.

## New PERF counters

The testbench now prints:

```text
PERF muldiv_start_count
PERF muldiv_busy_cycles
PERF muldiv_done_count
PERF muldiv_stall_cycles
```

These help confirm that the timing-friendly mode starts exactly one operation
per dynamic M instruction and quantifies the extra cycles from the registered
multiplier.
