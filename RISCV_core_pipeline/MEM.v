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
    localparam [31:0] DMEM_BASE    = 32'h1000_0000;
    localparam integer DMEM_BYTES  = 131072; // 128 KiB
    localparam [31:0] UART_TX_ADDR = 32'h2000_0000;

    // Byte-wide DMEM (read/write)
    reg [7:0] dmem [0:DMEM_BYTES-1];

    // Address decoding
    wire [31:0] dmem_off = alu_result - DMEM_BASE;
    wire        in_dmem  = (alu_result >= DMEM_BASE) && (dmem_off < DMEM_BYTES);
    wire        is_uart  = (alu_result == UART_TX_ADDR);

    `ifndef SYNTHESIS
    initial begin
    $readmemh("data.hex", dmem);
    end
    `endif
    
`ifndef SYNTHESIS
    // Strict OOR and alignment checks (Harvard: no data access to IMEM)
    always @(*) begin
        if (mem_read || mem_write) begin
            // Out-of-range checks: only DMEM reads/writes are valid (plus UART write)
            if (mem_read) begin
                if (!in_dmem) begin
                    $fatal(1, "Load OOR: 0x%08x (only DMEM 0x1000_0000..+size is valid)", alu_result);
                end
            end
            if (mem_write) begin
                if (!in_dmem && !is_uart) begin
                    $fatal(1, "Store OOR: 0x%08x (only DMEM or UART TX addr is valid)", alu_result);
                end
            end

            // Alignment checks when inside DMEM
            if (mem_read && in_dmem) begin
                if (load_size == 2'b01) begin // LH/LHU
                    if (alu_result[0] != 1'b0) begin
                        $display("ALIGN-ERR LH pc=%08x instr=%08x addr=%08x size=%0d",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, load_size);
                        $fatal(1, "Unaligned halfword @0x%08x", alu_result);
                    end
                end
                if (load_size[1]) begin // LW
                    if (alu_result[1:0] != 2'b00) begin
                        $display("ALIGN-ERR LW pc=%08x instr=%08x addr=%08x size=%0d",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, load_size);
                        $fatal(1, "Unaligned word @0x%08x", alu_result);
                    end
                end
            end

            if (mem_write && in_dmem) begin
                if (store_size == 2'b01) begin // SH
                    if (alu_result[0] != 1'b0) begin
                        $display("ALIGN-ERR SH pc=%08x instr=%08x addr=%08x size=%0d rs2=%08x",
                                 tb_top.uut.pc, tb_top.uut.instr, alu_result, store_size, rs2_data);
                        $fatal(1, "Unaligned halfword store @0x%08x", alu_result);
                    end
                end
                if (store_size == 2'b10) begin // SW
                    if (alu_result[1:0] != 2'b00) begin
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
/*
    // Synchronous read with 1-cycle latency
    reg        rd_en_q;
    reg [31:0] rd_addr_q;
    reg [1:0]  load_size_q;
    reg        load_signed_q;
    reg [31:0] dmem_off_q;

    

    always @(posedge clk) begin
    // Register request for 1-cycle latency
    rd_en_q <= mem_read;
    dmem_off_q <= dmem_off;
    load_size_q <= load_size;
    load_signed_q <= load_signed;

    if (rd_en_q) begin
        if (dmem_off_q < DMEM_BYTES) begin
            case (load_size_q)
                2'b00: begin
                    mem_data <= load_signed_q
                        ? {{24{dmem[dmem_off_q][7]}}, dmem[dmem_off_q]}
                        : {24'b0, dmem[dmem_off_q]};
                end
                2'b01: begin
                    mem_data <= load_signed_q
                        ? {{16{dmem[dmem_off_q+1][7]}}, dmem[dmem_off_q+1], dmem[dmem_off_q]}
                        : {16'b0, dmem[dmem_off_q+1], dmem[dmem_off_q]};
                end
                default: begin
                    mem_data <= { dmem[dmem_off_q+3], dmem[dmem_off_q+2], dmem[dmem_off_q+1], dmem[dmem_off_q+0] };
                end
            endcase
        end else begin
            // No readable MMIO other than DMEM
            mem_data <= 32'h0000_0000;
        end
        $display("MEM-RD: pc=%08x rd_en_q=1 off=%08x size=%0d signed=%0d => mem_data=%08x",
                 tb_top.uut.mem_pc, dmem_off_q, load_size_q, load_signed_q, mem_data); //newly added debug code
    end
    end
*/
    
    // Synchronous readv2: data becomes valid AFTER this clock edge
    always @(posedge clk) begin
        if (mem_read) begin
            if (in_dmem) begin
                case (load_size)
                    2'b00: mem_data <= load_signed
                        ? {{24{dmem[dmem_off][7]}}, dmem[dmem_off]}
                        : {24'b0, dmem[dmem_off]};
                    2'b01: mem_data <= load_signed
                        ? {{16{dmem[dmem_off+1][7]}}, dmem[dmem_off+1], dmem[dmem_off]}
                        : {16'b0, dmem[dmem_off+1], dmem[dmem_off]};
                    default: mem_data <= { dmem[dmem_off+3], dmem[dmem_off+2], dmem[dmem_off+1], dmem[dmem_off+0] };
                endcase
            end else begin
                mem_data <= 32'h0000_0000;
            end
        end
    end
    /*// Combinational read (fits 5-stage pipeline)
    always @(*) begin
        mem_data = 32'h0000_0000;
        if (mem_read && in_dmem) begin
            case (load_size)
                2'b00: mem_data = load_signed
                    ? {{24{dmem[dmem_off][7]}}, dmem[dmem_off]}
                    : {24'b0, dmem[dmem_off]};
                2'b01: mem_data = load_signed
                    ? {{16{dmem[dmem_off+1][7]}}, dmem[dmem_off+1], dmem[dmem_off]}
                    : {16'b0, dmem[dmem_off+1], dmem[dmem_off]};
                default: mem_data = {
                    dmem[dmem_off+3], dmem[dmem_off+2], dmem[dmem_off+1], dmem[dmem_off+0]
                };
            endcase
        end
    end */
    // Sequential write path
    always @(posedge clk) begin
        if (mem_write) begin
            `ifndef SYNTHESIS
            if (is_uart) begin
                uart_putc(rs2_data[7:0]);
            end 
            else
            `endif
            if (in_dmem) begin

                `ifndef SYNTHESIS
                if (alu_result >= 32'h1000_0000 && alu_result < 32'h1000_0010) begin
                    $display("DMEM WRITE to SIG: EA=%08x size=%0d data=%08x pc=%08x",
                            alu_result, store_size, rs2_data, tb_top.uut.pc);
                end
                `endif

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