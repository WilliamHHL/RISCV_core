# 64-entry BTB/BHT + 16-entry RAS experiment

This patch is intended to test whether the remaining CoreMark bottleneck is
branch/redirect related after the RV32IM combinational multiplier improvement.

Previous perf-counter result before this patch:

- CoreMark/MHz: ~2.78
- `ifid_flush_cycles`: ~60.7M cycles, 5.35%
- `branch_dir_mispredict_count`: ~22.37M, 13.14% of conditional branches
- `jal_mispredict_count`: ~3.67M
- `jalr_count`: ~4.31M, previously always redirected in EX
- `load_use_stall_cycles`: ~63.5M cycles, 5.60%

## RTL changes

1. `top.v`
   - BHT index bits changed from 4 to 6, giving 64 2-bit counters.
   - BTB index bits changed from 4 to 6, giving 64 direct-mapped entries.
   - Added a 16-entry RAS.
   - JALR no longer always redirects. It redirects only if the predicted target
     does not match the resolved JALR target.

2. `btb_direct.v`
   - Added `pred_is_return` metadata per BTB entry.
   - BTB entry classes are now:
     - branch entry: `!pred_is_jump && !pred_is_return`, uses BHT direction
     - jump entry: `pred_is_jump`, always predict taken
     - return entry: `pred_is_return`, predict from RAS top when valid

3. `ras_stack.v`
   - New 16-entry return-address stack.
   - Pushes `ex_pc + 4` on JAL/JALR calls where `rd` is x1 or x5.
   - Pops on standard return idiom `JALR x0, x1/x5, imm`.

4. `tb_top.v` and `analyze_perf_log.py`
   - Added counters for JALR prediction and RAS behavior:
     - `jalr_pred_taken_count`
     - `jalr_mispredict_count`
     - `ras_pred_count`
     - `ras_correct_count`
     - `ras_push_count`
     - `ras_pop_count`

## Expected behavior

The best-case improvement is limited by the previous branch/redirect penalty.
If the RAS works well, `jalr_mispredict_count` should drop significantly.
If the larger BHT/BTB helps, `branch_dir_mispredict_count` and/or
`jal_mispredict_count` should drop.

Load-use stalls are not touched by this patch, so `load_use_stall_cycles` should
remain near the old value unless the changed control flow affects dynamic count.

Run:

```bash
./run_bpred_ras_test.sh
```

or directly:

```bash
./run_perf_counters.sh rv32im-mul
cat perf_rv32im-mul.summary.txt
```
