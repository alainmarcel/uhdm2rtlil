// Reproducer for chipsalliance/synlig#555 — `$bits(typedef_name)`
// used inside a part-select range expression fails to resolve the
// width of the typedef.  The original orv64 source pattern (from
// `rtl/orv64/orv64_csr.sv:1627`) is:
//
//   if (ma2cs.csr_addr == ORV64_CSR_ADDR_MHPMCOUNTER3)
//     hpmcounter3 <= csr_wdata[$bits(orv64_cntr_t)-1:0];
//
// The user's attached reproducer from the issue
// (`Fail_detect_width/top.sv`) had only `assign b = $bits(...)`
// which observes the value but not the part-select form that
// orv64 actually uses.  We keep the package/typedef declaration
// verbatim from the issue and adapt the module to:
//   * be controllable (csr_wdata as input)
//   * be observable (hpmcounter as output, full ORV64_CNTR_WIDTH
//     bits — co-sim then exercises every bit of the part-select)
//   * actually exercise the failing `[$bits(...)-1:0]` part-select.
package pack;
  parameter ORV64_CNTR_WIDTH = 48;
  typedef logic [ORV64_CNTR_WIDTH-1:0]     orv64_cntr_t;
endpackage

module top (
    input  logic [63:0]                     csr_wdata,
    output logic [pack::ORV64_CNTR_WIDTH-1:0] hpmcounter
);
  import pack::*;
  assign hpmcounter = csr_wdata[$bits(orv64_cntr_t)-1:0];
endmodule
