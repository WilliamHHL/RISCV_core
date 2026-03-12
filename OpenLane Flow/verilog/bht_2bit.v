module bht_2bit #(
    parameter INDEX_BITS = 4
) (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] r_pc,
    output wire        pred_taken,

    input  wire        update_en,
    input  wire [31:0] u_pc,
    input  wire        actual_taken
);
    localparam ENTRIES = (1 << INDEX_BITS);

    wire [INDEX_BITS-1:0] r_idx;
    wire [INDEX_BITS-1:0] u_idx;
    wire [1:0] r_ctr;
    wire [1:0] u_ctr_cur;
    wire [1:0] u_ctr_next;

    reg [1:0] ctr_array [0:ENTRIES-1];

    assign r_idx     = r_pc[INDEX_BITS+1:2];
    assign u_idx     = u_pc[INDEX_BITS+1:2];
    assign r_ctr     = ctr_array[r_idx];
    assign u_ctr_cur = ctr_array[u_idx];

    assign pred_taken = r_ctr[1];

    assign u_ctr_next =
        actual_taken
            ? ((u_ctr_cur == 2'b11) ? 2'b11 : (u_ctr_cur + 2'b01))
            : ((u_ctr_cur == 2'b00) ? 2'b00 : (u_ctr_cur - 2'b01));

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                ctr_array[i] <= 2'b01;
        end else if (update_en) begin
            ctr_array[u_idx] <= u_ctr_next;
        end
    end
endmodule
