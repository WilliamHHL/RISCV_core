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
    input         load_signed,
    input  [1:0]  load_size,
    input  [1:0]  store_size
);

    // Memory map
    // DMEM: 0x1000_0000 ~ 0x1001_FFFF (128 KiB)
    // UART: 0x2000_0000

    reg [31:0] dmem [0:32767];

    // --- Decode (combinational, for assertions/debug like your original) ---
    wire [14:0] index    = alu_result[16:2];  // Word index
    wire [1:0]  byte_sel = alu_result[1:0];   // Byte select
    wire        in_dmem  = (alu_result[31:17] == 15'h0800);
    wire        is_uart  = (alu_result == 32'h2000_0000);

`ifndef SYNTHESIS
    initial begin
        $readmemh("data.hex", dmem);
    end

    always @(*) begin
        if (mem_read && !in_dmem)
            $fatal(1, "Load OOR: 0x%08x", alu_result);
        if (mem_write && !in_dmem && !is_uart)
            $fatal(1, "Store OOR: 0x%08x", alu_result);
        if (mem_read && in_dmem && load_size == 2'b01 && byte_sel[0])
            $fatal(1, "Unaligned LH/LHU @0x%08x", alu_result);
        if (mem_read && in_dmem && load_size[1] && byte_sel != 2'b00)
            $fatal(1, "Unaligned LW @0x%08x", alu_result);
        if (mem_write && in_dmem && store_size == 2'b01 && byte_sel[0])
            $fatal(1, "Unaligned SH @0x%08x", alu_result);
        if (mem_write && in_dmem && store_size == 2'b10 && byte_sel != 2'b00)
            $fatal(1, "Unaligned SW @0x%08x", alu_result);
    end
`endif

    // --------------------------------------------------------------------
    // Timing-like behavior:
    //   posedge: latch all inputs (addr/control/data/size/sign)
    //   negedge: perform write + read using latched values
    // --------------------------------------------------------------------
    reg        mem_read_q, mem_write_q;
    reg [31:0] addr_q, rs2_q;
    reg        load_signed_q;
    reg [1:0]  load_size_q, store_size_q;

    always @(posedge clk) begin
        mem_read_q    <= mem_read;
        mem_write_q   <= mem_write;
        addr_q        <= alu_result;
        rs2_q         <= rs2_data;
        load_signed_q <= load_signed;
        load_size_q   <= load_size;
        store_size_q  <= store_size;
    end

    // Derived fields from latched address
    wire [14:0] index_q    = addr_q[16:2];
    wire [1:0]  byte_sel_q = addr_q[1:0];
    wire        in_dmem_q  = (addr_q[31:17] == 15'h0800);
    wire        is_uart_q  = (addr_q == 32'h2000_0000);

    // Helper: apply a store (SB/SH/SW) to an existing word (write-first model)
    function automatic [31:0] apply_store_to_word(
        input [31:0] old_word,
        input [31:0] store_data,
        input [1:0]  st_size,
        input [1:0]  bsel
    );
        reg [31:0] w;
        begin
            w = old_word;
            case (st_size)
                2'b00: begin // SB
                    case (bsel)
                        2'b00: w[7:0]   = store_data[7:0];
                        2'b01: w[15:8]  = store_data[7:0];
                        2'b10: w[23:16] = store_data[7:0];
                        2'b11: w[31:24] = store_data[7:0];
                    endcase
                end
                2'b01: begin // SH
                    case (bsel[1])
                        1'b0: w[15:0]  = store_data[15:0];
                        1'b1: w[31:16] = store_data[15:0];
                    endcase
                end
                default: begin // SW (2'b10) or others
                    w = store_data;
                end
            endcase
            apply_store_to_word = w;
        end
    endfunction

    // Main memory action happens on negedge (like OpenRAM model)
    always @(negedge clk) begin : MEM_ACTION
        reg [31:0] word_before;
        reg [31:0] word_effective; // what a read returns (write-first if same-cycle write)
        reg [7:0]  sel_b;
        reg [15:0] sel_h;

        word_before    = dmem[index_q];
        word_effective = word_before;

        // WRITE (commit at negedge)
        if (mem_write_q) begin
`ifndef SYNTHESIS
            if (is_uart_q) begin
                uart_putc(rs2_q[7:0]);
            end
`endif
            if (in_dmem_q) begin
                word_effective = apply_store_to_word(word_before, rs2_q, store_size_q, byte_sel_q);
                dmem[index_q]  <= word_effective;
            end
        end

        // READ (produce data at negedge)
        if (mem_read_q && in_dmem_q) begin
            // select byte/half from word_effective (write-first if same-cycle store)
            case (byte_sel_q)
                2'b00: sel_b = word_effective[7:0];
                2'b01: sel_b = word_effective[15:8];
                2'b10: sel_b = word_effective[23:16];
                default: sel_b = word_effective[31:24];
            endcase

            case (byte_sel_q[1])
                1'b0: sel_h = word_effective[15:0];
                1'b1: sel_h = word_effective[31:16];
            endcase

            case (load_size_q)
                2'b00:   mem_data <= load_signed_q ? {{24{sel_b[7]}}, sel_b} : {24'b0, sel_b};
                2'b01:   mem_data <= load_signed_q ? {{16{sel_h[15]}}, sel_h} : {16'b0, sel_h};
                default: mem_data <= word_effective; // LW
            endcase
        end
        // else: hold mem_data (same as your original behavior)
    end

endmodule