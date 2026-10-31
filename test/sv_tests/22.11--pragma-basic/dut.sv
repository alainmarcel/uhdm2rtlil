// Converted from sv-tests chapter-22/22.11--pragma-basic.sv
// (:type: preprocessing).  Upstream is a single `pragma line with no module.
// The pragma is kept ahead of real logic: an unknown pragma must be ignored
// rather than break the compilation, which the surviving logic demonstrates.
`pragma pragma_name "pragma_value"
module top(input logic [3:0] a, input logic [3:0] b, output logic [3:0] amin);
  assign amin = (a < b) ? a : b;
endmodule
