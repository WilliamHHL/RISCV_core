module PC_reg(
    input clk,
    input rst_sync,
    output reg [31:0] pc,
    input [31:0] pc_next
);

    always @(posedge clk) begin
        if (rst_sync)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

endmodule