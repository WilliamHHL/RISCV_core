module PC_reg(
    input         clk,
    input         rst,
    output reg [31:0] pc,
    input         pc_stall,
    input         ex_redirect,
    input  [31:0] ex_redirect_pc,
    input         if_pred_redirect,
    input  [31:0] if_pred_target
);

wire [31:0] pc_plus4 = pc + 32'd4;
wire [31:0] pc_pred_or_seq = if_pred_redirect ? if_pred_target : pc_plus4;
wire [31:0] pc_next = ex_redirect ? ex_redirect_pc : pc_pred_or_seq;
wire        pc_en   = ex_redirect | ~pc_stall;

always @(posedge clk) begin
    if (rst) begin
        pc <= 32'b0;
    end else if (pc_en) begin
        pc <= pc_next;
    end
end

endmodule