// MikePopoloski/slang#1492 (closed): Named instance connections don't include correct source location for the expression.
// https://github.com/MikePopoloski/slang/issues/1492
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module passthrough (
  input clk,
  input rst,
  input in,
  output logic out
);
endmodule

module top;
logic clk, rstb;
logic in, out;

passthrough pt (
  .clk,
  .rst (!rstb),
  .*
);

endmodule

