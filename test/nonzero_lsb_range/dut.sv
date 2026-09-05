// A vector declared with a NON-ZERO LSB index (`logic [31:1] q`), read via
// full part-select `q[31:1]`, a bit-select of its LOWEST bit `q[1]`, and an
// inner part-select `q[3:2]`.  The importer's 0-based offset math
// over-shot by the declared low bound: `q[31:1]` warned "partially out of
// bounds" and collapsed to X (ibex_fetch_fifo's instr_addr_next), and
// `q[1]` read the wrong bit.
module nonzero_lsb_range (
  input  logic [31:0] a_i,
  output logic [31:0] next_o,
  output logic        bit1_o,
  output logic [1:0]  mid_o
);
  logic [31:1] q;
  assign q = a_i[31:1];
  assign bit1_o = q[1];
  assign mid_o  = q[3:2];
  assign next_o = {(q[31:1] + 31'd1), 1'b0};
endmodule
