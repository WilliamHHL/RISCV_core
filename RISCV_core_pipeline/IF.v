module IF (
    input clk,
    input [31:0] pc,
    output  [31:0] instr
);
    imem u_imem (   // Note: For FPGA BRAM inference, a synchronous read (registered output) may be required.
        .clk(clk),
        .addr(pc),
        .data(instr)
    );
endmodule
