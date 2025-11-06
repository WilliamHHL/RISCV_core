module top (
    input clk,
    input rst,
    output [31:0] pc,
    output [31:0] instr,
    /*output [31:0] x1,
    output [31:0] x2,
    output [31:0] x3,
    output [31:0] x4,*/
    output  ebreak_pulse
);

    // IF
    wire [31:0] pc_next;

    // ID (decode outputs; future: to be registered into ID/EX)
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire       reg_write;     // core WB write-enable from decode
    wire       mem_read, mem_write;
    wire       branch, jal, jalr;
    wire [2:0] branch_op;
    wire [3:0] alu_op;
    wire       alu_rs2_imm;
    wire [1:0] wb_sel;        // 00:ALU 01:MEM 10:PC+4 11:IMM
    wire       use_pc_add;    // AUIPC: use (pc+imm) on ALU-side WB candidate
    wire       load_signed;
    wire [1:0] load_size;
    wire [1:0] store_size;
    wire       ecall, ebreak, fence;

    // Regfile read data (future: to be registered into ID/EX)
    wire [31:0] rs1_data, rs2_data;
    //wire [31:0] regs_out1, regs_out2, regs_out3, regs_out4;

    // Immgen (future: to be registered into ID/EX)
    wire [31:0] imm;

    // EX (future: to be registered into EX/MEM)
    wire [31:0] alu_core_result;
    wire [31:0] pc_plus4;
    wire [31:0] auipc_result;
    wire [31:0] branch_target;
    wire        branch_taken;

    // MEM (future: to be registered into MEM/WB)
    wire [31:0] mem_data;

    // ALU-side candidate for WB (selected among ALU result / PC+4 / IMM / AUIPC)
    // Future: this will sit at the EX/MEM boundary
    reg  [31:0] alu_wb_candidate;

    // WB core output (datapath normal WB result: ALU-side vs MEM)
    wire [31:0] wb_data_core;

    // Final write-back signals to regfile (CSR overrides when hit)
    wire [31:0] wb_data;
    wire        wb_wen;

    // Exposed registers for observation
    /*assign x1 = regs_out1;
    assign x2 = regs_out2;
    assign x3 = regs_out3;
    assign x4 = regs_out4;*/

    // PC register (IF)
    PC_reg u_PC (
        .clk(clk),
        .rst_sync(rst),
        .pc(pc),
        .pc_next(pc_next)
    );

    // IF: instruction memory read (combinational read; for FPGA, need sync BRAM and IF/ID reg)
    IF u_IF (
        //.clk,
        .pc(pc),
        .instr(instr)
    );

    // ID: decode and control
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
        .use_pc_add(use_pc_add),
        .load_size(load_size),
        .load_signed(load_signed),
        .store_size(store_size),
        .ecall(ecall),
        .ebreak(ebreak),
        .fence(fence)
    );

    // Regfile: final WB signals write into the regfile
    reg_file u_regfile (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(wb_data),  // final write-back data (after CSR override)
        .rd_wen(wb_wen),    // final write-enable (after CSR override)
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
        /*.regs_out1(regs_out1),
        .regs_out2(regs_out2),
        .regs_out3(regs_out3),
        .regs_out4(regs_out4)*/
    );

    // Immediate generator
    immgen u_immgen (
        .inst(instr),
        .imm_type(imm_type),
        .imm(imm)
    );

    // EX: ALU, branch, jumps (decides next PC)
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

    // MEM: data memory access and load data assembly (byte/half/word, sign/zero-extend)
    MEM u_MEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_result(alu_core_result), // LW/SW address
        .rs2_data(rs2_data),
        .mem_data(mem_data),
        .load_signed(load_signed),
        .load_size(load_size),
        .store_size(store_size)
    );

    // Next PC selection (EX decides; with pipeline, add flush/redirection)
    assign pc_next = branch_taken ? branch_target : pc_plus4;

    // ALU-side candidate for WB:
    // - use_pc_add: AUIPC uses (pc + imm)
    // - otherwise per wb_sel:
    //   00: ALU core result
    //   10: PC + 4  (JAL/JALR link)
    //   11: IMM     (LUI)
    // For wb_sel==01 (MEM), this candidate is ignored by WB since MEM is selected.
    always @(*) begin
        if (use_pc_add) begin
            alu_wb_candidate = auipc_result;
        end else begin
            case (wb_sel)
                2'd0: alu_wb_candidate = alu_core_result; // ALU ops
                2'd2: alu_wb_candidate = pc_plus4;        // JAL/JALR link
                2'd3: alu_wb_candidate = imm;             // LUI
                default: alu_wb_candidate = alu_core_result;
            endcase
        end
    end

    // mem_to_reg selects MEM vs ALU-side in WB
    wire mem_to_reg = (wb_sel == 2'd1);

    // CSR mcycle: cycle counter (side-car; only affects final WB)
    reg [63:0] cycle_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst)
            cycle_cnt <= 64'd0;
        else
            cycle_cnt <= cycle_cnt + 1'b1;
    end

    // CSR read helper: currently supports only mcycle low (0xB00)
    wire        csr_hit;
    wire [31:0] csr_data;
    csr_read u_csr_read (
        .instr(instr),
        .cycle_cnt(cycle_cnt),
        .csr_hit(csr_hit),
        .csr_data(csr_data)
    );

    // WB (core 2:1 mux): datapath normal WB result (ALU-side vs MEM)
    WB u_WB (
        .mem_to_reg(mem_to_reg),
        .alu_result(alu_wb_candidate),
        .mem_data(mem_data),
        .wb_data(wb_data_core)
    );

    // Final write-back (CSR override): performed only right before regfile
    assign wb_data = csr_hit ? csr_data : wb_data_core;
    assign wb_wen  = csr_hit ? 1'b1     : reg_write;

    // Simulation-only handling for ECALL/EBREAK
`ifndef SYNTHESIS
    reg ebreak_q;
    always @(posedge clk or posedge rst) begin
        if (rst) ebreak_q <= 1'b0;
        else    
        ebreak_q <= ebreak;
    end
    assign ebreak_pulse = ebreak & ~ebreak_q;

    always @(posedge clk) begin
        if (!rst) begin
            if (ecall) begin
                $display("ECALL at PC=%08x", pc);
                $finish;
            end
            if (ebreak) begin
                $display("EBREAK at PC=%08x", pc);
                $finish;
            end
        end
    end
`endif

endmodule