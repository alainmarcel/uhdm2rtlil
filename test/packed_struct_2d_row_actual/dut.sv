// A bit-select on a packed array of typedef'd structs with TWO packed dims
// (`fp_info_t [NUM_FORMATS-1:0][2:0] info_q`, fpnew_fma_multi) used as an
// instance actual: `info_q[fmt]` is a whole ROW (3 structs, 24 bits), but the
// reader sized it as ONE struct (8 bits) -- hierarchy widened the port with x
// and 80 of the 120 info_q bits were never driven.
package p;
  typedef struct packed { logic is_normal; logic is_nan; logic [5:0] cls; } info_t;
endpackage
module classify #(parameter int unsigned NumOperands = 1) (
  input  logic [NumOperands-1:0][7:0] ops_i,
  output p::info_t [NumOperands-1:0] info_o
);
  for (genvar op = 0; op < NumOperands; op++) begin : g
    assign info_o[op].is_normal = ops_i[op][7];
    assign info_o[op].is_nan    = ops_i[op][6];
    assign info_o[op].cls       = ops_i[op][5:0] ^ 6'h15;
  end
endmodule
module packed_struct_2d_row_actual (
  input  logic [7:0][3:0][7:0] ops_i,
  input  logic [2:0] fmt_i,
  input  logic [1:0] op_i,
  output logic normal_o,
  output logic [5:0] cls_o
);
  p::info_t [7:0][3:0] info_q;
  for (genvar fmt = 0; fmt < 8; fmt++) begin : gen_fmt
    classify #(.NumOperands(4)) i_cls (.ops_i(ops_i[fmt]), .info_o(info_q[fmt]));
  end
  assign normal_o = info_q[fmt_i][op_i].is_normal;
  assign cls_o    = info_q[fmt_i][op_i].cls;
endmodule
