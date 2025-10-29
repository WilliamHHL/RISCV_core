`ifndef SYNTHESIS
import "DPI-C" function void uart_putc(input byte c);
`endif

module MEM (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [31:0] alu_result,
    input  [31:0] rs2_data,
    output reg [31:0] mem_data,
    input         load_signed,     // 1: signed load, 0: unsigned
    input  [1:0]  load_size,       // 00: byte, 01: halfword, 10/11: word
    input  [1:0]  store_size
);

    // Memory map
    localparam [31:0] IMEM_BASE    = 32'h0000_0000;
    localparam integer IMEM_BYTES  = 131072; // 128 KiB, must match imem.v
    localparam [31:0] DMEM_BASE    = 32'h1000_0000;
    localparam integer DMEM_BYTES  = 131072; // 128 KiB
    localparam [31:0] UART_TX_ADDR = 32'h2000_0000;

    // Byte-wide ROM mirror for IMEM (read-only for data loads)
    reg [7:0] rom [0:IMEM_BYTES-1];

    // Byte-wide DMEM (read/write)
    reg [7:0] dmem [0:DMEM_BYTES-1];

`ifndef SYNTHESIS
    initial begin
        // Load the same program image into ROM so data path can read from IMEM region
        // Note: imem.v also loads program.hex for instruction fetch
        $readmemh("program.hex", rom);
        // Optional: preload DMEM from a file if desired
        // $readmemh("data.hex", dmem);
    end
`endif

    // Address decoding
    wire [31:0] imem_off = alu_result - IMEM_BASE;
    wire [31:0] dmem_off = alu_result - DMEM_BASE;

    /* verilator lint_off UNSIGNED */
    wire in_imem = (alu_result >= IMEM_BASE) && (imem_off < IMEM_BYTES);
    /* verilator lint_on UNSIGNED */
    wire in_dmem = (alu_result >= DMEM_BASE) && (dmem_off < DMEM_BYTES);
    wire is_uart = (alu_result == UART_TX_ADDR);

`ifndef SYNTHESIS
    // Strict alignment and OOR checks with diagnostic prints
    always @(*) begin
        if (mem_read || mem_write) begin
            // Out-of-range checks
            if (mem_read) begin
                if (!in_dmem && !in_imem) begin
                    $fatal(1, "Load OOR: 0x%08x", alu_result);
                end
            end
            if (mem_write) begin
                if (!in_dmem && !is_uart) begin
                    $fatal(1, "Store OOR: 0x%08x", alu_result);
                end
            end

            // Alignment checks only when inside valid windows
            if (mem_read && (in_dmem || in_imem)) begin
                if (load_size == 2'b01) begin // LH/LHU
                    if ((alu_result[0] & 1'b1) != 1'b0) begin
                        $display("ALIGN-ERR LH pc=%08x instr=%08x addr=%08x size=%0d",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, load_size);
                        $fatal(1, "Unaligned halfword @0x%08x", alu_result);
                    end
                end
                if (load_size[1]) begin // LW
                    if ((alu_result[1:0] & 2'b11) != 2'b00) begin
                        $display("ALIGN-ERR LW pc=%08x instr=%08x addr=%08x size=%0d",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, load_size);
                        $fatal(1, "Unaligned word @0x%08x", alu_result);
                    end
                end
            end

            if (mem_write && in_dmem) begin
                if (store_size == 2'b01) begin // SH
                    if ((alu_result[0] & 1'b1) != 1'b0) begin
                        $display("ALIGN-ERR SH pc=%08x instr=%08x addr=%08x size=%0d rs2=%08x",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, store_size, rs2_data);
                        $fatal(1, "Unaligned halfword store @0x%08x", alu_result);
                    end
                end
                if (store_size == 2'b10) begin // SW
                    if ((alu_result[1:0] & 2'b11) != 2'b00) begin
                        // Detailed context to locate the offending code
                        $display("ALIGN-ERR SW pc=%08x instr=%08x addr=%08x rs1=x%0d rs2=%08x imm=%08x EA=%08x funct3=%0d",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result,
                                 tb_top.uut.u_ID.rs1_addr, rs2_data,
                                 tb_top.uut.u_immgen.imm, tb_top.uut.u_EX.alu_core_result,
                                 tb_top.uut.u_ID.funct3);
                        $fatal(1, "Unaligned word store @0x%08x", alu_result);
                    end
                end
            end
        end
    end
`endif

    // Combinational read path
    always @(*) begin
        mem_data = 32'b0;
        if (mem_read) begin
            if (in_dmem) begin
                // DMEM load
                case (load_size)
                    2'b00: begin
                        mem_data = load_signed
                            ? {{24{dmem[dmem_off][7]}}, dmem[dmem_off]}
                            : {24'b0, dmem[dmem_off]};
                    end
                    2'b01: begin
                        mem_data = load_signed
                            ? {{16{dmem[dmem_off+1][7]}}, dmem[dmem_off+1], dmem[dmem_off]}
                            : {16'b0, dmem[dmem_off+1], dmem[dmem_off]};
                    end
                    default: begin
                        mem_data = { dmem[dmem_off+3], dmem[dmem_off+2], dmem[dmem_off+1], dmem[dmem_off+0] };
                    end
                endcase
            end else if (in_imem) begin
                // IMEM load (read-only ROM mirror)
                case (load_size)
                    2'b00: begin
                        mem_data = load_signed
                            ? {{24{rom[imem_off][7]}}, rom[imem_off]}
                            : {24'b0, rom[imem_off]};
                    end
                    2'b01: begin
                        mem_data = load_signed
                            ? {{16{rom[imem_off+1][7]}}, rom[imem_off+1], rom[imem_off]}
                            : {16'b0, rom[imem_off+1], rom[imem_off]};
                    end
                    default: begin
                        mem_data = { rom[imem_off+3], rom[imem_off+2], rom[imem_off+1], rom[imem_off+0] };
                    end
                endcase
            end else begin
                // MMIO readable area could be added here (e.g., cycle counter)
                mem_data = 32'h0000_0000;
            end
        end
    end

    // Sequential write path
    always @(posedge clk) begin
        if (mem_write) begin
`ifndef SYNTHESIS
            if (is_uart) begin
                uart_putc(rs2_data[7:0]);
            end else
`endif
            if (in_dmem) begin
                case (store_size)
                    2'b00: dmem[dmem_off] <= rs2_data[7:0];
                    2'b01: begin
                        dmem[dmem_off]   <= rs2_data[7:0];
                        dmem[dmem_off+1] <= rs2_data[15:8];
                    end
                    2'b10: begin
                        dmem[dmem_off]   <= rs2_data[7:0];
                        dmem[dmem_off+1] <= rs2_data[15:8];
                        dmem[dmem_off+2] <= rs2_data[23:16];
                        dmem[dmem_off+3] <= rs2_data[31:24];
                    end
                    default: begin
                        dmem[dmem_off]   <= rs2_data[7:0];
                        dmem[dmem_off+1] <= rs2_data[15:8];
                        dmem[dmem_off+2] <= rs2_data[23:16];
                        dmem[dmem_off+3] <= rs2_data[31:24];
                    end
                endcase
            end
        end
    end

endmodule