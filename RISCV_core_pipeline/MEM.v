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

    // Load path
    wire [31:0] word_read = dmem[index];

    reg [7:0] selected_byte;
    always @(*) begin
        case (byte_sel)
            2'b00: selected_byte = word_read[7:0];
            2'b01: selected_byte = word_read[15:8];
            2'b10: selected_byte = word_read[23:16];
            2'b11: selected_byte = word_read[31:24];
        endcase
    end

    reg [15:0] selected_half;
    always @(*) begin
        case (byte_sel[1])
            1'b0: selected_half = word_read[15:0];
            1'b1: selected_half = word_read[31:16];
        endcase
    end

    always @(posedge clk) begin
        if (mem_read && in_dmem) begin
            case (load_size)
                2'b00:   mem_data <= load_signed ? {{24{selected_byte[7]}}, selected_byte} : {24'b0, selected_byte};
                2'b01:   mem_data <= load_signed ? {{16{selected_half[15]}}, selected_half} : {16'b0, selected_half};
                default: mem_data <= word_read;
            endcase
        end
    end

    // Store path
    always @(posedge clk) begin
        if (mem_write) begin
            `ifndef SYNTHESIS
            if (is_uart) begin
                uart_putc(rs2_data[7:0]);
            end else
            `endif
            if (in_dmem) begin
                case (store_size)
                    2'b00: begin
                        case (byte_sel)
                            2'b00: dmem[index][7:0]   <= rs2_data[7:0];
                            2'b01: dmem[index][15:8]  <= rs2_data[7:0];
                            2'b10: dmem[index][23:16] <= rs2_data[7:0];
                            2'b11: dmem[index][31:24] <= rs2_data[7:0];
                        endcase
                    end
                    2'b01: begin
                        case (byte_sel[1])
                            1'b0: dmem[index][15:0]  <= rs2_data[15:0];
                            1'b1: dmem[index][31:16] <= rs2_data[15:0];
                        endcase
                    end
                    default: dmem[index] <= rs2_data;
                endcase
            end
        end
    end

endmodule