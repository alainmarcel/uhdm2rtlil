// Converted from chipsalliance/sv-tests (integers-left-padding).
// Upstream assigns seven literals with x and z padding inside an `initial` block and never reads them, so none of the padding rules its comments state is checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [11:0] a, output logic [11:0] b, output logic [11:0] c,
           output logic [11:0] d, output logic [84:0] e, output logic [84:0] f,
           output logic [84:0] g);
  assign a = 'h x;   // yields xxx
  assign b = 'h 3x;  // yields 03x
  assign c = 'h z3;  // yields zz3
  assign d = 'h 0z3; // yields 0z3
  assign e = 'h5;    // yields {82{1'b0},3'b101}
  assign f = 'hx;    // yields {85{1'hx}}
  assign g = 'hz;    // yields {85{1'hz}}
endmodule
