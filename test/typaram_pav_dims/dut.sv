// Two width classes from hpdcache_memctrl (both over TYPE-PARAMETER chains):
// 1. packed_array_var whose OWN Ranges carry the outer dims while its
//    typespec is just the element typedef: `data_t [3:0] arr` with
//    `typedef word_t [0:0] data_t` — the ts-only width shortcut collapsed
//    512->64 (here 64->16) and dropped the outer dim.
// 2. two-index var_select through an Elem_typespec chain in a generate:
//    `wentry[gy][gx]` port connection — the second index was treated as a
//    BIT select of the element, wiring 1 bit instead of the element.
module typaram_pav_sub (
    input  logic [31:0] d,
    output logic [31:0] q
);
  assign q = ~d;
endmodule

module typaram_pav_dims #(
    parameter type word_t = logic [15:0]
)(
    input  logic [1:0]  y,
    input  word_t       w0, w1, w2, w3,
    output logic [63:0] flat,
    output word_t       sel,
    output logic [63:0] qflat
);
  typedef word_t [0:0] data_t;
  data_t [3:0] arr;
  assign arr[0] = w0;
  assign arr[1] = w1;
  assign arr[2] = w2;
  assign arr[3] = w3;
  assign flat = arr;
  assign sel  = arr[y];

  typedef word_t [1:0] pair_t;
  pair_t [1:0][0:0] wentry;
  logic [31:0] qout [2];
  assign wentry[0][0] = {w1, w0};
  assign wentry[1][0] = {w3, w2};
  genvar gy;
  for (gy = 0; gy < 2; gy++) begin : gen_y
    typaram_pav_sub s (.d(wentry[gy][0]), .q(qout[gy]));
  end
  assign qflat = {qout[1], qout[0]};
endmodule
