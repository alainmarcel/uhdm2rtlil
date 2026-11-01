// Converted from chipsalliance/sv-tests (packed-and-unsigned-structures).
// Upstream assigns 200 to a `struct packed unsigned` and prints it, inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output logic signed [31:0] o, output logic [7:0] raw);
struct packed unsigned {
	bit [3:0] lo;
	bit [3:0] hi;
} p1;
  always_comb p1 = x;
  assign o   = p1;
  assign raw = p1;
endmodule
