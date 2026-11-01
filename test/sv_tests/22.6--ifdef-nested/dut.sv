// Converted from chipsalliance/sv-tests (22.6--ifdef-nested, :type: preprocessing).
// Upstream marks each nesting level with a $display, so which of the three nested
// arms compiled cannot be told from the netlist.  The four `define directives and
// the nesting are kept VERBATIM, and each level now assigns its own output, so
// every level's selection is read back as a value.
// Upstream kept as orig.sv.
module test(output logic [1:0] lvl0, output logic [1:0] lvl1,
            output logic [1:0] lvl2);
`define wow
`define nest_one
`define second_nest
`define nest_two
`ifdef wow
	assign lvl0 = 2'd1;
	`ifdef nest_one
		assign lvl1 = 2'd1;
		`ifdef nest_two
			assign lvl2 = 2'd1;
		`else
			assign lvl2 = 2'd2;
		`endif
	`else
		assign lvl1 = 2'd2;
		assign lvl2 = 2'd0;
	`endif
`else
	assign lvl0 = 2'd2;
	assign lvl1 = 2'd0;
	`ifdef second_nest
		assign lvl2 = 2'd3;
	`else
		assign lvl2 = 2'd0;
	`endif
`endif
endmodule
