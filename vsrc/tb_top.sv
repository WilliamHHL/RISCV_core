// verilator lint_off BLKSEQ
module tb_top;
    logic clk = 0;
    logic rstn_sync = 1;

    // Instantiate the top module
    top u_top(
        .clk(clk),
        .rstn_sync(rstn_sync)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Reset for 2 cycles
        #15 rstn_sync = 0;
        // Run for 40 cycles (or as needed)
        #400 $finish;
    end
endmodule

