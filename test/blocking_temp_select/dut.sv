// Minimal reproduction of the alu_sub bug: a BLOCKING temp in always_ff that
// is read same-cycle via a PART-SELECT and a BIT-SELECT (not a whole-signal
// ref).  PR #291 redirected whole-signal blocking-temp reads to the in-flight
// `$0\t`; part/bit-selects (`t[7:0]`, `t[8]`) were missed, so the consumer
// got an extra cycle of delay (the netlist read the registered `\t`).
module blocking_temp_select (
	input  wire       clk,
	input  wire [7:0] a,
	input  wire [7:0] b,
	output reg  [7:0] lo,
	output reg        carry
);
	reg [8:0] t;
	always @(posedge clk) begin
		t = a + b;       // blocking temp
		lo    <= t[7:0]; // part-select read, same cycle
		carry <= t[8];   // bit-select read, same cycle
	end
endmodule
