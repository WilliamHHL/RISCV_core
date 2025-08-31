// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input  logic        clk,
    input  logic [31:0] addr,
    output logic [31:0] data
);
    logic [31:0] mem [0:255];
    logic [7:0] addr_reg;
    initial $readmemh("program.hex", mem);
    
    always_ff @(posedge clk) begin
    logic [31:0] offset;
    if (addr >= 32'h8000_0000)
        offset = (addr - 32'h8000_0000) >> 2;
    else
        offset = 0;
    addr_reg <= offset[7:0];
    end

    assign data = mem[addr_reg];
endmodule
