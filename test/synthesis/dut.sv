// === dff.sv ===
module top (
  input c,
  input d,
  output q
);

always @(posedge c)
  q <= d;

endmodule

// === dff_tb.v ===
`timescale 1ns/1ps

module sim;

reg clk = 1'b0;
reg d = 1'b0;
wire q;

glbl glbl();

top uut (.c(clk), .d(d), .q(q));

initial forever #5 clk = !clk;

initial #123 d <= 1'b1;
initial #245 d <= 1'b0;
initial #400 $finish;

initial begin $dumpfile("dump_dff.vcd"); $dumpvars(0); end

endmodule


// Xilinx's `glbl` (global set/reset) has no definition in this test's sources.
// read_uhdm refuses an instance of an undefined module, so give it the empty
// body the Xilinx library's glbl amounts to under synthesis.
module glbl();
endmodule
