module csr_read (
    input  [31:0] instr,
    input  [63:0] cycle_cnt,
    output        csr_hit,     // 1 if this instruction should return a CSR value
    output [31:0] csr_data     // value to return on WB when csr_hit=1
);
 
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    wire [6:0] opcode  = instr[6:0];
    wire [2:0] funct3  = instr[14:12];
    wire [11:0] csr_adr = instr[31:20];

    // CSRRW/CSRRS/CSRRC read forms (we ignore immediate forms for now)
    wire csr_read_like = (funct3 == 3'b001) || (funct3 == 3'b010) || (funct3 == 3'b011);
    wire is_system     = (opcode == OPCODE_SYSTEM);

    // Only support mcycle low (RV32): CSR=0xB00
    wire is_mcycle     = is_system && csr_read_like && (csr_adr == 12'hB00);

    assign csr_hit  = is_mcycle;
    assign csr_data = cycle_cnt[31:0];  // mcycle low
endmodule