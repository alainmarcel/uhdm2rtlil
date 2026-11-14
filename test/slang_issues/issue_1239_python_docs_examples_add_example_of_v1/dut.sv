// MikePopoloski/slang#1239 (closed): Python docs/examples: Add example of visiting and transforming AST
// https://github.com/MikePopoloski/slang/issues/1239
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module RefModule (
  input in1_visited,
  input in2_visited,
  output logic out_visited
);

  assign out_visited = in1_visited & ~in2_visited;

endmodule

