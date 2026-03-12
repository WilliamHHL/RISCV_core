
module imem (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire        imem_stall,
    output reg  [31:0] data
     `ifdef USE_POWER_PINS
    , inout         vccd1,
    inout         vssd1
    `endif
);
    wire [7:0] word_addr;
    wire       csb1;
    // 1 KiB = 256 words (32-bit)
    wire [7:0] word_addr = addr[9:2];

`ifdef SYNTHESIS
    // Use the macro's read-only port (port 1) for instruction fetch
    wire [31:0] dout1;

    // csb is active-low (csb=1 disables). Disable during reset or stall.
    
	

	assign word_addr = addr[9:2];
	assign csb1      = rst || imem_stall;
    sky130_sram_1kbyte_1rw1r_32x256_8 u_sram (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
`endif
        // Port 0 (RW) unused
        .clk0   (32'b0),
        .csb0   (1'b1),
        .web0   (1'b1),
        .wmask0 (4'b0000),
        .addr0  (8'b0),
        .din0   (32'b0),
        .dout0  (),

        // Port 1 (R) used
        .clk1   (clk),
        .csb1   (csb1),
        .addr1  (word_addr),
        .dout1  (dout1)
    );

    // Macro dout is assumed synchronous/registered (typical OpenRAM-style SRAM).
    // During reset, force NOP.
    always @(*) begin
        data = rst ? 32'h00000013 : dout1;
    end

`else
    // Behavioral model for simulation
    reg [31:0] mem [0:255];

    initial begin
        $display("IMEM: loading program.hex ...");
        $readmemh("program.hex", mem);
        $display("IMEM: load done.");
    end

    always @(posedge clk) begin
        if (rst) begin
            data <= 32'h00000013;  // NOP
        end else if (!imem_stall) begin
            data <= mem[word_addr];
        end
        // else: hold data
    end
`endif

endmodule
