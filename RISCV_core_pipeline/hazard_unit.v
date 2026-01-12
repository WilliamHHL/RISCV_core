module hazard_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input clk,
    input rst,

    // ID/EX (EX stage)
    input  wire       idex_mem_read,
    input  wire [4:0] idex_rd,
    input  wire       idex_reg_write,

    // EX/MEM
    input  wire       exmem_reg_write,
    input  wire [4:0] exmem_rd,

    // MEM/WB
    input  wire       memwb_reg_write,
    input  wire [4:0] memwb_rd,

    // redirect from EX (branch/jal/jalr taken)
    input  wire       ex_redirect,

    output wire       stall_if,
    output wire       stall_id,
    output wire       flush_ifid,
    output wire       flush_idex
);

    // Load-use hazard only:
    // ID needs id_rs1/id_rs2; EX stage has a load which will write idex_rd,
    // and that load result won't be ready until MEM/WB.
    wire load_use_hazard =
        idex_mem_read &&
        (idex_rd != 5'd0) &&
        ((idex_rd == id_rs1) || (idex_rd == id_rs2));

    // No ALU RAW hazards here: WB bypass in regfile already handles that.

    // Stalls on load-use
    assign stall_if  = load_use_hazard;
    assign stall_id  = load_use_hazard;

    // Flushing:
    // - on load-use, bubble EX by flushing ID/EX (once)
    // - on redirect, flush IF/ID and ID/EX
    //assign flush_ifid = ex_redirect;                 // kill wrong-path instr in IF/ID
    reg flush_ifid_q;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flush_ifid_q <= 1'b0;
        end else begin
            if (ex_redirect)       // cycle 0: branch taken
                flush_ifid_q <= 1'b1;
            else if (flush_ifid_q) // cycle 1 after redirect
                flush_ifid_q <= 1'b0;
        end
    end

    assign flush_ifid = ex_redirect | flush_ifid_q;
    assign flush_idex = ex_redirect || load_use_hazard; // kill EX instr on redirect or load-use

endmodule