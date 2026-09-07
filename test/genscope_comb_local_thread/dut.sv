// Regression: an always_comb inside a GENERATE scope where a generate-scope
// local is written earlier and read back later in the SAME block — via a
// full-var copy chain (f=s; s=f), a bit-select (f[j]=s[k]) and a part-select
// read-modify-write (s[k*4+:4] = TBL[s[k*4+:4]]) — then written to a 2D-array
// slice (data_state[r+1]=s).  The comb-value map is keyed by the FULL wire
// name (gen_round[0].s) but the reads carry the bare VpiName, so the in-flight
// value was missed: the block collapsed to backwards aliasing connects with
// the compute dropped.  The local is declared in the OUTER gen scope while the
// always_comb is in an inner if-generate scope (gen_enc), mirroring ibex
// prim_subst_perm / prim_present.
package tbl_pkg;
  parameter logic [15:0][3:0] TBL = {4'h2,4'h1,4'h7,4'h4,4'h8,4'hF,4'hE,4'h3,
                                     4'hD,4'hA,4'h0,4'h9,4'hB,4'h6,4'h5,4'hC};
endpackage

module genscope_comb_local_thread #(parameter int DW = 8, parameter int NR = 3,
                                     parameter bit ALT = 1'b0) (
  input  logic [DW-1:0] data_i,
  input  logic [DW-1:0] key_i,
  output logic [DW-1:0] data_o
);
  logic [NR:0][DW-1:0] data_state;
  assign data_state[0] = data_i;
  for (genvar r = 0; r < NR; r++) begin : gen_round
    logic [DW-1:0] s, f;                       // declared in OUTER (gen_round) scope
    if (ALT) begin : gen_alt
      always_comb data_state[r+1] = data_state[r];
    end else begin : gen_enc                    // inner if-generate scope
      always_comb begin
        s = data_state[r] ^ key_i;
        for (int k = 0; k < DW/4; k++)          // part-select read-modify-write
          s[k*4 +: 4] = tbl_pkg::TBL[s[k*4 +: 4]];
        for (int k = 0; k < DW; k++)            // bit-select read of s
          f[DW-1-k] = s[k];
        s = f;                                  // full-var copy chain
        for (int k = 0; k < DW/2; k++) begin    // bit-select reads of f
          s[k]         = f[k*2];
          s[k+DW/2]    = f[k*2 + 1];
        end
        data_state[r+1] = s;                    // 2D-array slice write
      end
    end
  end
  assign data_o = data_state[NR] ^ key_i;
endmodule
