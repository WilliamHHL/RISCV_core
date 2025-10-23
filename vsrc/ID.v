module ID (
    input  [31:0] inst,

    // Register address fields
    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,

    // Instruction fields
    output reg [2:0]  imm_type,
    output      [2:0] funct3,
    output      [6:0] funct7,

    // Control signals
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,       // conditional branch
    output reg        jal,          // JAL
    output reg        jalr,         // JALR
    output reg [2:0]  branch_op,    // branch comparator select (funct3)
    output reg [3:0]  alu_op,
    output reg        alu_rs2_imm,  // 1: immediate, 0: rs2
    output reg [1:0]  wb_sel,       // 00: ALU, 01: MEM, 10: PC+4, 11: IMM
    output reg        use_pc_add,    // 1: use pc + imm for AUIPC via ALU path
    output reg [1:0]  load_size,//determine the load size:LW(10)/LH(01)/LB(00)
    output reg load_signed,//determine the load is for sign number:1 is signed,0 is unsigned
    output reg [1:0] store_size//determine the store size:SW(10)/SH(01)/SB(00)
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

    // ALU ops
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

    // WB select
    localparam WB_ALU  = 2'd0;
    localparam WB_MEM  = 2'd1;
    localparam WB_PC4  = 2'd2;
    localparam WB_IMM  = 2'd3;

    wire [6:0] opcode;
    assign opcode    = inst[6:0];
    assign funct3    = inst[14:12];
    assign funct7    = inst[31:25];
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rd_addr   = inst[11:7];

    always @(*) begin
        // Defaults
        imm_type    = IMM_I;
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        branch_op   = 3'b000;
        alu_op      = ALU_ADD;
        alu_rs2_imm = 1'b0;
        wb_sel      = WB_ALU;
        use_pc_add  = 1'b0;
        load_size = 2'b10;
        load_signed = 1'b1;
        case (opcode)
            // I-type ALU
            OPCODE_OP_IMM: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b1;
                wb_sel      = WB_ALU;
                imm_type    = IMM_I;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI
                    3'b101: begin               // SRLI/SRAI (bit 30)
                        if (funct7[5]) alu_op = ALU_SRA; else alu_op = ALU_SRL;
                    end
                    default: alu_op = ALU_ADD;
                endcase
            end

            // LOAD (LW only)
            OPCODE_LOAD: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                alu_rs2_imm = 1'b1; // addr = rs1 + imm
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
                wb_sel      = WB_MEM;
                case(funct3)
                3'b010:begin //LW
                    load_size = 2'b10;
                    load_signed = 1'b1;
                end
                3'b001:begin //LH
                    load_size = 2'b01;
                    load_signed = 1'b1;
                end
                3'b000:begin //LB
                    load_size = 2'b00;
                    load_signed = 1'b1;
                end
                3'b100:begin//LBU
                    load_size = 2'b00;
                    load_signed = 1'b0;
                end
                3'b101:begin//LHU
                    load_size = 2'b01;
                    load_signed = 1'b0;
                end
               default: begin // treat as LW by default
                load_size = 2'b10;
                load_signed = 1'b1;
                end
            endcase
            end

            // JALR
            OPCODE_JALR: begin
                reg_write   = 1'b1;
                jalr        = 1'b1;
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
                wb_sel      = WB_PC4; // link = PC+4
            end

            // R-type ALU
            OPCODE_OP: begin
                reg_write   = 1'b1;
                alu_rs2_imm = 1'b0;
                wb_sel      = WB_ALU;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0100000) alu_op = ALU_SUB; else alu_op = ALU_ADD;
                    end
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: begin
                        if (funct7 == 7'b0100000) alu_op = ALU_SRA; else alu_op = ALU_SRL;
                    end
                    default: alu_op = ALU_ADD;
                endcase
            end

            // STORE (SW only)
            OPCODE_STORE: begin
                mem_write   = 1'b1;
                alu_rs2_imm = 1'b1; // addr = rs1 + imm
                alu_op      = ALU_ADD;
                imm_type    = IMM_S;
                wb_sel      = WB_ALU; // no WB
                case (funct3) 
                    3'b000:store_size = 2'b00;//SB
                    3'b001:store_size = 2'b01;//SH
                    3'b010:store_size = 2'b10;//SW
                    default:
                    store_size = 2'b10;//SW
            endcase
            end

            // BRANCH
            OPCODE_BRANCH: begin
                branch      = 1'b1;
                branch_op   = funct3;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_SUB;
                imm_type    = IMM_B;
                wb_sel      = WB_ALU; // no WB
            end

            // LUI
            OPCODE_LUI: begin
                reg_write   = 1'b1;
                imm_type    = IMM_U;
                wb_sel      = WB_IMM; // write U-imm directly
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
            end

            // AUIPC,Add Upper Imm with PC and store to a reg
            OPCODE_AUIPC: begin
                reg_write   = 1'b1;
                imm_type    = IMM_U;
                wb_sel      = WB_ALU;  // use ALU path
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
                use_pc_add  = 1'b1;    // tell top to use pc+imm on ALU path
            end

            // JAL
            OPCODE_JAL: begin
                reg_write   = 1'b1;
                jal         = 1'b1;
                imm_type    = IMM_J;
                wb_sel      = WB_PC4; // write PC+4
                alu_rs2_imm = 1'b1;
                alu_op      = ALU_ADD;
            end

            // FENCE / SYSTEM (NOP-like)
            OPCODE_FENCE, OPCODE_SYSTEM: begin
                reg_write   = 1'b0;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
                wb_sel      = WB_ALU;
            end

            default: begin
                reg_write   = 1'b0;
                mem_read    = 1'b0;
                mem_write   = 1'b0;
                branch      = 1'b0;
                jal         = 1'b0;
                jalr        = 1'b0;
                branch_op   = 3'b000;
                alu_rs2_imm = 1'b0;
                alu_op      = ALU_ADD;
                imm_type    = IMM_I;
                wb_sel      = WB_ALU;
                use_pc_add  = 1'b0;
                load_size = 2'b10;
                load_signed = 1'b1;
            end
        endcase
    end

endmodule
