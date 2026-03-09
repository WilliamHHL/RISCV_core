module PC_reg(
    input         clk,
    input         rst,
    output reg [31:0] pc,
    input         pc_stall,

    // Redirect from EX (mispredict / jal / jalr correction)
    input         ex_redirect,
    input  [31:0] ex_redirect_pc,

    // Redirect from IF predictor
    input         if_pred_redirect,
    input  [31:0] if_pred_target
);

reg [31:0] dbg_cnt;
reg [31:0] pc_before;

always @(posedge clk) begin
    pc_before <= pc;

    if (rst) begin
        pc      <= 32'b0;
        dbg_cnt <= 32'd0;
    end
    else if (ex_redirect) begin
        pc      <= ex_redirect_pc;
        dbg_cnt <= dbg_cnt + 1'b1;
    end
    else if (!pc_stall) begin
        if (if_pred_redirect) begin
            pc <= if_pred_target;
        end else begin
            pc <= pc + 32'd4;
        end
        dbg_cnt <= dbg_cnt + 1'b1;
    end
    else begin
        dbg_cnt <= dbg_cnt + 1'b1;
        pc <= pc;
    end
end

endmodule