// synthesis_top_1kb_ffmem: synthesis-friendly top with 1KB FF-based memories.
// Replaces the 128 KiB behavioural imem/dmem with small register arrays.
// No $readmemh, DPI, display, or testbench constructs.
// CPU pipeline logic is identical to top.v core.

module synth_top_1kb_ffmem (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc,
    output wire [31:0] instr,
    output wire        ebreak_pulse,
    output wire        ecall_pulse
);

    // --- predictor sizing (match golden 64-entry config) ---
    localparam BHT_INDEX_BITS = 6;
    localparam BTB_INDEX_BITS = 6;
    localparam BTB_TAG_BITS   = 12;
    localparam RAS_DEPTH      = 16;
    localparam RAS_PTR_BITS   = 4;

    // ALU opcodes
    localparam [4:0] ALU_ADD   = 5'd0;
    localparam [4:0] ALU_SUB   = 5'd1;
    localparam [4:0] ALU_MUL   = 5'd10;
    localparam [4:0] ALU_MULH  = 5'd11;
    localparam [4:0] ALU_MULHSU = 5'd12;
    localparam [4:0] ALU_MULHU = 5'd13;

    // --- redirect ---
    wire        ex_redirect;
    wire [31:0] ex_redirect_pc;

    // --- stall / flush ---
    wire        if_stall, id_stall, ifid_flush, idex_flush;
    wire        pc_stall;
    assign pc_stall = if_stall | id_stall;

    // --- predictor ---
    wire [31:0] pred_lookup_pc;
    assign pred_lookup_pc = pc;

    wire        bht_pred_taken;
    wire        btb_hit;
    wire        btb_is_jump;
    wire [31:0] btb_pred_target;
    wire        btb_is_return;
    wire        ras_top_valid;
    wire [31:0] ras_top_addr;
    wire        ras_pred_return;

    wire pred_is_branch_entry;
    wire pred_branch_taken;
    wire pred_jump_taken;
    wire pred_return_taken;

    assign pred_is_branch_entry = btb_hit & ~btb_is_jump & ~btb_is_return;
    assign pred_branch_taken    = pred_is_branch_entry & bht_pred_taken;
    assign pred_jump_taken      = btb_hit & btb_is_jump;
    assign ras_pred_return      = btb_hit & btb_is_return & ras_top_valid;
    assign pred_return_taken    = ras_pred_return;

    wire if_pred_taken_raw;
    wire [31:0] if_pred_target_raw;
    assign if_pred_taken_raw  = pred_branch_taken | pred_jump_taken | pred_return_taken;
    assign if_pred_target_raw = pred_return_taken ? ras_top_addr : btb_pred_target;

    // --- PC register ---
    PC_reg u_PC (
        .clk(clk), .rst(rst), .pc(pc), .pc_stall(pc_stall),
        .ex_redirect(ex_redirect), .ex_redirect_pc(ex_redirect_pc),
        .if_pred_redirect(if_pred_taken_raw), .if_pred_target(if_pred_target_raw)
    );

    // --- IF stage with 1KB FF IMEM ---
    wire [31:0] if_instr;
    reg  [31:0] if_pc;
    reg         if_pred_taken;
    reg  [31:0] if_pred_target;

    // ---- 1 KB FF-based instruction memory (256 x 32-bit) ----
    reg  [31:0] imem_ff [0:255];
    wire [31:0] imem_addr;
    reg  [31:0] imem_data_q;
    reg  [7:0]  imem_addr_q;
    assign imem_addr = pc;

    always @(posedge clk) begin
        if (!pc_stall)
            imem_addr_q <= imem_addr[9:2];           // 256 words: 8-bit word address
    end
    always @(negedge clk) begin
        if (rst)
            imem_data_q <= 32'h00000013;             // NOP after reset
        else
            imem_data_q <= imem_ff[imem_addr_q];
    end

    assign if_instr = imem_data_q;
    assign instr    = imem_data_q;

    always @(posedge clk) begin
        if (rst) begin
            if_pc          <= 32'b0;
            if_pred_taken  <= 1'b0;
            if_pred_target <= 32'b0;
        end else if (!pc_stall) begin
            if_pc          <= pc;
            if_pred_taken  <= if_pred_taken_raw;
            if_pred_target <= if_pred_target_raw;
        end
    end

    // --- IF/ID pipeline register ---
    wire [31:0] id_pc, id_instr;
    wire        id_pred_taken;
    wire [31:0] id_pred_target;

    IF_ID u_if_id (
        .clk(clk), .rst(rst), .id_stall(id_stall), .ifid_flush(ifid_flush),
        .if_pc(if_pc), .if_instr(if_instr),
        .if_pred_taken(if_pred_taken), .if_pred_target(if_pred_target),
        .id_pc(id_pc), .id_instr(id_instr),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target)
    );

    // --- ID stage ---
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire       reg_write_d, mem_read_d, mem_write_d;
    wire       branch_d, jal_d, jalr_d;
    wire [2:0] branch_op_d;
    wire [4:0] alu_op_d;
    wire       alu_rs2_imm_d;
    wire [1:0] wb_sel_d;
    wire       use_pc_add_d;
    wire       load_signed_d;
    wire [1:0] load_size_d;
    wire [1:0] store_size_d;
    wire       id_ecall, id_ebreak, id_fence;

    ID u_ID (
        .inst(id_instr), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rd_addr(rd_addr), .imm_type(imm_type), .funct3(funct3),
        .funct7(funct7), .reg_write(reg_write_d), .mem_read(mem_read_d),
        .mem_write(mem_write_d), .branch(branch_d), .jal(jal_d),
        .jalr(jalr_d), .branch_op(branch_op_d), .alu_op(alu_op_d),
        .alu_rs2_imm(alu_rs2_imm_d), .wb_sel(wb_sel_d),
        .use_pc_add(use_pc_add_d), .load_size(load_size_d),
        .load_signed(load_signed_d), .store_size(store_size_d),
        .ecall(id_ecall), .ebreak(id_ebreak), .fence(id_fence)
    );

    // --- WB signals ---
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_data_final;
    wire        wb_wen_final;

    // --- Register file ---
    wire [31:0] id_rs1_val, id_rs2_val;
    reg_file u_regfile (
        .clk(clk), .rst(rst), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rd_addr(wb_rd_addr), .rd_data(wb_data_final), .rd_wen(wb_wen_final),
        .rs1_data(id_rs1_val), .rs2_data(id_rs2_val)
    );

    // --- Immediate generator ---
    wire [31:0] id_imm;
    immgen u_immgen (.inst(id_instr), .imm_type(imm_type), .imm(id_imm));

    // --- CSR detection ---
    wire        csr_hit_id;
    wire [11:0] csr_addr_id;
    csr_read u_csr_read (.instr(id_instr), .csr_hit(csr_hit_id), .csr_addr(csr_addr_id));

    wire        ex_csr_hit;
    wire [11:0] ex_csr_addr;
    wire        mem_csr_hit;
    wire [11:0] mem_csr_addr;
    wire        wb_csr_hit;
    wire [11:0] wb_csr_addr;

    // --- ID/EX pipeline register ---
    wire [31:0] ex_pc, ex_rs1_val, ex_rs2_val, ex_imm;
    wire [31:0] ex_pred_target;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_branch, ex_jal, ex_jalr;
    wire        ex_pred_taken;
    wire [2:0]  ex_branch_op;
    wire [4:0]  ex_alu_op;
    wire        ex_alu_rs2_is_imm, ex_use_pc_add, ex_load_signed;
    wire [1:0]  ex_wb_sel, ex_load_size, ex_store_size;
    wire        ex_ecall, ex_ebreak, ex_fence;

    // muldiv_stall for ENABLE_TIMING_MULDIV
    wire muldiv_stall;

    ID_EX u_id_ex (
        .clk(clk), .rst(rst), .idex_flush(idex_flush), .idex_stall(muldiv_stall),
        .id_pc(id_pc), .id_rs1_val(id_rs1_val), .id_rs2_val(id_rs2_val),
        .id_imm(id_imm), .id_rs1_addr(rs1_addr), .id_rs2_addr(rs2_addr),
        .id_rd_addr(rd_addr), .id_reg_write(reg_write_d),
        .id_mem_read(mem_read_d), .id_mem_write(mem_write_d),
        .id_branch(branch_d), .id_jal(jal_d), .id_jalr(jalr_d),
        .id_branch_op(branch_op_d), .id_alu_op(alu_op_d),
        .id_alu_rs2_is_imm(alu_rs2_imm_d), .id_wb_sel(wb_sel_d),
        .id_use_pc_add(use_pc_add_d), .id_load_signed(load_signed_d),
        .id_load_size(load_size_d), .id_store_size(store_size_d),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target),
        .id_ebreak(id_ebreak), .id_ecall(id_ecall), .id_fence(id_fence),
        .id_csr_hit(csr_hit_id), .id_csr_addr(csr_addr_id),
        .ex_pc(ex_pc), .ex_rs1_val(ex_rs1_val), .ex_rs2_val(ex_rs2_val),
        .ex_imm(ex_imm), .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
        .ex_rd_addr(ex_rd_addr), .ex_reg_write(ex_reg_write),
        .ex_mem_read(ex_mem_read), .ex_mem_write(ex_mem_write),
        .ex_branch(ex_branch), .ex_jal(ex_jal), .ex_jalr(ex_jalr),
        .ex_branch_op(ex_branch_op), .ex_alu_op(ex_alu_op),
        .ex_alu_rs2_is_imm(ex_alu_rs2_is_imm), .ex_wb_sel(ex_wb_sel),
        .ex_use_pc_add(ex_use_pc_add), .ex_load_signed(ex_load_signed),
        .ex_load_size(ex_load_size), .ex_store_size(ex_store_size),
        .ex_csr_hit(ex_csr_hit), .ex_csr_addr(ex_csr_addr),
        .ex_ebreak(ex_ebreak), .ex_ecall(ex_ecall), .ex_fence(ex_fence),
        .ex_pred_taken(ex_pred_taken), .ex_pred_target(ex_pred_target)
    );

    // --- Forwarding ---
    wire [1:0] forward_a, forward_b;
    wire       ex_can_forward_d;
    reg        mem_can_forward_q;
    reg        mem2_can_forward_q;
    wire       wb_can_forward;

    wire [31:0] mem_load_data;

    reg        mem_mem_read_q;
    reg [31:0] mem_wb_candidate_q;
    reg [4:0]  mem_rd_addr_q;
    reg        mem_reg_write_q;
    reg [1:0]  mem_wb_sel_q;
    reg        mem_csr_hit_q;
    reg [11:0] mem_csr_addr_q;
    reg        mem_ebreak_q, mem_ecall_q, mem_fence_q;
    reg [31:0] mem_pc_q;

    assign ex_can_forward_d =
        ex_reg_write & ~ex_mem_read & ~ex_csr_hit & (ex_rd_addr != 5'd0) & ~muldiv_stall;
    assign wb_can_forward = wb_wen_final & (wb_rd_addr != 5'd0);

    always @(posedge clk) begin
        if (rst) begin
            mem_rd_addr_q      <= 5'd0;
            mem_reg_write_q    <= 1'b0;
            mem_wb_sel_q       <= 2'd0;
            mem_csr_hit_q      <= 1'b0;
            mem_csr_addr_q     <= 12'd0;
            mem_ebreak_q       <= 1'b0;
            mem_ecall_q        <= 1'b0;
            mem_fence_q        <= 1'b0;
            mem_mem_read_q     <= 1'b0;
            mem_can_forward_q  <= 1'b0;
            mem2_can_forward_q <= 1'b0;
        end else begin
            mem_rd_addr_q      <= mem_rd_addr;
            mem_reg_write_q    <= mem_reg_write;
            mem_wb_sel_q       <= mem_wb_sel;
            mem_csr_hit_q      <= mem_csr_hit;
            mem_csr_addr_q     <= mem_csr_addr;
            mem_ebreak_q       <= mem_ebreak;
            mem_ecall_q        <= mem_ecall;
            mem_fence_q        <= mem_fence;
            mem_mem_read_q     <= mem_mem_read;
            mem_can_forward_q  <= ex_can_forward_d;
            mem2_can_forward_q <= mem_reg_write & ~mem_csr_hit & (mem_rd_addr != 5'd0);
        end
    end

    always @(posedge clk) begin
        mem_wb_candidate_q <= mem_wb_candidate;
        mem_pc_q           <= mem_pc;
    end

    wire [31:0] mem2_forward_data;
    assign mem2_forward_data = mem_mem_read_q ? mem_load_data : mem_wb_candidate_q;

    forwarding_unit u_forwarding (
        .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
        .exmem_can_forward(mem_can_forward_q), .exmem_rd(mem_rd_addr),
        .mem2_can_forward(mem2_can_forward_q), .mem2_rd(mem_rd_addr_q),
        .memwb_can_forward(wb_can_forward), .memwb_rd(wb_rd_addr),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    wire [31:0] ex_rs1_fwd;
    wire [31:0] ex_rs2_fwd;
    assign ex_rs1_fwd = (forward_a == 2'b10) ? mem_wb_candidate :
                        (forward_a == 2'b11) ? mem2_forward_data :
                        (forward_a == 2'b01) ? wb_data_final : ex_rs1_val;
    assign ex_rs2_fwd = (forward_b == 2'b10) ? mem_wb_candidate :
                        (forward_b == 2'b11) ? mem2_forward_data :
                        (forward_b == 2'b01) ? wb_data_final : ex_rs2_val;

    // --- EX stage ---
    wire [31:0] ex_pc_plus4, ex_auipc_result;
    wire [31:0] ex_alu_result_raw, ex_branch_target;
    wire        ex_actual_taken;
    wire [31:0] ex_pc_imm_target_fast;
    assign ex_pc_imm_target_fast = ex_pc + ex_imm;

    EX u_EX (
        .pc(ex_pc), .rs1_data(ex_rs1_fwd), .rs2_data(ex_rs2_fwd),
        .imm(ex_imm), .alu_op(ex_alu_op), .alu_rs2_imm(ex_alu_rs2_is_imm),
        .branch(ex_branch), .branch_op(ex_branch_op), .jal(ex_jal),
        .jalr(ex_jalr), .alu_core_result(ex_alu_result_raw),
        .pc_plus4(ex_pc_plus4), .auipc_result(ex_auipc_result),
        .branch_target(ex_branch_target), .branch_taken(ex_actual_taken)
    );

    // --- Optional timing-friendly registered MUL ---
    wire        ex_is_mul_op;
    wire [2:0]  muldiv_op;
    wire        muldiv_start;
    wire        muldiv_busy;
    wire        muldiv_done;
    wire [31:0] muldiv_result;
    wire [31:0] ex_alu_result;

    assign ex_is_mul_op =
        (ex_alu_op == ALU_MUL) | (ex_alu_op == ALU_MULH) |
        (ex_alu_op == ALU_MULHSU) | (ex_alu_op == ALU_MULHU);

    assign muldiv_op =
        (ex_alu_op == ALU_MULH)   ? 3'd1 :
        (ex_alu_op == ALU_MULHSU) ? 3'd2 :
        (ex_alu_op == ALU_MULHU)  ? 3'd3 : 3'd0;

`ifdef ENABLE_TIMING_MULDIV
    assign muldiv_start = ex_is_mul_op & ~muldiv_busy & ~muldiv_done;
    assign muldiv_stall = ex_is_mul_op & ~muldiv_done;

    rv32_muldiv_unit u_muldiv (
        .clk(clk), .rst(rst), .start(muldiv_start), .op(muldiv_op),
        .rs1(ex_rs1_fwd), .rs2(ex_rs2_fwd),
        .busy(muldiv_busy), .done(muldiv_done), .result(muldiv_result)
    );
    assign ex_alu_result = ex_is_mul_op ? muldiv_result : ex_alu_result_raw;
`else
    assign muldiv_start  = 1'b0;
    assign muldiv_busy   = 1'b0;
    assign muldiv_done   = 1'b0;
    assign muldiv_result = 32'b0;
    assign muldiv_stall  = 1'b0;
    assign ex_alu_result = ex_alu_result_raw;
`endif

    // --- Predictors ---
    wire        ex_jal_call;
    wire        ex_jalr_call;
    wire        ex_jalr_return;
    wire        ex_jalr_mispredict;
    wire        ex_dir_mispredict;
    wire        ex_tgt_mispredict;
    wire        ex_is_ctrl;
    wire        ex_false_pred_nonctrl;

    bht_2bit #(.INDEX_BITS(BHT_INDEX_BITS)) u_bht (
        .clk(clk), .rst(rst), .r_pc(pred_lookup_pc),
        .pred_taken(bht_pred_taken),
        .update_en(ex_branch),
        .u_pc(ex_pc), .actual_taken(ex_actual_taken)
    );

    btb_direct #(.INDEX_BITS(BTB_INDEX_BITS), .TAG_BITS(BTB_TAG_BITS)) u_btb (
        .clk(clk), .rst(rst), .r_pc(pred_lookup_pc),
        .hit(btb_hit), .pred_target(btb_pred_target),
        .pred_is_jump(btb_is_jump), .pred_is_return(btb_is_return),
        .update_en(ex_jal | (ex_branch & ex_actual_taken) | ex_jalr_return),
        .u_pc(ex_pc),
        .u_target(ex_jalr_return ? ex_branch_target : ex_pc_imm_target_fast),
        .u_is_jump(ex_jal), .u_is_return(ex_jalr_return)
    );

    ras_stack #(.DEPTH(RAS_DEPTH), .PTR_BITS(RAS_PTR_BITS)) u_ras (
        .clk(clk), .rst(rst), .top_valid(ras_top_valid),
        .top_addr(ras_top_addr),
        .push(ex_jal_call | ex_jalr_call), .push_addr(ex_pc_plus4),
        .pop(ex_jalr_return)
    );

    wire [31:0] ex_wb_candidate =
        ex_use_pc_add ? ex_auipc_result :
        (ex_wb_sel == 2'b0)  ? ex_alu_result :
        (ex_wb_sel == 2'b10) ? ex_pc_plus4 :
        (ex_wb_sel == 2'b11) ? ex_imm : ex_alu_result;

    assign ex_dir_mispredict = (ex_actual_taken != ex_pred_taken);
    assign ex_tgt_mispredict = (ex_branch | ex_jal) & ex_actual_taken &
        ex_pred_taken & (ex_pc_imm_target_fast != ex_pred_target);
    assign ex_is_ctrl = ex_branch | ex_jal | ex_jalr;
    assign ex_false_pred_nonctrl = ex_pred_taken & ~ex_is_ctrl;

    assign ex_jalr_mispredict = ex_jalr &
        (~ex_pred_taken | (ex_pred_target != ex_branch_target));

    assign ex_redirect =
        ex_false_pred_nonctrl ? 1'b1 :
        ex_jalr               ? ex_jalr_mispredict :
        (ex_branch | ex_jal)  ? (ex_dir_mispredict | ex_tgt_mispredict) : 1'b0;

    assign ex_redirect_pc =
        ex_false_pred_nonctrl ? ex_pc_plus4 :
        ex_jalr               ? ex_branch_target :
        ex_actual_taken       ? ex_pc_imm_target_fast : ex_pc_plus4;

    wire ex_rd_is_link;
    wire ex_rs1_is_link;
    assign ex_rd_is_link  = (ex_rd_addr == 5'd1) | (ex_rd_addr == 5'd5);
    assign ex_rs1_is_link = (ex_rs1_addr == 5'd1) | (ex_rs1_addr == 5'd5);
    assign ex_jal_call    = ex_jal  & ex_rd_is_link;
    assign ex_jalr_call   = ex_jalr & ex_rd_is_link;
    assign ex_jalr_return = ex_jalr & ex_rs1_is_link & (ex_rd_addr == 5'd0);

    // --- EX/MEM pipeline register ---
    wire [31:0] mem_pc, mem_alu_result, mem_rs2_val_for_store, mem_wb_candidate;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_load_signed;
    wire [1:0]  mem_wb_sel, mem_load_size, mem_store_size;
    wire        mem_ecall, mem_ebreak, mem_fence;

    wire ex_to_mem_bubble = muldiv_stall;
    wire [31:0] ex_mem_pc_in           = ex_to_mem_bubble ? 32'b0 : ex_pc;
    wire [31:0] ex_mem_alu_result_in   = ex_to_mem_bubble ? 32'b0 : ex_alu_result;
    wire [31:0] ex_mem_rs2_store_in    = ex_to_mem_bubble ? 32'b0 : ex_rs2_fwd;
    wire [4:0]  ex_mem_rd_addr_in      = ex_to_mem_bubble ? 5'b0  : ex_rd_addr;
    wire        ex_mem_reg_write_in    = ex_to_mem_bubble ? 1'b0  : ex_reg_write;
    wire        ex_mem_mem_read_in     = ex_to_mem_bubble ? 1'b0  : ex_mem_read;
    wire        ex_mem_mem_write_in    = ex_to_mem_bubble ? 1'b0  : ex_mem_write;
    wire [1:0]  ex_mem_wb_sel_in       = ex_to_mem_bubble ? 2'b0  : ex_wb_sel;
    wire [1:0]  ex_mem_load_size_in    = ex_to_mem_bubble ? 2'b10 : ex_load_size;
    wire [1:0]  ex_mem_store_size_in   = ex_to_mem_bubble ? 2'b10 : ex_store_size;
    wire        ex_mem_load_signed_in  = ex_to_mem_bubble ? 1'b1  : ex_load_signed;
    wire [31:0] ex_mem_wb_candidate_in = ex_to_mem_bubble ? 32'b0 : ex_wb_candidate;
    wire        ex_mem_csr_hit_in      = ex_to_mem_bubble ? 1'b0  : ex_csr_hit;
    wire [11:0] ex_mem_csr_addr_in     = ex_to_mem_bubble ? 12'b0 : ex_csr_addr;
    wire        ex_mem_ecall_in        = ex_to_mem_bubble ? 1'b0  : ex_ecall;
    wire        ex_mem_ebreak_in       = ex_to_mem_bubble ? 1'b0  : ex_ebreak;
    wire        ex_mem_fence_in        = ex_to_mem_bubble ? 1'b0  : ex_fence;

    EX_MEM u_ex_mem (
        .clk(clk), .rst(rst),
        .ex_ebreak(ex_mem_ebreak_in), .ex_ecall(ex_mem_ecall_in),
        .ex_fence(ex_mem_fence_in), .ex_pc(ex_mem_pc_in),
        .ex_alu_result(ex_mem_alu_result_in),
        .ex_rs2_val_for_store(ex_mem_rs2_store_in),
        .ex_rd_addr(ex_mem_rd_addr_in),
        .ex_reg_write(ex_mem_reg_write_in),
        .ex_mem_read(ex_mem_mem_read_in),
        .ex_mem_write(ex_mem_mem_write_in),
        .ex_wb_sel(ex_mem_wb_sel_in),
        .ex_load_size(ex_mem_load_size_in),
        .ex_store_size(ex_mem_store_size_in),
        .ex_load_signed(ex_mem_load_signed_in),
        .ex_wb_candidate(ex_mem_wb_candidate_in),
        .ex_csr_hit(ex_mem_csr_hit_in),
        .ex_csr_addr(ex_mem_csr_addr_in),
        .mem_pc(mem_pc), .mem_alu_result(mem_alu_result),
        .mem_rs2_val_for_store(mem_rs2_val_for_store),
        .mem_rd_addr(mem_rd_addr), .mem_reg_write(mem_reg_write),
        .mem_mem_read(mem_mem_read), .mem_mem_write(mem_mem_write),
        .mem_wb_sel(mem_wb_sel), .mem_load_size(mem_load_size),
        .mem_store_size(mem_store_size), .mem_load_signed(mem_load_signed),
        .mem_wb_candidate(mem_wb_candidate),
        .mem_csr_hit(mem_csr_hit), .mem_csr_addr(mem_csr_addr),
        .mem_ebreak(mem_ebreak), .mem_ecall(mem_ecall), .mem_fence(mem_fence)
    );

    // --- 1 KB FF-based data memory (256 x 32-bit) ---
    reg [31:0] dmem_ff [0:255];
    wire       in_dmem;
    wire [7:0] dmem_word_addr;
    assign dmem_word_addr = mem_alu_result[9:2];    // 256 words: 8-bit word address
    assign in_dmem        = (mem_alu_result[31:10] == 22'h0400);

    function automatic [31:0] apply_store_to_word;
        input [31:0] old_word, store_data;
        input [1:0]  st_size, bsel;
        reg [31:0] w;
        begin
            w = old_word;
            case (st_size)
                2'b00: case (bsel)
                    2'b00: w[7:0] = store_data[7:0];
                    2'b01: w[15:8] = store_data[7:0];
                    2'b10: w[23:16] = store_data[7:0];
                    2'b11: w[31:24] = store_data[7:0];
                endcase
                2'b01: case (bsel[1])
                    1'b0: w[15:0] = store_data[15:0];
                    1'b1: w[31:16] = store_data[15:0];
                endcase
                default: w = store_data;
            endcase
            apply_store_to_word = w;
        end
    endfunction

    reg        mem_read_q, mem_write_q;
    reg [31:0] addr_q, rs2_q;
    reg        load_signed_q;
    reg [1:0]  load_size_q, store_size_q;

    always @(posedge clk) begin
        mem_read_q    <= mem_mem_read;
        mem_write_q   <= mem_mem_write;
        addr_q        <= mem_alu_result;
        rs2_q         <= mem_rs2_val_for_store;
        load_signed_q <= mem_load_signed;
        load_size_q   <= mem_load_size;
        store_size_q  <= mem_store_size;
    end

    wire [7:0]  index_q    = addr_q[9:2];
    wire [1:0]  byte_sel_q = addr_q[1:0];
    wire        in_dmem_q  = (addr_q[31:10] == 22'h0400);

    reg [31:0] dmem_word_before, dmem_word_effective;
    reg [7:0]  dmem_sel_b;
    reg [15:0] dmem_sel_h;

    always @(negedge clk) begin
        dmem_word_before    = dmem_ff[index_q];
        dmem_word_effective = dmem_word_before;

        if (mem_write_q && in_dmem_q) begin
            dmem_word_effective = apply_store_to_word(dmem_word_before, rs2_q, store_size_q, byte_sel_q);
            dmem_ff[index_q] <= dmem_word_effective;
        end

        if (mem_read_q && in_dmem_q) begin
            case (byte_sel_q)
                2'b00: dmem_sel_b = dmem_word_effective[7:0];
                2'b01: dmem_sel_b = dmem_word_effective[15:8];
                2'b10: dmem_sel_b = dmem_word_effective[23:16];
                default: dmem_sel_b = dmem_word_effective[31:24];
            endcase
            case (byte_sel_q[1])
                1'b0: dmem_sel_h = dmem_word_effective[15:0];
                1'b1: dmem_sel_h = dmem_word_effective[31:16];
            endcase
            case (load_size_q)
                2'b00: mem_load_data <= load_signed_q ? {{24{dmem_sel_b[7]}}, dmem_sel_b} : {24'b0, dmem_sel_b};
                2'b01: mem_load_data <= load_signed_q ? {{16{dmem_sel_h[15]}}, dmem_sel_h} : {16'b0, dmem_sel_h};
                default: mem_load_data <= dmem_word_effective;
            endcase
        end
    end

    // --- MEM/WB pipeline register ---
    wire [31:0] wb_wb_candidate, wb_load_data;
    wire        wb_reg_write;
    wire [1:0]  wb_wb_sel;
    wire        wb_ecall, wb_ebreak, wb_fence;
    wire        ebreak_q, ecall_q, fence_q;

    MEM_WB u_mem_wb (
        .clk(clk), .rst(rst),
        .mem_pc(mem_pc_q), .mem_wb_candidate(mem_wb_candidate_q),
        .mem_load_data(mem_load_data), .mem_rd_addr(mem_rd_addr_q),
        .mem_reg_write(mem_reg_write_q), .mem_wb_sel(mem_wb_sel_q),
        .mem_csr_hit(mem_csr_hit_q), .mem_csr_addr(mem_csr_addr_q),
        .mem_ebreak(mem_ebreak_q), .mem_ecall(mem_ecall_q),
        .mem_fence(mem_fence_q),
        .wb_wb_candidate(wb_wb_candidate), .wb_load_data(wb_load_data),
        .wb_rd_addr(wb_rd_addr), .wb_reg_write(wb_reg_write),
        .wb_wb_sel(wb_wb_sel),
        .wb_csr_hit(wb_csr_hit), .wb_csr_addr(wb_csr_addr),
        .wb_ebreak(wb_ebreak), .wb_ecall(wb_ecall), .wb_fence(wb_fence),
        .ebreak_q(ebreak_q), .ecall_q(ecall_q), .fence_q(fence_q)
    );

    // --- WB stage ---
    wire [31:0] wb_wb_data_core;
    wire        wb_mem_to_reg;
    assign wb_mem_to_reg   = wb_wb_sel[0] & ~wb_wb_sel[1];
    assign wb_wb_data_core = wb_mem_to_reg ? wb_load_data : wb_wb_candidate;

    assign wb_data_final = wb_csr_hit ? 32'd0 : wb_wb_data_core;
    assign wb_wen_final  = wb_csr_hit | wb_reg_write;

    // --- Hazard unit ---
    wire        hazard_if_stall;
    wire        hazard_id_stall;
    wire        hazard_ifid_flush;
    wire        hazard_idex_flush;

    assign if_stall   = hazard_if_stall | muldiv_stall;
    assign id_stall   = hazard_id_stall | muldiv_stall;
    assign ifid_flush = hazard_ifid_flush;
    assign idex_flush = hazard_idex_flush;

    hazard_unit u_hazard (
        .id_rs1(rs1_addr), .id_rs2(rs2_addr), .clk(clk), .rst(rst),
        .idex_mem_read(ex_mem_read), .idex_rd(ex_rd_addr),
        .idex_csr_hit(ex_csr_hit),
        .exmem_rd(mem_rd_addr), .exmem_csr_hit(mem_csr_hit),
        .ex_redirect(ex_redirect),
        .stall_if(hazard_if_stall), .stall_id(hazard_id_stall),
        .flush_ifid(hazard_ifid_flush), .flush_idex(hazard_idex_flush)
    );

    assign ebreak_pulse = ebreak_q;
    assign ecall_pulse  = ecall_q;

endmodule
