// Regression for Caliptra soc_ifc_top's last 24 undriven bits (the
// `fuse_hek_seed` / `fuse_manuf_dbg_unlock_token` `swwel` locks).
//
// `extract_assigned_signals` scanned `for` loop bodies but not `foreach`
// bodies.  The foreach writes were unrolled at import time into the shared
// `$0\hwif_in` temp that the neighbouring `for` loop had created, but their
// bits never entered the written-bits scan — so the process's PARTIAL update
// rule left them out and the bits stayed undriven.
package rp;
  typedef struct packed { logic swwel; }                   fld_t;
  typedef struct packed { fld_t seed; }                    seed_t;
  typedef struct packed { fld_t svn; }                     svn_t;
  typedef struct packed { logic [7:0] other; }             ctrl_t;
  typedef struct packed {
    seed_t [7:0] fuse_hek_seed;      // written by a foreach
    svn_t  [3:0] fuse_runtime_svn;   // written by a for loop
    ctrl_t       CTRL;               // written by a second process
  } reg_in_t;
endpackage

module dut import rp::*; (input logic done, input logic [7:0] oth, output reg_in_t hwif_in);
  always_comb begin
    for (int i = 0; i < 4; i++) begin
      hwif_in.fuse_runtime_svn[i].svn.swwel = done;
    end
    foreach (hwif_in.fuse_hek_seed[i]) begin
      hwif_in.fuse_hek_seed[i].seed.swwel = done;
    end
  end

  always_comb hwif_in.CTRL.other = oth;
endmodule
