// Regression for OpenTitan pinmux_strap_sampling (egret u_pinmux_aon co-sim
// divergence, mio_attr_o bit 5): a named assignment pattern with `default:`
// used as an ARM of a conditional operator whose target is one ELEMENT of a
// packed array of structs.  The pattern has no typespec of its own; the reader
// recovered the target type from the assignment LHS, but (1) the pattern's
// parent is the `?:`, not the assignment, and (2) the LHS is a bit-select on a
// PORT net whose typespec lives on the port, not the net — so the pattern was
// laid out without its struct and folded to all-zeros (schmitt_en dropped).
package pad_pkg;
  typedef struct packed {
    logic [3:0] drive_strength;
    logic [1:0] slew_rate;
    logic       input_disable;
    logic       od_en;
    logic       schmitt_en;
    logic       keep_en;
    logic       pull_select;
    logic       pull_en;
    logic       virt_od_en;
    logic       invert;
  } pad_attr_t;
  typedef struct packed { integer tck_idx; integer trst_idx; } target_cfg_t;
  parameter target_cfg_t DefaultCfg = '{tck_idx: 0, trst_idx: 3};
endpackage

module dut
  import pad_pkg::*;
#(parameter int NumIOs = 4, parameter target_cfg_t TargetCfg = DefaultCfg)
  (input  logic                  clk,
   input  logic                  rst_n,
   input  logic                  jtag_en,
   input  pad_attr_t [NumIOs-1:0] attr_core_i,
   output pad_attr_t [NumIOs-1:0] attr_padring_o,
   output pad_attr_t [NumIOs-1:0] attr_q_o);

  // Continuous-assign form (pinmux_strap_sampling).
  for (genvar k = 0; k < NumIOs; k++) begin : gen_pads
    if (k == TargetCfg.tck_idx || k == TargetCfg.trst_idx) begin : gen_schmitt_en
      assign attr_padring_o[k] = (jtag_en) ? '{schmitt_en: 1'b1, default: '0} : attr_core_i[k];
    end else begin : gen_no_schmitt
      assign attr_padring_o[k] = (jtag_en) ? '0 : attr_core_i[k];
    end
  end

  // Procedural form: element write through a conditional-op arm, and the
  // pinmux p_regs reset shape (`q[kk] <= '{pull_en: 1'b1, default: '0}`).
  pad_attr_t [NumIOs-1:0] attr_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int kk = 0; kk < NumIOs; kk++) begin
        if (kk == TargetCfg.trst_idx) attr_q[kk] <= '{pull_en: 1'b1, default: '0};
        else                          attr_q[kk] <= '0;
      end
    end else begin
      for (int kk = 0; kk < NumIOs; kk++) begin
        attr_q[kk] <= (kk == TargetCfg.tck_idx && jtag_en) ? '{keep_en: 1'b1, invert: 1'b1, default: '0}
                                                            : attr_core_i[kk];
      end
    end
  end
  assign attr_q_o = attr_q;
endmodule
