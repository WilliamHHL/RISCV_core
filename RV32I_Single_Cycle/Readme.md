## Single Cycle Version RV32I
Support 40 Instructions:  
LUI, AUIPC  
Jumps: JAL, JALR  
Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU  
Loads: LB, LH, LW, LBU, LHU   
Stores: SB, SH, SW  
ALU-immediates: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI  
ALU-register: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND  

For Ebreak and Ecall now are just for simulation purpose.  
For Fence,just treat as nop.

**Coremark result: 1.15 Coremark/Mhz(on Verilator)  
Pass OpenLane Flow,achieve 100Mhz, Die area 0.0051667968 mm2, Power: 3.51e-04 Watts  
using Sky130 PDk**
