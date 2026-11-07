// YosysHQ/yosys#3604 (closed): Incorrect return value from `$bits` function
// https://github.com/YosysHQ/yosys/issues/3604
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(output int o);

	typedef struct packed {
		logic [1:0][15:0] v_2x16;
		logic [1:0] 	  v_2bit;
	} struct_2el;

	struct_2el array;

	assign o = $bits(array.v_2x16[0]);
endmodule

