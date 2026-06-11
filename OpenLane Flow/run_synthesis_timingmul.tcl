# OpenLane synthesis-only run: timing-friendly registered-MUL mode
prep -design /home/william/RISCV_core_push/OpenLane\ Flow -tag timingmul_100mhz -overwrite -config_file config_timingmul.tcl
run_synthesis
run_sta
