module hazard_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire       clk,
    input  wire       rst,

    // ID/EX (EX stage)
    input  wire       idex_mem_read,
    input  wire [4:0] idex_rd,
    input  wire       idex_csr_hit,

    // EX/MEM
    input  wire [4:0] exmem_rd,
    input  wire       exmem_csr_hit,

    // redirect from EX
    input  wire       ex_redirect,

    output wire       stall_if,
    output wire       stall_id,
    output wire       flush_ifid,
    output wire       flush_idex
);

    wire load_use_hazard =
        idex_mem_read &&
        (idex_rd != 5'd0) &&
        ((idex_rd == id_rs1) || (idex_rd == id_rs2));

    wire csr_use_hazard_ex =
        idex_csr_hit &&
        (idex_rd != 5'd0) &&
        ((idex_rd == id_rs1) || (idex_rd == id_rs2));

    wire csr_use_hazard_mem =
        exmem_csr_hit &&
        (exmem_rd != 5'd0) &&
        ((exmem_rd == id_rs1) || (exmem_rd == id_rs2));

    wire any_data_hazard = load_use_hazard | csr_use_hazard_ex | csr_use_hazard_mem;

    assign stall_if = any_data_hazard;
    assign stall_id = any_data_hazard;

    reg ex_redirect_q;
    always @(posedge clk) begin
        if (rst)
            ex_redirect_q <= 1'b0;
        else
            ex_redirect_q <= ex_redirect;
    end

    assign flush_ifid = ex_redirect | ex_redirect_q;
    assign flush_idex = ex_redirect | any_data_hazard;

endmodule
