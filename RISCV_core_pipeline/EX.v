module EX (
    input  [31:0] pc,
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [31:0] imm,
    input  [4:0]  alu_op,
    input         alu_rs2_imm,
    input         branch,
    input  [2:0]  branch_op,
    input         jal,
    input         jalr,

    output reg [31:0] alu_core_result,
    output      [31:0] pc_plus4,
    output      [31:0] auipc_result,
    output reg [31:0] branch_target,
    output reg        branch_taken
);
    wire [31:0] alu_in2 = alu_rs2_imm ? imm : rs2_data;

    localparam ALU_ADD  = 5'd0;
    localparam ALU_SUB  = 5'd1;
    localparam ALU_AND  = 5'd2;
    localparam ALU_OR   = 5'd3;
    localparam ALU_XOR  = 5'd4;
    localparam ALU_SLT  = 5'd5;
    localparam ALU_SLTU = 5'd6;
    localparam ALU_SLL   = 5'd7;
    localparam ALU_SRL   = 5'd8;
    localparam ALU_SRA   = 5'd9;
    // RV32M multiply/divide operations. MUL is the normal performance path.
    // DIV/REM below are simulation-only when ENABLE_SIM_COMB_DIV is defined.
    localparam ALU_MUL   = 5'd10;
    localparam ALU_MULH  = 5'd11;
    localparam ALU_MULHSU= 5'd12;
    localparam ALU_MULHU = 5'd13;
    localparam ALU_DIV   = 5'd14;
    localparam ALU_DIVU  = 5'd15;
    localparam ALU_REM   = 5'd16;
    localparam ALU_REMU  = 5'd17;

    assign pc_plus4     = pc + 32'd4;
    assign auipc_result = pc + imm;

    wire [4:0] shamt = alu_rs2_imm ? imm[4:0] : rs2_data[4:0];//shamt=shift amount

    // Combinational multiplier datapath for the RV32M/Zmmul multiply subset.
    // Low 32 bits are identical for signed and unsigned multiply. The high-word
    // variants need the correct operand signedness.
    wire        [63:0] rs1_u64 = {32'b0, rs1_data};
    wire        [63:0] rs2_u64 = {32'b0, rs2_data};
    wire signed [63:0] rs1_s64 = {{32{rs1_data[31]}}, rs1_data};
    wire signed [63:0] rs2_s64 = {{32{rs2_data[31]}}, rs2_data};
    wire signed [63:0] rs2_u_s64 = {32'b0, rs2_data};

    wire        [63:0] mul_uu = rs1_u64 * rs2_u64;
    wire signed [63:0] mul_ss = rs1_s64 * rs2_s64;
    wire signed [63:0] mul_su = rs1_s64 * rs2_u_s64;

    // ------------------------------------------------------------------------
    // Simulation-only combinational divider.
    //
    // This exists only to measure the CoreMark impact of full RV32IM. It is
    // guarded twice:
    //   1. ENABLE_SIM_COMB_DIV must be passed to Verilator.
    //   2. SYNTHESIS must not be defined.
    //
    // Do not use this divider for FPGA/ASIC implementation. A real design
    // should replace it with an iterative or pipelined divider and stall EX
    // while the divider is busy.
    // ------------------------------------------------------------------------
    wire div_by_zero = (alu_in2 == 32'b0);
    wire div_overflow = (rs1_data == 32'h8000_0000) && (alu_in2 == 32'hffff_ffff);
    wire signed [31:0] rs1_s32 = rs1_data;
    wire signed [31:0] rs2_s32 = alu_in2;

`ifdef ENABLE_SIM_COMB_DIV
`ifndef SYNTHESIS
    // synthesis translate_off
    reg [31:0] sim_div_result;
    reg [31:0] sim_divu_result;
    reg [31:0] sim_rem_result;
    reg [31:0] sim_remu_result;

    always @(*) begin
        // RISC-V M-extension divide corner cases:
        // - divide by zero: quotient = all 1s, remainder = dividend
        // - signed overflow INT_MIN / -1: quotient = INT_MIN, remainder = 0
        if (div_by_zero) begin
            sim_div_result  = 32'hffff_ffff;
            sim_divu_result = 32'hffff_ffff;
            sim_rem_result  = rs1_data;
            sim_remu_result = rs1_data;
        end else begin
            sim_divu_result = rs1_data / alu_in2;
            sim_remu_result = rs1_data % alu_in2;

            if (div_overflow) begin
                sim_div_result = 32'h8000_0000;
                sim_rem_result = 32'b0;
            end else begin
                sim_div_result = rs1_s32 / rs2_s32;
                sim_rem_result = rs1_s32 % rs2_s32;
            end
        end
    end
    // synthesis translate_on
`else
    // If a synthesis flow defines SYNTHESIS, the / and % operators above are
    // not present in the synthesized RTL. These poison values make accidental
    // synthesis builds obvious during review.
    wire [31:0] sim_div_result  = 32'hbad0_d100;
    wire [31:0] sim_divu_result = 32'hbad0_d101;
    wire [31:0] sim_rem_result  = 32'hbad0_d102;
    wire [31:0] sim_remu_result = 32'hbad0_d103;
`endif
`else
    // DIV/REM should not be decoded unless ENABLE_SIM_COMB_DIV is defined.
    wire [31:0] sim_div_result  = 32'hbad0_d200;
    wire [31:0] sim_divu_result = 32'hbad0_d201;
    wire [31:0] sim_rem_result  = 32'hbad0_d202;
    wire [31:0] sim_remu_result = 32'hbad0_d203;
`endif

    always @(*) begin
        case (alu_op)
            ALU_ADD:  alu_core_result = rs1_data + alu_in2;
            ALU_SUB:  alu_core_result = rs1_data - alu_in2;
            ALU_AND:  alu_core_result = rs1_data & alu_in2;
            ALU_OR:   alu_core_result = rs1_data | alu_in2;
            ALU_XOR:  alu_core_result = rs1_data ^ alu_in2;
            ALU_SLT:  alu_core_result = ($signed(rs1_data) < $signed(alu_in2)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_core_result = (rs1_data < alu_in2) ? 32'd1 : 32'd0;
            ALU_SLL:    alu_core_result = rs1_data << shamt;
            ALU_SRL:    alu_core_result = rs1_data >> shamt;
            ALU_SRA:    alu_core_result = $signed(rs1_data) >>> shamt;
            ALU_MUL:    alu_core_result = mul_uu[31:0];
            ALU_MULH:   alu_core_result = mul_ss[63:32];
            ALU_MULHSU: alu_core_result = mul_su[63:32];
            ALU_MULHU:  alu_core_result = mul_uu[63:32];
            ALU_DIV:    alu_core_result = sim_div_result;
            ALU_DIVU:   alu_core_result = sim_divu_result;
            ALU_REM:    alu_core_result = sim_rem_result;
            ALU_REMU:   alu_core_result = sim_remu_result;
            default:    alu_core_result = 32'b0;
        endcase
    end

    // Branch comparator
    wire beq  = (rs1_data == rs2_data);
    wire blt  = ($signed(rs1_data) <  $signed(rs2_data));
    wire bltu = (rs1_data < rs2_data);

    reg branch_cond;
    always @(*) begin
        case (branch_op)
            3'b000: branch_cond = beq;       // BEQ
            3'b001: branch_cond = ~beq;      // BNE
            3'b100: branch_cond = blt;       // BLT
            3'b101: branch_cond = ~blt;      // BGE
            3'b110: branch_cond = bltu;      // BLTU
            3'b111: branch_cond = ~bltu;     // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    // Target and decision
    always @(*) begin
        branch_taken  = 1'b0;
        branch_target = pc_plus4;

        if (branch) begin
            branch_target = pc + imm; // B-type imm already LSB=0
            branch_taken  = branch_cond;
        end

        if (jal) begin
            branch_target = pc + imm; // JAL
            branch_taken  = 1'b1;
        end

        if (jalr) begin
            branch_target = (rs1_data + imm) & 32'hFFFF_FFFE; // JALR target
            branch_taken  = 1'b1;
        end
    end

endmodule
