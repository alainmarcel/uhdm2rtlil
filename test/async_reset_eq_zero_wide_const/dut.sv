// The veer_el2 `rvdff` flop as caliptra instantiates it: an async-reset
// always_ff whose reset test is `rst_l == 0`.  Surelog stores the unsized
// literal 0 at 64 bits; equality sizing (LRM 11.8.2) then widened the 1-bit
// `rst_l` to a 64-bit `$eq`, and yosys's proc_arst -- which recognises the
// reset only when the switch signal is the reset (or a 1-bit compare of it)
// -- reported "Multiple edge sensitive events found for this signal" on
// every such flop: the caliptra chip co-sim netlist could not be generated
// (nightly of 2026-09-27).  A constant wider than the signal whose extra
// bits are only the extension is now narrowed to the signal instead, so the
// compare stays at the signal's width, as read_verilog emits it.
// test_structural.ys gates on `proc` succeeding and yielding one $adff.
module rvdff #( parameter WIDTH=1, SHORT=0 ) (
  input  logic [WIDTH-1:0] din,
  input  logic             clk,
  input  logic             rst_l,
  output logic [WIDTH-1:0] dout
);
if (SHORT == 1) begin : gen_short
   assign dout = din;
end
else begin : gen_ff
   always_ff @(posedge clk or negedge rst_l) begin
      if (rst_l == 0)
        dout[WIDTH-1:0] <= 0;
      else
        dout[WIDTH-1:0] <= din[WIDTH-1:0];
   end
end
endmodule
module async_reset_eq_zero_wide_const (
  input  logic [38:0] din,
  input  logic        clk,
  input  logic        rst_l,
  output logic [38:0] dout,
  output logic [38:0] dout_s
);
  rvdff #(.WIDTH(39)) ff (.din(din), .clk(clk), .rst_l(rst_l), .dout(dout));
  rvdff #(.WIDTH(39), .SHORT(1)) sh (.din(din), .clk(clk), .rst_l(rst_l), .dout(dout_s));
endmodule
