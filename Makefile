VSRC_DIR = vsrc
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

TB = $(VSRC_DIR)/tb_top.v
TOP = tb_top
EXE = obj_dir/V$(TOP)
DPI_CPP = $(VSRC_DIR)/dpi_uart.cc

.PHONY: all run clean

all: $(EXE)

$(EXE): $(SRC) $(TB)  $(DPI_CPP)
	verilator --sv --cc --binary --exe --trace --MMD -Mdir obj_dir --build --top-module $(TOP) $(TB) $(SRC) $(DPI_CPP)

run: $(EXE)
	./$(EXE)

clean:
	rm -rf obj_dir