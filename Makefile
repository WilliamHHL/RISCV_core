SRC_DIR = RISCV_core_pipeline
SRC = \
  $(SRC_DIR)/ID.v \
  $(SRC_DIR)/IF.v \
  $(SRC_DIR)/imem.v \
  $(SRC_DIR)/immgen.v \
  $(SRC_DIR)/PC_reg.v \
  $(SRC_DIR)/reg_file.v \
  $(SRC_DIR)/EX.v \
  $(SRC_DIR)/MEM.v \
  $(SRC_DIR)/WB.v \
  $(SRC_DIR)/top.v \
  $(SRC_DIR)/csr_read.v \
  $(SRC_DIR)/csr_wb_read.v \
  $(SRC_DIR)/IF_ID.v \
  $(SRC_DIR)/ID_EX.v \
  $(SRC_DIR)/EX_MEM.v \
  $(SRC_DIR)/MEM_WB.v \
  $(SRC_DIR)/hazard_unit.v \
  $(SRC_DIR)/forwarding_unit.v \
  $(SRC_DIR)/bht_2bit.v \
  $(SRC_DIR)/btb_direct.v \
  $(SRC_DIR)/ras_stack.v \
  $(SRC_DIR)/rv32_muldiv_unit.v

TB = $(SRC_DIR)/tb_top.v
TOP = tb_top
EXE = obj_dir/V$(TOP)
DPI_CPP = $(SRC_DIR)/dpi_uart.cc
VERILATOR_DEFS ?=

COREMARK_DIR = Coremark
PROGRAM_HEX = $(COREMARK_DIR)/program.hex
DATA_HEX = $(COREMARK_DIR)/data.hex

.PHONY: all run clean coremark coremark-rv32i coremark-rv32im-mul coremark-rv32im-mul-timing coremark-rv32im-full coremark-zmmul run-rv32i run-rv32im-mul run-rv32im-mul-timing run-rv32im-full-simdiv run-zmmul perf-rv32i perf-rv32im-mul perf-rv32im-mul-timing perf-rv32im-full-simdiv perf-zmmul sim

all: $(EXE)

coremark:
	$(MAKE) -C $(COREMARK_DIR)

# Baseline RV32I build.
coremark-rv32i:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32i_zicsr COREMARK_TAG=rv32i-baseline

# Multiplier-only benchmark build. The RTL in this package implements
# MUL/MULH/MULHSU/MULHU, but not DIV/REM yet. -mno-div asks GCC to use
# multiply instructions but keep division in software/libgcc.
coremark-rv32im-mul:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32im_zicsr EXTRA_CFLAGS=-mno-div COREMARK_TAG=rv32im-combmul-mno-div

# Same binary ISA constraints as coremark-rv32im-mul, but tagged separately
# for the timing-friendly registered-MUL RTL experiment.
coremark-rv32im-mul-timing:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32im_zicsr EXTRA_CFLAGS=-mno-div COREMARK_TAG=rv32im-timingmul-mno-div

# Full RV32IM benchmark build. This may emit DIV/DIVU/REM/REMU.
# Only run it with VERILATOR_DEFS=-DENABLE_SIM_COMB_DIV until a real divider
# replaces the simulation-only combinational divider in EX.v.
coremark-rv32im-full:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32im_zicsr COREMARK_TAG=rv32im-full-simdiv

# Alternative if your GCC supports the official Zmmul extension. This is the
# cleanest ISA string for multiplier-only hardware.
coremark-zmmul:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32i_zicsr_zmmul COREMARK_TAG=rv32i-zmmul-combmul

$(EXE): $(SRC) $(TB) $(DPI_CPP)
	verilator --cc --binary --exe --trace --MMD -Mdir obj_dir --build $(VERILATOR_DEFS) --top-module $(TOP) $(TB) $(SRC) $(DPI_CPP)

run: $(EXE) coremark
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE)

run-rv32i: $(EXE) coremark-rv32i
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE) | tee coremark_rv32i_baseline.log

run-rv32im-mul: $(EXE) coremark-rv32im-mul
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE) | tee coremark_rv32im_combmul.log

# Timing-friendly registered MUL build. This rebuilds Verilator with
# ENABLE_TIMING_MULDIV so MUL/MULH/MULHSU/MULHU use rv32_muldiv_unit
# instead of the one-cycle EX combinational multiplier. DIV/REM remain
# unsupported in this first timing-friendly commit, so CoreMark still uses
# -mno-div via coremark-rv32im-mul.
run-rv32im-mul-timing:
	$(MAKE) clean
	$(MAKE) VERILATOR_DEFS=-DENABLE_TIMING_MULDIV $(EXE)
	$(MAKE) coremark-rv32im-mul-timing
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE) | tee coremark_rv32im_timing_mul.log

run-rv32im-full-simdiv: $(EXE) coremark-rv32im-full
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE) | tee coremark_rv32im_full_simdiv.log

run-zmmul: $(EXE) coremark-zmmul
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE) | tee coremark_rv32i_zmmul_combmul.log

perf-rv32i:
	./run_perf_counters.sh rv32i

perf-rv32im-mul:
	./run_perf_counters.sh rv32im-mul

perf-rv32im-mul-timing:
	./run_perf_counters.sh rv32im-mul-timing

perf-rv32im-full-simdiv:
	./run_perf_counters.sh rv32im-full-simdiv

perf-zmmul:
	./run_perf_counters.sh zmmul

sim: $(EXE)
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE)

clean:
	rm -rf obj_dir program.hex data.hex *.log perf_*.summary.txt perf_*.raw.txt
	$(MAKE) -C $(COREMARK_DIR) clean
