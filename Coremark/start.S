/* Minimal RV32I crt0: set stack, copy .data (LMA in IMEM) to DMEM, clear .bss, call main */
.section .init
.global _start
_start:
  /* Set stack to top of DMEM */
  la   sp, __stack

  /* Copy .data from LMA (_sidata in IMEM) to VMA (_sdata in DMEM) */
  la   a0, _sdata
  la   a1, _edata
  la   a2, _sidata
1:
  beq  a0, a1, 2f
  lw   t0, 0(a2)
  sw   t0, 0(a0)
  addi a0, a0, 4
  addi a2, a2, 4
  j    1b
2:
  /* Zero .bss */
  la   a0, _sbss
  la   a1, _ebss
3:
  beq  a0, a1, 4f
  sw   x0, 0(a0)
  addi a0, a0, 4
  j    3b

4:
  /* Call main(int argc=0, char** argv=NULL) */
  li   a0, 0
  li   a1, 0
  call main

  /* If main returns, trigger EBREAK to end sim */
  ebreak
  j .
