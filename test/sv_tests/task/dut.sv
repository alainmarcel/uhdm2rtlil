// Converted from chipsalliance/sv-tests (task).
// Upstream's task body is a `$display`, so calling it does nothing a netlist can see.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
task mytask(input int i, output int r);
	r = i + 1;
endtask
  always_comb mytask(x, o);
endmodule
