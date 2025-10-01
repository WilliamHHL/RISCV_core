`timescale 1ns / 1ps

module tb_top;

    reg clk = 0;
    reg rst = 1;
    wire [31:0] pc, instr, x1, x2, x3, x4;

    // Connect top module
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

    repeat (16) begin
        @(posedge clk);
        #1;
        $display("PC=%08x instr=%08x | rd=%0d wen=%0d wb=%08x | rs1=%0d rs2=%0d | x2=%08x x3=%08x x4=%08x",
        pc, instr,
        tb_top.uut.u_regfile.rd_addr,
        tb_top.uut.u_regfile.rd_wen,
        tb_top.uut.u_WB.wb_data,
        tb_top.uut.u_ID.rs1_addr,
        tb_top.uut.u_ID.rs2_addr,
        tb_top.uut.u_regfile.regs[2],
        tb_top.uut.u_regfile.regs[3],
        tb_top.uut.u_regfile.regs[4]
        );
        end

    for (i = 0; i < 32; i = i + 1) begin
        $display("x%0d = %08x", i, tb_top.uut.u_regfile.regs[i]);
    end

    #20 $finish;
end

endmodule