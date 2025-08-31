module immgen (
    input  logic [31:0] inst,      // 32-bit instruction
    input  logic [2:0]  imm_type,  // Immediate type selector
    output logic [31:0] imm        // 32-bit immediate output
);
    // Possible encoding for imm_type:
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    always_comb begin
        case (imm_type)
            IMM_I: imm = {{20{inst[31]}}, inst[31:20]}; // I-type
            IMM_S: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]}; // S-type
            IMM_B: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}; // B-type
            IMM_U: imm = {inst[31:12], 12'b0}; // U-type
            IMM_J: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // J-type
            default: imm = 32'b0;
        endcase
    end
endmodule