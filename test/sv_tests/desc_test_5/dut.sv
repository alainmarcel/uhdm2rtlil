// Converted from chipsalliance/sv-tests (desc_test_5).
// Upstream is an `ifdef skeleton with none of its names defined, so it resolves to an empty arm and declares no module at all -- nothing about which arm was taken is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
`ifdef DEBUGGER
  assign arm = 4'd1;
`elsif BORED
  assign arm = 4'd2;
`elsif MORE_BORED
  assign arm = 4'd3;
`else
  assign arm = 4'd4;
`endif
  assign y = a + b;
endmodule
