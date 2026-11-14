// MikePopoloski/slang#772 (closed): Statically Override Parameters as preprocessing
// https://github.com/MikePopoloski/slang/issues/772
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module mux (
  input [3:0] in,
  input [1:0] select,
  input clk,
  output reg out
);
  wire [0:1] reversed = select;
  assign out = in[reversed];
endmodule

