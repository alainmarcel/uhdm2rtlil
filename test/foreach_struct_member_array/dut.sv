// Regression for Caliptra soc_ifc_top (24 fuse `swwel` bits undriven in the
// flattened chip): `foreach (hwif_in.fuse_hek_seed[i])` iterates a STRUCT
// MEMBER packed array — the loop bounds live on the member's typespec,
// reached through the hierarchical path.  The foreach was not unrolled
// ("Cannot unroll foreach in comb context") and every write in it was lost.
package rp;
  typedef struct packed { logic swwel; logic we; } fld_in_t;
  typedef struct packed { fld_in_t seed; } seed_in_t;
  typedef struct packed { logic value; } done_out_t;
  typedef struct packed {
    seed_in_t [7:0] fuse_hek_seed;
    seed_in_t [15:0] fuse_token;
  } reg_in_t;
endpackage
module dut import rp::*; (input logic done, input logic [7:0] we_i, output reg_in_t hwif_in);
  always_comb begin
    hwif_in = '0;
    foreach (hwif_in.fuse_hek_seed[i]) begin
      hwif_in.fuse_hek_seed[i].seed.swwel = done;
    end
    foreach (hwif_in.fuse_token[i]) begin
      hwif_in.fuse_token[i].seed.swwel = done;
      hwif_in.fuse_token[i].seed.we    = we_i[i % 8];
    end
  end
endmodule
