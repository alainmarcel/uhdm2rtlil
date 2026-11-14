// MikePopoloski/slang#1227 (closed): wire and port marked as "undriven" when connected to output of not primitive
// https://github.com/MikePopoloski/slang/issues/1227
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test (Y, A);
  output Y;
  input A;
wire B;
not (B, A);
not (Y, B);
endmodule

