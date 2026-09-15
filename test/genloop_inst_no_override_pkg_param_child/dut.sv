// Several generate-loop instances of a child with NO parameters of its own
// (so no overrides), whose definition imports a package parameter into its own scope and
// instantiates a parameterized grandchild (OpenTitan alert_handler's
// `gen_classes[k].u_accu` -> alert_handler_accu -> prim_count #(.Width)).
// The instance importer (which only encodes constant values, not the
// '{} pattern) named the child plain `accu`, the module importer
// registered it as `$paramod\accu\PKG_DEFAULT=...` and also imported the
// bare DEFINITION as `accu`; instances 1..N-1 bound to that definition
// module, whose grandchild cell stayed unspecialized, and `hierarchy`
// rejected the Egret top ("does not have a parameter named 'WIDTH'").
package genloop_inst_no_override_pkg_param_child_reg_pkg;
  parameter int NClasses = 4;
  parameter int NAlerts = 40;
endpackage

package genloop_inst_no_override_pkg_param_child_pkg;
  localparam int unsigned N_CLASSES = genloop_inst_no_override_pkg_param_child_reg_pkg::NClasses;
  localparam int unsigned NAlerts   = genloop_inst_no_override_pkg_param_child_reg_pkg::NAlerts;
  typedef enum logic [2:0] {Idle = 3'b000, Timeout = 3'b001, Terminal = 3'b011} cstate_e;
  typedef struct packed {
    logic    [NAlerts-1:0]             cause;
    logic    [N_CLASSES-1:0][15:0]     accum_cnt;
    cstate_e [N_CLASSES-1:0]           esc_state;
  } dump_t;
  // Replication of an enum inside the pattern: Surelog leaves the value an
  // operation (not a folded constant) on the instance's param_assign.
  parameter dump_t PKG_DEFAULT = '{
    cause: '0,
    accum_cnt: '0,
    esc_state: {N_CLASSES{Idle}}
  };
  localparam int AccuCntDw = 6;
endpackage

module genloop_inst_no_override_pkg_param_child_cnt #(parameter int Width = 4) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             en_i,
  output logic [Width-1:0] cnt_o
);
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) cnt_o <= '0;
    else if (en_i) cnt_o <= cnt_o + 1'b1;
endmodule

module genloop_inst_no_override_pkg_param_child_accu
  import genloop_inst_no_override_pkg_param_child_pkg::*;
(
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              trig_i,
  output logic [AccuCntDw-1:0] cnt_o,
  output logic [7:0]        dflt_o
);
  genloop_inst_no_override_pkg_param_child_cnt #(.Width(AccuCntDw)) u_cnt (
    .clk_i, .rst_ni, .en_i(trig_i), .cnt_o
  );
  assign dflt_o = {PKG_DEFAULT.esc_state[1:0], PKG_DEFAULT.accum_cnt[0][1:0]} ^ 8'h5A;
endmodule

module genloop_inst_no_override_pkg_param_child (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [3:0]  trig_i,
  output logic [23:0] cnt_o,
  output logic [7:0]  dflt_o
);
  logic [7:0] dflt [4];
  for (genvar k = 0; k < 4; k++) begin : gen_classes
    genloop_inst_no_override_pkg_param_child_accu u_accu (
      .clk_i, .rst_ni, .trig_i(trig_i[k]), .cnt_o(cnt_o[k*6 +: 6]), .dflt_o(dflt[k])
    );
  end
  assign dflt_o = dflt[0] ^ dflt[1] ^ dflt[2] ^ dflt[3] ^ 8'hFF;
endmodule
