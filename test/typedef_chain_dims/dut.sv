// Plain-logic twin of typaram_pav_dims: Surelog's ELABORATED net/var for
// `data_t [3:0] arr` (typedef base + extra packed dims) carries only the
// named element typespec; the anonymous outer typespec with [3:0] survives
// only on the AllModules definition view.  The importer widened the wire and
// stamps element-stride attrs from the def view.
module typedef_chain_sub (
    input  logic [31:0] d,
    output logic [31:0] q
);
  assign q = ~d;
endmodule

module typedef_chain_dims (
    input  logic [1:0]  y,
    input  logic [15:0] w0, w1, w2, w3,
    output logic [63:0] flat,
    output logic [15:0] sel,
    output logic [63:0] qflat
);
  typedef logic [15:0] word_p;
  typedef word_p [0:0] data_t;
  data_t [3:0] arr;
  assign arr[0] = w0;
  assign arr[1] = w1;
  assign arr[2] = w2;
  assign arr[3] = w3;
  assign flat = arr;
  assign sel  = arr[y];

  typedef word_p [1:0] pair_t;
  pair_t [1:0][0:0] wentry;
  logic [31:0] qout [2];
  assign wentry[0][0] = {w1, w0};
  assign wentry[1][0] = {w3, w2};
  genvar gy;
  for (gy = 0; gy < 2; gy++) begin : gen_y
    typedef_chain_sub s (.d(wentry[gy][0]), .q(qout[gy]));
  end
  assign qflat = {qout[1], qout[0]};
endmodule
