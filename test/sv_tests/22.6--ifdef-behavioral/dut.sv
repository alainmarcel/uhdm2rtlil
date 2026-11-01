// Converted from chipsalliance/sv-tests (22.6--ifdef-behavioral, :type: preprocessing).
// Upstream already has real logic, but its two `ifdef arms compute the SAME
// function, so which one compiled cannot be told from the netlist.  Both arms are
// kept VERBATIM and each now also sets a witness bit, so the arm selection is
// observable -- and the ports are given directions and types so the module
// synthesizes.
// Upstream kept as orig.sv.
module and_op (a, b, c, which);
	output a;
	output which;
	input b, c;
	`ifdef behavioral
		wire a = b & c;
		wire which = 1'b1;
	`else
		and a1 (a,b,c);
		wire which = 1'b0;
	`endif
endmodule
