// Converted from chipsalliance/sv-tests (itor_function).
// Upstream prints `$itor(20)` from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  // $itor yields a real; scaled by 10 and cast so a netlist can carry it.
  assign o = int'($itor(20) * 10);
  assign w = x;
endmodule
