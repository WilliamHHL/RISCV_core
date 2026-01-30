module IF (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc,
    input  wire        if_stall,
    output wire [31:0] instr
);
    imem u_imem (
        .clk        (clk),
        .rst        (rst),
        .addr       (pc),
        .imem_stall (if_stall),
        .data       (instr)
    );
endmodule
