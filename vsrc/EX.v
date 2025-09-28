module EX (
    input  [31:0] rs1_data,     // Operand 1 (from regfile)
    input  [31:0] rs2_data,     // Operand 2 (from regfile)
    input  [31:0] imm,          // Immediate value (from immgen)
    input  [3:0]  alu_op,       // ALU operation selector
    input  alu_rs2_imm,         //Determine the imm or rs2(I type or R type),1 is imm,0 is rs2
    output reg [31:0] alu_result    // ALU output

);
    wire [31:0] alu_in2;
    assign alu_in2 = alu_rs2_imm ? imm : rs2_data;
    always@(*) begin
    case (alu_op)
        4'd0: alu_result = rs1_data + alu_in2;      // addi
        4'd1: alu_result = rs1_data - alu_in2; // sub
        4'd2: alu_result = rs1_data & alu_in2; // and
        4'd3: alu_result = rs1_data | alu_in2; // or
        4'd4: alu_result = rs1_data ^ alu_in2; // xor

        default: alu_result = 32'b0;
    endcase
    end
endmodule
