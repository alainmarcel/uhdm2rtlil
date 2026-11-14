// MikePopoloski/slang#772 (closed): Statically Override Parameters as preprocessing
// https://github.com/MikePopoloski/slang/issues/772
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module mux #(parameter n = 4) (
  input [n-1:0] in,
  input [$clog2(n)-1:0] select,
  input clk,
  output reg out
);
  wire [0:$clog2(n)-1] reversed = select;
  assign out = in[reversed];
endmodule

