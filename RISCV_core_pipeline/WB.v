module WB (
    input  mem_to_reg,    // 1: Write-back comes from memory, 0: from ALU
    input [31:0] alu_result,    // ALU computation result
    input  [31:0] mem_data,      // Data loaded from memory
    output [31:0] wb_data ,
    input clk
     // Data to write back to regfile
);
    // Select data to write back to the register file 
    assign wb_data = mem_to_reg ? mem_data : alu_result;
   /* reg mem_to_reg_q;
    reg [31:0] alu_result_q;
    always @(posedge clk) begin
    
        mem_to_reg_q <= mem_to_reg;
 
        alu_result_q <= alu_result;
    end
    assign wb_data = mem_to_reg_q ? mem_data : alu_result_q;
    */
endmodule