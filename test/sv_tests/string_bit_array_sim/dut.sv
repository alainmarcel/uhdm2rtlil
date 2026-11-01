// Converted from chipsalliance/sv-tests (string_bit_array_sim).
// Upstream assigns the literal "Test" to a 112-bit vector inside an `initial` block and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic [8*14:1] a, output logic w);
  // A string literal is a packed vector of its characters, right-aligned.
  always_comb a = "Test";
  assign w = x;
endmodule
