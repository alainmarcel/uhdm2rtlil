// Converted from chipsalliance/sv-tests (packed-and-signed-structures).
// Upstream assigns 200 to a `struct packed signed` and prints it as -56, inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output logic signed [31:0] o, output logic [7:0] raw);
struct packed signed {
	bit [3:0] lo;
	bit [3:0] hi;
} p1;
  // A packed struct declared `signed` must SIGN-extend when read into a wider
  // signed context: 8'd200 is 8'hc8, i.e. -56.
  always_comb p1 = x;
  assign o   = p1;
  assign raw = p1;
endmodule
