module IF_ID (
    input         clk,
    input         rst,
    input         id_stall,       // stall request from ID side
    input         ifid_flush,     // flush request (e.g., on redirect)
    input  [31:0] if_pc,          // PC produced by IF
    input  [31:0] if_instr,       // Instruction fetched in IF
    output reg [31:0] id_pc,      // PC presented to ID
    output reg [31:0] id_instr    // Instruction presented to ID
);
    always @(posedge clk or posedge rst) begin
        if (rst || ifid_flush) begin
            id_pc    <= 32'b0;
            id_instr <= 32'h00000013; // NOP
            
        end else if (!id_stall) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
    end
endmodule
