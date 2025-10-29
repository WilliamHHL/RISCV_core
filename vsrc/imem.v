// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input  [31:0] addr,
    output [31:0] data
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

    // little-endian assemble: addr is byte address (PC)
    assign data = { mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr + 0] };
endmodule