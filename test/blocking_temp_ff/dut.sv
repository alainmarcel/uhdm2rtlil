// Minimal reproduction of picorv32's current_pc bug: a BLOCKING temp in an
// always_ff, read same-cycle by a non-blocking assignment.  q <= t must use
// the in-flight combinational t (= a+1), i.e. q <= a+1.  The UHDM frontend
// registered `t` (t <= a+1 as a FF) and made q read the DELAYED t, so q
// became a[t-1]+1 — a one-cycle lag that dropped picorv32 JAL targets.
module blocking_temp_ff (
	input  wire        clk,
	input  wire [31:0] a,
	output reg  [31:0] q
);
	reg [31:0] t;
	always @(posedge clk) begin
		t = a + 1;     // blocking combinational temp
		q <= t;        // non-blocking, reads t same cycle
	end
endmodule
