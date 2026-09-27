// A net declared with OUTER packed dims over a TYPE-PARAMETER element whose
// binding is itself a packed-array typedef, written element-wise through a
// three-index generate assign -- hpdcache_memctrl's read-data reorganiser:
//
//   hpdcache_req_data_t [HPDCACHE_DATA_REQ_RATIO-1:0][ways-1:0] data_read_words;
//   assign data_read_words[gen_i][gen_j][gen_k] = data_rentry[...];
//
// with `typedef word_t [reqWords-1:0] hpdcache_req_data_t` bound through a
// `parameter type`.  Two things collapsed the array before the fix: the
// declaration's [0:0] was taken for a DUPLICATE of the typedef's own [0:0]
// (so both outer dims were dropped and the 512-bit net became 64), and the
// typedef was folded into a single bit dim, so the third index selected ONE
// BIT of a word.  56 of the 64 bits of the way-mux input were left undriven
// in CVA6's hpdcache_memctrl / hpdcache_ctrl.
package p;
  typedef logic [63:0] word_t;
  typedef word_t [0:0] req_data_t;
endpackage
module inner #(parameter type req_data_t = logic) (
  input  logic [511:0] a,
  output logic [511:0] y,
  output logic [63:0]  w3
);
  req_data_t [0:0][7:0] w;
  for (genvar i = 0; i < 1; i++) begin : gi
    for (genvar j = 0; j < 8; j++) begin : gj
      for (genvar k = 0; k < 1; k++) begin : gk
        assign w[i][j][k] = a[(j*64) +: 64];
      end
    end
  end
  assign y  = w;
  assign w3 = w[0][3][0];
endmodule
module typeparam_packed_array_outer_dims (
  input  logic [511:0] a,
  output logic [511:0] y,
  output logic [63:0]  w3
);
  inner #(.req_data_t(p::req_data_t)) u (.a(a), .y(y), .w3(w3));
endmodule
