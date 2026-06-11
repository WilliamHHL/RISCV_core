#!/usr/bin/env bash
set -euo pipefail

# Run a CoreMark configuration and parse the PERF counters emitted by tb_top.v.
# Usage:
#   ./run_perf_counters.sh rv32im-mul
#   ./run_perf_counters.sh rv32im-mul-timing
#   ./run_perf_counters.sh rv32i
#   ./run_perf_counters.sh rv32im-full-simdiv
#   ./run_perf_counters.sh zmmul

MODE="${1:-rv32im-mul}"

case "$MODE" in
  rv32i)
    LOG="coremark_rv32i_baseline.log"
    ;;
  rv32im-mul)
    LOG="coremark_rv32im_combmul.log"
    ;;
  rv32im-mul-timing|timing-mul|timing)
    LOG="coremark_rv32im_timing_mul.log"
    ;;
  rv32im-full-simdiv|full-simdiv|simdiv)
    LOG="coremark_rv32im_full_simdiv.log"
    ;;
  zmmul)
    LOG="coremark_rv32i_zmmul_combmul.log"
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Valid modes: rv32i, rv32im-mul, rv32im-mul-timing, rv32im-full-simdiv, zmmul" >&2
    exit 2
    ;;
esac

./run_coremark_mul.sh "$MODE"

echo
echo "[run_perf_counters] Parsing $LOG"
./analyze_perf_log.py "$LOG" | tee "perf_${MODE}.summary.txt"

echo
echo "[run_perf_counters] Key raw PERF lines:"
grep '^PERF ' "$LOG" | tee "perf_${MODE}.raw.txt"
