// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem(
    input  [31:0] addr,
    output [31:0] data
);

    reg [31:0] mem [0:32767];//128KB = 32768 words
    initial begin
        $readmemh("program.hex", mem);
    end
    wire [31:0] offset = addr >> 2;   // convert byte address (PC) to 32-bit word index (addr/4)
    assign data = mem[offset[14:0]];  // 15-bit index: 2^15 = 32768 words; mask high bits to avoid out-of-range
  

endmodule