// YosysHQ/yosys#2451 (closed): SV: Parameterised module names not always contain interface parameters.
// https://github.com/YosysHQ/yosys/issues/2451
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
interface pingpong #(parameter WIDTH=32);
	logic [WIDTH-1:0] ping;
	logic [WIDTH-1:0] pong;
	modport pinger(output ping, input pong);
	modport ponger(output pong, input ping);
endinterface

module responder #(parameter WIDTH=32) (input wire clock, pingpong.ponger ping);
	assign ping.pong = ping.ping;
	assert property (ping.ping == ping.pong);
endmodule

module top(input wire clock, pingpong.ponger p0, pingpong.ponger p1);
	responder #(.WIDTH(32)) resp0(.clock(clock), .ping(p0));
	responder #(.WIDTH(32)) resp1(.clock(clock), .ping(p1));
	assert property (p0.ping == p0.pong);
	assert property (p1.ping == p1.pong);
endmodule

