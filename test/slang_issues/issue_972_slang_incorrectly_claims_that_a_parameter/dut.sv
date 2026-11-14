// MikePopoloski/slang#972 (closed): Slang incorrectly claims that a parameter is recursively defined
// https://github.com/MikePopoloski/slang/issues/972
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define PARAM_DECL parameter X=1,\
                           parameter I=3,\
                           parameter W=I+1\


module t
#(// Parameters
  `PARAM_DECL,
  parameter J=2,
  parameter Y=I+1,
  parameter Z=J+1
)
  (
output [W-1:0]w,
output [Y-1:0]y,
output [X-1:0]z
);
assign w = {W{1'b0}};
endmodule

