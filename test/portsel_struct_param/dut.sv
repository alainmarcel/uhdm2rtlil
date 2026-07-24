// Reproducer for CVA6 `.boot_addr_i(boot_addr_i[CVA6Cfg.VLEN-1:0])` (cva6.sv:692).
// The CHILD port resolves to the correct width (like id_stage.fetch_entry_i =
// 366), but the parent's port-connection part-select range uses a struct-param
// field CFG.VLEN that the frontend can't fold (CFG computed by build_config()),
// so the connection collapses to `boot_addr_i[0]` (1 bit) and gets resized from
// 1 bit at flatten — dropping boot_addr_i[63:1].
package cfg_pkg;
  typedef struct packed { logic [31:0] VLEN; logic [31:0] XLEN; } cfg_t;
  localparam int unsigned CVA6ConfigXlen = 64;
  function automatic cfg_t build_config();
    cfg_t c; c.VLEN = CVA6ConfigXlen; c.XLEN = CVA6ConfigXlen; return c;
  endfunction
  localparam cfg_t CFG = build_config();
endpackage

module child (
    input  logic [63:0] addr_i,      // fixed 64-bit port (resolves correctly)
    output logic [63:0] addr_o
);
    assign addr_o = addr_i ^ 64'h1;
endmodule

module portsel_struct_param #(
    parameter cfg_pkg::cfg_t CFG = cfg_pkg::build_config()
) (
    input  logic [63:0] boot_addr_i,
    output logic [63:0] out
);
    child c (
        .addr_i(boot_addr_i[CFG.VLEN-1:0]),  // part-select range = CFG.VLEN
        .addr_o(out)
    );
endmodule
