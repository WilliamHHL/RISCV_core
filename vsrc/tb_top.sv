`timescale 1ns / 1ps

module tb_top;

    logic clk = 0;
    logic rst = 1;
    logic [31:0] pc, instr, x1, x2, x3, x4;

    // Connect your top module (make sure top.sv has these outputs!)
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
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        // Reset sequence
        rst = 1;
        #20;
        rst = 0;

        // Run for 30 cycles, printing register values
        repeat (10) begin
            @(negedge clk);
            $display("PC=%08x | instr=%08x | x1=%08x x2=%08x x3=%08x x4=%08x", pc, instr, x1, x2, x3, x4);
        end

        #20 $finish;
    end

endmodule