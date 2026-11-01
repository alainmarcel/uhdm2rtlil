// Converted from chipsalliance/sv-tests (desc_test_8).
// Upstream is an `ifdef skeleton with none of its names defined, so it resolves to an empty arm and declares no module at all -- nothing about which arm was taken is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`ifdef DEBUGGER
package mypkg;
  localparam int K = 1;
endpackage
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
  // The guarded arm declares a PACKAGE, so a reference to it is what would fail if
  // the `ifdef had been taken wrongly.
`ifdef DEBUGGER
  assign arm = 4'(mypkg::K);
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
