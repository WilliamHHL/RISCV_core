`timescale 1ns / 1ps

module tb_top;

    reg clk = 0;
    reg rst = 1;
    wire [31:0] pc, instr, x1, x2, x3, x4;

    // Connect your top module
    top uut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instr(instr),
        .x1(x1),
        .x2(x2),
        .x3(x3),
        .x4(x4)
    );

    // Clock generator: 10ns period
    always #5 clk = ~clk;

    initial begin
    integer i;
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_top.uut.u_regfile.regs);
    $dumpvars(0, tb_top);

    rst = 1;
    #20;
    rst = 0;

    repeat (10) begin
        @(negedge clk);
        $display("PC=%08x | instr=%08x | x1=%08x x2=%08x x3=%08x x4=%08x", pc, instr, x1, x2, x3, x4);
    end

    for (i = 0; i < 32; i = i + 1) begin
        $display("x%0d = %08x", i, tb_top.uut.u_regfile.regs[i]);
    end

    #20 $finish;
end

endmodule