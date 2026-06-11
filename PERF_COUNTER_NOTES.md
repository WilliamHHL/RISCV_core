# Performance counter patch

This patch adds simulation-only bottleneck counters to `src/tb_top.v`. The CPU RTL datapath is not changed.

## Main command

```bash
./run_perf_counters.sh rv32im-mul
```

Other modes:

```bash
./run_perf_counters.sh rv32i
./run_perf_counters.sh rv32im-full-simdiv
./run_perf_counters.sh zmmul
```

Equivalent Makefile targets:

```bash
make perf-rv32im-mul
make perf-rv32i
make perf-rv32im-full-simdiv
make perf-zmmul
```

## What is counted

The testbench prints `PERF <name> <value>` lines at ECALL/EBREAK/timeout.

Key counters:

- `pc_stall_cycles`: cycles where the PC is held by the hazard logic.
- `ifid_flush_cycles`: frontend flush cycles; this is usually the direct branch/redirect penalty counter in this design.
- `idex_flush_cycles`: bubbles inserted into EX, including redirect and load-use/CSR hazards.
- `load_use_stall_cycles`: classic load-use stalls from `hazard_unit`.
- `branch_count`, `branch_dir_mispredict_count`, `branch_tgt_mispredict_count`: conditional branch behavior.
- `jal_count`, `jal_mispredict_count`, `jalr_count`: jump/call/return behavior. In this current core, JALR redirects in EX, so a high JALR count is expected to cost frontend bubbles.
- `redirect_count`: all EX redirects, including branch mispredicts, JAL target misses, JALR, and false BTB hits.
- `load_count`, `store_count`: dynamic memory-op count in EX.
- `mul_count`, `mulh_count`, `mulhu_count`, etc.: dynamic M-extension use.

## Interpretation notes

`instr_issue_count` is approximate. It counts non-NOP instructions that ID is allowed to send into EX. This is good enough for bottleneck ratios, but it is not a formal architectural retired-instruction counter because this core does not currently carry a valid bit/instruction through all pipeline stages.

For branch bottleneck checking, first look at:

```text
ifid_flush_cycles / total_cycles
redirect_count
branch_dir_mispredict_count / branch_count
branch_tgt_mispredict_count / branch_count
jalr_count
```

If `ifid_flush_cycles` is large, the frontend is losing cycles to redirects/branch recovery. If `branch_*_mispredict` is low but `jalr_count` is high, then return/JALR prediction or RAS support is a likely next optimization.

For load bottleneck checking, first look at:

```text
load_use_stall_cycles / total_cycles
load_use_stall_cycles / load_count
```

If this is high, the next performance target is load-use scheduling/forwarding or reducing load latency.
