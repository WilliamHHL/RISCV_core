module top (
    input clk,
    input rst,
    output [31:0] pc,
    output [31:0] instr,
    output [31:0] x1,
    output [31:0] x2,
    output [31:0] x3,
    output [31:0] x4
);

    // IF
    wire [31:0] pc_next;

    // ID
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire reg_write, mem_read, mem_write, branch, jal, jalr;
    wire [2:0] branch_op;
    wire [3:0] alu_op;
    wire alu_rs2_imm;
    wire [1:0] wb_sel;
    wire use_pc_add;

    // Regfile
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] regs_out1, regs_out2, regs_out3, regs_out4;

    // Immgen
    wire [31:0] imm;

    // EX
    wire [31:0] alu_core_result;
    wire [31:0] pc_plus4;
    wire [31:0] auipc_result;
    wire [31:0] branch_target;
    wire        branch_taken;

    // MEM
    wire [31:0] mem_data;

    // Pre-WB and WB
    reg  [31:0] alu_pre_wb;  // value fed to WB on ALU side
    wire [31:0] wb_data;     // final writeback to regfile
    wire        mem_to_reg;  // selects MEM vs ALU in WB

    assign x1 = regs_out1;
    assign x2 = regs_out2;
    assign x3 = regs_out3;
    assign x4 = regs_out4;

    // PC register
    PC_reg u_PC (
        .clk(clk),
        .rstn_sync(rst),
        .pc(pc),
        .pc_next(pc_next)
    );

    // IF
    IF u_IF (
        //.clk(clk),
        .pc(pc),
        .instr(instr)
    );

    // ID
    ID u_ID (
        .inst(instr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .imm_type(imm_type),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .branch_op(branch_op),
        .alu_op(alu_op),
        .alu_rs2_imm(alu_rs2_imm),
        .wb_sel(wb_sel),
        .use_pc_add(use_pc_add)
    );

    // Regfile
    reg_file u_regfile (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(wb_data),
        .rd_wen(reg_write),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .regs_out1(regs_out1),
        .regs_out2(regs_out2),
        .regs_out3(regs_out3),
        .regs_out4(regs_out4)
    );

    // Immgen
    immgen u_immgen (
        .inst(instr),
        .imm_type(imm_type),
        .imm(imm)
    );

    // EX
    EX u_EX (
        .pc(pc),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm(imm),
        .alu_op(alu_op),
        .alu_rs2_imm(alu_rs2_imm),
        .branch(branch),
        .branch_op(branch_op),
        .jal(jal),
        .jalr(jalr),
        .funct3(funct3),
        .funct7(funct7),
        .alu_core_result(alu_core_result),
        .pc_plus4(pc_plus4),
        .auipc_result(auipc_result),
        .branch_target(branch_target),
        .branch_taken(branch_taken)
    );

    // MEM
    MEM u_MEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_result(alu_core_result), // address for LW/SW
        .rs2_data(rs2_data),
        .mem_data(mem_data)
    );

    // Next PC selection
    assign pc_next = branch_taken ? branch_target : pc_plus4;

    // Pre-WB ALU-path mux:
    // - use_pc_add: select auipc_result (pc + imm) for AUIPC
    // - else per wb_sel:
    //   00: ALU core result
    //   10: PC + 4  (JAL/JALR)
    //   11: IMM     (LUI)
    // For wb_sel==01 (MEM), alu_pre_wb is ignored by WB.
    always @(*) begin
        if (use_pc_add) begin
            alu_pre_wb = auipc_result;
        end else begin
            case (wb_sel)
                2'd0: alu_pre_wb = alu_core_result; // ALU ops
                2'd2: alu_pre_wb = pc_plus4;        // link for JAL/JALR
                2'd3: alu_pre_wb = imm;             // LUI
                default: alu_pre_wb = alu_core_result;
            endcase
        end
    end

    // mem_to_reg selects memory vs ALU for WB. 
    assign mem_to_reg = (wb_sel == 2'd1);

    // WB (kept as original 2:1 mux)
    WB u_WB (
        .mem_to_reg(mem_to_reg),
        .alu_result(alu_pre_wb),
        .mem_data(mem_data),
        .wb_data(wb_data)
    );

endmodule
