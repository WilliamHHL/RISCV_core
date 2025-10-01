// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input  [31:0] addr,
    output [31:0] data
);

    reg [31:0] mem [0:255];
    initial begin
        $readmemh("program.hex", mem);
    end

    wire [31:0]offset = (addr >= 32'h8000_0000)? (addr - 32'h8000_0000) >> 2:0;

    assign data = mem[offset[7:0]];

endmodule