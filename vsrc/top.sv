module top(
    input  logic clk,
    input  logic rstn_sync
);
    logic [31:0] pc, pc_next;
    logic [31:0] instr;

    // PC register
    PC_reg u_pc_reg(
        .clk(clk),
        .rstn_sync(rstn_sync),
        .pc(pc),
        .pc_next(pc_next)
    );

    // IF stage (fetch)
    IF u_if(
        .clk(clk),
        .pc(pc),
        .instr(instr)
    );

    // PC update logic: increment by 4 every cycle (for now)
    assign pc_next = pc + 32'd4;

    // For simulation: monitor PC and instruction
    initial begin
        $monitor("PC=%08x INSTR=%08x", pc, instr);
    end

endmodule
