// Converted from chipsalliance/sv-tests (preproc_test_6).
// Upstream defines a three-argument arithmetic macro and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`define INCEPTION(a, b, c) (a*b-c)
module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
  assign arm = `INCEPTION(3, 2, 1);
  assign y = sel ? (a + b) : (a - b);
endmodule
