module PC_reg(
    input         clk,
    input         rst,
    output reg [31:0] pc,
    input         pc_stall,
    input         ex_redirect_taken,
    input  [31:0] ex_branch_target
);

reg [31:0]  dbg_cnt;
reg [31:0] pc_before;  // debug purpose

always @(posedge clk) begin
    pc_before <= pc; //debug purpose

    if (rst) begin
        pc      <= 32'b0;
        dbg_cnt <= 32'd0;
    end
    // branch/jump
    else if (ex_redirect_taken) begin
        pc      <= ex_branch_target;
        dbg_cnt <= dbg_cnt + 1'b1;
        `ifndef SYNTHESIS
        //$display("PC_REG BR  : ... pc_before=%08x pc_next=%08x", pc_before, ex_branch_target);
        `endif
    end
    else if (!pc_stall) begin
        pc      <= pc + 4;   // step,also equal to branch prediction: always not taken
        dbg_cnt <= dbg_cnt + 1'b1;
        `ifndef SYNTHESIS
        //$display("PC_REG STEP: time=%0t pc_before=%08x pc_after=%08x pc_stall=%b",
          //       $time, pc_before, pc, pc_stall);
        `endif
    end
    else begin
        // stall
        dbg_cnt <= dbg_cnt + 1'b1;
        pc <= pc;
        `ifndef SYNTHESIS
        //$display("PC_REG HOLD: time=%0t pc_before=%08x pc_after=%08x pc_stall=%b",
        //         $time, pc_before, pc, pc_stall);
        `endif
    end
end

endmodule