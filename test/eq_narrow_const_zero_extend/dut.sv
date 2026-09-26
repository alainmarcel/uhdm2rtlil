// A narrow constant on one side of `==` / `!=` was SIGN-extended whenever its
// MSB was 1 (a rule meant for `a == -1`), so `count == 1'b1` compared an
// 8-bit counter with 8'hFF and `x == 3'b101` with 8'hFD: verilog-ethernet
// axis_cobs_encode's output FSM (`if (output_count_reg == 1'b1)`) never
// returned to IDLE (243 co-sim divergences).  LRM 11.8.2: the narrower
// operand is sign-extended only when BOTH operands are signed, else
// zero-extended; a folded arithmetic sub-expression (`-1`, `2 - 3`) is
// evaluated at the expression width, which is what read_slang does too.
module eq_narrow_const_zero_extend (
  input  logic        [7:0]  cnt,
  input  logic signed [7:0]  scnt,
  input  logic        [63:0] wide,
  input  logic        [1:0]  st,
  input  logic               rdy,
  output logic               eq_1b1,
  output logic               ne_1b1,
  output logic               eq_3b101,
  output logic               eq_signed_lit_unsigned_lhs,
  output logic               eq_signed_lit_signed_lhs,
  output logic               eq_minus_one,
  output logic               eq_folded_sub,
  output logic        [1:0]  nst
);
  localparam IDLE = 2'd0, SEG = 2'd1;
  assign eq_1b1   = (cnt == 1'b1);
  assign ne_1b1   = (cnt != 1'b1);
  assign eq_3b101 = (cnt == 3'b101);
  assign eq_signed_lit_unsigned_lhs = (cnt  == 4'sb1000);
  assign eq_signed_lit_signed_lhs   = (scnt == 4'sb1000);
  assign eq_minus_one  = (wide == -1);
  assign eq_folded_sub = (wide == 2 - 3);
  // the axis_cobs_encode shape: a 1-bit literal compare inside a case arm
  always @* begin
    nst = IDLE;
    case (st)
      IDLE: nst = IDLE;
      SEG:  if (rdy) begin
              if (cnt == 1'b1) nst = IDLE; else nst = SEG;
            end else nst = SEG;
      default: nst = IDLE;
    endcase
  end
endmodule
