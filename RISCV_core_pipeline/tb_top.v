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


    // ================================================================
    // Simulation-only performance counters
    // ================================================================
    // These counters are intentionally kept in the testbench so they do not
    // affect the synthesizable CPU RTL. They use hierarchical references into
    // top.v to classify cycles/instructions and to diagnose bottlenecks.
    //
    // Important interpretation notes:
    // - instr_issue_count is an approximate count of non-NOP instructions that
    //   ID is allowed to issue into EX. It is good enough for CPI direction,
    //   but not a formal retired-instruction counter.
    // - branch/jump/load/store/mul/div counters are counted in EX stage when
    //   the corresponding decoded control is present.
    // - ifid_flush_cycles is usually the most direct branch-redirect penalty
    //   counter in this core, because hazard_unit flushes IF/ID for redirect
    //   and for the registered one-cycle redirect shadow.
    // ================================================================
    localparam [4:0] PERF_ALU_MUL    = 5'd10;
    localparam [4:0] PERF_ALU_MULH   = 5'd11;
    localparam [4:0] PERF_ALU_MULHSU = 5'd12;
    localparam [4:0] PERF_ALU_MULHU  = 5'd13;
    localparam [4:0] PERF_ALU_DIV    = 5'd14;
    localparam [4:0] PERF_ALU_DIVU   = 5'd15;
    localparam [4:0] PERF_ALU_REM    = 5'd16;
    localparam [4:0] PERF_ALU_REMU   = 5'd17;

    reg [63:0] perf_total_cycles;
    reg [63:0] perf_pc_stall_cycles;
    reg [63:0] perf_if_stall_cycles;
    reg [63:0] perf_id_stall_cycles;
    reg [63:0] perf_ifid_flush_cycles;
    reg [63:0] perf_idex_flush_cycles;
    reg [63:0] perf_load_use_stall_cycles;
    reg [63:0] perf_csr_use_stall_cycles;

    reg [63:0] perf_instr_issue_count;
    reg [63:0] perf_regwrite_wb_count;
    reg [63:0] perf_csr_count;
    reg [63:0] perf_load_count;
    reg [63:0] perf_store_count;
    reg [63:0] perf_branch_count;
    reg [63:0] perf_branch_taken_count;
    reg [63:0] perf_branch_pred_taken_count;
    reg [63:0] perf_branch_dir_mispredict_count;
    reg [63:0] perf_branch_tgt_mispredict_count;
    reg [63:0] perf_jal_count;
    reg [63:0] perf_jal_pred_taken_count;
    reg [63:0] perf_jal_mispredict_count;
    reg [63:0] perf_jalr_count;
    reg [63:0] perf_jalr_pred_taken_count;
    reg [63:0] perf_jalr_mispredict_count;
    reg [63:0] perf_ras_pred_count;
    reg [63:0] perf_ras_correct_count;
    reg [63:0] perf_ras_push_count;
    reg [63:0] perf_ras_pop_count;
    reg [63:0] perf_false_pred_nonctrl_count;
    reg [63:0] perf_redirect_count;

    reg [63:0] perf_mul_count;
    reg [63:0] perf_mulh_count;
    reg [63:0] perf_mulhsu_count;
    reg [63:0] perf_mulhu_count;
    reg [63:0] perf_div_count;
    reg [63:0] perf_divu_count;
    reg [63:0] perf_rem_count;
    reg [63:0] perf_remu_count;
    reg [63:0] perf_muldiv_start_count;
    reg [63:0] perf_muldiv_busy_cycles;
    reg [63:0] perf_muldiv_done_count;
    reg [63:0] perf_muldiv_stall_cycles;

    wire perf_id_issues_non_nop =
        !rst &&
        !tb_top.uut.idex_flush &&
        !tb_top.uut.id_stall &&
        (tb_top.uut.id_instr != 32'h0000_0013);

    wire perf_ex_is_mul    = (tb_top.uut.ex_alu_op == PERF_ALU_MUL);
    wire perf_ex_is_mulh   = (tb_top.uut.ex_alu_op == PERF_ALU_MULH);
    wire perf_ex_is_mulhsu = (tb_top.uut.ex_alu_op == PERF_ALU_MULHSU);
    wire perf_ex_is_mulhu  = (tb_top.uut.ex_alu_op == PERF_ALU_MULHU);
    wire perf_ex_is_div    = (tb_top.uut.ex_alu_op == PERF_ALU_DIV);
    wire perf_ex_is_divu   = (tb_top.uut.ex_alu_op == PERF_ALU_DIVU);
    wire perf_ex_is_rem    = (tb_top.uut.ex_alu_op == PERF_ALU_REM);
    wire perf_ex_is_remu   = (tb_top.uut.ex_alu_op == PERF_ALU_REMU);

    // In ENABLE_TIMING_MULDIV mode the EX-stage M instruction is held while
    // the registered multiplier runs. Count the M instruction once, on the
    // cycle it is allowed to leave EX, not once per stall cycle.
    wire perf_ex_count_enable = !tb_top.uut.muldiv_stall;

    wire perf_load_use_hazard =
        tb_top.uut.ex_mem_read &&
        (tb_top.uut.ex_rd_addr != 5'd0) &&
        ((tb_top.uut.ex_rd_addr == tb_top.uut.rs1_addr) ||
         (tb_top.uut.ex_rd_addr == tb_top.uut.rs2_addr));

    wire perf_csr_use_hazard =
        (tb_top.uut.ex_csr_hit &&
         (tb_top.uut.ex_rd_addr != 5'd0) &&
         ((tb_top.uut.ex_rd_addr == tb_top.uut.rs1_addr) ||
          (tb_top.uut.ex_rd_addr == tb_top.uut.rs2_addr))) ||
        (tb_top.uut.mem_csr_hit &&
         (tb_top.uut.mem_rd_addr != 5'd0) &&
         ((tb_top.uut.mem_rd_addr == tb_top.uut.rs1_addr) ||
          (tb_top.uut.mem_rd_addr == tb_top.uut.rs2_addr)));

    always @(posedge clk) begin
        if (rst) begin
            perf_total_cycles                <= 64'd0;
            perf_pc_stall_cycles             <= 64'd0;
            perf_if_stall_cycles             <= 64'd0;
            perf_id_stall_cycles             <= 64'd0;
            perf_ifid_flush_cycles           <= 64'd0;
            perf_idex_flush_cycles           <= 64'd0;
            perf_load_use_stall_cycles       <= 64'd0;
            perf_csr_use_stall_cycles        <= 64'd0;
            perf_instr_issue_count           <= 64'd0;
            perf_regwrite_wb_count           <= 64'd0;
            perf_csr_count                   <= 64'd0;
            perf_load_count                  <= 64'd0;
            perf_store_count                 <= 64'd0;
            perf_branch_count                <= 64'd0;
            perf_branch_taken_count          <= 64'd0;
            perf_branch_pred_taken_count     <= 64'd0;
            perf_branch_dir_mispredict_count <= 64'd0;
            perf_branch_tgt_mispredict_count <= 64'd0;
            perf_jal_count                   <= 64'd0;
            perf_jal_pred_taken_count        <= 64'd0;
            perf_jal_mispredict_count        <= 64'd0;
            perf_jalr_count                  <= 64'd0;
            perf_jalr_pred_taken_count       <= 64'd0;
            perf_jalr_mispredict_count       <= 64'd0;
            perf_ras_pred_count              <= 64'd0;
            perf_ras_correct_count           <= 64'd0;
            perf_ras_push_count              <= 64'd0;
            perf_ras_pop_count               <= 64'd0;
            perf_false_pred_nonctrl_count    <= 64'd0;
            perf_redirect_count              <= 64'd0;
            perf_mul_count                   <= 64'd0;
            perf_mulh_count                  <= 64'd0;
            perf_mulhsu_count                <= 64'd0;
            perf_mulhu_count                 <= 64'd0;
            perf_div_count                   <= 64'd0;
            perf_divu_count                  <= 64'd0;
            perf_rem_count                   <= 64'd0;
            perf_remu_count                  <= 64'd0;
            perf_muldiv_start_count          <= 64'd0;
            perf_muldiv_busy_cycles          <= 64'd0;
            perf_muldiv_done_count           <= 64'd0;
            perf_muldiv_stall_cycles         <= 64'd0;
        end else begin
            perf_total_cycles <= perf_total_cycles + 64'd1;

            if (tb_top.uut.pc_stall)       perf_pc_stall_cycles       <= perf_pc_stall_cycles + 64'd1;
            if (tb_top.uut.if_stall)       perf_if_stall_cycles       <= perf_if_stall_cycles + 64'd1;
            if (tb_top.uut.id_stall)       perf_id_stall_cycles       <= perf_id_stall_cycles + 64'd1;
            if (tb_top.uut.ifid_flush)     perf_ifid_flush_cycles     <= perf_ifid_flush_cycles + 64'd1;
            if (tb_top.uut.idex_flush)     perf_idex_flush_cycles     <= perf_idex_flush_cycles + 64'd1;
            if (perf_load_use_hazard)
                perf_load_use_stall_cycles <= perf_load_use_stall_cycles + 64'd1;
            if (perf_csr_use_hazard)
                perf_csr_use_stall_cycles  <= perf_csr_use_stall_cycles + 64'd1;

            if (perf_id_issues_non_nop)    perf_instr_issue_count     <= perf_instr_issue_count + 64'd1;
            if (tb_top.uut.wb_wen_final)   perf_regwrite_wb_count     <= perf_regwrite_wb_count + 64'd1;
            if (tb_top.uut.ex_csr_hit)     perf_csr_count             <= perf_csr_count + 64'd1;
            if (tb_top.uut.ex_mem_read)    perf_load_count            <= perf_load_count + 64'd1;
            if (tb_top.uut.ex_mem_write)   perf_store_count           <= perf_store_count + 64'd1;

            if (tb_top.uut.ex_branch) begin
                perf_branch_count <= perf_branch_count + 64'd1;
                if (tb_top.uut.ex_actual_taken)
                    perf_branch_taken_count <= perf_branch_taken_count + 64'd1;
                if (tb_top.uut.ex_pred_taken)
                    perf_branch_pred_taken_count <= perf_branch_pred_taken_count + 64'd1;
                if (tb_top.uut.ex_dir_mispredict)
                    perf_branch_dir_mispredict_count <= perf_branch_dir_mispredict_count + 64'd1;
                if (tb_top.uut.ex_tgt_mispredict)
                    perf_branch_tgt_mispredict_count <= perf_branch_tgt_mispredict_count + 64'd1;
            end

            if (tb_top.uut.ex_jal) begin
                perf_jal_count <= perf_jal_count + 64'd1;
                if (tb_top.uut.ex_pred_taken)
                    perf_jal_pred_taken_count <= perf_jal_pred_taken_count + 64'd1;
                if (tb_top.uut.ex_redirect)
                    perf_jal_mispredict_count <= perf_jal_mispredict_count + 64'd1;
            end
            if (tb_top.uut.ex_jalr) begin
                perf_jalr_count <= perf_jalr_count + 64'd1;
                if (tb_top.uut.ex_pred_taken)
                    perf_jalr_pred_taken_count <= perf_jalr_pred_taken_count + 64'd1;
                if (tb_top.uut.ex_redirect)
                    perf_jalr_mispredict_count <= perf_jalr_mispredict_count + 64'd1;
            end
            if (tb_top.uut.ras_pred_return)
                perf_ras_pred_count <= perf_ras_pred_count + 64'd1;
            if (tb_top.uut.ex_jalr_return && tb_top.uut.ex_pred_taken && !tb_top.uut.ex_redirect)
                perf_ras_correct_count <= perf_ras_correct_count + 64'd1;
            if (tb_top.uut.ex_jal_call || tb_top.uut.ex_jalr_call)
                perf_ras_push_count <= perf_ras_push_count + 64'd1;
            if (tb_top.uut.ex_jalr_return)
                perf_ras_pop_count <= perf_ras_pop_count + 64'd1;
            if (tb_top.uut.ex_false_pred_nonctrl)
                perf_false_pred_nonctrl_count <= perf_false_pred_nonctrl_count + 64'd1;
            if (tb_top.uut.ex_redirect)
                perf_redirect_count <= perf_redirect_count + 64'd1;

            if (tb_top.uut.muldiv_start)
                perf_muldiv_start_count <= perf_muldiv_start_count + 64'd1;
            if (tb_top.uut.muldiv_busy)
                perf_muldiv_busy_cycles <= perf_muldiv_busy_cycles + 64'd1;
            if (tb_top.uut.muldiv_done)
                perf_muldiv_done_count <= perf_muldiv_done_count + 64'd1;
            if (tb_top.uut.muldiv_stall)
                perf_muldiv_stall_cycles <= perf_muldiv_stall_cycles + 64'd1;

            if (perf_ex_count_enable && perf_ex_is_mul)    perf_mul_count    <= perf_mul_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_mulh)   perf_mulh_count   <= perf_mulh_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_mulhsu) perf_mulhsu_count <= perf_mulhsu_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_mulhu)  perf_mulhu_count  <= perf_mulhu_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_div)    perf_div_count    <= perf_div_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_divu)   perf_divu_count   <= perf_divu_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_rem)    perf_rem_count    <= perf_rem_count + 64'd1;
            if (perf_ex_count_enable && perf_ex_is_remu)   perf_remu_count   <= perf_remu_count + 64'd1;
        end
    end

    task print_perf_counters;
        begin
            $display("================ PERF COUNTERS ================");
            $display("PERF total_cycles %0d", perf_total_cycles);
            $display("PERF instr_issue_count %0d", perf_instr_issue_count);
            $display("PERF regwrite_wb_count %0d", perf_regwrite_wb_count);
            $display("PERF pc_stall_cycles %0d", perf_pc_stall_cycles);
            $display("PERF if_stall_cycles %0d", perf_if_stall_cycles);
            $display("PERF id_stall_cycles %0d", perf_id_stall_cycles);
            $display("PERF ifid_flush_cycles %0d", perf_ifid_flush_cycles);
            $display("PERF idex_flush_cycles %0d", perf_idex_flush_cycles);
            $display("PERF load_use_stall_cycles %0d", perf_load_use_stall_cycles);
            $display("PERF csr_use_stall_cycles %0d", perf_csr_use_stall_cycles);
            $display("PERF load_count %0d", perf_load_count);
            $display("PERF store_count %0d", perf_store_count);
            $display("PERF csr_count %0d", perf_csr_count);
            $display("PERF branch_count %0d", perf_branch_count);
            $display("PERF branch_taken_count %0d", perf_branch_taken_count);
            $display("PERF branch_pred_taken_count %0d", perf_branch_pred_taken_count);
            $display("PERF branch_dir_mispredict_count %0d", perf_branch_dir_mispredict_count);
            $display("PERF branch_tgt_mispredict_count %0d", perf_branch_tgt_mispredict_count);
            $display("PERF jal_count %0d", perf_jal_count);
            $display("PERF jal_pred_taken_count %0d", perf_jal_pred_taken_count);
            $display("PERF jal_mispredict_count %0d", perf_jal_mispredict_count);
            $display("PERF jalr_count %0d", perf_jalr_count);
            $display("PERF jalr_pred_taken_count %0d", perf_jalr_pred_taken_count);
            $display("PERF jalr_mispredict_count %0d", perf_jalr_mispredict_count);
            $display("PERF ras_pred_count %0d", perf_ras_pred_count);
            $display("PERF ras_correct_count %0d", perf_ras_correct_count);
            $display("PERF ras_push_count %0d", perf_ras_push_count);
            $display("PERF ras_pop_count %0d", perf_ras_pop_count);
            $display("PERF false_pred_nonctrl_count %0d", perf_false_pred_nonctrl_count);
            $display("PERF redirect_count %0d", perf_redirect_count);
            $display("PERF mul_count %0d", perf_mul_count);
            $display("PERF mulh_count %0d", perf_mulh_count);
            $display("PERF mulhsu_count %0d", perf_mulhsu_count);
            $display("PERF mulhu_count %0d", perf_mulhu_count);
            $display("PERF div_count %0d", perf_div_count);
            $display("PERF divu_count %0d", perf_divu_count);
            $display("PERF rem_count %0d", perf_rem_count);
            $display("PERF remu_count %0d", perf_remu_count);
            $display("PERF muldiv_start_count %0d", perf_muldiv_start_count);
            $display("PERF muldiv_busy_cycles %0d", perf_muldiv_busy_cycles);
            $display("PERF muldiv_done_count %0d", perf_muldiv_done_count);
            $display("PERF muldiv_stall_cycles %0d", perf_muldiv_stall_cycles);
            $display("================================================");
        end
    endtask

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
/*
always @(posedge clk) begin
    $display("cycle=%0d if_pc=%08x id_pc=%08x ex_pc=%08x mem_pc=%08x wb_rd=%0d wb_wen=%b wb_data=%08x ex_redirect=%b ex_target=%08x if_stall=%b id_stall=%b flush_ifid=%b flush_idex=%b",
             tb_top.uut.u_PC.dbg_cnt, tb_top.uut.if_pc, tb_top.uut.id_pc, tb_top.uut.ex_pc, tb_top.uut.mem_pc, tb_top.uut.wb_rd_addr, tb_top.uut.wb_wen_final, tb_top.uut.wb_data_final,
             tb_top.uut.ex_redirect_taken, tb_top.uut.ex_branch_target, tb_top.uut.if_stall, tb_top.uut.id_stall, tb_top.uut.ifid_flush, tb_top.uut.idex_flush);
end
*/
reg [31:0] stuck_pc;
reg [31:0] stuck_cnt;

always @(posedge clk) begin
    if (rst) begin
        stuck_pc  <= 32'hffffffff;
        stuck_cnt <= 32'd0;
    end else begin
        if (uut.mem_pc == stuck_pc) begin
            stuck_cnt <= stuck_cnt + 1;
        end else begin
            stuck_pc  <= uut.mem_pc;
            stuck_cnt <= 32'd0;
        end

        if (stuck_cnt == 32'd2000000) begin
            $display("WARNING: mem_pc=%08x seen for 2M cycles, likely stuck", stuck_pc);
            $finish;
        end
    end
end
/*
always @(posedge clk) begin
    #0;
    $display("time=%0t ps dbg_cnt=%0d pc=%08x instr=%08x", 
         $time, tb_top.uut.u_PC.dbg_cnt, tb_top.uut.if_pc, tb_top.uut.if_instr);
end 
*/
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
        //$dumpfile("wave.vcd");
        //$dumpvars(0, tb_top);

        // Reset
        rst = 1;
        repeat (1) @(posedge clk);
        rst = 0;
    
        // Short trace to sanity-check stage alignment
        for (i = 0; i < 60; i = i + 1) begin
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
        while (cycles < 64'd50_000_000_000_000) begin //original value for coremark is 50_000_000
            @(posedge clk); 
            #0; // sample after NBA updates

            if (ecall_pulse) begin
                $display("ECALL  at ID.pc=%08x | IF.pc=%08x after %0d cycles",
                         tb_top.uut.id_pc, pc, cycles);
                print_perf_counters();
                dump_regs();
                $finish;
            end
            if (ebreak_pulse) begin
                $display("EBREAK at ID.pc=%08x | IF.pc=%08x after %0d cycles",
                // real finished ebreak's pc is at pc-20000,
                //as idk why the pc wil shift in the tb,if have any doubts,just use the ebreak inside the top.v
                         tb_top.uut.id_pc, pc, cycles);
                print_perf_counters();
                dump_regs();
                $finish;
            end

            cycles = cycles + 1;
        end

        $display("Timeout after %0d cycles (no ECALL/EBREAK)", cycles);
        print_perf_counters();
        dump_regs();
        $finish;
    end

endmodule