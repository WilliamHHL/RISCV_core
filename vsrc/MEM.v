module MEM (
    input        clk,
    input        mem_read,     // 1: read from data memory
    input        mem_write,    // 1: write to data memory
    input  [31:0] alu_result,  // Address for memory access
    input  [31:0] rs2_data,    // Data to write (for store instructions)
    output reg [31:0] mem_data // Data read from memory
);

    // Simple data memory (256 words)
    reg [31:0] dmem [0:255];

    // Read: combinational output
    always @(*) begin
        if (mem_read)
            mem_data = dmem[alu_result[9:2]]; // word-aligned address
        else
            mem_data = 32'b0;
    end

    // Write: synchronous with clock
    always @(posedge clk) begin
        if (mem_write)
            dmem[alu_result[9:2]] <= rs2_data;
    end

endmodule