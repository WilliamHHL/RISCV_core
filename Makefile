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
  $(SRC_DIR)/ras_stack.v

TB = $(SRC_DIR)/tb_top.v
TOP = tb_top
EXE = obj_dir/V$(TOP)
DPI_CPP = $(SRC_DIR)/dpi_uart.cc

COREMARK_DIR = Coremark
PROGRAM_HEX = $(COREMARK_DIR)/program.hex
DATA_HEX = $(COREMARK_DIR)/data.hex

.PHONY: all run clean coremark coremark-rv32i coremark-rv32im-mul coremark-rv32im-full coremark-zmmul run-rv32i run-rv32im-mul run-rv32im-full-simdiv run-zmmul perf-rv32i perf-rv32im-mul perf-rv32im-full-simdiv perf-zmmul sim

all: $(EXE)

coremark:
	$(MAKE) -C $(COREMARK_DIR)

coremark-rv32i:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32i_zicsr COREMARK_TAG=rv32i-baseline

coremark-rv32im-mul:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32im_zicsr EXTRA_CFLAGS=-mno-div COREMARK_TAG=rv32im-combmul-mno-div

coremark-rv32im-full:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32im_zicsr COREMARK_TAG=rv32im-full-simdiv

coremark-zmmul:
	$(MAKE) -C $(COREMARK_DIR) clean
	$(MAKE) -C $(COREMARK_DIR) RV_ARCH=rv32i_zicsr_zmmul COREMARK_TAG=rv32i-zmmul-combmul

$(EXE): $(SRC) $(TB) $(DPI_CPP)
	verilator --cc --binary --exe --trace --MMD -Mdir obj_dir --build --top-module $(TOP) $(TB) $(SRC) $(DPI_CPP)

run: $(EXE) coremark
	cp $(PROGRAM_HEX) ./
	cp $(DATA_HEX) ./
	./$(EXE)

sim: $(EXE)
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

perf-rv32im-full-simdiv:
	./run_perf_counters.sh rv32im-full-simdiv

perf-zmmul:
	./run_perf_counters.sh zmmul

clean:
	rm -rf obj_dir program.hex data.hex *.log perf_*.summary.txt perf_*.raw.txt
	$(MAKE) -C $(COREMARK_DIR) clean
