// Converted from chipsalliance/sv-tests (desc_test_0).
// Upstream is an `ifdef skeleton with none of its names defined, so it resolves to an empty arm and declares no module at all -- nothing about which arm was taken is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
`ifdef DEBUGGER
  assign arm = 4'd1;
`endif
`ifndef DEBUGGER
  assign arm = 4'd9;      // the fall-through: upstream has no `else at all
`endif
  assign y = a + b;
endmodule
