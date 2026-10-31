// Converted from chipsalliance/sv-tests (22.7--timescale-module, :type: preprocessing).
// Upstream spends its `timescale on `#d` delays in an initial block, which
// synthesis has nothing to do with, and the real parameter d reaches nothing else.
// The `timescale and the parameter are kept VERBATIM; the delays are replaced by a
// scaled read of d, so the REAL parameter's value is observable.  A `timescale's
// own effect is a simulation-time one and no netlist can show it -- see NOTE.md.
// Upstream kept as orig.sv.
`timescale 10 ns / 1 ns
module test(output logic [8:0] o);
	logic set;
	parameter d = 1.55;
	// The real parameter has to survive elaboration with its value: 1.55 * 100
	// rounds to 155, and a parameter lost or truncated to an integer does not.
	assign o = int'(d * 100);
	assign set = 1'b0;
endmodule
