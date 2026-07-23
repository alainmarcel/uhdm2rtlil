// Minimal reproducer of CVA6's `CVA6Cfg.XLEN` UH0725 blocker.
//
// A module parameter whose TYPE is a packed struct (`config_pkg::cva6_cfg_t
// CVA6Cfg`), with a FIELD of that parameter (`Cfg.XLEN`) read inside a
// `localparam type = struct packed { ... }` definition and a localparam
// initializer — exactly how core/cva6.sv builds its `interrupts_t` /
// `INTERRUPTS`.  Surelog raised UH0725 "Unresolved hierarchical reference
// Cfg.XLEN" for the struct-typed-parameter member access in the localparam-type
// context (it resolves fine in a port width).
package cfg_pkg;
  typedef struct packed {
    int unsigned XLEN;
    int unsigned VLEN;
  } cfg_t;
  localparam cfg_t DefaultCfg = '{XLEN: 32'd64, VLEN: 32'd64};
endpackage

module cva6_struct_param_field #(
    parameter cfg_pkg::cfg_t Cfg = cfg_pkg::DefaultCfg
) (
    input  logic                a_i,
    output logic [Cfg.XLEN-1:0] b_o
);
  // localparam TYPE whose struct field widths reference the struct-param field.
  localparam type it_t = struct packed {
    logic [Cfg.XLEN-1:0] x;
    logic [Cfg.XLEN-1:0] y;
  };
  localparam it_t I = '{x: Cfg.XLEN'(1), y: Cfg.XLEN'(2)};
  assign b_o = a_i ? I.x : I.y;
endmodule
