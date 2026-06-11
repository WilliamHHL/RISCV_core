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
     `ifdef USE_POWER_PINS
    , inout         vccd1,
    inout         vssd1
    `endif
);
	wire [1:0] byte_sel;
	wire [7:0] index;
	wire       in_dmem;
	wire       is_uart;

	assign byte_sel = alu_result[1:0];
	assign index    = alu_result[9:2];
	assign in_dmem  = (alu_result[31:10] == 22'h040000);
	assign is_uart  = (alu_result == 32'h2000_0000);
    // Memory map (1 KiB DMEM for this macro)
    // DMEM: 0x1000_0000 ~ 0x1000_03FF (1 KiB)
    // UART: 0x2000_0000

   

    

`ifdef SYNTHESIS
    // -------------------------
    // SRAM macro implementation
    // -------------------------

    // Register the load formatting controls so they align with synchronous SRAM dout
    reg [1:0]  byte_sel_q;
    reg [1:0]  load_size_q;
    reg        load_signed_q;

    always @(posedge clk) begin
        if (mem_read && in_dmem) begin
            byte_sel_q    <= byte_sel;
            load_size_q   <= load_size;
            load_signed_q <= load_signed;
        end
    end

    // Byte write mask and aligned write data for masked writes
    reg [3:0]  wmask;
    reg [31:0] din_aligned;

    always @(*) begin
        // defaults
        wmask       = 4'b0000;
        din_aligned = rs2_data;

        case (store_size)
            2'b00: begin
                // SB: write one byte lane; replicate byte so selected lane gets correct value
                wmask       = (4'b0001 << byte_sel);
                din_aligned = {4{rs2_data[7:0]}};
            end
            2'b01: begin
                // SH: write two byte lanes; replicate halfword
                wmask       = byte_sel[1] ? 4'b1100 : 4'b0011;
                din_aligned = {2{rs2_data[15:0]}};
            end
            default: begin
                // SW: write full word
                wmask       = 4'b1111;
                din_aligned = rs2_data;
            end
        endcase
    end

    // Enable SRAM only for DMEM accesses
    wire dmem_en = in_dmem && (mem_read || mem_write);

    // Common convention: csb/web are active-low
    wire csb0 = ~dmem_en;
    wire web0 = ~(in_dmem && mem_write);

    wire [31:0] dout0;

    sky130_sram_1kbyte_1rw1r_32x256_8 u_dmem (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
`endif
        // Port 0: RW
        .clk0   (clk),
        .csb0   (csb0),
        .web0   (web0),

        // NOTE: if your macro expects active-low wmask, change to (~wmask)
        .wmask0 (wmask),

        .addr0  (index),
        .din0   (din_aligned),
        .dout0  (dout0),

        // Port 1: R (unused)
        .clk1   (32'b0),
        .csb1   (1'b1),
        .addr1  (8'b0),
        .dout1  ()
    );

    // Format read data from SRAM dout0 using the registered controls
    reg [7:0]  selected_byte;
    reg [15:0] selected_half;

    always @(*) begin
        // byte select
        case (byte_sel_q)
            2'b00: selected_byte = dout0[7:0];
            2'b01: selected_byte = dout0[15:8];
            2'b10: selected_byte = dout0[23:16];
            default: selected_byte = dout0[31:24];
        endcase

        // halfword select
        selected_half = byte_sel_q[1] ? dout0[31:16] : dout0[15:0];

        // default
        mem_data = dout0;

        case (load_size_q)
            2'b00: mem_data = load_signed_q ? {{24{selected_byte[7]}}, selected_byte}
                                            : {24'b0, selected_byte};
            2'b01: mem_data = load_signed_q ? {{16{selected_half[15]}}, selected_half}
                                            : {16'b0, selected_half};
            default: mem_data = dout0; // LW
        endcase
    end

`else
    // -------------------------
    // Behavioral DMEM for sim
    // -------------------------
    reg [31:0] dmem [0:255];

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

    wire [31:0] word_read = dmem[index];

    reg [7:0] selected_byte;
    always @(*) begin
        case (byte_sel)
            2'b00: selected_byte = word_read[7:0];
            2'b01: selected_byte = word_read[15:8];
            2'b10: selected_byte = word_read[23:16];
            default: selected_byte = word_read[31:24];
        endcase
    end

    reg [15:0] selected_half;
    always @(*) begin
        selected_half = byte_sel[1] ? word_read[31:16] : word_read[15:0];
    end

    // Load path
    always @(posedge clk) begin
        if (mem_read && in_dmem) begin
            case (load_size)
                2'b00:   mem_data <= load_signed ? {{24{selected_byte[7]}}, selected_byte}
                                                 : {24'b0, selected_byte};
                2'b01:   mem_data <= load_signed ? {{16{selected_half[15]}}, selected_half}
                                                 : {16'b0, selected_half};
                default: mem_data <= word_read;
            endcase
        end
    end

    // Store path
    always @(posedge clk) begin
        if (mem_write) begin
            if (is_uart) begin
                uart_putc(rs2_data[7:0]);
            end else if (in_dmem) begin
                case (store_size)
                    2'b00: begin
                        case (byte_sel)
                            2'b00: dmem[index][7:0]   <= rs2_data[7:0];
                            2'b01: dmem[index][15:8]  <= rs2_data[7:0];
                            2'b10: dmem[index][23:16] <= rs2_data[7:0];
                            default: dmem[index][31:24] <= rs2_data[7:0];
                        endcase
                    end
                    2'b01: begin
                        if (!byte_sel[1]) dmem[index][15:0]  <= rs2_data[15:0];
                        else              dmem[index][31:16] <= rs2_data[15:0];
                    end
                    default: dmem[index] <= rs2_data;
                endcase
            end
        end
    end
`endif

endmodule
