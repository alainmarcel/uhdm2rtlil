// MikePopoloski/slang#1042 (closed): type support for parameterized virtual interfaces
// https://github.com/MikePopoloski/slang/issues/1042
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface my_intf # (
  IN_WIDTH = 8,
  OUT_WIDTH = 8
  )
  ();
  logic [IN_WIDTH-1:0] d_in;
  logic [OUT_WIDTH-1:0] d_out;
  
  modport sp (input d_in, output d_out);
  modport mp (output d_in, input d_out);
endinterface

module DUT(
	input logic clk,
	input logic reset,
	my_intf.sp intf_inst
);
	logic [7:0] d_flop1;
	always @(posedge clk) begin
		if (reset) begin
			intf_inst.d_out <= 0;
			d_flop1 <= 0;
		end else begin
			d_flop1 <= intf_inst.d_in;
			intf_inst.d_out <= d_flop1;
		end
	end

endmodule

