module forwarding_unit (
    input  [4:0] ex_rs1_addr,
    input  [4:0] ex_rs2_addr,

    // EX/MEM stage
    input        exmem_can_forward,
    input  [4:0] exmem_rd,

    // MEM2 stage
    input        mem2_can_forward,
    input  [4:0] mem2_rd,

    // MEM/WB stage
    input        memwb_can_forward,
    input  [4:0] memwb_rd,

    output [1:0] forward_a,
    output [1:0] forward_b
);

    wire rs1_nz = |ex_rs1_addr;
    wire rs2_nz = |ex_rs2_addr;

    wire exmem_hit_a = rs1_nz & exmem_can_forward & (exmem_rd == ex_rs1_addr);
    wire mem2_hit_a  = rs1_nz & mem2_can_forward  & (mem2_rd  == ex_rs1_addr);
    wire memwb_hit_a = rs1_nz & memwb_can_forward & (memwb_rd == ex_rs1_addr);

    wire exmem_hit_b = rs2_nz & exmem_can_forward & (exmem_rd == ex_rs2_addr);
    wire mem2_hit_b  = rs2_nz & mem2_can_forward  & (mem2_rd  == ex_rs2_addr);
    wire memwb_hit_b = rs2_nz & memwb_can_forward & (memwb_rd == ex_rs2_addr);

    assign forward_a =
        exmem_hit_a ? 2'b10 :
        mem2_hit_a  ? 2'b11 :
        memwb_hit_a ? 2'b01 :
                      2'b00;

    assign forward_b =
        exmem_hit_b ? 2'b10 :
        mem2_hit_b  ? 2'b11 :
        memwb_hit_b ? 2'b01 :
                      2'b00;

endmodule
