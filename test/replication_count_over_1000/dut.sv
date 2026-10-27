// A replication count ABOVE 1000.
//
// UHDM's ExprEval clamps a replication count to 1000
// (third_party/UHDM templates/ExprEval.cpp:
//     if (n > 1000) n = 1000;   // Must be -1 or something silly
// ), a guard against a garbage count that silently truncates every legitimate
// wide replication.  The reader pre-folds a whole operation through ExprEval
// when nothing in it needs the reader's own resolution, so
// `{{(INT_NUM-1){1'b1}}, 1'b0}` -- the standard "all ones except bit 0" mask
// -- came back as a 1001-bit constant instead of 1024.  yosys then
// ZERO-EXTENDS it to the 1024-bit AND, so the top 23 bits of the mask are 0
// and the masked value loses them.
//
// OpenC910's PLIC has INT_NUM = 1024: every per-hart interrupt-enable mask
// (hart_mie_flop_msk_zero / hart_sie_flop_msk_zero) lost its top 23 bits, and
// hreg_arbx_int_en -- the enable bus the arbiter reads -- was wrong for every
// interrupt above 1000.  plic_hreg_busif was `differs` with 5 co-simulated
// divergences and read_slang clean.
//
// The second form is the one that actually appears in the wild: inside a
// GENERATE SCOPE Surelog has already substituted the parameter's value, so the
// count arrives as the literal `1024 - 1` and a guard keyed on "the count
// mentions a parameter" never fires.
module replication_count_over_1000 #(parameter INT_NUM = 1024) (
  input  [INT_NUM-1:0] y,
  output [INT_NUM-1:0] x,        // count is `INT_NUM-1`, a parameter expression
  output [INT_NUM-1:0] g         // count is a literal after generate substitution
);
  assign x = y & {{(INT_NUM-1){1'b1}}, 1'b0};

  wire [INT_NUM-1:0] gm [0:0];
  genvar i;
  generate
    for (i = 0; i < 1; i = i + 1) begin : G
      assign gm[i] = y & {{(INT_NUM-1){1'b1}}, 1'b0};
    end
  endgenerate
  assign g = gm[0];
endmodule
