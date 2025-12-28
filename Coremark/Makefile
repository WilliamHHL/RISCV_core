CROSS      ?= riscv64-unknown-elf
CC         := $(CROSS)-gcc
OBJCOPY    := $(CROSS)-objcopy
OBJDUMP    := $(CROSS)-objdump

# 紧凑与节回收
CFLAGS  := -Os -ffreestanding -fno-builtin -nostdlib -nostartfiles \
           -march=rv32i_zicsr -mabi=ilp32 -Wall -Wextra \
           -fno-tree-loop-distribute-patterns -fno-tree-vectorize -fno-tree-slp-vectorize \
           -ffunction-sections -fdata-sections

LDFLAGS := -Wl,-T,linker.ld -Wl,--gc-sections

INCLUDES := -I.. -I.

SRCS := \
  memcpy.c \
  memset.c \
  ../core_list_join.c \
  core_main.c \
  ../core_matrix.c \
  ../core_state.c \
  ../core_util.c \
  start.S \
  core_portme.c

# 产物
IMEM_ONLY_ELF := coremark_imem.elf
DMEM_ONLY_ELF := coremark_dmem.elf
PROGRAM_HEX   := program.hex     # 给 imem.v 读
DATA_HEX      := data.hex        # 给 MEM.v 的 dmem 读（零基址）

all: $(PROGRAM_HEX) $(DATA_HEX)

coremark.elf: $(SRCS) linker.ld core_portme.h
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $(SRCS) -lgcc -o $@

# 仅 IMEM 节
$(IMEM_ONLY_ELF): coremark.elf
	$(OBJCOPY) --only-section .init --only-section .text $< $@

# 仅 DMEM 节
$(DMEM_ONLY_ELF): coremark.elf
	$(OBJCOPY) --only-section .rodata --only-section .data $< $@

# 导出 IMEM hex（已是从 0 开始）
$(PROGRAM_HEX): $(IMEM_ONLY_ELF)
	$(OBJCOPY) -O verilog $< $@

# 导出 DMEM hex（先导出 verilog，再把 @10000000 改成 @00000000）
# 注：下面的 sed 命令把所有 @1xxxxxxxx（即 @10000000 起）重写为 @00000000。
# 如果你的 DMEM_BASE 不是 0x10000000，请把 10000000 和 00000000 替换成对应的基址与 0。
$(DATA_HEX): $(DMEM_ONLY_ELF)
	$(OBJCOPY) -O verilog $< $@.tmp && \
	sed -E 's/@10000000/@00000000/g' $@.tmp > $@ && \
	rm -f $@.tmp

size:
	$(OBJDUMP) -h coremark.elf

clean:
	rm -f coremark.elf $(IMEM_ONLY_ELF) $(DMEM_ONLY_ELF) $(PROGRAM_HEX) $(DATA_HEX)

.PHONY: all clean size
