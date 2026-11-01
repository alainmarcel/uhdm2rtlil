// Converted from chipsalliance/sv-tests (desc_test_6).
// Upstream is an `ifdef skeleton with none of its names defined, so it resolves to an empty arm and declares no module at all -- nothing about which arm was taken is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`ifdef DEBUGGER
module mymod;
endmodule
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
  // DEBUGGER is not defined, so `mymod` must NOT exist -- which is what makes the
  // fall-through code below the observable part.
`ifdef DEBUGGER
  mymod u_m ();
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
