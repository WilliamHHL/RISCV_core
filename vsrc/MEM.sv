module MEM (
    input  logic        clk,
    input  logic        mem_read,     // 1: read from data memory
    input  logic        mem_write,    // 1: write to data memory
    input  logic [31:0] alu_result,   // Address for memory access
    input  logic [31:0] rs2_data,     // Data to write (for store instructions)
    output logic [31:0] mem_data      // Data read from memory
);
    // Simple data memory (256 words)
    logic [31:0] dmem [0:255];

    // Read: combinational output
    always_comb begin
        if (mem_read)
            mem_data = dmem[alu_result[9:2]]; // word-aligned address
        else
            mem_data = 32'b0;
    end

    // Write: synchronous with clock
    always_ff @(posedge clk) begin
        if (mem_write)
            dmem[alu_result[9:2]] <= rs2_data;
    end
endmodule