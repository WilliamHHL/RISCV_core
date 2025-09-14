module PC_reg(
    input clk,
    input rstn_sync,
    output reg [31:0] pc,
    input [31:0] pc_next
);

    always @(posedge clk) begin
        if (rstn_sync)
            pc <= 32'h8000_0000;
        else
            pc <= pc_next;
    end

endmodule