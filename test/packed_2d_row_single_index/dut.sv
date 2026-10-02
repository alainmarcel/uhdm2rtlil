// ONE index into a 2-D PACKED array selects a whole ROW, not one element.
//
// `packed_elem_width` is the BASE element (a nested `a[i][j]` steps the inner
// index by it), so on `my_t [1:0][1:0]` it is 12 while a row is 24.  A single
// `a[k]` extracted 12 of the 24 bits.  PULP's cc_stream_xbar is the shape that
// matters: `payload_t [NumOut-1:0][NumInp-1:0] out_data` with `out_data[j]`
// handed its arbiter 54 of 216 bits -- one input instead of four.
//
// Both a plain typedef base and a relayed TYPE PARAMETER base are covered, and
// `n` keeps the nested two-index form honest (it must still step the inner
// index by the base element).
module leaf #(parameter int unsigned N = 2, parameter type d_t = logic) (
  input  d_t [N-1:0] i,
  output d_t         o
);
  assign o = i[1] ^ i[0];
endmodule

module mid #(
  parameter int unsigned DW   = 32'd1,
  parameter type         pl_t = logic [DW-1:0]
) (
  input  pl_t [1:0][1:0] d,
  output pl_t [1:0]      o
);
  for (genvar j = 0; j < 2; j++) begin : gen_outs
    leaf #(.N(2), .d_t(pl_t)) u_leaf (.i(d[j]), .o(o[j]));
  end
endmodule

module dut (
  input  logic [1:0][1:0][11:0] d,
  input  logic [1:0]            k,
  output logic [1:0][11:0]      o,     // row through a type parameter
  output logic [23:0]           row,   // row of a plain typedef array
  output logic [11:0]           n      // nested two-index select
);
  typedef struct packed { logic [7:0] a; logic [3:0] b; } my_t;   // 12 bits

  mid #(.pl_t(my_t)) u_mid (.d(d), .o(o));

  my_t [1:0][1:0] e;
  assign e = d;
  assign row = e[k[0]];          // ONE index -> a 24-bit row
  assign n   = e[k[0]][k[1]];    // two indices -> a 12-bit element
endmodule
