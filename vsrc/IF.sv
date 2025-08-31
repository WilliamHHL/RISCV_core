module IF (
    input  logic        clk,
    input  logic [31:0] pc,
    output logic [31:0] instr
);
    imem u_imem (
        .clk(clk),
        .addr(pc),
        .data(instr)
    );
endmodule
