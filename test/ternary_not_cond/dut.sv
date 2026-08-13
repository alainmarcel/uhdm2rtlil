// Repro of CVA6 alu.sv MIN/MINU bug: `result_o = ~less ? operand_b :
// operand_a;` — a `~cond` ternary condition inside a wide-LHS case-arm
// assignment.  The condition is SELF-DETERMINED per LRM; importing it under
// the 64-bit LHS context widens `less` before the `~`, so `~less` is nonzero
// for BOTH values and the mux always picks operand_b (UHDM MIN == MAX).
module ternary_not_cond (
    input  logic [7:0] op_i,
    input  logic [7:0] a_i,
    input  logic [7:0] b_i,
    output logic [7:0] y_o,
    output logic [7:0] z_o
);
  logic less;
  assign less = a_i < b_i;

  // continuous-assign shape
  assign z_o = ~less ? b_i : a_i;

  // case-arm shape (the CVA6 alu context)
  always_comb begin
    y_o = '0;
    unique case (op_i)
      8'd170:  y_o = less ? b_i : a_i;   // MAX
      8'd172:  y_o = ~less ? b_i : a_i;  // MIN
      default: y_o = a_i;
    endcase
  end
endmodule
