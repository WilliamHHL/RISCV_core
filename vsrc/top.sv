module top (
    input  logic clk,
    input  logic rst,
    output logic [31:0] pc,
    output logic [31:0] instr,
    output logic [31:0] x1,
    output logic [31:0] x2,
    output logic [31:0] x3,
    output logic [31:0] x4
    );

    // IF stage
    logic [31:0] pc_next;

    // ID stage
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [2:0] imm_type, funct3;
    logic [6:0] funct7;
    logic reg_write, mem_read, mem_write, branch;
    logic [3:0] alu_op;

    // Regfile
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] regs_out1, regs_out2, regs_out3,regs_out4;
    // Immgen
    logic [31:0] imm;

    // EX stage
    logic [31:0] alu_result;

    // MEM stage
    logic [31:0] mem_data;

    // WB stage
    logic [31:0] wb_data;
    logic mem_to_reg;

    // PC logic (always PC + 4 for now)
    assign pc_next = pc + 32'd4;

    assign x1 = regs_out1;
    assign x2 = regs_out2;
    assign x3 = regs_out3;
    assign x4 = regs_out4;

    // IF stage (fetch)
    PC_reg u_PC (
        .clk(clk),
        .rstn_sync(rst),
        .pc(pc),
        .pc_next(pc_next)
    );

    IF u_IF (
        .clk(clk),
        .pc(pc),
        .instr(instr)
    );

    // ID stage
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
        .alu_op(alu_op)
    );

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

    immgen u_immgen (
        .inst(instr),
        .imm_type(imm_type),
        .imm(imm)
    );

    // EX stage
    EX u_EX (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm(imm),
        .alu_op(alu_op),
        .alu_result(alu_result)
    );

    // MEM stage
    MEM u_MEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_result(alu_result),
        .rs2_data(rs2_data),
        .mem_data(mem_data)
    );

    // Choose write-back source (for addi, reg_write comes from ALU)
    assign mem_to_reg = mem_read; // For load instructions, write from memory

    // WB stage
    WB u_WB (
        .mem_to_reg(mem_to_reg),
        .alu_result(alu_result),
        .mem_data(mem_data),
        .wb_data(wb_data)
    );

endmodule