// Converted from chipsalliance/sv-tests (empty_string_sim).
// Upstream assigns the EMPTY STRING to a 112-bit vector inside an `initial` block and checks it with an immediate `assert`, which synthesis does not evaluate.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic is_zero, output logic [8*14:1] a_o);
  bit [8*14:1] a;
  // The empty string must zero the WHOLE vector, not just its low byte.
  always_comb a = "";
  assign a_o     = a;
  assign is_zero = (a == 0);
endmodule
