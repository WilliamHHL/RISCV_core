module IF (
    input         clk,
    input         rst,
    input  [31:0] pc,
    input         if_stall,
    output [31:0] instr,
    output reg [31:0] if_pc,
    input if_flush
);

    wire [31:0] imem_data;

    imem u_imem (
        .clk        (clk),
        .addr       (pc),
        .data       (imem_data),
        .imem_stall (if_stall),
        .rst        (rst)
    );

    assign instr = (if_flush) ? 32'h00000013 : imem_data;  // NOP on flush

    reg [31:0] pc_q;
    
    // 修复：stall 时保持 pc_q 不变！
    always @(posedge clk) begin
        if (rst) begin
            pc_q <= 32'b0;
        end else if (!if_stall) begin  // ← 关键修复！
            pc_q <= pc;
        end
        // else: stall 时保持 pc_q
    end

    assign if_pc = (if_flush) ? 32'b0 : pc_q;

endmodule