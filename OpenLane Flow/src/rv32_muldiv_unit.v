// -----------------------------------------------------------------------------
// rv32_muldiv_unit
// -----------------------------------------------------------------------------
// Timing-friendly synthesizable RV32M multiply/divide unit.
//
// Implemented operations:
//   MUL, MULH, MULHSU, MULHU
//   DIV, DIVU, REM, REMU
//
// Design intent:
// - MUL operations use registered operands and a registered result, keeping the
//   32x32 multiplier out of the normal single-cycle EX ALU path.
// - DIV/REM operations use a simple 32-iteration restoring divider. No Verilog
//   '/' or '%' operators are used in this synthesizable unit.
//
// Latency model:
//   MUL: start cycle + 1 busy cycle + done cycle
//        From the top-level pipeline perspective this costs 2 stall cycles.
//   DIV/REM: special cases return quickly; normal divide performs 32 one-bit
//        iterations and then asserts done for one cycle.
//
// The top-level pipeline holds the EX instruction while busy and injects
// bubbles into EX/MEM until done=1. On the done cycle the result is valid and
// the instruction is allowed to leave EX.
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
    localparam [2:0] OP_DIV    = 3'd4;
    localparam [2:0] OP_DIVU   = 3'd5;
    localparam [2:0] OP_REM    = 3'd6;
    localparam [2:0] OP_REMU   = 3'd7;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_MUL  = 2'd1;
    localparam [1:0] S_DIV  = 2'd2;
    localparam [1:0] S_DONE = 2'd3;

    reg [1:0]  state_q;
    reg [2:0]  op_q;
    reg [31:0] rs1_q;
    reg [31:0] rs2_q;
    reg [31:0] result_q;

    // Divider state.
    reg [31:0] div_divisor_q;
    reg [31:0] div_dividend_shift_q;
    reg [31:0] div_quotient_q;
    reg [32:0] div_remainder_q;
    reg [5:0]  div_count_q;
    reg        div_quotient_neg_q;
    reg        div_remainder_neg_q;
    reg        div_result_is_rem_q;

    // Registered multiply datapath.
    wire        [63:0] rs1_u64 = {32'b0, rs1_q};
    wire        [63:0] rs2_u64 = {32'b0, rs2_q};
    wire signed [63:0] rs1_s64 = {{32{rs1_q[31]}}, rs1_q};
    wire signed [63:0] rs2_s64 = {{32{rs2_q[31]}}, rs2_q};
    wire signed [63:0] rs2_u_s64 = {32'b0, rs2_q};

    wire        [63:0] mul_uu = rs1_u64 * rs2_u64;
    wire signed [63:0] mul_ss = rs1_s64 * rs2_s64;
    wire signed [63:0] mul_su = rs1_s64 * rs2_u_s64;

    // Start-time divider classification and corner cases.
    wire start_is_div_op =
        (op == OP_DIV)  |
        (op == OP_DIVU) |
        (op == OP_REM)  |
        (op == OP_REMU);

    wire start_is_signed_div = (op == OP_DIV) | (op == OP_REM);
    wire start_is_rem        = (op == OP_REM) | (op == OP_REMU);
    wire start_div_by_zero   = (rs2 == 32'b0);
    wire start_div_overflow  =
        start_is_signed_div &&
        (rs1 == 32'h8000_0000) &&
        (rs2 == 32'hffff_ffff);

    wire start_rs1_neg = start_is_signed_div & rs1[31];
    wire start_rs2_neg = start_is_signed_div & rs2[31];

    wire [31:0] start_rs1_abs = start_rs1_neg ? (~rs1 + 32'd1) : rs1;
    wire [31:0] start_rs2_abs = start_rs2_neg ? (~rs2 + 32'd1) : rs2;

    wire [31:0] start_special_result =
        start_div_by_zero ?
            (((op == OP_DIV) | (op == OP_DIVU)) ? 32'hffff_ffff : rs1) :
        start_div_overflow ?
            ((op == OP_DIV) ? 32'h8000_0000 : 32'b0) :
            32'b0;

    // One restoring-divider iteration. The divider consumes dividend bits from
    // MSB to LSB and shifts the quotient left, appending the new quotient bit.
    wire [32:0] div_trial_remainder = {div_remainder_q[31:0], div_dividend_shift_q[31]};
    wire [32:0] div_divisor_ext     = {1'b0, div_divisor_q};
    wire        div_trial_ge        = (div_trial_remainder >= div_divisor_ext);
    wire [32:0] div_remainder_next  = div_trial_ge ?
                                      (div_trial_remainder - div_divisor_ext) :
                                       div_trial_remainder;
    wire [31:0] div_quotient_next   = {div_quotient_q[30:0], div_trial_ge};
    wire [31:0] div_shift_next      = {div_dividend_shift_q[30:0], 1'b0};

    wire [31:0] div_quotient_signed =
        div_quotient_neg_q ? (~div_quotient_next + 32'd1) : div_quotient_next;
    wire [31:0] div_remainder_signed =
        div_remainder_neg_q ? (~div_remainder_next[31:0] + 32'd1) : div_remainder_next[31:0];
    wire [31:0] div_final_result =
        div_result_is_rem_q ? div_remainder_signed : div_quotient_signed;

    assign busy   = (state_q == S_MUL) | (state_q == S_DIV);
    assign done   = (state_q == S_DONE);
    assign result = result_q;

    always @(posedge clk) begin
        if (rst) begin
            state_q              <= S_IDLE;
            op_q                 <= 3'd0;
            rs1_q                <= 32'd0;
            rs2_q                <= 32'd0;
            result_q             <= 32'd0;
            div_divisor_q        <= 32'd0;
            div_dividend_shift_q <= 32'd0;
            div_quotient_q       <= 32'd0;
            div_remainder_q      <= 33'd0;
            div_count_q          <= 6'd0;
            div_quotient_neg_q   <= 1'b0;
            div_remainder_neg_q  <= 1'b0;
            div_result_is_rem_q  <= 1'b0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (start) begin
                        op_q <= op;

                        if (start_is_div_op) begin
                            if (start_div_by_zero | start_div_overflow) begin
                                result_q <= start_special_result;
                                state_q  <= S_DONE;
                            end else begin
                                div_divisor_q        <= start_rs2_abs;
                                div_dividend_shift_q <= start_rs1_abs;
                                div_quotient_q       <= 32'd0;
                                div_remainder_q      <= 33'd0;
                                div_count_q          <= 6'd0;
                                div_quotient_neg_q   <= start_is_signed_div & (rs1[31] ^ rs2[31]);
                                div_remainder_neg_q  <= start_is_signed_div & rs1[31];
                                div_result_is_rem_q  <= start_is_rem;
                                state_q              <= S_DIV;
                            end
                        end else begin
                            rs1_q   <= rs1;
                            rs2_q   <= rs2;
                            state_q <= S_MUL;
                        end
                    end
                end

                S_MUL: begin
                    case (op_q)
                        OP_MUL:    result_q <= mul_uu[31:0];
                        OP_MULH:   result_q <= mul_ss[63:32];
                        OP_MULHSU: result_q <= mul_su[63:32];
                        OP_MULHU:  result_q <= mul_uu[63:32];
                        default:   result_q <= 32'd0;
                    endcase
                    state_q <= S_DONE;
                end

                S_DIV: begin
                    div_remainder_q      <= div_remainder_next;
                    div_quotient_q       <= div_quotient_next;
                    div_dividend_shift_q <= div_shift_next;

                    if (div_count_q == 6'd31) begin
                        result_q <= div_final_result;
                        state_q  <= S_DONE;
                    end else begin
                        div_count_q <= div_count_q + 6'd1;
                    end
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
