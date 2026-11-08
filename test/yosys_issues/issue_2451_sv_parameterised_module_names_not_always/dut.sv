// YosysHQ/yosys#2451 (closed): SV: Parameterised module names not always contain interface parameters.
// https://github.com/YosysHQ/yosys/issues/2451
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): wrapper top added: the interface-port module cannot be a co-sim top

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

module harness_top (input wire clock, input wire [31:0] ping0, input wire [31:0] ping1,
                    output wire [31:0] pong0, output wire [31:0] pong1);
	pingpong #(.WIDTH(32)) p0();
	pingpong #(.WIDTH(32)) p1();
	assign p0.ping = ping0;
	assign p1.ping = ping1;
	assign pong0 = p0.pong;
	assign pong1 = p1.pong;
	top u (.clock(clock), .p0(p0), .p1(p1));
endmodule
