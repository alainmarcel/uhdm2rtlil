// Async-reset for-loop whose reset value is a NAMED pattern with `default:`
// for one element selected by a struct-parameter field (OpenTitan pinmux:
// `if (kk == TargetCfg.tap_strap0_idx) q[kk] <= '{pull_en: 1'b1, default: '0};`).
package ff_reset_loop_named_pattern_cfg_index_pad_pkg;
  // The pad attribute type lives in its own package and is referenced with an
  // explicit package prefix (OpenTitan prim_pad_wrapper_pkg::pad_attr_t).
  typedef struct packed {
    logic       invert;
    logic       virt_od_en;
    logic       pull_en;
    logic       pull_select;
    logic       keep_en;
    logic       schmitt_en;
    logic       od_en;
    logic [1:0] slew_rate;
    logic [3:0] drive_strength;
    logic       input_disable;
  } pad_attr_t;
endpackage

package ff_reset_loop_named_pattern_cfg_index_pkg;
  parameter int NPadsCfg = 4;
  parameter int NDio = 3;
  typedef enum logic [1:0] { PadStd = 2'd0, PadOd = 2'd1 } pad_type_e;
  // Same shape as OpenTitan pinmux_pkg::target_cfg_t: `integer` index fields
  // followed by packed arrays of enums.
  typedef enum logic [1:0] { NoScan = 2'd0, ScanIn = 2'd1 } scan_role_e;
  typedef struct packed {
    integer                    tck_idx;
    integer                    tms_idx;
    integer                    trst_idx;
    integer                    tdi_idx;
    integer                    tdo_idx;
    integer                    tap_idx;
    integer                    tap1_idx;
    integer                    dft0_idx;
    integer                    dft1_idx;
    integer                    usb_dp_idx;
    integer                    usb_dn_idx;
    integer                    usb_sense_idx;
    pad_type_e  [NDio-1:0]     dio_pad_type;
    pad_type_e  [NPadsCfg-1:0] mio_pad_type;
    scan_role_e [NDio-1:0]     dio_scan_role;
    scan_role_e [NPadsCfg-1:0] mio_scan_role;
  } cfg_t;
  parameter cfg_t DefaultCfg = '{
    tck_idx: 0, tms_idx: 0, trst_idx: 0, tdi_idx: 0, tdo_idx: 0,
    tap_idx: 0, tap1_idx: 0, dft0_idx: 0, dft1_idx: 0,
    usb_dp_idx: 0, usb_dn_idx: 0, usb_sense_idx: 0,
    dio_pad_type:  {NDio{PadStd}},
    mio_pad_type:  {NPadsCfg{PadStd}},
    dio_scan_role: {NDio{NoScan}},
    mio_scan_role: {NPadsCfg{NoScan}}
  };
endpackage

module ff_reset_loop_named_pattern_cfg_index_child
  import ff_reset_loop_named_pattern_cfg_index_pkg::*;
#(
  parameter cfg_t Cfg   = DefaultCfg,
  parameter int   NPads = 4
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [NPads-1:0]   we_i,
  input  ff_reset_loop_named_pattern_cfg_index_pad_pkg::pad_attr_t [NPads-1:0] wdata_i,
  output ff_reset_loop_named_pattern_cfg_index_pad_pkg::pad_attr_t [NPads-1:0] attr_o
);
  ff_reset_loop_named_pattern_cfg_index_pad_pkg::pad_attr_t [NPads-1:0] attr_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int kk = 0; kk < NPads; kk++) begin
        if (kk == Cfg.tap_idx) begin
          attr_q[kk] <= '{pull_en: 1'b1, default: '0};
        end else begin
          attr_q[kk] <= '0;
        end
      end
    end else begin
      for (int kk = 0; kk < NPads; kk++) begin
        if (we_i[kk]) begin
          attr_q[kk] <= wdata_i[kk];
        end
      end
    end
  end
  assign attr_o = attr_q;
endmodule

// Chip-level parent: passes its own struct parameter down, as top_egret passes
// PinmuxAonTargetCfg to the pinmux instance.
module ff_reset_loop_named_pattern_cfg_index
  import ff_reset_loop_named_pattern_cfg_index_pkg::*;
#(
  parameter cfg_t TargetCfg = DefaultCfg
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic [3:0]        we_i,
  input  ff_reset_loop_named_pattern_cfg_index_pad_pkg::pad_attr_t [3:0] wdata_i,
  output ff_reset_loop_named_pattern_cfg_index_pad_pkg::pad_attr_t [3:0] attr_o
);
  ff_reset_loop_named_pattern_cfg_index_child #(
    .Cfg(TargetCfg)
  ) u_child (
    .clk_i, .rst_ni, .we_i, .wdata_i, .attr_o
  );
endmodule
