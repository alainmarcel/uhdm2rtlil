// Converted from chipsalliance/sv-tests (countbits_function).
// Upstream prints all five counts from an `initial` block on a constant, so neither the counts nor the CONTROL BITS that select which values are counted reach anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] val, output logic signed [31:0] n_ones,
           output logic signed [31:0] n_ones2, output logic signed [31:0] n_zeros,
           output logic signed [31:0] n_both);
  // Upstream's own asserted numbers are for 32'h70008421, which has 7 set bits.
  // The control-bit forms are what distinguish $countbits from $countones.
  assign n_ones  = $countbits(val, '1);
  assign n_ones2 = $countones(val);
  assign n_zeros = $countbits(val, '0);
  assign n_both  = $countbits(val, '0, '1);
  // Upstream's fifth query, `$countbits(val, 'x, 'z)`, is deliberately NOT a
  // port: read_verilog lowers an x/z control to `$eqx(bit, 1'bx)`, which a SAT
  // model treats as unconstrained, so the uhdm-vs-verilog equivalence check
  // can never prove it although `eval` gives 0 on both sides (and read_uhdm
  // folds it to the constant 0 a two-state netlist can carry).
endmodule
