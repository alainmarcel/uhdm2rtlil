// A module that exists only to fold an expression must not leave the importer
// holding pointers into it.
//
// `parameter int DATA_WIDTH = $bits(req_t)` over a TYPE PARAMETER is a value
// Surelog cannot stamp, so the paramod-signature builder re-imports the
// expression inside a THROWAWAY module.  `req_t` is a type, so importing it as
// an expression is a reference to an unknown signal and the fallback fabricates
// a 1-bit wire for it.  The SECOND reference in the same expression then finds
// that wire with `module->wire()` and caches it as `name_map["req_t"]`  --
// which is why the expression below names the type twice.  Deleting the
// throwaway module frees the wire while name_map keeps pointing at it, so the
// next reference to `req_t` builds a SigSpec over freed memory and takes
// whatever width the block now holds.
//
// PULP's axi_burst_counters (via common_cells' cc_id_queue, whose
// `localparam type id_t = logic[IdWidth-1:0]` arrives the same way) aborted
// read_uhdm outright with
//     ERROR: Assert `chunk_.width >= 0' failed in kernel/rtlil.cc
// but only sometimes: it reproduced under `yosys check.ys` and not under
// `yosys -s check.ys`, and never under gdb.  Nothing about the netlist gives
// the bug away, so the gate here is test_memcheck.ys under valgrind, which
// reports the stale read unconditionally:
//     Invalid read of size 4
//        at RTLIL::SigSpec::SigSpec(RTLIL::Wire*)
//        by UhdmImporter::import_ref_obj(...)
//      Address ... inside a block of size 104 free'd
//        by UhdmImporter::import_module_hierarchy(...)
//      Block was alloc'd at
//        by UhdmImporter::create_wire(...)
package pk;
  typedef struct packed { logic [31:0] a; logic [63:0] d; logic w; } req_t;
endpackage

module leaf #(
    parameter  type req_t      = pk::req_t,
    parameter  int  DATA_WIDTH = ($bits(req_t) + $bits(req_t)) / 2,
    localparam type data_t     = logic [DATA_WIDTH-1:0]
) (
    input  data_t d_i,
    output logic  o
);
  assign o = ^d_i;
endmodule

module dut (
    input  logic [96:0] d0_i,
    input  logic [96:0] d1_i,
    output logic        o0,
    output logic        o1
);
  leaf #(.req_t(pk::req_t)) u0 (.d_i(d0_i), .o(o0));
  leaf #(.req_t(pk::req_t)) u1 (.d_i(d1_i), .o(o1));
endmodule
