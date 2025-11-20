module EX_MEM (
    input         clk,
    input         rst,

    // From EX stage
    input  [31:0] ex_pc,
    input  [31:0] ex_alu_result,
    input  [31:0] ex_rs2_val_for_store,
    input  [4:0]  ex_rd_addr,
    input         ex_reg_write,
    input         ex_mem_read,
    input         ex_mem_write,
    input  [1:0]  ex_wb_sel,
    input  [1:0]  ex_load_size,
    input  [1:0]  ex_store_size,
    input         ex_load_signed,
    input  [31:0] ex_wb_candidate,
    input         ex_csr_hit,
    input  [31:0] ex_csr_data,

    // To MEM stage
    output reg [31:0] mem_pc,
    output reg [31:0] mem_alu_result,
    output reg [31:0] mem_rs2_val_for_store,
    output reg [4:0]  mem_rd_addr,
    output reg        mem_reg_write,
    output reg        mem_mem_read,
    output reg        mem_mem_write,
    output reg [1:0]  mem_wb_sel,
    output reg [1:0]  mem_load_size,
    output reg [1:0]  mem_store_size,
    output reg        mem_load_signed,
    output reg [31:0] mem_wb_candidate,
    output reg        mem_csr_hit,
    output reg [31:0] mem_csr_data
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_pc               <= 32'b0;
            mem_alu_result       <= 32'b0;
            mem_rs2_val_for_store<= 32'b0;
            mem_rd_addr          <= 5'd0;
            mem_reg_write        <= 1'b0;
            mem_mem_read         <= 1'b0;
            mem_mem_write        <= 1'b0;
            mem_wb_sel           <= 2'd0;
            mem_load_size        <= 2'b10;
            mem_store_size       <= 2'b10;
            mem_load_signed      <= 1'b1;
            mem_wb_candidate     <= 32'b0;
            mem_csr_hit          <= 1'b0;
            mem_csr_data         <= 32'b0;
        end else begin
            mem_pc               <= ex_pc;
            mem_alu_result       <= ex_alu_result;
            mem_rs2_val_for_store<= ex_rs2_val_for_store;
            mem_rd_addr          <= ex_rd_addr;
            mem_reg_write        <= ex_reg_write;
            mem_mem_read         <= ex_mem_read;
            mem_mem_write        <= ex_mem_write;
            mem_wb_sel           <= ex_wb_sel;
            mem_load_size        <= ex_load_size;
            mem_store_size       <= ex_store_size;
            mem_load_signed      <= ex_load_signed;
            mem_wb_candidate     <= ex_wb_candidate;
            mem_csr_hit          <= ex_csr_hit;
            mem_csr_data         <= ex_csr_data;
        end
    end
endmodule