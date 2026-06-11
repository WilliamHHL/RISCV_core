#!/usr/bin/env python3
"""Parse PERF lines emitted by src/tb_top.v and print bottleneck ratios."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    print("Usage: ./analyze_perf_log.py <simulation.log>", file=sys.stderr)
    sys.exit(2)

path = Path(sys.argv[1])
text = path.read_text(errors="replace")
perf = {}
for name, value in re.findall(r"^PERF\s+(\S+)\s+(\d+)\s*$", text, re.M):
    perf[name] = int(value)

def g(name: str) -> int:
    return perf.get(name, 0)

def pct(num: int, den: int) -> str:
    if den == 0:
        return "n/a"
    return f"{100.0 * num / den:.3f}%"

def ratio(num: int, den: int) -> str:
    if den == 0:
        return "n/a"
    return f"{num / den:.6f}"

total = g("total_cycles")
issue = g("instr_issue_count")
branch = g("branch_count")
branch_miss = g("branch_dir_mispredict_count") + g("branch_tgt_mispredict_count")
loads = g("load_count")
stores = g("store_count")
load_use = g("load_use_stall_cycles")
redirect = g("redirect_count")
ifid_flush = g("ifid_flush_cycles")

print(f"== PERF summary for {path} ==")
if not perf:
    print("No PERF lines found. Did the simulation reach ECALL/EBREAK with the patched tb_top.v?")
    sys.exit(1)

print(f"total_cycles                 {total}")
print(f"instr_issue_count approx      {issue}")
print(f"issue_per_cycle approx        {ratio(issue, total)}")
print()
print("-- Stall / flush cycles --")
print(f"pc_stall_cycles              {g('pc_stall_cycles')}  ({pct(g('pc_stall_cycles'), total)})")
print(f"ifid_flush_cycles            {ifid_flush}  ({pct(ifid_flush, total)})")
print(f"idex_flush_cycles            {g('idex_flush_cycles')}  ({pct(g('idex_flush_cycles'), total)})")
print(f"load_use_stall_cycles        {load_use}  ({pct(load_use, total)})")
print(f"csr_use_stall_cycles         {g('csr_use_stall_cycles')}  ({pct(g('csr_use_stall_cycles'), total)})")
print()
print("-- Instruction mix approximations --")
print(f"loads                        {loads}  ({pct(loads, issue)} of issue)")
print(f"stores                       {stores}  ({pct(stores, issue)} of issue)")
print(f"branches                     {branch}  ({pct(branch, issue)} of issue)")
print(f"jal                          {g('jal_count')}  ({pct(g('jal_count'), issue)} of issue)")
print(f"jalr                         {g('jalr_count')}  ({pct(g('jalr_count'), issue)} of issue)")
print(f"csr                          {g('csr_count')}  ({pct(g('csr_count'), issue)} of issue)")
print(f"mul total                    {g('mul_count') + g('mulh_count') + g('mulhsu_count') + g('mulhu_count')}  ({pct(g('mul_count') + g('mulh_count') + g('mulhsu_count') + g('mulhu_count'), issue)} of issue)")
print(f"div/rem total                {g('div_count') + g('divu_count') + g('rem_count') + g('remu_count')}  ({pct(g('div_count') + g('divu_count') + g('rem_count') + g('remu_count'), issue)} of issue)")
print()
print("-- Branch / redirect diagnostics --")
print(f"branch_taken                 {g('branch_taken_count')}  ({pct(g('branch_taken_count'), branch)} of branches)")
print(f"branch_pred_taken            {g('branch_pred_taken_count')}  ({pct(g('branch_pred_taken_count'), branch)} of branches)")
print(f"branch_dir_mispredict        {g('branch_dir_mispredict_count')}  ({pct(g('branch_dir_mispredict_count'), branch)} of branches)")
print(f"branch_tgt_mispredict        {g('branch_tgt_mispredict_count')}  ({pct(g('branch_tgt_mispredict_count'), branch)} of branches)")
print(f"branch_total_mispredict      {branch_miss}  ({pct(branch_miss, branch)} of branches)")
print(f"jal_mispredict               {g('jal_mispredict_count')}  ({pct(g('jal_mispredict_count'), g('jal_count'))} of JAL)")
print(f"jalr_pred_taken              {g('jalr_pred_taken_count')}  ({pct(g('jalr_pred_taken_count'), g('jalr_count'))} of JALR)")
print(f"jalr_mispredict              {g('jalr_mispredict_count')}  ({pct(g('jalr_mispredict_count'), g('jalr_count'))} of JALR)")
print(f"ras_pred                     {g('ras_pred_count')}")
print(f"ras_correct                  {g('ras_correct_count')}  ({pct(g('ras_correct_count'), g('ras_pop_count'))} of RAS returns)")
print(f"ras_push                     {g('ras_push_count')}")
print(f"ras_pop                      {g('ras_pop_count')}")
print(f"false_pred_nonctrl           {g('false_pred_nonctrl_count')}")
print(f"redirect_count               {redirect}  ({pct(redirect, issue)} per issued instr)")
print(f"flush_cycles_per_redirect    {ratio(ifid_flush, redirect)}")
print()
print("-- Load-use diagnostics --")
print(f"load_use_stall_per_load      {ratio(load_use, loads)}")
print(f"load_use_stall_per_issue     {ratio(load_use, issue)}")
print()
print("Raw PERF counters:")
for k in sorted(perf):
    print(f"  {k} {perf[k]}")
