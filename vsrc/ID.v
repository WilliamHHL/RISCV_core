module ID (
    input  [31:0] inst, // just inst

    // Outputs: Register address fields extracted from the instruction
    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,

    // Outputs: Instruction type and function fields
    output reg [2:0]  imm_type,
    output [2:0]  funct3,
    output reg [6:0]  funct7,
    // Control signals
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg [3:0]  alu_op
);

    // Opcodes
    localparam [6:0] OPCODE_LUI = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC = 7'b0010111;
    localparam [6:0] OPCODE_JAL = 7'b1101111;
    localparam [6:0] OPCODE_JALR = 7'b1100111;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_LOAD = 7'b0000011;
    localparam [6:0] OPCODE_STORE = 7'b0100011;
    localparam [6:0] OPCODE_OP_IMM = 7'b0010011;
    localparam [6:0] OPCODE_OP = 7'b0110011;
    localparam [6:0] OPCODE_FENCE = 7'b0001111;
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    // Immediate types
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    // ALU operation codes
    localparam ALU_ADD      = 4'd0; // addi
    localparam ALU_SUB      = 4'd1;
    localparam ALU_AND      = 4'd2;
    localparam ALU_OR       = 4'd3;
    localparam ALU_XOR      = 4'd4;
    localparam ALU_ADD_REG  = 4'd5; // add

    wire [6:0] opcode;
    assign opcode    = inst[6:0];
    assign funct3    = inst[14:12];
    assign funct7    = inst[31:25];
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rd_addr   = inst[11:7];

    always @(*) begin
        // Default values
        imm_type   = IMM_I;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        alu_op     = ALU_ADD;
        funct7     = funct7; // for completeness

        case (opcode)
            OPCODE_LUI: begin
                // LUI
                imm_type  = IMM_U;
                reg_write = 1;
                mem_read  = 0;
                mem_write = 0;
                branch    = 0;
                alu_op    = ALU_ADD;
            end
            OPCODE_AUIPC: begin
                // AUIPC
                imm_type  = IMM_U;
                reg_write = 1;
                mem_read  = 0;
                mem_write = 0;
                branch    = 0;
                alu_op    = ALU_ADD;
            end
            OPCODE_JAL: begin
                // JAL
                imm_type  = IMM_J;
                reg_write = 1;
                mem_read  = 0;
                mem_write = 0;
                branch    = 1;
                alu_op    = ALU_ADD;
            end
            OPCODE_JALR: begin
                // JALR
                imm_type  = IMM_I;
                reg_write = 1;
                mem_read  = 0;
                mem_write = 0;
                branch    = 1;
                alu_op    = ALU_ADD;
            end
            OPCODE_BRANCH: begin
                case (funct3)
                    3'b000: begin // BEQ
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    3'b001: begin // BNE
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    3'b100: begin // BLT
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    3'b101: begin // BGE
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    3'b110: begin // BLTU
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    3'b111: begin // BGEU
                        imm_type  = IMM_B;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 1;
                        alu_op    = ALU_SUB;
                    end
                    default: begin
                        imm_type   = IMM_I;
                        reg_write  = 1'b0;
                        mem_read   = 1'b0;
                        mem_write  = 1'b0;
                        branch     = 1'b0;
                        alu_op     = ALU_ADD;
                    end
                endcase
            end
            OPCODE_LOAD: begin
                case (funct3)
                    3'b000: begin // LB
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 1;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b001: begin // LH
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 1;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b010: begin // LW
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 1;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b100: begin // LBU
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 1;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b101: begin // LHU
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 1;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    default: begin
                        imm_type   = IMM_I;
                        reg_write  = 1'b0;
                        mem_read   = 1'b0;
                        mem_write  = 1'b0;
                        branch     = 1'b0;
                        alu_op     = ALU_ADD;
                    end
                endcase
            end
            OPCODE_STORE: begin
                case (funct3)
                    3'b000: begin // SB
                        imm_type  = IMM_S;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 1;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b001: begin // SH
                        imm_type  = IMM_S;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 1;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b010: begin // SW
                        imm_type  = IMM_S;
                        reg_write = 0;
                        mem_read  = 0;
                        mem_write = 1;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    default: begin
                        imm_type   = IMM_I;
                        reg_write  = 1'b0;
                        mem_read   = 1'b0;
                        mem_write  = 1'b0;
                        branch     = 1'b0;
                        alu_op     = ALU_ADD;
                    end
                endcase
            end
            OPCODE_OP_IMM: begin
                case (funct3)
                    3'b000: begin // ADDI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b010: begin // SLTI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b011: begin // SLTIU
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b100: begin // XORI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_XOR;
                    end
                    3'b110: begin // ORI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_OR;
                    end
                    3'b111: begin // ANDI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_AND;
                    end
                    3'b001: begin // SLLI
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD;
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRLI
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_ADD;
                            end
                            7'b0100000: begin // SRAI
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_ADD;
                            end
                            default: begin
                                imm_type   = IMM_I;
                                reg_write  = 1'b0;
                                mem_read   = 1'b0;
                                mem_write  = 1'b0;
                                branch     = 1'b0;
                                alu_op     = ALU_ADD;
                            end
                        endcase
                    end
                    default: begin
                        imm_type   = IMM_I;
                        reg_write  = 1'b0;
                        mem_read   = 1'b0;
                        mem_write  = 1'b0;
                        branch     = 1'b0;
                        alu_op     = ALU_ADD;
                    end
                endcase
            end
            OPCODE_OP: begin
                case (funct3)
                    3'b000: begin
                        case (funct7)
                            7'b0000000: begin // ADD
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_ADD_REG;
                            end
                            7'b0100000: begin // SUB
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_SUB;
                            end
                            default: begin
                                imm_type   = IMM_I;
                                reg_write  = 1'b0;
                                mem_read   = 1'b0;
                                mem_write  = 1'b0;
                                branch     = 1'b0;
                                alu_op     = ALU_ADD;
                            end
                        endcase
                    end
                    3'b001: begin // SLL
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD_REG;
                    end
                    3'b010: begin // SLT
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD_REG;
                    end
                    3'b011: begin // SLTU
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_ADD_REG;
                    end
                    3'b100: begin // XOR
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_XOR;
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRL
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_ADD_REG;
                            end
                            7'b0100000: begin // SRA
                                imm_type  = IMM_I;
                                reg_write = 1;
                                mem_read  = 0;
                                mem_write = 0;
                                branch    = 0;
                                alu_op    = ALU_ADD_REG;
                            end
                            default: begin
                                imm_type   = IMM_I;
                                reg_write  = 1'b0;
                                mem_read   = 1'b0;
                                mem_write  = 1'b0;
                                branch     = 1'b0;
                                alu_op     = ALU_ADD;
                            end
                        endcase
                    end
                    3'b110: begin // OR
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_OR;
                    end
                    3'b111: begin // AND
                        imm_type  = IMM_I;
                        reg_write = 1;
                        mem_read  = 0;
                        mem_write = 0;
                        branch    = 0;
                        alu_op    = ALU_AND;
                    end
                    default: begin
                        imm_type   = IMM_I;
                        reg_write  = 1'b0;
                        mem_read   = 1'b0;
                        mem_write  = 1'b0;
                        branch     = 1'b0;
                        alu_op     = ALU_ADD;
                    end
                endcase
            end
            OPCODE_FENCE: begin
                // FENCE
                imm_type  = IMM_I;
                reg_write = 0;
                mem_read  = 0;
                mem_write = 0;
                branch    = 0;
                alu_op    = ALU_ADD;
            end
            OPCODE_SYSTEM: begin
                case (inst[31:20])
                    12'b0000_0000_0000: begin // ECALL
                        imm_type  = IMM_I;
                        reg_write = 1'b0;
                        mem_read  = 1'b0;
                        mem_write = 1'b0;
                        branch    = 1'b0;
                        alu_op    = ALU_ADD;
                    end
                    12'b0000_0000_0001: begin // EBREAK
                        imm_type  = IMM_I;
                        reg_write = 1'b0;
                        mem_read  = 1'b0;
                        mem_write = 1'b0;
                        branch    = 1'b0;
                        alu_op    = ALU_ADD;
                    end
                    default: begin
                        // Other system instructions (NOP or safe defaults)
                        imm_type  = IMM_I;
                        reg_write = 1'b0;
                        mem_read  = 1'b0;
                        mem_write = 1'b0;
                        branch    = 1'b0;
                        alu_op    = ALU_ADD;
                    end
                endcase
            end
            default: begin
                imm_type   = IMM_I;
                reg_write  = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_op     = ALU_ADD;
            end
        endcase
    end

endmodule