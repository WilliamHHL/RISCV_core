module IF (
    input         clk,
    input         rst,
    input  [31:0] pc,
    input         if_stall,

    input         fetch_pred_taken,
    input  [31:0] fetch_pred_target,

    output [31:0] instr,
    output reg [31:0] if_pc,
    output reg        if_pred_taken,
    output reg [31:0] if_pred_target
);

    wire [31:0] imem_data;

    imem u_imem (
        .clk        (clk),
        .addr       (pc),
        .data       (imem_data),
        .imem_stall (if_stall),
        .rst        (rst)
    );

    assign instr = imem_data;

    always @(posedge clk) begin
        if (rst) begin
            if_pc          <= 32'b0;
            if_pred_taken  <= 1'b0;
            if_pred_target <= 32'b0;
        end else if (!if_stall) begin
            if_pc          <= pc;
            if_pred_taken  <= fetch_pred_taken;
            if_pred_target <= fetch_pred_target;
        end
    end

endmodule