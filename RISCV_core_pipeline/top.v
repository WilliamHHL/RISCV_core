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

    /*
    // 1-cycle delayed hold for IF stage
    reg if_hold;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_hold <= 1'b0;
        end else begin
            if_hold <= if_stall;  // 下一拍才真正 hold IF 的輸出
        end
    end
    */
    PC_reg u_PC (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        //.pc_next(pc_next),
        .pc_stall(pc_stall),
        .ex_branch_target(ex_branch_target),
        .ex_redirect_taken(ex_redirect_taken)
    );
    assign instr = if_instr; // expose current fetched instruction for observation
    // IF: instruction fetch (synchronous in this version)
    wire [31:0] if_instr,if_pc;
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
    // - Handles stall and flush from hazard/branch unit
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

    // ID: decode stage control/data outputs (suffix _d indicates ID stage)
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire       reg_write_d, mem_read_d, mem_write_d;
    wire       branch_d, jal_d, jalr_d;
    wire [2:0] branch_op_d;
    wire [3:0] alu_op_d;
    wire       alu_rs2_imm_d;
    wire [1:0] wb_sel_d;      // 00:ALU 01:MEM 10:PC+4 11:IMM
    wire       use_pc_add_d;  // AUIPC: use pc+imm on ALU-side path
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

    // Register file reads in ID; writes happen in WB
    wire [31:0] id_rs1_val, id_rs2_val;
    reg_file u_regfile (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(wb_rd_addr),
        .rd_data(wb_data_final),  // final WB data (after CSR override)
        .rd_wen(wb_wen_final),    // final WB enable
        .rs1_data(id_rs1_val),
        .rs2_data(id_rs2_val)
    );

    // Immediate generator (ID)
    wire [31:0] id_imm;
    immgen u_immgen (
        .inst(id_instr),
        .imm_type(imm_type),
        .imm(id_imm)
    );

    // CSR read in ID; carried down to WB where it overrides normal WB when hit
    reg [63:0] cycle_cnt; // mcycle
    always @(posedge clk /*or posedge rst*/) begin
        if (rst) cycle_cnt <= 64'd0;
        else     cycle_cnt <= cycle_cnt + 1'b1;
    end
    wire        csr_hit_id;
    wire [31:0] csr_data_id;
    csr_read u_csr_read (
        .instr(id_instr),
        .cycle_cnt(cycle_cnt),
        .csr_hit(csr_hit_id),
        .csr_data(csr_data_id)
    );

    // ID/EX pipeline register: latches operands, immediates, and all control signals into EX
    wire [31:0] ex_pc, ex_rs1_val, ex_rs2_val, ex_imm;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_branch, ex_jal, ex_jalr;
    wire [2:0]  ex_branch_op;
    wire [3:0]  ex_alu_op;
    wire        ex_alu_rs2_is_imm, ex_use_pc_add, ex_load_signed;
    wire [1:0]  ex_wb_sel, ex_load_size, ex_store_size;
    wire        ex_csr_hit;
    wire [31:0] ex_csr_data;
    wire       ex_ecall, ex_ebreak, ex_fence;



    ID_EX u_id_ex (
        .clk(clk),
        .rst(rst),
        .idex_flush(idex_flush), // flush on redirect/exception

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
        .id_csr_data(csr_data_id),

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
        .ex_csr_data(ex_csr_data),
        .ex_ebreak(ex_ebreak),
        .ex_ecall(ex_ecall),
        .ex_fence(ex_fence)

    );

    // Forwarding unit controls
    wire [1:0] forward_a, forward_b;

    forwarding_unit u_forwarding (
        .ex_rs1_addr     (ex_rs1_addr),
        .ex_rs2_addr     (ex_rs2_addr),
        .exmem_reg_write (mem_reg_write),
        .exmem_rd        (mem_rd_addr),
        // Use final WB write enable for MEM/WB, including CSR hits
        .memwb_reg_write (wb_wen_final),
        .memwb_rd        (wb_rd_addr),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );


    // Forwarded values for rs1, rs2 before IMM selection
    wire [31:0] ex_rs1_fwd;
    wire [31:0] ex_rs2_fwd;

    // Data sources:
    // - ID/EX: ex_rs* _val
    // - EX/MEM: mem_wb_candidate (ALU/AUIPC/JAL data already selected)
    // - MEM/WB: wb_data_final   (final value written back, including CSR)
    assign ex_rs1_fwd = (forward_a == 2'b10) ? mem_wb_candidate : // from EX_MEM forward to EX
                        (forward_a == 2'b01) ? wb_data_final : ex_rs1_val;//from MEM_WB to EX

    assign ex_rs2_fwd = (forward_b == 2'b10) ? mem_wb_candidate :
                        (forward_b == 2'b01) ? wb_data_final : ex_rs2_val;

    // Final ALU operands
    wire [31:0] ex_rs1_val_to_alu = ex_rs1_fwd;
    wire [31:0] ex_rs2_val_to_alu = ex_alu_rs2_is_imm ? ex_imm : ex_rs2_fwd;
    // EX: operand selection without forwarding
    /*wire [31:0] ex_rs1_val_to_alu = ex_rs1_val;
    wire [31:0] ex_rs2_val_to_alu = ex_alu_rs2_is_imm ? ex_imm : ex_rs2_val;*/

    // EX: ALU, branch/jump resolution (produces redirect and next PC+4/AUIPC)
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
        .funct3(funct3),
        .funct7(funct7),
        .alu_core_result(ex_alu_result),
        .pc_plus4(ex_pc_plus4),
        .auipc_result(ex_auipc_result),
        .branch_target(ex_branch_target),
        .branch_taken(ex_redirect_taken)
    );

    // ALU-side write-back candidate (selected in EX):
    // - use_pc_add: AUIPC (pc+imm)
    // - wb_sel: 00 ALU, 10 PC+4 (JAL/JALR link), 11 IMM (LUI)
    wire [31:0] ex_wb_candidate =
        ex_use_pc_add ? ex_auipc_result :
        (ex_wb_sel == 2'b0) ? ex_alu_result :
        (ex_wb_sel == 2'b10) ? ex_pc_plus4 :
        (ex_wb_sel == 2'b11) ? ex_imm : ex_alu_result;

    // Next PC selection:
   // wire [31:0] pc_redirect = ex_redirect_taken ? ex_branch_target : ex_pc_plus4;//pc + 32'd4;
    //assign pc_next = pc_redirect; //if_stall ? pc : pc_redirect;

    // EX/MEM pipeline register: carries ALU result, store data, and WB/MEM controls
    wire [31:0] mem_pc, mem_alu_result, mem_rs2_val_for_store, mem_wb_candidate;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_load_signed, mem_csr_hit;
    wire [1:0]  mem_wb_sel, mem_load_size, mem_store_size;
    wire [31:0] mem_csr_data;
    wire       mem_ecall, mem_ebreak, mem_fence;
    EX_MEM u_ex_mem (
        .clk(clk),
        .rst(rst),
        
        .ex_ebreak(ex_ebreak),
        .ex_ecall(ex_ecall),
        .ex_fence(ex_fence),
        .ex_pc(ex_pc),
        .ex_alu_result(ex_alu_result),
        .ex_rs2_val_for_store(ex_rs2_fwd), // store uses RS2 as latched in EX
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
        .ex_csr_data(ex_csr_data),

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
        .mem_csr_data(mem_csr_data),
        .mem_ebreak(mem_ebreak),
        .mem_ecall(mem_ecall),
        .mem_fence(mem_fence)
    );

    // MEM: data memory access and load data assembly (byte/half/word, sign/zero-extend)
    wire [31:0] mem_load_data;
    MEM u_MEM (
        .clk(clk),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .alu_result(mem_alu_result),      // address for LW/SW
        .rs2_data(mem_rs2_val_for_store), // no store-data forwarding
        .mem_data(mem_load_data),
        .load_signed(mem_load_signed),
        .load_size(mem_load_size),
        .store_size(mem_store_size)
    );

    // MEM/WB pipeline register
    // - Carries ALU/MEM candidates and CSR info to WB
    wire [31:0] wb_wb_candidate, wb_load_data, wb_csr_data;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write, wb_csr_hit;
    wire [1:0]  wb_wb_sel;
    wire       wb_ecall, wb_ebreak, wb_fence;
    wire ebreak_q,ecall_q,fence_q;
    


    MEM_WB u_mem_wb (
        .clk(clk),
        .rst(rst),
        .mem_pc(mem_pc),
        .mem_wb_candidate(mem_wb_candidate),
        .mem_load_data(mem_load_data),
        .mem_rd_addr(mem_rd_addr),
        .mem_reg_write(mem_reg_write),
        .mem_wb_sel(mem_wb_sel),
        .mem_csr_hit(mem_csr_hit),
        .mem_csr_data(mem_csr_data),
        .mem_ebreak(mem_ebreak),
        .mem_ecall(mem_ecall),
        .mem_fence(mem_fence),

        .wb_wb_candidate(wb_wb_candidate),
        .wb_load_data(wb_load_data),
        .wb_rd_addr(wb_rd_addr),
        .wb_reg_write(wb_reg_write),
        .wb_wb_sel(wb_wb_sel),
        .wb_csr_hit(wb_csr_hit),
        .wb_csr_data(wb_csr_data),
        .wb_ebreak(wb_ebreak),
        .wb_ecall(wb_ecall),
        .wb_fence(wb_fence),
        .ebreak_q,
        .ecall_q,
        .fence_q
    );

    // WB: core WB mux (MEM vs ALU-side), then CSR overrides when hit
    wire [31:0] wb_wb_data_core;
    WB u_WB (
        .mem_to_reg(wb_wb_sel == 2'd1),
        .alu_result(wb_wb_candidate),
        .mem_data(mem_load_data),//dont use the wb_load_data:dmem timing
        .wb_data(wb_wb_data_core)
    );
    /*
    `ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!rst && wb_wen_final && (wb_rd_addr != 0)) begin
            $display("WB: pc=%08x rd=x%0d data=%08x sel=%0d csr_hit=%0d",
                    mem_pc, wb_rd_addr, wb_data_final, wb_wb_sel, wb_csr_hit);
        end
    end
    `endif
    */
    // Final write-back signals to regfile
    wire [31:0] wb_data_final = wb_csr_hit ? wb_csr_data : wb_wb_data_core;//the wb_data_final is connected to the regfile's rd_data
    wire        wb_wen_final  = wb_csr_hit ? 1'b1        : wb_reg_write;

    // Hazard unit (stall-only, no forwarding)
    hazard_unit u_hazard (
        // ID stage sources
        .id_rs1 (rs1_addr),
        .id_rs2 (rs2_addr),
        .clk(clk),
        .rst(rst),

        // ID/EX (EX stage current)
        .idex_mem_read   (ex_mem_read),
        .idex_rd         (ex_rd_addr),
        .idex_reg_write  (ex_reg_write),

        // EX/MEM
        .exmem_reg_write (mem_reg_write),
        .exmem_rd        (mem_rd_addr),

        // MEM/WB (safe to provide; unit may ignore)
        .memwb_reg_write (wb_reg_write),
        .memwb_rd        (wb_rd_addr),

        // Control-flow flush from EX
        .ex_redirect     (ex_redirect_taken),

        // Outputs: stalls/flushes
        .stall_if        (if_stall),
        .stall_id        (id_stall),
        .flush_ifid      (ifid_flush),
        .flush_idex      (idex_flush)

        // No forwarding ports on stall-only unit
    );


    // Simulation-only ECALL/EBREAK handling and pulse
    /*reg ebreak_q,ecall_q;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ebreak_q <= 1'b0;
            ecall_q  <= 1'b0;
        end else begin
            ebreak_q <= wb_ebreak;
            ecall_q  <= wb_ecall;
        end
    end*/
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
  /*  
    // 在 always @(posedge clk) 中添加
always @(posedge clk) begin
    if (!rst) begin
        // 追踪 lh 指令在 EX 阶段的转发情况
        if (ex_mem_read && ex_rd_addr == 5'd14) begin  // lh x14 在 EX
            $display("[T=%0t] LH@EX: rs1_addr=%0d forward_a=%b", $time, ex_rs1_addr, forward_a);
            $display("        WB: rd=%0d reg_wr=%b wb_sel=%0d wb_data=%08x", 
                     wb_rd_addr, wb_reg_write, wb_wb_sel, wb_data_final);
            $display("        MEM: rd=%0d reg_wr=%b mem_cand=%08x",
                     mem_rd_addr, mem_reg_write, mem_wb_candidate);
        end
    end
end*/
    
    //assign ebreak_pulse = 1'b0;
/*
always @(posedge clk) begin
    if (!rst) begin
        if (id_instr == 32'h00100393 || id_instr == 32'h00200393) begin
            $display("ID x7 ADDI: pc=%08x instr=%08x reg_write=%b wb_sel=%0d rd=%0d",
                     id_pc, id_instr, reg_write_d, wb_sel_d, rd_addr);
        end
    end
end

always @(posedge clk) begin
    if (!rst && ex_branch) begin
        $display("[BRANCH] pc=%08x rs1=%0d rs2=%0d fwd_a=%b fwd_b=%b",
                 ex_pc, ex_rs1_addr, ex_rs2_addr, forward_a, forward_b);
        $display("         rs1_val=%08x rs2_val=%08x alu_rs2_imm=%b",
                 ex_rs1_val_to_alu, ex_rs2_val_to_alu, ex_alu_rs2_is_imm);
        $display("         mem_rd=%0d mem_cand=%08x wb_rd=%0d wb_data=%08x",
                 mem_rd_addr, mem_wb_candidate, wb_rd_addr, wb_data_final);
    end
end*/
endmodule