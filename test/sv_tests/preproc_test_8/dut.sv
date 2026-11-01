// Converted from chipsalliance/sv-tests (preproc_test_8).
// Upstream defines a macro whose body DEFINES ANOTHER macro and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`define INCEPTION(xyz) \
  `define DEEPER (xyz)
module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
`INCEPTION(7)
  // Expanding INCEPTION defines DEEPER, which must then expand to (7).
  assign arm = `DEEPER;
  assign y = sel ? (a + b) : (a - b);
endmodule
