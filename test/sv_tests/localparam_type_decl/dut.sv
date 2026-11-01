// Converted from chipsalliance/sv-tests (localparam_type_decl).
// Upstream declares a TYPE localparam and a variable of it, and never drives or reads the variable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic x, output logic o, output logic signed [31:0] nbits);
  localparam type testtype = logic;
  testtype t;
  // The type localparam must actually name a type: the variable declared over it
  // has to be a usable one-bit signal, which $bits and the round trip both read.
  always_comb t = x;
  assign o     = t;
  assign nbits = $bits(testtype);
endmodule
