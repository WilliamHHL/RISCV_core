// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input        clk,
    input  [31:0] addr,
    output [31:0] data
);

    reg [31:0] mem [0:255];
    reg [7:0] addr_reg;

    initial begin
        $readmemh("program.hex", mem);
    end
    reg [31:0] offset;
    always @(posedge clk) begin
        
        if (addr >= 32'h8000_0000)
            offset = (addr - 32'h8000_0000) >> 2;
        else
            offset = 0;
        addr_reg <= offset[7:0];
    end

    assign data = mem[addr_reg];

endmodule