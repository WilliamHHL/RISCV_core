/* IMEM/DMEM map for your Verilog core */
MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
  DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 128K
}

ENTRY(_start)

SECTIONS
{
  /* Code in IMEM */
  .text : {
    KEEP(*(.init))
    *(.text .text.*)
    . = ALIGN(4);
    _sidata = .;               /* LMA source address for .data copy (end of .text) */
  } > IMEM

  /* Place rodata in DMEM so data-side loads never target IMEM */
  .rodata : {
    . = ALIGN(4);
    *(.rodata .rodata.*)
  } > DMEM

  /* .data lives in DMEM; initialized bytes are loaded from IMEM at _sidata */
  .data : AT ( _sidata ) {
    . = ALIGN(4);
    _sdata = .;
    *(.data .data.*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM

  /* .bss in DMEM */
  .bss (NOLOAD) : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss .bss.* COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM

  /* Stack at top of DMEM */
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
  PROVIDE(__stack = _stack_top);
}
