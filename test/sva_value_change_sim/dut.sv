module top (
	input  clk,
	// Outputs exposing the FSM state and assertion-monitored registers —
	// without them the DUT is purely self-checking.
	output [7:0] counter_o,
	output       a_o,
	output       b_o,
	output       c_o,
	output [2:0] wide_a_o,
	output [2:0] wide_b_o
);

reg [7:0] counter = 0;

reg a = 0;
reg b = 1;
reg c;
reg [2:0] wide_a = 3'b10x;
reg [2:0] wide_b = 'x;

`ifndef VERILATOR
// Explicit-clock `$fell/$rose/$stable(sig, @(posedge clk))` aren't accepted
// by Verilator 5.x — ifdef them out of co-sim but keep them in synth.
wire a_fell; assign a_fell = $fell(a, @(posedge clk));
wire a_rose; assign a_rose = $rose(a, @(posedge clk));
wire a_stable; assign a_stable = $stable(a, @(posedge clk));

wire b_fell; assign b_fell = $fell(b, @(posedge clk));
wire b_rose; assign b_rose = $rose(b, @(posedge clk));
wire b_stable; assign b_stable = $stable(b, @(posedge clk));

wire c_fell; assign c_fell = $fell(c, @(posedge clk));
wire c_rose; assign c_rose = $rose(c, @(posedge clk));
wire c_stable; assign c_stable = $stable(c, @(posedge clk));

wire wide_a_stable; assign wide_a_stable = $stable(wide_a, @(posedge clk));
wire wide_b_stable; assign wide_b_stable = $stable(wide_b, @(posedge clk));
`endif

assign counter_o = counter;
assign a_o       = a;
assign b_o       = b;
assign c_o       = c;
assign wide_a_o  = wide_a;
assign wide_b_o  = wide_b;

always @(posedge clk) begin
	counter <= counter + 1;

	case (counter)
		0: begin
`ifndef VERILATOR
            assert property ( $fell(a) && !$rose(a) && !$stable(a));
            assert property (!$fell(b) &&  $rose(b) && !$stable(b));
            assert property (!$fell(c) && !$rose(c) &&  $stable(c));
            assert property (!$stable(wide_a));
            assert property ($stable(wide_b));
`endif
            a <= 1; b <= 1; c <= 1;
        end
		1: begin
            a <= 0; b <= 1; c <= 'x;
            wide_a <= 3'b101; wide_b <= 3'bxx0;
        end
		2: begin
`ifndef VERILATOR
            assert property ( $fell(a) && !$rose(a) && !$stable(a));
            assert property (!$fell(b) && !$rose(b) &&  $stable(b));
            assert property (!$fell(c) && !$rose(c) && !$stable(c));
            assert property (!$stable(wide_a));
            assert property (!$stable(wide_b));
`endif
            a <= 0; b <= 0; c <= 0;
        end
		3: begin a <= 0; b <= 1; c <= 'x; end
		4: begin
`ifndef VERILATOR
            assert property (!$fell(a) && !$rose(a) &&  $stable(a));
            assert property (!$fell(b) &&  $rose(b) && !$stable(b));
            assert property (!$fell(c) && !$rose(c) && !$stable(c));
            assert property ($stable(wide_a));
            assert property ($stable(wide_b));
`endif
            a <= 'x; b <= 'x; c <= 'x;
            wide_a <= 'x; wide_b <= 'x;
        end
		5: begin
            a <= 0; b <= 1; c <= 'x;
            wide_a <= 3'b10x; wide_b <= 'x;
            counter <= 0;
        end
	endcase;
end

endmodule
