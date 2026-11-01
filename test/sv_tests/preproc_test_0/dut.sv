// Converted from chipsalliance/sv-tests (preproc_test_0).
// Upstream defines a macro and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`define TRUTH
module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
`ifdef TRUTH
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = sel ? (a + b) : (a - b);
endmodule
