// Unpacked-array element conventions that must be elem0@LSB regardless of
// the declared direction (mirrors ibex_pmp):
// 1. An unpacked struct-array INPUT PORT (`cfg_t cfg_i [4]`, ascending
//    [0:3]) read via `cfg_i[k].mode` — the struct-field-on-flat-port path
//    applied the PACKED ascending flip and read element 3-k's field
//    (ibex_pmp read region 15-r's cfg and matched the wrong regions).
// 2. `logic [9:2] mask [4]` — element with a NON-ZERO LSB, written per-bit
//    by genvar cont_assigns `mask[r][b]` (b = 2..9) and read whole
//    (ibex_pmp's region_addr_mask [33:2]).
package uaf_pk;
  typedef struct packed {
    logic       lock;
    logic [1:0] mode;
    logic       exec;
    logic       write;
    logic       read;
  } cfg_t;
endpackage

module uaf_sub import uaf_pk::*; (
  input  cfg_t        cfg_i [4],
  input  logic [1:0]  sel_i,
  output logic [1:0]  mode1_o,
  output logic [1:0]  mode_sel_o
);
  assign mode1_o    = 2'b00;
  assign mode_sel_o = cfg_i[sel_i].mode;
endmodule

module unpacked_asc_field import uaf_pk::*; (
  input  logic [23:0] cfg_flat_i,
  input  logic [7:0]  m_i,
  input  logic [1:0]  sel_i,
  output logic [1:0]  mode1_o,
  output logic [1:0]  mode_sel_o,
  output logic [7:0]  mask0_o
);
  cfg_t cfg [4];
  for (genvar r = 0; r < 4; r++) begin : gen_cfg
    assign cfg[r] = cfg_flat_i[r*6 +: 6];
  end

  uaf_sub u_sub (
    .cfg_i      (cfg),
    .sel_i      (sel_i),
    .mode1_o    (mode1_o),
    .mode_sel_o (mode_sel_o)
  );

  logic [9:2] mask [4];
  for (genvar r = 0; r < 4; r++) begin : gen_mask
    for (genvar b = 2; b < 10; b++) begin : gen_bit
      assign mask[r][b] = m_i[b-2] ^ r[0];
    end
  end
  assign mask0_o = mask[0];
endmodule
