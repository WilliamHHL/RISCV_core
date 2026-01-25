// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNDRIVEN

module imem (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire        imem_stall,
    output reg  [31:0] data
);

    // 128 KiB = 32768 words
    reg [31:0] mem [0:32767];
    wire [14:0] word_addr = addr[16:2];

`ifndef SYNTHESIS
    initial begin
        $display("IMEM: loading program.hex ...");
        $readmemh("program.hex", mem);
        $display("IMEM: load done.");
    end
`endif

    always @(posedge clk) begin
        if (rst) begin
            data <= 32'h00000013;  // NOP
        end else if (!imem_stall) begin
            data <= mem[word_addr];
        end
        // else: hold data (implicit)
    end

endmodule