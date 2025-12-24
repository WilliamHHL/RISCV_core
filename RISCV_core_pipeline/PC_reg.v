module PC_reg(
    input clk,
    input rst,
    output reg [31:0] pc,
    input [31:0] pc_next
);
reg [7:0] dbg_cnt;
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
            dbg_cnt <= 8'd0;
        end
        else begin
            pc <= pc_next;
            dbg_cnt <= dbg_cnt + 1'b1;
        end
    end

endmodule