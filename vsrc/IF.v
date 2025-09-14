module IF (
    input clk,
    input [31:0] pc,
    output  [31:0] instr
);
    imem u_imem (
        .clk(clk),
        .addr(pc),
        .data(instr)
    );
endmodule
