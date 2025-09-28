module ID (
    input  [31:0] inst, // just inst

    // Outputs: Register address fields extracted from the instruction
    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,

    // Outputs: Instruction type and function fields
    output reg [2:0]  imm_type,
    output      [2:0] funct3,
    output      [6:0] funct7,
    // Control signals
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg [3:0]  alu_op,
    output reg        alu_rs2_imm // 1: use immediate, 0: use rs2
);

    // Opcodes
    localparam [6:0] OPCODE_LUI    = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam [6:0] OPCODE_JAL    = 7'b1101111;
    localparam [6:0] OPCODE_JALR   = 7'b1100111;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam [6:0] OPCODE_STORE  = 7'b0100011;
    localparam [6:0] OPCODE_OP_IMM = 7'b0010011;
    localparam [6:0] OPCODE_OP     = 7'b0110011;
    localparam [6:0] OPCODE_FENCE  = 7'b0001111;
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    // Immediate types
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    // ALU operation codes
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;

    wire [6:0] opcode;
    assign opcode    = inst[6:0];
    assign funct3    = inst[14:12];
    assign funct7    = inst[31:25];
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rd_addr   = inst[11:7];

    always @(*) begin
        // Default values
        imm_type    = IMM_I;
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        alu_op      = ALU_ADD;
        alu_rs2_imm = 1'b0; // 0: use rs2 (register), 1: use immediate

        case (opcode)
            // I-type ALU instructions (ADDI, XORI, ORI, ANDI...)
            OPCODE_OP_IMM: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b1; // Use immediate
                case (funct3)
                    3'b000: alu_op = ALU_ADD; // ADDI
                    3'b100: alu_op = ALU_XOR; // XORI
                    3'b110: alu_op = ALU_OR;  // ORI
                    3'b111: alu_op = ALU_AND; // ANDI
                    default: alu_op = ALU_ADD;
                endcase
            end
            // Load instructions (LB, LH, LW, LBU, LHU)
            OPCODE_LOAD: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                alu_rs2_imm = 1'b1; // Address = rs1 + imm
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
            end
            // JALR (I-type jump)
            OPCODE_JALR: begin
                reg_write   = 1'b1;
                branch      = 1'b1;
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
            end
            // R-type ALU instructions (ADD, SUB, XOR, OR, AND...)
            OPCODE_OP: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b0; // Use rs2
                case (funct3)
                    3'b000: begin
                        case (funct7)
                        7'b0000000:begin 
                            alu_op = ALU_ADD; // ADD
                        end
                        7'b0100000:begin 
                            alu_op = ALU_SUB; // SUB
                        end
                        default:alu_op = ALU_ADD;
                        endcase
                    end
                    3'b100: alu_op = ALU_XOR; // XOR
                    3'b110: alu_op = ALU_OR;  // OR
                    3'b111: alu_op = ALU_AND; // AND
                    default: alu_op = ALU_ADD;
                endcase
            end
            // Store instructions (SB, SH, SW)
            OPCODE_STORE: begin
                mem_write   = 1'b1;
                alu_rs2_imm = 1'b1; // Address = rs1 + imm
                alu_op      = ALU_ADD;
                imm_type    = IMM_S;
            end
            // Branch instructions 
            OPCODE_BRANCH: begin
                branch      = 1'b1;
                alu_rs2_imm = 1'b0; // Compare two registers
                alu_op      = ALU_SUB;
                imm_type    = IMM_B;
            end
            // LUI, AUIPC, JAL
            OPCODE_LUI: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                imm_type    = IMM_U;
            end
            OPCODE_AUIPC: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                imm_type    = IMM_U;
            end
            OPCODE_JAL: begin
                reg_write   = 1'b1;
                branch      = 1'b1;
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                imm_type    = IMM_J;
            end
            // Fence and System instructions (not writing to reg)
            OPCODE_FENCE: begin
                reg_write   = 1'b0;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
            end

            OPCODE_SYSTEM: begin
                reg_write   = 1'b0;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
            end
            // Default: NOP
            default: begin
                reg_write   = 1'b0;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
            end
        endcase
    end

endmodule