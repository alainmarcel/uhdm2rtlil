// A struct member read whose member NAME is also a module-level signal
// (OpenTitan pattgen_chan: `logic enable; assign enable = ctrl_i.enable;`).
// Surelog binds the `enable` path element to the module-scope signal
// (VpiFullName work@pattgen_chan.enable) and the hier_path importer followed
// that binding, producing `assign enable = enable` — a self-loop that folded
// to 0, so neither pattgen channel ever enabled.  The base `ctrl_i` is a
// struct PORT with no Actual_group; the importer now resolves its typespec by
// name on the instance and never binds later path elements by module name.
package hsm_pkg;
  typedef struct packed { logic enable; logic polarity; logic [31:0] prediv; logic [5:0] len; } ctrl_t;
endpackage
module hier_path_struct_member_shadow import hsm_pkg::*; (
  input  logic  clk_i, input logic rst_ni,
  input  ctrl_t ctrl_i,
  output logic  enable_o, output logic polarity_o, output logic [31:0] prediv_o
);
  logic enable;
  logic polarity;
  logic [31:0] prediv_q;
  assign enable   = ctrl_i.enable;
  assign polarity = ctrl_i.polarity;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) prediv_q <= '0;
    else prediv_q <= enable ? prediv_q : ctrl_i.prediv;
  end
  assign enable_o   = enable;
  assign polarity_o = polarity;
  assign prediv_o   = prediv_q;
endmodule
