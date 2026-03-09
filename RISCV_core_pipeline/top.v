module top (
    input clk,
    input rst,
    output [31:0] pc,
    output [31:0] instr,
    output  ebreak_pulse,
    output ecall_pulse
);
    //wire  [31:0] pc;
    //wire [31:0] instr;

    // Split predictor sizing:
    // - keep BHT a little larger
    // - shrink BTB to help timing
    // - use a safer tag width to reduce false hits
    localparam BHT_INDEX_BITS = 4;
    localparam BTB_INDEX_BITS = 4;
    localparam BTB_TAG_BITS   = 12;

    // Redirect from EX
    wire        ex_redirect;
    wire [31:0] ex_redirect_pc;

    // Stall / flush
    wire        if_stall, id_stall, ifid_flush, idex_flush;
    wire        pc_stall;
    //wire        frontend_if_stall;

    assign pc_stall          = if_stall | id_stall;
    //assign frontend_if_stall = pc_stall & ~ex_redirect;

    // Actual address sent to IMEM this cycle
    // EX redirect has priority so redirected fetch can start immediately.
    //wire [31:0] fetch_pc;
    //assign fetch_pc = ex_redirect ? ex_redirect_pc : pc;

    // Predictor lookup PC
    // IMPORTANT:
    // Read predictor using the registered PC only, not fetch_pc.
    // This shortens the EX->redirect->predictor->PC critical path.
    wire [31:0] pred_lookup_pc;
    assign pred_lookup_pc = pc;

    // IF-stage predictor lookup
    wire        bht_pred_taken;
    wire        btb_hit;
    wire        btb_is_jump;
    wire [31:0] btb_pred_target;

    wire        if_pred_taken_raw;
    wire [31:0] if_pred_target_raw;

    // Disable predictor redirection in a cycle where EX already redirects.
    assign if_pred_taken_raw  = (~ex_redirect) & btb_hit & (btb_is_jump | bht_pred_taken);
    assign if_pred_target_raw = btb_pred_target;

    PC_reg u_PC (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_stall(pc_stall),

        .ex_redirect(ex_redirect),
        .ex_redirect_pc(ex_redirect_pc),

        .if_pred_redirect(if_pred_taken_raw),
        .if_pred_target(if_pred_target_raw)
    );

    // IF
    wire [31:0] if_instr, if_pc;
    wire        if_pred_taken;
    wire [31:0] if_pred_target;

    IF u_if (
        .clk              (clk),
        .rst              (rst),
        .pc               (pc),
        .if_stall         (pc_stall),
        .fetch_pred_taken (if_pred_taken_raw),
        .fetch_pred_target(if_pred_target_raw),
        .instr            (if_instr),
        .if_pc            (if_pc),
        .if_pred_taken    (if_pred_taken),
        .if_pred_target   (if_pred_target)
    );

    assign instr = if_instr;

    // IF/ID pipeline register
    wire [31:0] id_pc, id_instr;
    wire        id_pred_taken;
    wire [31:0] id_pred_target;

    IF_ID u_if_id (
        .clk           (clk),
        .rst           (rst),
        .id_stall      (id_stall),
        .ifid_flush    (ifid_flush),
        .if_pc         (if_pc),
        .if_instr      (if_instr),
        .if_pred_taken (if_pred_taken),
        .if_pred_target(if_pred_target),
        .id_pc         (id_pc),
        .id_instr      (id_instr),
        .id_pred_taken (id_pred_taken),
        .id_pred_target(id_pred_target)
    );

    // ID: decode stage control/data outputs
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire       reg_write_d, mem_read_d, mem_write_d;
    wire       branch_d, jal_d, jalr_d;
    wire [2:0] branch_op_d;
    wire [3:0] alu_op_d;
    wire       alu_rs2_imm_d;
    wire [1:0] wb_sel_d;
    wire       use_pc_add_d;
    wire       load_signed_d;
    wire [1:0] load_size_d;
    wire [1:0] store_size_d;
    wire       id_ecall, id_ebreak, id_fence;

    ID u_ID (
        .inst(id_instr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .imm_type(imm_type),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write_d),
        .mem_read(mem_read_d),
        .mem_write(mem_write_d),
        .branch(branch_d),
        .jal(jal_d),
        .jalr(jalr_d),
        .branch_op(branch_op_d),
        .alu_op(alu_op_d),
        .alu_rs2_imm(alu_rs2_imm_d),
        .wb_sel(wb_sel_d),
        .use_pc_add(use_pc_add_d),
        .load_size(load_size_d),
        .load_signed(load_signed_d),
        .store_size(store_size_d),
        .ecall(id_ecall),
        .ebreak(id_ebreak),
        .fence(id_fence)
    );

    // Forward declarations for WB signals used by regfile / forwarding
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_data_final;
    wire        wb_wen_final;

    // Register file
    wire [31:0] id_rs1_val, id_rs2_val;
    reg_file u_regfile (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(wb_rd_addr),
        .rd_data(wb_data_final),
        .rd_wen(wb_wen_final),
        .rs1_data(id_rs1_val),
        .rs2_data(id_rs2_val)
    );

    // Immediate generator
    wire [31:0] id_imm;
    immgen u_immgen (
        .inst(id_instr),
        .imm_type(imm_type),
        .imm(id_imm)
    );
    
    // ================================================================
    // CSR: cycle counter (independent, always increments)
    // ================================================================
    reg [63:0] cycle_cnt;
    always @(posedge clk) begin
        if (rst) cycle_cnt <= 64'd0;
        else     cycle_cnt <= cycle_cnt + 1'b1;
    end

    // ================================================================
    // CSR detection in ID - only get hit and address, NOT data
    // ================================================================
    wire        csr_hit_id;
    wire [11:0] csr_addr_id;

    csr_read u_csr_read (
        .instr(id_instr),
        .csr_hit(csr_hit_id),
        .csr_addr(csr_addr_id)
    );

    // CSR signals through pipeline (address, not data)
    wire        ex_csr_hit;
    wire [11:0] ex_csr_addr;
    wire        mem_csr_hit;
    wire [11:0] mem_csr_addr;
    wire        wb_csr_hit;
    wire [11:0] wb_csr_addr;

    // ID/EX pipeline register
    wire [31:0] ex_pc, ex_rs1_val, ex_rs2_val, ex_imm;
    wire [31:0] ex_pred_target;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_branch, ex_jal, ex_jalr;
    wire        ex_pred_taken;
    wire [2:0]  ex_branch_op;
    wire [3:0]  ex_alu_op;
    wire        ex_alu_rs2_is_imm, ex_use_pc_add, ex_load_signed;
    wire [1:0]  ex_wb_sel, ex_load_size, ex_store_size;
    wire        ex_ecall, ex_ebreak, ex_fence;

    ID_EX u_id_ex (
        .clk(clk),
        .rst(rst),
        .idex_flush(idex_flush),

        .id_pc(id_pc),
        .id_rs1_val(id_rs1_val),
        .id_rs2_val(id_rs2_val),
        .id_imm(id_imm),
        .id_rs1_addr(rs1_addr),
        .id_rs2_addr(rs2_addr),
        .id_rd_addr(rd_addr),

        .id_reg_write(reg_write_d),
        .id_mem_read(mem_read_d),
        .id_mem_write(mem_write_d),
        .id_branch(branch_d),
        .id_jal(jal_d),
        .id_jalr(jalr_d),
        .id_branch_op(branch_op_d),
        .id_alu_op(alu_op_d),
        .id_alu_rs2_is_imm(alu_rs2_imm_d),
        .id_wb_sel(wb_sel_d),
        .id_use_pc_add(use_pc_add_d),
        .id_load_signed(load_signed_d),
        .id_load_size(load_size_d),
        .id_store_size(store_size_d),

        .id_pred_taken(id_pred_taken),
        .id_pred_target(id_pred_target),

        .id_ebreak(id_ebreak),
        .id_ecall(id_ecall),
        .id_fence(id_fence),

        .id_csr_hit(csr_hit_id),
        .id_csr_addr(csr_addr_id),

        .ex_pc(ex_pc),
        .ex_rs1_val(ex_rs1_val),
        .ex_rs2_val(ex_rs2_val),
        .ex_imm(ex_imm),
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),
        .ex_rd_addr(ex_rd_addr),

        .ex_reg_write(ex_reg_write),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_branch(ex_branch),
        .ex_jal(ex_jal),
        .ex_jalr(ex_jalr),
        .ex_branch_op(ex_branch_op),
        .ex_alu_op(ex_alu_op),
        .ex_alu_rs2_is_imm(ex_alu_rs2_is_imm),
        .ex_wb_sel(ex_wb_sel),
        .ex_use_pc_add(ex_use_pc_add),
        .ex_load_signed(ex_load_signed),
        .ex_load_size(ex_load_size),
        .ex_store_size(ex_store_size),

        .ex_csr_hit(ex_csr_hit),
        .ex_csr_addr(ex_csr_addr),
        .ex_ebreak(ex_ebreak),
        .ex_ecall(ex_ecall),
        .ex_fence(ex_fence),

        .ex_pred_taken(ex_pred_taken),
        .ex_pred_target(ex_pred_target)
    );

    // Forwarding unit controls
    wire [1:0] forward_a, forward_b;

    // Forward declaration for load data used by MEM2 forwarding
    wire [31:0] mem_load_data;
    
    // MEM2 delay registers
    reg        mem_mem_read_q;
    reg [31:0] mem_wb_candidate_q;
    reg [4:0]  mem_rd_addr_q;
    reg        mem_reg_write_q;
    reg [1:0]  mem_wb_sel_q;
    reg        mem_csr_hit_q;
    reg [11:0] mem_csr_addr_q;
    reg        mem_ebreak_q, mem_ecall_q, mem_fence_q;
    reg [31:0] mem_pc_q;
    
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_candidate_q <= 32'b0;
            mem_rd_addr_q      <= 5'd0;
            mem_reg_write_q    <= 1'b0;
            mem_wb_sel_q       <= 2'd0;
            mem_csr_hit_q      <= 1'b0;
            mem_csr_addr_q     <= 12'd0;
            mem_ebreak_q       <= 1'b0;
            mem_ecall_q        <= 1'b0;
            mem_fence_q        <= 1'b0;
            mem_pc_q           <= 32'b0;
            mem_mem_read_q     <= 1'b0;
        end else begin
            mem_wb_candidate_q <= mem_wb_candidate;
            mem_rd_addr_q      <= mem_rd_addr;
            mem_reg_write_q    <= mem_reg_write;
            mem_wb_sel_q       <= mem_wb_sel;
            mem_csr_hit_q      <= mem_csr_hit;
            mem_csr_addr_q     <= mem_csr_addr;
            mem_ebreak_q       <= mem_ebreak;
            mem_ecall_q        <= mem_ecall;
            mem_fence_q        <= mem_fence;
            mem_pc_q           <= mem_pc;
            mem_mem_read_q     <= mem_mem_read;
        end
    end

    // MEM2 forwarding data
    wire        mem2_is_load;
    wire [31:0] mem2_forward_data;

    assign mem2_is_load      = mem_mem_read_q;
    assign mem2_forward_data = mem2_is_load ? mem_load_data : mem_wb_candidate_q;

    // Forwarding unit
    forwarding_unit u_forwarding (
        .ex_rs1_addr     (ex_rs1_addr),
        .ex_rs2_addr     (ex_rs2_addr),
        .exmem_reg_write (mem_reg_write),
        .exmem_mem_read  (mem_mem_read),
        .exmem_csr_hit   (mem_csr_hit),
        .exmem_rd        (mem_rd_addr),
        .mem2_reg_write  (mem_reg_write_q),
        .mem2_csr_hit    (mem_csr_hit_q),
        .mem2_rd         (mem_rd_addr_q),
        .memwb_reg_write (wb_wen_final),
        .memwb_rd        (wb_rd_addr),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    wire [31:0] ex_rs1_fwd;
    wire [31:0] ex_rs2_fwd;

    assign ex_rs1_fwd = (forward_a == 2'b10) ? mem_wb_candidate :
                        (forward_a == 2'b11) ? mem2_forward_data :
                        (forward_a == 2'b01) ? wb_data_final :
                                               ex_rs1_val;

    assign ex_rs2_fwd = (forward_b == 2'b10) ? mem_wb_candidate :
                        (forward_b == 2'b11) ? mem2_forward_data :
                        (forward_b == 2'b01) ? wb_data_final :
                                               ex_rs2_val;

    // Final ALU operands
    wire [31:0] ex_rs1_val_to_alu = ex_rs1_fwd;
    wire [31:0] ex_rs2_val_to_alu = ex_alu_rs2_is_imm ? ex_imm : ex_rs2_fwd;

    // EX stage
    wire [31:0] ex_pc_plus4, ex_auipc_result;
    wire [31:0] ex_alu_result, ex_branch_target;
    wire        ex_actual_taken;

    EX u_EX (
        .pc(ex_pc),
        .rs1_data(ex_rs1_val_to_alu),
        .rs2_data(ex_rs2_val_to_alu),
        .imm(ex_imm),
        .alu_op(ex_alu_op),
        .alu_rs2_imm(ex_alu_rs2_is_imm),
        .branch(ex_branch),
        .branch_op(ex_branch_op),
        .jal(ex_jal),
        .jalr(ex_jalr),
        .alu_core_result(ex_alu_result),
        .pc_plus4(ex_pc_plus4),
        .auipc_result(ex_auipc_result),
        .branch_target(ex_branch_target),
        .branch_taken(ex_actual_taken)
    );

    // IF-stage predictors
    bht_2bit #(.INDEX_BITS(BHT_INDEX_BITS)) u_bht (
        .clk         (clk),
        .rst         (rst),
        .r_pc        (pred_lookup_pc),
        .pred_taken  (bht_pred_taken),
        .update_en   (ex_branch),        // only conditional branches update BHT
        .u_pc        (ex_pc),
        .actual_taken(ex_actual_taken)
    );

    btb_direct #(
        .INDEX_BITS(BTB_INDEX_BITS),
        .TAG_BITS  (BTB_TAG_BITS)
    ) u_btb (
        .clk         (clk),
        .rst         (rst),
        .r_pc        (pred_lookup_pc),
        .hit         (btb_hit),
        .pred_target (btb_pred_target),
        .pred_is_jump(btb_is_jump),
        .update_en   (ex_jal | (ex_branch & ex_actual_taken)),
        .u_pc        (ex_pc),
        .u_target    (ex_branch_target),
        .u_is_jump   (ex_jal)
    );

    // WB candidate selection in EX
    wire [31:0] ex_wb_candidate =
        ex_use_pc_add ? ex_auipc_result :
        (ex_wb_sel == 2'b0)  ? ex_alu_result :
        (ex_wb_sel == 2'b10) ? ex_pc_plus4 :
        (ex_wb_sel == 2'b11) ? ex_imm :
                               ex_alu_result;

    // Mispredict / false-hit detection
    // - conditional branch: direction + target
    // - JAL: direction + target
    // - JALR: always redirect in EX in this version
    // - false predicted-taken on a non-control instruction: recover to PC+4
    wire ex_dir_mispredict;
    wire ex_tgt_mispredict;
    wire ex_is_ctrl;
    wire ex_false_pred_nonctrl;

    assign ex_dir_mispredict = (ex_actual_taken != ex_pred_taken);
    assign ex_tgt_mispredict =
        ex_actual_taken &
        ex_pred_taken &
        (ex_branch_target != ex_pred_target);

    assign ex_is_ctrl = ex_branch | ex_jal | ex_jalr;

    // If IF predicted taken but the decoded instruction in EX is not control-flow,
    // this was a false BTB hit / alias. Recover to sequential PC.
    assign ex_false_pred_nonctrl = ex_pred_taken & ~ex_is_ctrl;

    assign ex_redirect =
        ex_false_pred_nonctrl ? 1'b1 :
        ex_jalr               ? 1'b1 :
        (ex_branch | ex_jal)  ? (ex_dir_mispredict | ex_tgt_mispredict) :
                                1'b0;

    assign ex_redirect_pc =
        ex_false_pred_nonctrl ? ex_pc_plus4 :
        ex_actual_taken       ? ex_branch_target : ex_pc_plus4;

    // EX/MEM pipeline register
    wire [31:0] mem_pc, mem_alu_result, mem_rs2_val_for_store, mem_wb_candidate;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_load_signed;
    wire [1:0]  mem_wb_sel, mem_load_size, mem_store_size;
    wire        mem_ecall, mem_ebreak, mem_fence;

    EX_MEM u_ex_mem (
        .clk(clk),
        .rst(rst),
        
        .ex_ebreak(ex_ebreak),
        .ex_ecall(ex_ecall),
        .ex_fence(ex_fence),
        .ex_pc(ex_pc),
        .ex_alu_result(ex_alu_result),
        .ex_rs2_val_for_store(ex_rs2_fwd),
        .ex_rd_addr(ex_rd_addr),
        .ex_reg_write(ex_reg_write),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_wb_sel(ex_wb_sel),
        .ex_load_size(ex_load_size),
        .ex_store_size(ex_store_size),
        .ex_load_signed(ex_load_signed),
        .ex_wb_candidate(ex_wb_candidate),
        .ex_csr_hit(ex_csr_hit),
        .ex_csr_addr(ex_csr_addr),

        .mem_pc(mem_pc),
        .mem_alu_result(mem_alu_result),
        .mem_rs2_val_for_store(mem_rs2_val_for_store),
        .mem_rd_addr(mem_rd_addr),
        .mem_reg_write(mem_reg_write),
        .mem_mem_read(mem_mem_read),
        .mem_mem_write(mem_mem_write),
        .mem_wb_sel(mem_wb_sel),
        .mem_load_size(mem_load_size),
        .mem_store_size(mem_store_size),
        .mem_load_signed(mem_load_signed),
        .mem_wb_candidate(mem_wb_candidate),
        .mem_csr_hit(mem_csr_hit),
        .mem_csr_addr(mem_csr_addr),
        .mem_ebreak(mem_ebreak),
        .mem_ecall(mem_ecall),
        .mem_fence(mem_fence)
    );

    // MEM stage
    MEM u_MEM (
        .clk(clk),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .alu_result(mem_alu_result),
        .rs2_data(mem_rs2_val_for_store),
        .mem_data(mem_load_data),
        .load_signed(mem_load_signed),
        .load_size(mem_load_size),
        .store_size(mem_store_size)
    );

    // MEM/WB pipeline register
    wire [31:0] wb_wb_candidate, wb_load_data;
    wire        wb_reg_write;
    wire [1:0]  wb_wb_sel;
    wire        wb_ecall, wb_ebreak, wb_fence;
    wire        ebreak_q, ecall_q, fence_q;

    MEM_WB u_mem_wb (
        .clk(clk),
        .rst(rst),
        .mem_pc(mem_pc_q),
        .mem_wb_candidate(mem_wb_candidate_q),
        .mem_load_data(mem_load_data),
        .mem_rd_addr(mem_rd_addr_q),
        .mem_reg_write(mem_reg_write_q),
        .mem_wb_sel(mem_wb_sel_q),
        .mem_csr_hit(mem_csr_hit_q),
        .mem_csr_addr(mem_csr_addr_q),
        .mem_ebreak(mem_ebreak_q),
        .mem_ecall(mem_ecall_q),
        .mem_fence(mem_fence_q),

        .wb_wb_candidate(wb_wb_candidate),
        .wb_load_data(wb_load_data),
        .wb_rd_addr(wb_rd_addr),
        .wb_reg_write(wb_reg_write),
        .wb_wb_sel(wb_wb_sel),
        .wb_csr_hit(wb_csr_hit),
        .wb_csr_addr(wb_csr_addr),
        .wb_ebreak(wb_ebreak),
        .wb_ecall(wb_ecall),
        .wb_fence(wb_fence),
        .ebreak_q(ebreak_q),
        .ecall_q(ecall_q),
        .fence_q(fence_q)
    );
    
    // WB: core WB mux
    wire [31:0] wb_wb_data_core;
    WB u_WB (
        .mem_to_reg(wb_wb_sel == 2'd1),
        .alu_result(wb_wb_candidate),
        .mem_data(wb_load_data),
        .wb_data(wb_wb_data_core),
        .clk(clk)
    );

    // ================================================================
    // Independent CSR read at WB stage - uses CURRENT cycle_cnt
    // ================================================================
    wire [31:0] wb_csr_data_live;

    csr_wb_read u_csr_wb (
        .csr_addr(wb_csr_addr),
        .cycle_cnt(cycle_cnt),
        .csr_hit(wb_csr_hit),
        .csr_data(wb_csr_data_live)
    );

    // Final write-back: use live CSR data when CSR hit
    assign wb_data_final = wb_csr_hit ? wb_csr_data_live : wb_wb_data_core;
    assign wb_wen_final  = wb_csr_hit ? 1'b1 : wb_reg_write;

    // Hazard unit
    hazard_unit u_hazard (
        .id_rs1 (rs1_addr),
        .id_rs2 (rs2_addr),
        .clk(clk),
        .rst(rst),

        .idex_mem_read   (ex_mem_read),
        .idex_rd         (ex_rd_addr),
        .idex_reg_write  (ex_reg_write),
        .idex_csr_hit    (ex_csr_hit),

        .exmem_reg_write (mem_reg_write),
        .exmem_rd        (mem_rd_addr),
        .exmem_csr_hit   (mem_csr_hit),

        .memwb_reg_write (wb_wen_final),
        .memwb_rd        (wb_rd_addr),

        .ex_redirect     (ex_redirect),
        .stall_if        (if_stall),
        .stall_id        (id_stall),
        .flush_ifid      (ifid_flush),
        .flush_idex      (idex_flush)
    );

    // ECALL/EBREAK pulses
    assign ebreak_pulse = ebreak_q;
    assign ecall_pulse  = ecall_q; 

endmodule