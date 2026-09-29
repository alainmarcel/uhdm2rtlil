// `signed >= 2**(f())-1` where f() returns `int unsigned`: the exponent of
// `**` is self-determined and takes no part in the result's signedness, so
// the compare is SIGNED (iverilog, Verilator, read_slang agree).  The reader
// grouped `**` with the arithmetic operators ("signed iff all operands are")
// and compared unsigned: fpnew_fma_multi's overflow check
// `final_exponent >= 2**(fpnew_pkg::exp_bits(dst_fmt_q2))-1` fired on every
// NEGATIVE exponent and the FMA returned infinity.
module pow_exponent_self_determined (
  input  logic signed [12:0] e,
  input  logic        [2:0]  sel,
  output logic               of_fn,      // 2**(unsigned function) - 1: SIGNED compare
  output logic               of_const,   // 2**8 - 1: signed compare (reference)
  output logic               of_unsigned // plain unsigned function: UNSIGNED compare
);
  function automatic int unsigned exp_bits(input logic [2:0] fmt);
    return fmt[0] ? 11 : 8;
  endfunction
  assign of_fn       = e >= 2**(exp_bits(sel))-1;
  assign of_const    = e >= 2**8-1;
  assign of_unsigned = e >= exp_bits(sel);
endmodule
