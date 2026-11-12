// povik/sv-elab#168 (open): Support for tagged unions and pattern matching
// https://github.com/povik/sv-elab/issues/168
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module case_tb ();

	typedef union tagged {
		struct {
			bit [3:0] val1, val2;
		} a;
		struct {
			bit [7:0] val1, val2;
		} b;
		struct {
			bit [15:0] val1, val2;
		} c;
	} u;

	u tmp;

	bit [3:0] val;

	initial begin
          val = tmp matches tagged a '{4'b01zx, .v} ? 1 : 2;
	end
endmodule

