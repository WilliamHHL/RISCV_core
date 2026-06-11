# OpenLane synthesis-only run: golden comb-MUL mode
prep -design /home/william/RISCV_core_push/OpenLane\ Flow -tag combmul_100mhz -overwrite
run_synthesis
run_sta
