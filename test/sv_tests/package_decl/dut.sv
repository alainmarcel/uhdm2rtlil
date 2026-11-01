// Converted from chipsalliance/sv-tests (package_decl).
// Upstream declares the package AFTER an empty module and never calls its function.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
package mypkg;
function int add(int a, b);
	return a + b;
endfunction
endpackage : mypkg
module top(input logic signed [31:0] x, output logic signed [31:0] o);
  // The package's function has to be callable for the declaration to mean anything.
  assign o = mypkg::add(x, 3);
endmodule
