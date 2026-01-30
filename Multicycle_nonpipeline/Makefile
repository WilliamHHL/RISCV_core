# 顶层工程目录
VSRC_DIR = /home/william/RISCV_core_Dec_2026/RV32I_Single_Cycle

# RTL 源码列表（根据你的单周期工程实际文件名修改）
SRC = \
  $(VSRC_DIR)/ID.v \
  $(VSRC_DIR)/IF.v \
  $(VSRC_DIR)/imem.v \
  $(VSRC_DIR)/immgen.v \
  $(VSRC_DIR)/PC_reg.v \
  $(VSRC_DIR)/reg_file.v \
  $(VSRC_DIR)/EX.v \
  $(VSRC_DIR)/MEM.v \
  $(VSRC_DIR)/WB.v \
  $(VSRC_DIR)/top.v \
  $(VSRC_DIR)/csr_read.v

# 如果单周期版本有其他模块（比如 hazard_unit 不需要就删掉）
# 你可以继续往 SRC 里按需添加：
#  $(VSRC_DIR)/xxx.v \

# Testbench 和 DPI（如果单周期工程也复用同一个 tb_top 与 dpi_uart）
TB      = $(VSRC_DIR)/tb_top.v
TOP     = tb_top
DPI_CPP = $(VSRC_DIR)/dpi_uart.cc

EXE = obj_dir/V$(TOP)

.PHONY: all run clean

all: $(EXE)

$(EXE): $(SRC) $(TB) $(DPI_CPP)
	verilator --sv --cc --binary --exe --trace --MMD -Mdir obj_dir --build \
	  --top-module $(TOP) \
	  $(TB) $(SRC) $(DPI_CPP)

run: $(EXE)
	./$(EXE)

clean:
	rm -rf obj_dir
