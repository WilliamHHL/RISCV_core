#!/usr/bin/env bash
set -euo pipefail

# Compare the current golden one-cycle comb-MUL build against the first
# timing-friendly registered-MUL experiment.
#
# Golden expected before this patch:
#   RV32IM comb-MUL + 64-entry BTB/BHT + 16-entry RAS ~= 2.93 CoreMark/MHz
#
# Timing-friendly mode uses -DENABLE_TIMING_MULDIV and should still pass
# validation, but it is expected to lose some CoreMark/MHz because every MUL
# now stalls while the registered multiplier runs.

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

chmod +x run_coremark_mul.sh run_perf_counters.sh analyze_perf_log.py

echo "== Golden one-cycle comb-MUL baseline =="
./run_perf_counters.sh rv32im-mul

echo
echo "== Timing-friendly registered-MUL experiment =="
./run_perf_counters.sh rv32im-mul-timing

echo
echo "== Summary files =="
echo "  coremark_rv32im_combmul.log"
echo "  coremark_rv32im_timing_mul.log"
echo "  perf_rv32im-mul.summary.txt"
echo "  perf_rv32im-mul-timing.summary.txt"
