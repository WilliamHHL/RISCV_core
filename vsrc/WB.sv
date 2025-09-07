module WB (
    input  logic        mem_to_reg,    // 1: Write-back comes from memory, 0: from ALU
    input  logic [31:0] alu_result,    // ALU computation result
    input  logic [31:0] mem_data,      // Data loaded from memory
    output logic [31:0] wb_data        // Data to write back to regfile
);
    // Select data to write back to the register file
    assign wb_data = mem_to_reg ? mem_data : alu_result;
endmodule