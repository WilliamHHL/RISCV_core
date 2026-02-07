module top (
    input clk,
    input rst,
    output [31:0] pc,
    output [31:0] instr,
    output  ebreak_pulse,
    output ecall_pulse
);

    
    // IF: PC register and next-PC selection happens later (EX redirect + stall)
    wire [31:0] pc_next;
    wire pc_stall;
    assign pc_stall = if_stall||id_stall;

    PC_reg u_PC (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_stall(pc_stall),
        .ex_branch_target(ex_branch_target),
        .ex_redirect_taken(ex_redirect_taken)
    );
    assign instr = if_instr;

    // IF: instruction fetch
    wire [31:0] if_instr, if_pc;
    IF u_if (
        .clk     (clk),
        .rst     (rst),
        .pc      (pc),
        .if_stall(pc_stall),
        .instr   (if_instr),
        .if_pc   (if_pc),
        .if_flush(ifid_flush)
    );

    // IF/ID pipeline register
    wire        if_stall, id_stall, ifid_flush, idex_flush;
    wire [31:0] id_pc, id_instr;
    IF_ID u_if_id (
        .clk(clk),
        .rst(rst),
        .id_stall(id_stall),
        .ifid_flush(ifid_flush),
        .if_pc(if_pc),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_instr(id_instr)
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
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_branch, ex_jal, ex_jalr;
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
        .id_ebreak(id_ebreak),
        .id_ecall(id_ecall),
        .id_fence(id_fence),

        .id_csr_hit(csr_hit_id),
        .id_csr_addr(csr_addr_id),      // Changed: addr instead of data

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
        .ex_csr_addr(ex_csr_addr),      // Changed: addr instead of data
        .ex_ebreak(ex_ebreak),
        .ex_ecall(ex_ecall),
        .ex_fence(ex_fence)
    );

    // Forwarding unit controls
    wire [1:0] forward_a, forward_b;
    
    // MEM2 delay registers
    reg        mem_mem_read_q;
    reg [31:0] mem_wb_candidate_q;
    reg [4:0]  mem_rd_addr_q;
    reg        mem_reg_write_q;
    reg [1:0]  mem_wb_sel_q;
    reg        mem_csr_hit_q;
    reg [11:0] mem_csr_addr_q;          // Changed: 12-bit addr instead of 32-bit data
    reg        mem_ebreak_q, mem_ecall_q, mem_fence_q;
    reg [31:0] mem_pc_q;
    
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_candidate_q <= 32'b0;
            mem_rd_addr_q      <= 5'd0;
            mem_reg_write_q    <= 1'b0;
            mem_wb_sel_q       <= 2'd0;
            mem_csr_hit_q      <= 1'b0;
            mem_csr_addr_q     <= 12'd0;    // Changed
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
            mem_csr_addr_q     <= mem_csr_addr;    // Changed
            mem_ebreak_q       <= mem_ebreak;
            mem_ecall_q        <= mem_ecall;
            mem_fence_q        <= mem_fence;
            mem_pc_q           <= mem_pc;
            mem_mem_read_q     <= mem_mem_read;
        end
    end

    // MEM2 forwarding data
    wire mem2_is_load = mem_mem_read_q;
    wire [31:0] mem2_forward_data = mem2_is_load ? mem_load_data : mem_wb_candidate_q;

    // Forwarding unit
    forwarding_unit u_forwarding (
        .ex_rs1_addr     (ex_rs1_addr),
        .ex_rs2_addr     (ex_rs2_addr),
        .exmem_reg_write (mem_reg_write),
        .exmem_mem_read  (mem_mem_read),
        .exmem_csr_hit   (mem_csr_hit),           // NEW
        .exmem_rd        (mem_rd_addr),
        .mem2_reg_write  (mem_reg_write_q),
        .mem2_csr_hit    (mem_csr_hit_q),         // NEW
        .mem2_rd         (mem_rd_addr_q),
        .memwb_reg_write (wb_wen_final),          // CHANGED from wb_reg_write
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
    wire        ex_redirect_taken;

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
        .branch_taken(ex_redirect_taken)
    );

    // WB candidate selection in EX
    wire [31:0] ex_wb_candidate =
        ex_use_pc_add ? ex_auipc_result :
        (ex_wb_sel == 2'b0) ? ex_alu_result :
        (ex_wb_sel == 2'b10) ? ex_pc_plus4 :
        (ex_wb_sel == 2'b11) ? ex_imm : ex_alu_result;

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
        .ex_csr_addr(ex_csr_addr),          // Changed: addr instead of data

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
        .mem_csr_addr(mem_csr_addr),        // Changed: addr instead of data
        .mem_ebreak(mem_ebreak),
        .mem_ecall(mem_ecall),
        .mem_fence(mem_fence)
    );

    // MEM stage
    wire [31:0] mem_load_data;
    
    reg [31:0] mem_load_data_negedge;
    reg [31:0] mem_load_data_posedge;

    always @(negedge clk) begin
        mem_load_data_negedge <= mem_load_data;
    end

    always @(posedge clk) begin
        if (rst) mem_load_data_posedge <= 32'b0;
        else     mem_load_data_posedge <= mem_load_data_negedge;
    end
    
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
    wire [4:0]  wb_rd_addr;
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
        .mem_csr_addr(mem_csr_addr_q),      // Changed: addr instead of data
        .mem_ebreak(mem_ebreak_q),
        .mem_ecall(mem_ecall_q),
        .mem_fence(mem_fence_q),

        .wb_wb_candidate(wb_wb_candidate),
        .wb_load_data(wb_load_data),
        .wb_rd_addr(wb_rd_addr),
        .wb_reg_write(wb_reg_write),
        .wb_wb_sel(wb_wb_sel),
        .wb_csr_hit(wb_csr_hit),
        .wb_csr_addr(wb_csr_addr),          // Changed: addr instead of data
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
        .cycle_cnt(cycle_cnt),      // Current value from top, not pipelined!
        .csr_hit(wb_csr_hit),
        .csr_data(wb_csr_data_live)
    );

    // Final write-back: use live CSR data when CSR hit
    wire [31:0] wb_data_final = wb_csr_hit ? wb_csr_data_live : wb_wb_data_core;
    wire        wb_wen_final  = wb_csr_hit ? 1'b1 : wb_reg_write;

    // Hazard unit
    // Hazard unit - add CSR signals
    hazard_unit u_hazard (
        .id_rs1 (rs1_addr),
        .id_rs2 (rs2_addr),
        .clk(clk),
        .rst(rst),

        .idex_mem_read   (ex_mem_read),
        .idex_rd         (ex_rd_addr),
        .idex_reg_write  (ex_reg_write),
        .idex_csr_hit    (ex_csr_hit),      // NEW

        .exmem_reg_write (mem_reg_write),
        .exmem_rd        (mem_rd_addr),
        .exmem_csr_hit   (mem_csr_hit),     // NEW

        .memwb_reg_write (wb_wen_final),    // CHANGED: use wb_wen_final instead of wb_reg_write
        .memwb_rd        (wb_rd_addr),

        .ex_redirect     (ex_redirect_taken),

        .stall_if        (if_stall),
        .stall_id        (id_stall),
        .flush_ifid      (ifid_flush),
        .flush_idex      (idex_flush)
    );

    // ECALL/EBREAK pulses
    assign ebreak_pulse = ebreak_q;
    assign ecall_pulse  = ecall_q; 

    always @(posedge clk) begin
        if (!rst) begin
            if (ecall_q) begin
                $display("ECALL at PC=%08x", pc);
                $finish;
            end
            if (ebreak_q) begin
                $display("EBREAK at PC=%08x", pc);
                $display("Final_mem_PC=%08x", mem_pc);
                $finish;
            end
        end
    end

endmodule