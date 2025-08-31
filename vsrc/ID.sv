module ID (
    input  logic [31:0] inst,
    output logic [4:0]  rs1_addr,
    output logic [4:0]  rs2_addr,
    output logic [4:0]  rd_addr,
    output logic [2:0]  imm_type,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7,
    // Control signals for pipeline
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic        branch,
    output logic [3:0]  alu_op,
    // one-hot instruction ID for hazard/forwarding/debug
    output logic        is_addi,
    output logic        is_sub
    // ...
);

    // Opcodes (same as before)
    localparam OPCODE_LUI      = 7'b0110111;
    localparam OPCODE_AUIPC    = 7'b0010111;
    localparam OPCODE_JAL      = 7'b1101111;
    localparam OPCODE_JALR     = 7'b1100111;
    localparam OPCODE_BRANCH   = 7'b1100011;
    localparam OPCODE_LOAD     = 7'b0000011;
    localparam OPCODE_STORE    = 7'b0100011;
    localparam OPCODE_OP_IMM   = 7'b0010011;
    localparam OPCODE_OP       = 7'b0110011;
    localparam OPCODE_MISC_MEM = 7'b0001111;
    localparam OPCODE_SYSTEM   = 7'b1110011;

    // Immediate types
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    // ALU operation codes (define as needed)
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    // ... add more for your ALU

    // Extract fields
    logic [6:0] opcode;
    assign opcode    = inst[6:0];
    assign funct3    = inst[14:12];
    assign funct7    = inst[31:25];
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rd_addr   = inst[11:7];

    // Default assignments
    always_comb begin
        // Default values
        imm_type   = IMM_I;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        alu_op     = ALU_ADD;
        is_addi    = 1'b0;
        is_sub     = 1'b0;

        case (opcode)
            OPCODE_OP_IMM: begin // I-type ALU (e.g., addi)
                imm_type  = IMM_I;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: begin alu_op = ALU_ADD; is_addi = 1'b1; end // addi
                    3'b111: begin alu_op = ALU_AND; end // andi
                    3'b110: begin alu_op = ALU_OR;  end // ori
                    // ... add more I-type ALU
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPCODE_OP: begin // R-type ALU (e.g., add, sub)
                imm_type  = IMM_I; // not used, but can set
                reg_write = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            alu_op = ALU_ADD; is_addi = 1'b1; // add
                        end else if (funct7 == 7'b0100000) begin
                            alu_op = ALU_SUB; is_sub = 1'b1; // sub
                        end
                    end
                    3'b111: alu_op = ALU_AND; // and
                    3'b110: alu_op = ALU_OR;  // or
                    3'b100: alu_op = ALU_XOR; // xor
                    // ... add more R-type ALU
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPCODE_LOAD: begin
                imm_type  = IMM_I;
                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_op    = ALU_ADD; // Address calculation
            end

            OPCODE_STORE: begin
                imm_type  = IMM_S;
                mem_write = 1'b1;
                alu_op    = ALU_ADD; // Address calculation
            end

            OPCODE_BRANCH: begin
                imm_type  = IMM_B;
                branch    = 1'b1;
                alu_op    = ALU_SUB; // Use ALU to compare (beq, bne, etc.)
            end

            OPCODE_LUI: begin
                imm_type  = IMM_U;
                reg_write = 1'b1;
                alu_op    = ALU_ADD; // ALU passes immediate
            end

            OPCODE_AUIPC: begin
                imm_type  = IMM_U;
                reg_write = 1'b1;
                alu_op    = ALU_ADD; // PC + immediate
            end

            OPCODE_JAL: begin
                imm_type  = IMM_J;
                reg_write = 1'b1;
                branch    = 1'b1;
                alu_op    = ALU_ADD; // PC + offset
            end

            OPCODE_JALR: begin
                imm_type  = IMM_I;
                reg_write = 1'b1;
                branch    = 1'b1;
                alu_op    = ALU_ADD; // rs1 + offset
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
