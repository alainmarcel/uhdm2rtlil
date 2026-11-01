// Converted from chipsalliance/sv-tests (countbits_function).
// Upstream prints all five counts from an `initial` block on a constant, so neither the counts nor the CONTROL BITS that select which values are counted reach anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] val, output logic signed [31:0] n_ones,
           output logic signed [31:0] n_ones2, output logic signed [31:0] n_zeros,
           output logic signed [31:0] n_both, output logic signed [31:0] n_xz);
  // Upstream's own asserted numbers are for 32'h70008421, which has 7 set bits.
  // The control-bit forms are what distinguish $countbits from $countones.
  assign n_ones  = $countbits(val, '1);
  assign n_ones2 = $countones(val);
  assign n_zeros = $countbits(val, '0);
  assign n_both  = $countbits(val, '0, '1);
  assign n_xz    = $countbits(val, 'x, 'z);
endmodule
