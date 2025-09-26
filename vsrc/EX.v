module EX (
    input  [31:0] rs1_data,     // Operand 1 (from regfile)
    input  [31:0] rs2_data,     // Operand 2 (from regfile)
    input  [31:0] imm,          // Immediate value (from immgen)
    input  [3:0]  alu_op,       // ALU operation selector
    output reg [31:0] alu_result    // ALU output
);
    always_comb begin
    case (alu_op)
        4'd0: alu_result = rs1_data + imm;      // addi
        4'd1: alu_result = rs1_data - rs2_data; // sub
        4'd2: alu_result = rs1_data & rs2_data; // and
        4'd3: alu_result = rs1_data | rs2_data; // or
        4'd4: alu_result = rs1_data ^ rs2_data; // xor
        4'd5: alu_result = rs1_data + rs2_data; // add (R-type)
        default: alu_result = 32'b0;
    endcase
    end
endmodule
