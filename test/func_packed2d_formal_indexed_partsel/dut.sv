// Indexed part-select on a function FORMAL that is a 2-D packed array
// (OpenTitan otp_ctrl_part_pkg::named_broadcast_assign reads
// `part_buf_data[HwCfg0Offset +: (HwCfg0Size - 8)]` from a
// `logic [2047:0][7:0]` formal): the offset and width count ELEMENTS (bytes).
package func_packed2d_formal_indexed_partsel_pkg;
  parameter int Cfg0Offset = 3;
  parameter int Cfg0Size   = 4;
  typedef struct packed {
    logic [7:0]  tag;
    logic [15:0] word;
  } cfg_t;
  function automatic cfg_t pick(logic [7:0][7:0] buf_data);
    cfg_t c;
    c = cfg_t'(buf_data[Cfg0Offset +: (Cfg0Size - 1)]);
    return c;
  endfunction
  function automatic logic [15:0] pick_word(logic [7:0][7:0] buf_data, logic [2:0] k);
    return {buf_data[k], buf_data[1 +: 1]};
  endfunction
endpackage

module func_packed2d_formal_indexed_partsel
  import func_packed2d_formal_indexed_partsel_pkg::*;
(
  input  logic [63:0] data_i,
  input  logic [2:0]  k_i,
  output cfg_t        cfg_o,
  output cfg_t        cfg_comb_o,
  output logic [15:0] word_o
);
  logic [7:0][7:0] buf_data;
  assign buf_data = data_i;
  assign cfg_o = pick(buf_data);
  always_comb begin
    cfg_comb_o = pick(buf_data);
  end
  assign word_o = pick_word(buf_data, k_i);
endmodule
