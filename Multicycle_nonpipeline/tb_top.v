`timescale 1ns / 1ps

module tb_top;

    reg clk = 0;
    reg rst = 1;
    wire [31:0] pc, instr;//,x1, x2, x3, x4;
    wire ebreak_pulse;

    top uut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instr(instr),
        /*.x1(x1),
        .x2(x2),
        .x3(x3),
        .x4(x4),*/
        .ebreak_pulse(ebreak_pulse)
    );

    always #12.5 clk = ~clk;

    initial begin
    integer i;
    reg [63:0] cycles; 

        // config VCD fire
        /*$dumpfile("wave.vcd");
        $dumpvars(0, tb_top);*/

        rst = 1;
        repeat (4) @(posedge clk);
        rst = 0;

        // only record the first N cycles
        /*$dumpon;
        repeat (20) @(posedge clk); // adjust N base on file size
        $dumpoff;*/

        // print the first 50 cycles info 
        /*for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            #1;
            $display("PC=%08x instr=%08x | rd=%0d wen=%0d wb=%08x | rs1=%0d rs2=%0d | mem_w=%0d st_size=%0d addr=%08x imm=%08x | x2=%08x x3=%08x x4=%08x",
                pc, instr,
                tb_top.uut.u_regfile.rd_addr,
                tb_top.uut.u_regfile.rd_wen,
                tb_top.uut.u_WB.wb_data,
                tb_top.uut.u_ID.rs1_addr,
                tb_top.uut.u_ID.rs2_addr,
                tb_top.uut.u_ID.mem_write,
                tb_top.uut.u_ID.store_size,
                tb_top.uut.u_EX.alu_core_result,
                tb_top.uut.u_immgen.imm,
                tb_top.uut.u_regfile.regs[2],
                tb_top.uut.u_regfile.regs[3],
                tb_top.uut.u_regfile.regs[4]
            );
        end*/

        // main loop until break stop
        cycles = 0;
        while (!ebreak_pulse && cycles < 64'd5000_000_000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (ebreak_pulse)
            $display("EBREAK at PC=%08x after %0d cycles", pc, cycles);
        else
            $display("Timeout after %0d cycles", cycles);

        for (i = 0; i < 32; i = i + 1)
            $display("x%0d = %08x", i, tb_top.uut.u_regfile.regs[i]);

        #20 $finish;
    end


endmodule