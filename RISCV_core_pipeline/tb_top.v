`timescale 1ns / 1ps

module tb_top;

    reg clk = 0;
    reg rst = 1;

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

    // Latch previous-cycle ID-stage PC so it aligns with decode pulses
    reg [31:0] id_pc_q;
    always @(posedge clk or posedge rst) begin
        if (rst) id_pc_q <= 32'h0;
        else     id_pc_q <= tb_top.uut.id_pc; // hierarchical reference into top
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
        repeat (4) @(posedge clk);
        rst = 0;

        // Short trace to sanity-check stage alignment
        for (i = 0; i < 12; i = i + 1) begin
            @(posedge clk);
            #0;
            $display("ID: pc=%08x instr=%08x | IF.port: pc=%08x instr=%08x",
                tb_top.uut.id_pc,
                tb_top.uut.id_instr,
                pc, instr
            );
        end

        // Run until ECALL or EBREAK (with reasonable timeout)
        cycles = 0;
        while (cycles < 64'd50_000_000) begin
            @(posedge clk);
            #0; // sample after NBA updates

            if (ecall_pulse) begin
                $display("ECALL  at ID.pc=%08x | IF.pc=%08x after %0d cycles",
                         id_pc_q, pc, cycles);
                dump_regs();
                $finish;
            end
            if (ebreak_pulse) begin
                $display("EBREAK at ID.pc=%08x | IF.pc=%08x after %0d cycles",// real finished ebreak's pc is at pc-20000,as idk why the pc wil shify in the tb
                         id_pc_q, pc, cycles);
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