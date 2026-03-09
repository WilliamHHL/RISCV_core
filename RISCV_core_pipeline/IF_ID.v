module IF_ID (
    input         clk,
    input         rst,
    input         id_stall,
    input         ifid_flush,

    input  [31:0] if_pc,
    input  [31:0] if_instr,
    input         if_pred_taken,
    input  [31:0] if_pred_target,

    output reg [31:0] id_pc,
    output reg [31:0] id_instr,
    output reg        id_pred_taken,
    output reg [31:0] id_pred_target
);
    always @(posedge clk) begin
        if (rst || ifid_flush) begin
            id_pc          <= 32'b0;
            id_instr       <= 32'h00000013; // NOP
            id_pred_taken  <= 1'b0;
            id_pred_target <= 32'b0;
        end else if (!id_stall) begin
            id_pc          <= if_pc;
            id_instr       <= if_instr;
            id_pred_taken  <= if_pred_taken;
            id_pred_target <= if_pred_target;
        end
    end
endmodule