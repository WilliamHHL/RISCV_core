module IF (
    input         clk,
    input         rst,
    input  [31:0] pc,
    input         if_stall,    // 1 = hold current IF outputs (stall IF stage)
    output [31:0] instr,
    output reg [31:0] if_pc,
    input if_flush
);

    // Instruction memory output
    wire [31:0] imem_data;
    wire [31:0] imem_pc;

    imem u_imem (
        .clk        (clk),
        .addr       (pc),
        .data       (imem_data),
        .imem_stall (if_stall),
        .rst        (rst)
        //.imem_pc(imem_pc)
    );
    /*
    // PC used for the *fetch* that will produce the next imem_data
    reg [31:0] pc_q;

    // Registered instruction so we can truly "hold" on stall
    reg [31:0] instr_r;
    assign instr = instr_r;

    always @(posedge clk) begin
        if (rst) begin
            pc_q    <= 32'b0;
            if_pc   <= 32'b0;
            instr_r <= 32'h00000013;  // RISC‑V NOP (addi x0, x0, 0)
        end else if (!if_stall) begin
            // imem_data now corresponds to pc_q from the previous cycle
            if_pc   <= imem_pc;  // originally is pc_q
            //pc_q    <= pc;    // <-- remember PC used for the *next* fetch
            instr_r <= imem_data;
        end
        // else: if_stall=1 => hold pc_q, if_pc, instr_r
    end
    */
    assign instr    = (if_flush)? 32'b0:imem_data;
    reg [31:0] pc_q;
    assign if_pc = (if_flush)?32'b0:pc_q;
    always @(posedge clk) begin
        pc_q <= pc;
    end
    //assign if_pc    = imem_pc;
    //assign if_valid = imem_valid;
endmodule 