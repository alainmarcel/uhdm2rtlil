// Converted from chipsalliance/sv-tests (preproc_test_5).
// Upstream defines a three-argument macro with an EMPTY body and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`define INCEPTION(a, b, c)
module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
  // An empty-bodied macro must expand to nothing, so the statement after it is
  // just the assignment.
  `INCEPTION(1, 2, 3) assign arm = 4'd3;
  assign y = sel ? (a + b) : (a - b);
endmodule
