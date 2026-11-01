// Converted from chipsalliance/sv-tests (number_test_24).
// Upstream declares the parameter at $unit scope and leaves the module EMPTY, so the literal's value reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
parameter int foo = 'd0;
module test(input logic signed [31:0] x, output logic signed [31:0] o,
            output logic signed [31:0] w);
  // The parameter declaration is kept verbatim; its value is an output now.
  assign o = foo;
  // A port-driven witness: many of these literals are 0, and a netlist whose every
  // output is constant zero makes the co-sim VACUOUS rather than comparing.
  assign w = x;
endmodule
