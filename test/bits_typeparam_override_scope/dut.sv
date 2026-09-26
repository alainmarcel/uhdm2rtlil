// `.IdWidth($bits(id_t))` -- a parameter OVERRIDE actual is written in the
// INSTANTIATING scope, where `id_t` is the parent's type parameter (bound to
// logic [3:0]).  The child declares its own `localparam type id_t =
// logic[IdWidth-1:0]`, and Surelog binds the actual's ref to THAT one, which
// recurses into the very parameter being set: read_uhdm built the child at
// IdWidth 1 (paramod signature) / 2 (applied value, the cycle guard's
// `[-1:0]`) and resized its 4-bit id ports ("Resizing cell port ... from 4
// bits to 2 bits").  common_cells cc_id_queue under PULP axi_burst_splitter.
// The override RHS node is detached, so the callers that evaluate an override
// now record the child and `$bits` resolves the name in the parent first.
module bits_typeparam_override_scope (
  input  logic       clk,
  input  logic [3:0] a,
  input  logic [3:0] b,
  output logic [3:0] y,
  output logic [4:0] w
);
  mid #(.id_t(logic [3:0])) u (.clk(clk), .a(a), .b(b), .y(y), .w(w));
endmodule

module mid #(
  parameter type id_t = logic
) (
  input  logic clk,
  input  id_t  a,
  input  id_t  b,
  output id_t  y,
  output logic [4:0] w
);
  leaf #(.IdWidth($bits(id_t))) i_leaf (.clk(clk), .a(a), .b(b), .y(y), .w(w));
endmodule

module leaf #(
  parameter int unsigned IdWidth = 1,
  localparam type id_t = logic [IdWidth-1:0]
) (
  input  logic clk,
  input  id_t  a,
  input  id_t  b,
  output id_t  y,
  output logic [4:0] w
);
  id_t q;
  always_ff @(posedge clk) q <= a ^ b;
  assign y = q;
  assign w = IdWidth;
endmodule
