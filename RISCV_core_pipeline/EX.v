module EX (
    input  [31:0] pc,
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [31:0] imm,
    input  [3:0]  alu_op,
    input         alu_rs2_imm,
    input         branch,
    input  [2:0]  branch_op,
    input         jal,
    input         jalr,
    input  [2:0]  funct3, // unused
    input  [6:0]  funct7, // unused

    output reg [31:0] alu_core_result,
    output      [31:0] pc_plus4,
    output      [31:0] auipc_result,
    output reg [31:0] branch_target,
    output reg        branch_taken
);
    wire [31:0] alu_in2 = alu_rs2_imm ? imm : rs2_data;

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLT  = 4'd5;
    localparam ALU_SLTU = 4'd6;
    localparam ALU_SLL  = 4'd7;
    localparam ALU_SRL  = 4'd8;
    localparam ALU_SRA  = 4'd9;

    assign pc_plus4     = pc + 32'd4;
    assign auipc_result = pc + imm;

    wire [4:0] shamt = alu_rs2_imm ? imm[4:0] : rs2_data[4:0];//shamt=shift amount

    always @(*) begin
        case (alu_op)
            ALU_ADD:  alu_core_result = rs1_data + alu_in2;
            ALU_SUB:  alu_core_result = rs1_data - alu_in2;
            ALU_AND:  alu_core_result = rs1_data & alu_in2;
            ALU_OR:   alu_core_result = rs1_data | alu_in2;
            ALU_XOR:  alu_core_result = rs1_data ^ alu_in2;
            ALU_SLT:  alu_core_result = ($signed(rs1_data) < $signed(alu_in2)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_core_result = (rs1_data < alu_in2) ? 32'd1 : 32'd0;
            ALU_SLL:  alu_core_result = rs1_data << shamt;
            ALU_SRL:  alu_core_result = rs1_data >> shamt;
            ALU_SRA:  alu_core_result = $signed(rs1_data) >>> shamt;
            default:  alu_core_result = 32'b0;
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
