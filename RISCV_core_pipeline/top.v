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
    PC_reg u_PC (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_next(pc_next)
    );
    assign instr = if_instr; // expose current fetched instruction for observation
    // IF: instruction fetch (synchronous in this version)
    wire [31:0] if_instr,if_pc;
    IF u_IF (
        .clk(clk),
        .pc(pc),
        .if_pc(if_pc),
        .instr(if_instr)
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
    wire       ecall_d, ebreak_d, fence_d;

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
        .ecall(ecall_d),
        .ebreak(ebreak_d),
        .fence(fence_d)
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
        .ex_csr_data(ex_csr_data)
    );

    // EX: operand selection without forwarding
    wire [31:0] ex_rs1_val_to_alu = ex_rs1_val;
    wire [31:0] ex_rs2_val_to_alu = ex_alu_rs2_is_imm ? ex_imm : ex_rs2_val;

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
        (ex_wb_sel == 2'd0) ? ex_alu_result :
        (ex_wb_sel == 2'd2) ? ex_pc_plus4 :
        (ex_wb_sel == 2'd3) ? ex_imm : ex_alu_result;

    // Next PC selection and IF stall hold
    wire [31:0] pc_redirect = ex_redirect_taken ? ex_branch_target : ex_pc_plus4;//the ex_pc_plus_4 should be (pc + 32'd4),as it should be the top pc;
    assign pc_next = if_stall ? pc : pc_redirect;//pc_redirect;

    // EX/MEM pipeline register: carries ALU result, store data, and WB/MEM controls
    wire [31:0] mem_pc, mem_alu_result, mem_rs2_val_for_store, mem_wb_candidate;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_load_signed, mem_csr_hit;
    wire [1:0]  mem_wb_sel, mem_load_size, mem_store_size;
    wire [31:0] mem_csr_data;

    EX_MEM u_ex_mem (
        .clk(clk),
        .rst(rst),

        .ex_pc(ex_pc),
        .ex_alu_result(ex_alu_result),
        .ex_rs2_val_for_store(ex_rs2_val), // store uses RS2 as latched in EX
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
        .mem_csr_data(mem_csr_data)
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

    MEM_WB u_mem_wb (
        .clk(clk),
        .rst(rst),

        .mem_wb_candidate(mem_wb_candidate),
        .mem_load_data(mem_load_data),
        .mem_rd_addr(mem_rd_addr),
        .mem_reg_write(mem_reg_write),
        .mem_wb_sel(mem_wb_sel),
        .mem_csr_hit(mem_csr_hit),
        .mem_csr_data(mem_csr_data),

        .wb_wb_candidate(wb_wb_candidate),
        .wb_load_data(wb_load_data),
        .wb_rd_addr(wb_rd_addr),
        .wb_reg_write(wb_reg_write),
        .wb_wb_sel(wb_wb_sel),
        .wb_csr_hit(wb_csr_hit),
        .wb_csr_data(wb_csr_data)
    );

    // WB: core WB mux (MEM vs ALU-side), then CSR overrides when hit
    wire [31:0] wb_wb_data_core;
    WB u_WB (
        .mem_to_reg(wb_wb_sel == 2'd1),
        .alu_result(wb_wb_candidate),
        .mem_data(wb_load_data),
        .wb_data(wb_wb_data_core)
    );

    // Final write-back signals to regfile
    wire [31:0] wb_data_final = wb_csr_hit ? wb_csr_data : wb_wb_data_core;
    wire        wb_wen_final  = wb_csr_hit ? 1'b1        : wb_reg_write;

    // Hazard unit (stall-only, no forwarding)
    hazard_unit u_hazard (
        // ID stage sources
        .id_rs1 (rs1_addr),
        .id_rs2 (rs2_addr),

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
    reg ebreak_q,ecall_q;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ebreak_q <= 1'b0;
            ecall_q  <= 1'b0;
        end else begin
            ebreak_q <= ebreak_d;
            ecall_q  <= ecall_d;
        end
    end
    assign ebreak_pulse = ebreak_d;
    assign ecall_pulse  = ecall_d; 
    /* always @(posedge clk) begin
        if (!rst) begin
            if (ecall_d) begin
                $display("ECALL at PC=%08x", pc);
                $finish;
            end
            if (ebreak_d) begin
                $display("EBREAK at PC=%08x", pc);
                $finish;
            end
        end
    end
    */
    
    
    //assign ebreak_pulse = 1'b0;




endmodule