// povik/sv-elab#401: one asynchronous condition over two reset triggers,
// `if (!rst_a || !rst_b)`.  yosys's proc_arst recognises an async reset only
// when the switch tests a single trigger, so the three edge events reached
// proc_dff and it aborted ("Multiple edge sensitive events found for this
// signal!").  q is 1 while either reset is low, else it follows d.
module top(input clk, input rst_a, input rst_b, input d, output reg q);
  always @(posedge clk or negedge rst_a or negedge rst_b)
    if (!rst_a || !rst_b) q <= 1'b1;
    else q <= d;
endmodule
