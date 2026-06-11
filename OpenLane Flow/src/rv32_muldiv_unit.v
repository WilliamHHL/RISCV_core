// -----------------------------------------------------------------------------
// rv32_muldiv_unit
// -----------------------------------------------------------------------------
// First timing-friendly RV32M unit commit.
//
// This module currently implements only the RV32M multiply subset:
//   MUL, MULH, MULHSU, MULHU
// using registered operands and a registered 64-bit product. It intentionally
// does not implement DIV/REM yet. No Verilog '/' or '%' operators are used.
//
// Latency model for MUL operations:
//   cycle N:     start=1, operands/op are captured
//   cycle N+1:   product is calculated from registered operands and captured
//   cycle N+2:   done=1, result is valid
//
// The top-level pipeline holds the EX instruction while busy and injects
// bubbles into EX/MEM until done=1. This keeps the design simple and removes
// the 32x32 multiplier from the normal single-cycle EX ALU critical path.
// -----------------------------------------------------------------------------

module rv32_muldiv_unit (
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [2:0]  op,
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,

    output wire        busy,
    output wire        done,
    output wire [31:0] result
);
    localparam [2:0] OP_MUL    = 3'd0;
    localparam [2:0] OP_MULH   = 3'd1;
    localparam [2:0] OP_MULHSU = 3'd2;
    localparam [2:0] OP_MULHU  = 3'd3;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_MUL  = 2'd1;
    localparam [1:0] S_DONE = 2'd2;

    reg [1:0]  state_q;
    reg [2:0]  op_q;
    reg [31:0] rs1_q;
    reg [31:0] rs2_q;
    reg [63:0] product_q;

    wire        [63:0] rs1_u64 = {32'b0, rs1_q};
    wire        [63:0] rs2_u64 = {32'b0, rs2_q};
    wire signed [63:0] rs1_s64 = {{32{rs1_q[31]}}, rs1_q};
    wire signed [63:0] rs2_s64 = {{32{rs2_q[31]}}, rs2_q};
    wire signed [63:0] rs2_u_s64 = {32'b0, rs2_q};

    wire        [63:0] mul_uu = rs1_u64 * rs2_u64;
    wire signed [63:0] mul_ss = rs1_s64 * rs2_s64;
    wire signed [63:0] mul_su = rs1_s64 * rs2_u_s64;

    assign busy   = (state_q == S_MUL);
    assign done   = (state_q == S_DONE);
    assign result =
        (op_q == OP_MUL)    ? product_q[31:0]  :
        (op_q == OP_MULH)   ? product_q[63:32] :
        (op_q == OP_MULHSU) ? product_q[63:32] :
        (op_q == OP_MULHU)  ? product_q[63:32] :
                               32'd0;

    always @(posedge clk) begin
        if (rst) begin
            state_q   <= S_IDLE;
            op_q      <= 3'd0;
            rs1_q     <= 32'd0;
            rs2_q     <= 32'd0;
            product_q <= 64'd0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (start) begin
                        op_q    <= op;
                        rs1_q   <= rs1;
                        rs2_q   <= rs2;
                        state_q <= S_MUL;
                    end
                end

                S_MUL: begin
                    case (op_q)
                        OP_MUL:    product_q <= mul_uu;
                        OP_MULH:   product_q <= mul_ss;
                        OP_MULHSU: product_q <= mul_su;
                        OP_MULHU:  product_q <= mul_uu;
                        default:   product_q <= 64'd0;
                    endcase
                    state_q <= S_DONE;
                end

                S_DONE: begin
                    state_q <= S_IDLE;
                end

                default: begin
                    state_q <= S_IDLE;
                end
            endcase
        end
    end

endmodule
