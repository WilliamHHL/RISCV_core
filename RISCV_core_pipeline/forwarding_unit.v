module forwarding_unit(
    input  wire [4:0] ex_rs1_addr,
    input  wire [4:0] ex_rs2_addr,

    // EX/MEM (one stage ahead of EX)
    input  wire       exmem_reg_write,
    input  wire [4:0] exmem_rd,

    // MEM/WB (two stages ahead of EX)
    input  wire       memwb_reg_write,
    input  wire [4:0] memwb_rd,

    output reg  [1:0] forward_a,   // for rs1
    output reg  [1:0] forward_b    // for rs2
);
    // Default: no forwarding
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Forward A (rs1)
        if (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == ex_rs1_addr)) begin
            forward_a = 2'b10;  // from EX/MEM
        end else if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == ex_rs1_addr)) begin
            forward_a = 2'b01;  // from MEM/WB
        end

        // Forward B (rs2)
        if (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == ex_rs2_addr)) begin
            forward_b = 2'b10;  // from EX/MEM
        end else if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == ex_rs2_addr)) begin
            forward_b = 2'b01;  // from MEM/WB
        end
    end

endmodule