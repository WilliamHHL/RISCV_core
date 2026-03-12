module btb_direct #(
    parameter INDEX_BITS = 4,
    parameter TAG_BITS   = 8
) (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] r_pc,
    output wire        hit,
    output wire [31:0] pred_target,
    output wire        pred_is_jump,

    input  wire        update_en,
    input  wire [31:0] u_pc,
    input  wire [31:0] u_target,
    input  wire        u_is_jump
);

    localparam ENTRIES = (1 << INDEX_BITS);

    reg [ENTRIES-1:0]   valid_bits;
    reg [TAG_BITS-1:0]  tag_array     [0:ENTRIES-1];
    reg [29:0]          target_array  [0:ENTRIES-1];
    reg                 is_jump_array [0:ENTRIES-1];

    wire [INDEX_BITS-1:0] r_idx;
    wire [TAG_BITS-1:0]   r_tag;
    wire [INDEX_BITS-1:0] u_idx;
    wire [TAG_BITS-1:0]   u_tag;

    wire                  valid_r;
    wire [TAG_BITS-1:0]   tag_r;
    wire [29:0]           target_r;
    wire                  is_jump_r;

    assign r_idx = r_pc[INDEX_BITS+1:2];
    assign u_idx = u_pc[INDEX_BITS+1:2];

    assign r_tag = r_pc[INDEX_BITS+TAG_BITS+1:INDEX_BITS+2];
    assign u_tag = u_pc[INDEX_BITS+TAG_BITS+1:INDEX_BITS+2];

    assign valid_r  = valid_bits[r_idx];
    assign tag_r    = tag_array[r_idx];
    assign target_r = target_array[r_idx];
    assign is_jump_r = is_jump_array[r_idx];

    assign hit         = valid_r & (tag_r == r_tag);
    assign pred_target = {target_r, 2'b00};
    assign pred_is_jump = is_jump_r;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_bits <= {ENTRIES{1'b0}};
        end else if (update_en) begin
            valid_bits[u_idx]    <= 1'b1;
            tag_array[u_idx]     <= u_tag;
            target_array[u_idx]  <= u_target[31:2];
            is_jump_array[u_idx] <= u_is_jump;
        end
    end

endmodule
