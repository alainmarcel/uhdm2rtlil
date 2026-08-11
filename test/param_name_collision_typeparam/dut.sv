// Minimal repro of the CVA6 tc_sram_wrapper we_i=4 bug.
// An inner module with a `parameter type` AND a port sized `[NumPorts-1:0]`
// (its own NumPorts=1) is instantiated inside an enclosing module that ALSO
// has a `parameter NumPorts` (=4).  Surelog resolves the inner PORT typespec
// range against the ENCLOSING NumPorts=4 (giving we_i=[3:0]=4) instead of the
// inner's own NumPorts=1 — while the inner NET typespec is correctly [0:0]=1.
// The `parameter type` is essential (no bug without it).
module inner #(
  parameter int unsigned NumPorts = 1,
  parameter int unsigned DataWidth = 8,
  parameter type data_t = logic [DataWidth-1:0]
) (
  input  logic  [NumPorts-1:0] we_i,
  input  data_t [NumPorts-1:0] d_i,
  output data_t o
);
  assign o = d_i[0];
endmodule

module mid #(parameter int DW = 8) (input logic w, input logic [DW-1:0] d, output logic [DW-1:0] o);
  for (genvar k = 0; k < 1; k++) begin : gen_cut
    inner #(.NumPorts(1), .DataWidth(DW)) u (.we_i(w), .d_i(d), .o(o));
  end
endmodule

module outer #(parameter int unsigned NumPorts = 4) (input logic w, input logic [7:0] d, output logic [7:0] o);
  logic [NumPorts-1:0] some_ports;
  assign some_ports = '0;
  mid #(.DW(8)) m (.w(w), .d(d), .o(o));
endmodule

module param_name_collision_typeparam (input logic w, input logic [7:0] d, output logic [7:0] o);
  outer #(.NumPorts(4)) i (.w(w), .d(d), .o(o));
endmodule
