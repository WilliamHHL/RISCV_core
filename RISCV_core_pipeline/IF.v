module IF (
    input clk,
    input [31:0] pc,
    output  [31:0] instr,
    output  reg [31:0] if_pc
);
    wire [31:0] addr_q_raw;
    imem u_imem (   // Note: For FPGA BRAM inference, a synchronous read (registered output) may be required.
        .clk(clk),
        .addr(pc),
        .data(instr),
        .addr_q(addr_q_raw)
    );

     always @(posedge clk) begin
        if_pc <= addr_q_raw;
    end
endmodule