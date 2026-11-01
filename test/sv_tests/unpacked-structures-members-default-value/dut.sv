// Converted from chipsalliance/sv-tests (unpacked-structures-members-default-value).
// Upstream gives one struct member a DEFAULT VALUE from a parameter, writes the other in an `initial` block, and prints both.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [3:0] x, output logic [3:0] lo_o, output logic [3:0] hi_o);
parameter c = 4'h5;
struct {
	bit [3:0] lo = c;
	bit [3:0] hi;
} p1;
  // `lo` is never written, so its DEFAULT must survive as its value.
  always_comb p1.hi = x;
  assign lo_o = p1.lo; assign hi_o = p1.hi;
endmodule
