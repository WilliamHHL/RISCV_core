// csr_read.v - ID stage: detect CSR instruction and extract address
module csr_read (
    input  wire [31:0] instr,
    output wire        csr_hit,      // 1 if this is a CSR read instruction
    output wire [11:0] csr_addr      // CSR address to pipeline to WB
);
 
    localparam [6:0] OPCODE_SYSTEM = 7'b1110011;

    wire [6:0]  opcode   = instr[6:0];
    wire [2:0]  funct3   = instr[14:12];
    wire [11:0] csr_adr  = instr[31:20];

    // CSRRW/CSRRS/CSRRC (funct3 = 001/010/011) and immediate variants (101/110/111)
    wire csr_read_like = (funct3 == 3'b001) || (funct3 == 3'b010) || (funct3 == 3'b011) ||
                         (funct3 == 3'b101) || (funct3 == 3'b110) || (funct3 == 3'b111);
    wire is_system     = (opcode == OPCODE_SYSTEM);

    // Supported CSRs: cycle, cycleh, mcycle, mcycleh
    wire supported_csr = (csr_adr == 12'hC00) || (csr_adr == 12'hC80) ||
                         (csr_adr == 12'hB00) || (csr_adr == 12'hB80);

    assign csr_hit  = is_system && csr_read_like && supported_csr;
    assign csr_addr = csr_adr;

endmodule