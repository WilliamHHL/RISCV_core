#!/usr/bin/env bash
set -euo pipefail

# Run the RV32IM comb-MUL CoreMark benchmark with the updated predictor:
# 64-entry BTB + 64-entry BHT + 16-entry RAS.
# This is just a convenience wrapper around the existing perf counter flow.

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

chmod +x run_perf_counters.sh analyze_perf_log.py

echo "[run_bpred_ras_test] Running RV32IM comb-MUL CoreMark with 64-entry BTB/BHT + 16-entry RAS..."
./run_perf_counters.sh rv32im-mul

echo
if [[ -f perf_rv32im-mul.summary.txt ]]; then
    echo "[run_bpred_ras_test] Analyzer summary:"
    cat perf_rv32im-mul.summary.txt
else
    echo "[run_bpred_ras_test] WARNING: perf_rv32im-mul.summary.txt was not produced" >&2
fi

echo
if [[ -f coremark_rv32im_combmul.log ]]; then
    echo "[run_bpred_ras_test] Key PERF lines:"
    grep -E '^PERF (total_cycles|instr_issue_count|ifid_flush_cycles|load_use_stall_cycles|branch_count|branch_dir_mispredict_count|jal_count|jal_mispredict_count|jalr_count|jalr_pred_taken_count|jalr_mispredict_count|ras_pred_count|ras_correct_count|ras_push_count|ras_pop_count|redirect_count)' coremark_rv32im_combmul.log || true
fi
