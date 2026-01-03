`timescale 1ns / 1ps

module tb_top;

    reg clk = 0;
    reg rst = 0;

    // DUT observation ports
    wire [31:0] pc, instr;   // IF stage observation ports from top.v
    wire        ebreak_pulse;
    wire        ecall_pulse;

    // DUT
    top uut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instr(instr),
        .ebreak_pulse(ebreak_pulse),
        .ecall_pulse(ecall_pulse)
    );

    // 40 MHz clock (25 ns)
    always #12.5 clk = ~clk;

/*
   always @(posedge clk) begin
    if (!rst &&
        tb_top.uut.wb_wen_final &&
        tb_top.uut.wb_rd_addr == 5'd1) begin
        $display("WB x1: time=%0t  ex_pc=%08x  wb_data_final=%08x",
                 $time,
                 tb_top.uut.ex_pc,
                 tb_top.uut.wb_data_final);
    end
end
*/

always @(posedge clk) begin
    $display("cycle=%0d pc=%08x id_pc=%08x ex_pc=%08x mem_pc=%08x wb_rd=%0d wb_wen=%b wb_data=%08x ex_redirect=%b ex_target=%08x if_stall=%b id_stall=%b flush_ifid=%b flush_idex=%b",
             tb_top.uut.u_PC.dbg_cnt, tb_top.uut.pc, tb_top.uut.id_pc, tb_top.uut.ex_pc, tb_top.uut.mem_pc, tb_top.uut.wb_rd_addr, tb_top.uut.wb_wen_final, tb_top.uut.wb_data_final,
             tb_top.uut.ex_redirect_taken, tb_top.uut.ex_branch_target, tb_top.uut.if_stall, tb_top.uut.id_stall, tb_top.uut.ifid_flush, tb_top.uut.idex_flush);
end

always @(posedge clk) begin
    #0;
    $display("time=%0t ps  dbg_cnt=%0d pc(top)=%08x", 
             $time, tb_top.uut.u_PC.dbg_cnt, pc);
end
    // Task to dump register file contents
    task dump_regs;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1) begin
                $display("x%0d = %08x", i, tb_top.uut.u_regfile.regs[i]);
            end
        end
    endtask

    
    initial begin
        integer i;
        reg [63:0] cycles;

        // Wave dump
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        // Reset
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
    
        // Short trace to sanity-check stage alignment
        for (i = 0; i < 12; i = i + 1) begin
            @(posedge clk);
            //#0;
            $display("ID: pc=%08x instr=%08x | IF.port: pc=%08x instr=%08x",
                tb_top.uut.id_pc,
                tb_top.uut.id_instr,
                tb_top.uut.if_pc, tb_top.uut.if_instr
            );
        end

        // Run until ECALL or EBREAK (with reasonable timeout)
        cycles = 0;
        while (cycles < 64'd50) begin //original value for coremark is 50_000_000
            @(posedge clk); 
            #0; // sample after NBA updates

            if (ecall_pulse) begin
                $display("ECALL  at ID.pc=%08x | IF.pc=%08x after %0d cycles",
                         tb_top.uut.id_pc, pc, cycles);
                dump_regs();
                $finish;
            end
            if (ebreak_pulse) begin
                $display("EBREAK at ID.pc=%08x | IF.pc=%08x after %0d cycles",
                // real finished ebreak's pc is at pc-20000,
                //as idk why the pc wil shift in the tb,if have any doubts,just use the ebreak inside the top.v
                         tb_top.uut.id_pc, pc, cycles);
                dump_regs();
                $finish;
            end

            cycles = cycles + 1;
        end

        $display("Timeout after %0d cycles (no ECALL/EBREAK)", cycles);
        dump_regs();
        $finish;
    end

endmodule