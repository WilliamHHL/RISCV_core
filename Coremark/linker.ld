/* Split IMEM/DMEM map for Verilog RTL: IMEM reads program.hex, DMEM reads data.hex */
MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
  DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 128K
}

ENTRY(_start)

SECTIONS
{
  .text : {
    KEEP(*(.init))
    *(.text .text.*)
    . = ALIGN(4);
    _sidata = .;
  } > IMEM

  .rodata : {
    . = ALIGN(4);
    *(.rodata .rodata.*)
  } > DMEM

  .data : AT ( _sidata ) {
    . = ALIGN(4);
    _sdata = .;
    *(.data .data.*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM

  .bss (NOLOAD) : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss .bss.* COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM

  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
  PROVIDE(__stack = _stack_top);
}
