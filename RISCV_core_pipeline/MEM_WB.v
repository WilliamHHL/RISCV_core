module MEM_WB (
    input         clk,
    input         rst,
    input [31:0]mem_pc,
    // From MEM stage
    input  [31:0] mem_wb_candidate,
    input  [31:0] mem_load_data,
    input  [4:0]  mem_rd_addr,
    input         mem_reg_write,
    input  [1:0]  mem_wb_sel,
    input         mem_csr_hit,
    input  [31:0] mem_csr_data,
    input mem_ebreak,mem_ecall,mem_fence,
    // To WB stage
    output reg [31:0] wb_wb_candidate,
    output reg [31:0] wb_load_data,
    output reg [4:0]  wb_rd_addr,
    output reg        wb_reg_write,
    output reg [1:0]  wb_wb_sel,
    output reg        wb_csr_hit,
    output reg [31:0] wb_csr_data,
    output reg wb_ebreak,wb_ecall,wb_fence,

    output reg ebreak_q,ecall_q,fence_q
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_wb_candidate <= 32'b0;
            wb_load_data    <= 32'b0;
            wb_rd_addr      <= 5'd0;
            wb_reg_write    <= 1'b0;
            wb_wb_sel       <= 2'd0;
            wb_csr_hit      <= 1'b0;
            wb_csr_data     <= 32'b0;
            wb_ebreak          <= 1'b0;
            wb_ecall          <= 1'b0;
            wb_fence          <= 1'b0;

        end else begin
            wb_wb_candidate <= mem_wb_candidate;
            wb_load_data    <= mem_load_data;
            wb_rd_addr      <= mem_rd_addr;
            wb_reg_write    <= mem_reg_write;
            wb_wb_sel       <= mem_wb_sel;
            wb_csr_hit      <= mem_csr_hit;
            wb_csr_data     <= mem_csr_data;
            wb_ebreak          <= mem_ebreak;
            wb_ecall          <= mem_ecall;
            wb_fence          <= mem_fence;

            ebreak_q          <= wb_ebreak;
            ecall_q          <= wb_ecall;
            fence_q          <= wb_fence;
        end
    end
    always @(posedge clk) begin
    if (!rst && wb_reg_write && wb_rd_addr == 5'd7) begin
        $display("WB x7: pc=%08x data=%08x wb_sel=%0d",
                 mem_pc, wb_wb_candidate, wb_wb_sel);
    end
    end
endmodule
/*module MEM_WB (
    input         clk,
    input         rst,
    input [31:0]mem_pc,
    // From MEM stage
    input  [31:0] mem_wb_candidate,
    input  [31:0] mem_load_data,
    input  [4:0]  mem_rd_addr,
    input         mem_reg_write,
    input  [1:0]  mem_wb_sel,
    input         mem_csr_hit,
    input  [31:0] mem_csr_data,
    input mem_ebreak,mem_ecall,mem_fence,
    // To WB stage
    output reg [31:0] wb_wb_candidate,
    output reg [31:0] wb_load_data,
    output reg [4:0]  wb_rd_addr,
    output reg        wb_reg_write,
    output reg [1:0]  wb_wb_sel,
    output reg        wb_csr_hit,
    output reg [31:0] wb_csr_data,
    output reg wb_ebreak,wb_ecall,wb_fence,

    output reg ebreak_q,ecall_q,fence_q
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_wb_candidate <= 32'b0;
            wb_load_data    <= 32'b0;
            wb_rd_addr      <= 5'd0;
            wb_reg_write    <= 1'b0;
            wb_wb_sel       <= 2'd0;
            wb_csr_hit      <= 1'b0;
            wb_csr_data     <= 32'b0;
            wb_ebreak          <= 1'b0;
            wb_ecall          <= 1'b0;
            wb_fence          <= 1'b0;

        end else begin
            wb_wb_candidate <= mem_wb_candidate;
            wb_load_data    <= mem_load_data;
            wb_rd_addr      <= mem_rd_addr;
            wb_reg_write    <= mem_reg_write;
            wb_wb_sel       <= mem_wb_sel;
            wb_csr_hit      <= mem_csr_hit;
            wb_csr_data     <= mem_csr_data;
            wb_ebreak          <= mem_ebreak;
            wb_ecall          <= mem_ecall;
            wb_fence          <= mem_fence;

            ebreak_q          <= wb_ebreak;
            ecall_q          <= wb_ecall;
            fence_q          <= wb_fence;
        end
    end
    always @(posedge clk) begin
    if (!rst && wb_reg_write && wb_rd_addr == 5'd7) begin
        $display("WB x7: pc=%08x data=%08x wb_sel=%0d",
                 mem_pc, wb_wb_candidate, wb_wb_sel);
    end
    end
endmodule*/