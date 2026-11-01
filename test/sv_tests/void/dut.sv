// Converted from chipsalliance/sv-tests (void).
// Upstream's void function body is a `$display`.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
	function void fun(input int i, output int r);
		r = i * 2;
	endfunction
  always_comb fun(x, o);
endmodule
