// Converted from chipsalliance/sv-tests (preproc_test_2).
// Upstream includes a payload that defines SUCCESS, checks it with a bare string (a syntax error if it failed), and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`include "preproc_test_2.svh"
`ifndef SUCCESS
"Didn't successfully include preproc_test_2.svh!"
`endif
`ifndef SANITY
`define SANITY
`endif
module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
`ifdef SUCCESS
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = sel ? (a + b) : (a - b);
endmodule
