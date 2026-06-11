#!/usr/bin/env bash
set -euo pipefail

# Run CoreMark variants on this RV32 CPU workspace.
# Usage:
#   ./run_coremark_mul.sh rv32i              # baseline: -march=rv32i_zicsr
#   ./run_coremark_mul.sh rv32im-mul         # MUL only: -march=rv32im_zicsr -mno-div
#   ./run_coremark_mul.sh rv32im-full-simdiv # full RV32IM with simulation-only comb DIV
#   ./run_coremark_mul.sh zmmul              # official Zmmul ISA string, if GCC supports it

MODE="${1:-rv32im-mul}"

case "$MODE" in
  rv32im-mul)
    echo "[run_coremark_mul] Cleaning and running RV32IM combinational MUL build (-mno-div)..."
    make clean
    make run-rv32im-mul
    ;;
  rv32im-full-simdiv|full-simdiv|simdiv)
    echo "[run_coremark_mul] Cleaning and running full RV32IM with simulation-only combinational DIV/REM..."
    echo "[run_coremark_mul] Verilator define: -DENABLE_SIM_COMB_DIV"
    make clean
    make VERILATOR_DEFS="-DENABLE_SIM_COMB_DIV" run-rv32im-full-simdiv
    ;;
  zmmul)
    echo "[run_coremark_mul] Cleaning and running Zmmul combinational MUL build..."
    make clean
    make run-zmmul
    ;;
  rv32i)
    echo "[run_coremark_mul] Cleaning and running RV32I baseline build..."
    make clean
    make run-rv32i
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Valid modes: rv32i, rv32im-mul, rv32im-full-simdiv, zmmul" >&2
    exit 2
    ;;
esac
