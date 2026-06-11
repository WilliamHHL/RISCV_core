// Simple return-address stack (RAS) for simulation/RTL experiments.
//
// - DEPTH should be a power of two.
// - top_valid/top_addr provide a combinational prediction target.
// - Updates are made on resolved control-flow in EX in the current core.
// - On simultaneous pop+push, this module pops one return and then pushes the
//   new return address. That is a reasonable default for JALR coroutine hints,
//   although this core currently only uses simple call/return classification.
module ras_stack #(
    parameter DEPTH = 16,
    parameter PTR_BITS = 4
) (
    input  wire        clk,
    input  wire        rst,

    output wire        top_valid,
    output wire [31:0] top_addr,

    input  wire        push,
    input  wire [31:0] push_addr,
    input  wire        pop
);

    reg [31:0] stack [0:DEPTH-1];
    reg [PTR_BITS-1:0] sp;       // next free slot
    reg [PTR_BITS:0]   count;    // 0..DEPTH, saturating

    localparam [PTR_BITS:0] DEPTH_VALUE = DEPTH;

    wire non_empty = (count != {(PTR_BITS+1){1'b0}});
    wire full      = (count == DEPTH_VALUE);
    wire [PTR_BITS-1:0] top_idx = sp - {{(PTR_BITS-1){1'b0}}, 1'b1};

    assign top_valid = non_empty;
    assign top_addr  = non_empty ? stack[top_idx] : 32'b0;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            sp    <= {PTR_BITS{1'b0}};
            count <= {(PTR_BITS+1){1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                stack[i] <= 32'b0;
        end else begin
            case ({push, pop})
                2'b00: begin
                    // no update
                end

                2'b01: begin
                    // pop
                    if (non_empty) begin
                        sp    <= sp - {{(PTR_BITS-1){1'b0}}, 1'b1};
                        count <= count - {{PTR_BITS{1'b0}}, 1'b1};
                    end
                end

                2'b10: begin
                    // push; if full, overwrite the oldest entry by advancing sp
                    stack[sp] <= push_addr;
                    sp        <= sp + {{(PTR_BITS-1){1'b0}}, 1'b1};
                    if (!full)
                        count <= count + {{PTR_BITS{1'b0}}, 1'b1};
                end

                2'b11: begin
                    // pop then push. If empty, this degenerates into push.
                    if (non_empty) begin
                        stack[sp - {{(PTR_BITS-1){1'b0}}, 1'b1}] <= push_addr;
                        // sp and count unchanged: one pop plus one push
                    end else begin
                        stack[sp] <= push_addr;
                        sp        <= sp + {{(PTR_BITS-1){1'b0}}, 1'b1};
                        count     <= count + {{PTR_BITS{1'b0}}, 1'b1};
                    end
                end
            endcase
        end
    end

endmodule
