module ID_EX (
    input         clk,
    input         rst,
    input         idex_flush,

    // From ID stage
    input  [31:0] id_pc,
    input  [31:0] id_rs1_val,
    input  [31:0] id_rs2_val,
    input  [31:0] id_imm,
    input  [4:0]  id_rs1_addr,
    input  [4:0]  id_rs2_addr,
    input  [4:0]  id_rd_addr,

    input         id_reg_write,
    input         id_mem_read,
    input         id_mem_write,
    input         id_branch,
    input         id_jal,
    input         id_jalr,
    input  [2:0]  id_branch_op,
    input  [3:0]  id_alu_op,
    input         id_alu_rs2_is_imm,
    input  [1:0]  id_wb_sel,
    input         id_use_pc_add,
    input         id_load_signed,
    input  [1:0]  id_load_size,
    input  [1:0]  id_store_size,

    input         id_csr_hit,
    input  [31:0] id_csr_data,
    input       id_ecall, id_ebreak, id_fence,

    // To EX stage
    output reg [31:0] ex_pc,
    output reg [31:0] ex_rs1_val,
    output reg [31:0] ex_rs2_val,
    output reg [31:0] ex_imm,
    output reg [4:0]  ex_rs1_addr,
    output reg [4:0]  ex_rs2_addr,
    output reg [4:0]  ex_rd_addr,

    output reg        ex_reg_write,
    output reg        ex_mem_read,
    output reg        ex_mem_write,
    output reg        ex_branch,
    output reg        ex_jal,
    output reg        ex_jalr,
    output reg [2:0]  ex_branch_op,
    output reg [3:0]  ex_alu_op,
    output reg        ex_alu_rs2_is_imm,
    output reg [1:0]  ex_wb_sel,
    output reg        ex_use_pc_add,
    output reg        ex_load_signed,
    output reg [1:0]  ex_load_size,
    output reg [1:0]  ex_store_size,

    output reg        ex_csr_hit,
    output reg [31:0] ex_csr_data,
    output reg       ex_ecall, ex_ebreak, ex_fence
);
    always @(posedge clk or posedge rst) begin
        if (rst || idex_flush) begin
            ex_pc              <= 32'b0;
            ex_rs1_val         <= 32'b0;
            ex_rs2_val         <= 32'b0;
            ex_imm             <= 32'b0;
            ex_rs1_addr        <= 5'd0;
            ex_rs2_addr        <= 5'd0;
            ex_rd_addr         <= 5'd0;
            ex_reg_write       <= 1'b0;
            ex_mem_read        <= 1'b0;
            ex_mem_write       <= 1'b0;
            ex_branch          <= 1'b0;
            ex_jal             <= 1'b0;
            ex_jalr            <= 1'b0;
            ex_branch_op       <= 3'b000;
            ex_alu_op          <= 4'd0;
            ex_alu_rs2_is_imm  <= 1'b0;
            ex_wb_sel          <= 2'd0;
            ex_use_pc_add      <= 1'b0;
            ex_load_signed     <= 1'b1;
            ex_load_size       <= 2'b10;
            ex_store_size      <= 2'b10;
            ex_csr_hit         <= 1'b0;
            ex_csr_data        <= 32'b0;
            ex_ebreak          <= 1'b0;
            ex_ecall          <= 1'b0;
            ex_fence          <= 1'b0;
            
            
        end else begin
            ex_pc              <= id_pc;
            ex_rs1_val         <= id_rs1_val;
            ex_rs2_val         <= id_rs2_val;
            ex_imm             <= id_imm;
            ex_rs1_addr        <= id_rs1_addr;
            ex_rs2_addr        <= id_rs2_addr;
            ex_rd_addr         <= id_rd_addr;
            ex_reg_write       <= id_reg_write;
            ex_mem_read        <= id_mem_read;
            ex_mem_write       <= id_mem_write;
            ex_branch          <= id_branch;
            ex_jal             <= id_jal;
            ex_jalr            <= id_jalr;
            ex_branch_op       <= id_branch_op;
            ex_alu_op          <= id_alu_op;
            ex_alu_rs2_is_imm  <= id_alu_rs2_is_imm;
            ex_wb_sel          <= id_wb_sel;
            ex_use_pc_add      <= id_use_pc_add;
            ex_load_signed     <= id_load_signed;
            ex_load_size       <= id_load_size;
            ex_store_size      <= id_store_size;
            ex_csr_hit         <= id_csr_hit;
            ex_csr_data        <= id_csr_data;
            ex_ebreak          <= id_ebreak;
            ex_ecall          <= id_ecall;
            ex_fence          <= id_fence;
        end
    end
endmodule