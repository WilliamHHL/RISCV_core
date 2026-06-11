// csr_wb_read.v - reads CSR at retire time, independent of pipeline stages
module csr_wb_read (
    input  wire [11:0] csr_addr,     // CSR address (pipelined to WB)
    input  wire [63:0] cycle_cnt,    // Current cycle count from top
    input  wire        csr_hit,      // Is this a CSR read instruction?
    output wire [31:0] csr_data      // CSR value at WB (retire) time
);

    reg [31:0] data;
    
    always @(*) begin
        if (csr_hit) begin
            case (csr_addr)
                12'hC00, 12'hB00: data = cycle_cnt[31:0];     // cycle / mcycle
                12'hC80, 12'hB80: data = cycle_cnt[63:32];    // cycleh / mcycleh
                12'hC02, 12'hB02: data = 32'd0;               // instret (add if needed)
                12'hC82, 12'hB82: data = 32'd0;               // instreth
                12'hF14:          data = 32'd0;               // mhartid
                default:          data = 32'd0;
            endcase
        end else begin
            data = 32'd0;
        end
    end
    
    assign csr_data = data;

endmodule