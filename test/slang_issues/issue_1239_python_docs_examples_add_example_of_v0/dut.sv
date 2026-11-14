// MikePopoloski/slang#1239 (closed): Python docs/examples: Add example of visiting and transforming AST
// https://github.com/MikePopoloski/slang/issues/1239
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module RefModule (
  input in1,
  input in2,
  output logic out
);

  assign out = in1 & ~in2;

endmodule

