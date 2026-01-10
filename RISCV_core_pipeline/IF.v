module IF (
    input         clk,
    input         rst,
    input [31:0] pc,
    input         if_stall,    // 1 = hold current IF outputs (stall IF stage)
    output [31:0] instr,
    output reg [31:0] if_pc
);

    // Instruction memory output
    wire [31:0] imem_data;
    //wire [31:0] addr_q;

    imem u_imem (   // 可支援同步或非同步 IMEM 實作
        .clk (clk),
        .addr(pc),
        .data(imem_data),
        .imem_stall(if_stall)
        //.addr_q
    );
    reg [31:0] pc_q = pc;
    // Registered instruction so we can真正“hold” on stall
    reg [31:0] instr_r;
    assign instr = instr_r;

    always @(posedge clk) begin
        if (rst) begin
            if_pc   <= 32'b0;
            // RISC‑V NOP = addi x0, x0, 0 = 0x00000013
            instr_r <= 32'h00000013;
        end
        else if (!if_stall) begin
            // 正常情況：更新 IF.pc 與 instr
            if_pc   <= pc;
            instr_r <= imem_data;
        end
            //pc_q <= pc_q;
            // if_stall = 1：保持上一拍的 if_pc / instr_r 不變
            // (什麼都不做就會 hold 住)
    end

endmodule