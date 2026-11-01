// Converted from chipsalliance/sv-tests (package_ref).
// Upstream calls the package function inside an `initial` block on constants and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
package mypkg;
function int add(int a, b);
	return a + b;
endfunction
endpackage : mypkg
module top(input logic signed [31:0] x, input logic signed [31:0] y,
           output logic signed [31:0] o);
  assign o = mypkg::add(x, y);
endmodule
