// Reproducer for CVA6 csr_regfile `ariane_pkg::SMODE_STATUS_WRITE_MASK[XLEN-1:0]`
// "Base signal not found" warning: a PACKAGE localparam sliced directly as the
// base of a part-select.  It is a compile-time constant, not a signal, so it
// must resolve from the package parameter map.
package mask_pkg;
  localparam logic [63:0] MASK = 64'hDEADBEEF_12345678;
endpackage

module pkg_localparam_partsel #(
    parameter int XLEN = 32
) (
    input  logic            sel_i,
    output logic [XLEN-1:0] o_o
);
  assign o_o = sel_i ? mask_pkg::MASK[XLEN-1:0] : '0;
endmodule
