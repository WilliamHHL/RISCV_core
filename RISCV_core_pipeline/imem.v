// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] data,
    output reg  [31:0] addr_q
);
    // 128 KiB bytes
    reg [7:0] mem [0:131071];

`ifndef SYNTHESIS
    initial begin
        $display("IMEM: loading program.hex (byte-wide) ...");
        $readmemh("program.hex", mem);
        $display("IMEM: load done.");
    end
`endif

   // reg [31:0] addr_q;
    always @(posedge clk) begin
        addr_q <= addr;
        data   <= { mem[addr_q + 3], mem[addr_q + 2], mem[addr_q + 1], mem[addr_q + 0] };
    end
endmodule