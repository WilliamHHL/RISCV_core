module MEM_WB (
    input         clk,
    input         rst,
    input  [31:0] mem_pc,   // currently unused, kept to avoid interface changes

    // From MEM stage
    input  [31:0] mem_wb_candidate,
    input  [31:0] mem_load_data,
    input  [4:0]  mem_rd_addr,
    input         mem_reg_write,
    input  [1:0]  mem_wb_sel,
    input         mem_csr_hit,
    input  [11:0] mem_csr_addr,
    input         mem_ebreak,
    input         mem_ecall,
    input         mem_fence,

    // To WB stage
    output reg [31:0] wb_wb_candidate,
    output reg [31:0] wb_load_data,
    output reg [4:0]  wb_rd_addr,
    output reg        wb_reg_write,
    output reg [1:0]  wb_wb_sel,
    output reg        wb_csr_hit,
    output reg [11:0] wb_csr_addr,
    output reg        wb_ebreak,
    output reg        wb_ecall,
    output reg        wb_fence,

    output reg        ebreak_q,
    output reg        ecall_q,
    output reg        fence_q
);

    // ------------------------------------------------------------
    // Control flops: keep reset
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            wb_rd_addr      <= 5'd0;
            wb_reg_write    <= 1'b0;
            wb_wb_sel       <= 2'd0;
            wb_csr_hit      <= 1'b0;
            wb_csr_addr     <= 12'b0;
            wb_ebreak       <= 1'b0;
            wb_ecall        <= 1'b0;
            wb_fence        <= 1'b0;

            ebreak_q        <= 1'b0;
            ecall_q         <= 1'b0;
            fence_q         <= 1'b0;
        end else begin
            wb_rd_addr      <= mem_rd_addr;
            wb_reg_write    <= mem_reg_write;
            wb_wb_sel       <= mem_wb_sel;
            wb_csr_hit      <= mem_csr_hit;
            wb_csr_addr     <= mem_csr_addr;
            wb_ebreak       <= mem_ebreak;
            wb_ecall        <= mem_ecall;
            wb_fence        <= mem_fence;

            // preserve your original 1-cycle delayed pulse behavior
            ebreak_q        <= wb_ebreak;
            ecall_q         <= wb_ecall;
            fence_q         <= wb_fence;
        end
    end

    // ------------------------------------------------------------
    // Wide data flops: NO reset, NO enable
    // ------------------------------------------------------------
    always @(posedge clk) begin
        wb_wb_candidate <= mem_wb_candidate;
        wb_load_data    <= mem_load_data;
    end

endmodule

