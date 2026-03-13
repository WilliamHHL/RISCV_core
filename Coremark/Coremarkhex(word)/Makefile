CROSS      ?= riscv64-unknown-elf
CC         := $(CROSS)-gcc
OBJCOPY    := $(CROSS)-objcopy
OBJDUMP    := $(CROSS)-objdump

CFLAGS  := -O3 -ffreestanding -fno-builtin -nostdlib -nostartfiles \
           -march=rv32i_zicsr -mabi=ilp32 -Wall -Wextra \
           -fno-tree-loop-distribute-patterns -fno-tree-vectorize -fno-tree-slp-vectorize \
           -ffunction-sections -fdata-sections \
           -mno-relax

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

MAIN_ELF      := coremark.elf
IMEM_ONLY_ELF := coremark_imem.elf
DMEM_ONLY_ELF := coremark_dmem.elf

IMEM_BIN := imem.bin
DMEM_BIN := dmem.bin

PROGRAM_HEX   := program.hex
DATA_HEX      := data.hex

DMEM_BASE_HEX := 10000000

all: $(PROGRAM_HEX) $(DATA_HEX)

$(MAIN_ELF): $(SRCS) linker.ld core_portme.h
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $(SRCS) -lgcc -o $@

$(IMEM_ONLY_ELF): $(MAIN_ELF)
	$(OBJCOPY) --only-section .init --only-section .text $< $@

$(DMEM_ONLY_ELF): $(MAIN_ELF)
	$(OBJCOPY) --only-section .rodata --only-section .data $< $@

$(IMEM_BIN): $(IMEM_ONLY_ELF)
	$(OBJCOPY) -O binary $< $@

$(DMEM_BIN): $(DMEM_ONLY_ELF)
	$(OBJCOPY) -O binary \
	  --change-section-vma .rodata-0x$(DMEM_BASE_HEX) \
	  --change-section-vma .data-0x$(DMEM_BASE_HEX) \
	  $< $@

# Word-wide hex: one 32-bit word per line (little-endian byte swap)
$(PROGRAM_HEX): $(IMEM_BIN)
	xxd -p -c 4 $(IMEM_BIN) | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $(PROGRAM_HEX)

$(DATA_HEX): $(DMEM_BIN)
	xxd -p -c 4 $(DMEM_BIN) | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $(DATA_HEX)

dump:
	$(OBJDUMP) -d -S $(MAIN_ELF) > $(MAIN_ELF:.elf=.dump)

size:
	$(OBJDUMP) -h $(MAIN_ELF)

clean:
	rm -f $(MAIN_ELF) $(IMEM_ONLY_ELF) $(DMEM_ONLY_ELF) \
	      $(IMEM_BIN) $(DMEM_BIN) \
	      $(PROGRAM_HEX) $(DATA_HEX) *.dump

.PHONY: all clean size dump
