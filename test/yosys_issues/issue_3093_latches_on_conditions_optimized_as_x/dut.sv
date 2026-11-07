// YosysHQ/yosys#3093 (closed): Latches on conditions optimized as X upon multiple conditions
// https://github.com/YosysHQ/yosys/issues/3093
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mwe (
	input  logic       i_clk   , //!
	input  logic       i_rst_n , //!
	input  logic       i_valid , //!
	input  logic       i_force , //!
	output logic [2:0] o_signal  //!
);

	always_ff @(posedge i_clk or negedge i_rst_n) begin : p_seq
		if (~ i_rst_n ) begin
			o_signal <= 0;
		end else begin
			if (i_force) begin
				o_signal <= 0;
			end else if (i_valid) begin
				o_signal <= o_signal +1;
			end
		end
	end

endmodule

