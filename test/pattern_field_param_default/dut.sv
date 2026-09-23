// A named-field ASSIGNMENT PATTERN used to fold its field values against the
// module's DEFAULT parameters instead of the instance's overrides.
//
// `AxiSize` below is a localparam over the module's `W`, which the parent
// overrides to 64.  Used DIRECTLY it was always correct (3); used as a field
// value inside `'{ ... size: AxiSize, ... }` it came out 0 -- and with a
// default of 16 it came out 1, i.e. $clog2(16/8), which is what pinned the
// fold to the DEFAULT rather than to zero.
//
// The fold was Surelog's.  compileAssignmentPattern substituted a field that
// names a parameter with a hard-coded Reduce::Yes lookup, ignoring the
// Reduce::No its caller passes for a module body:
//
//   if (exp->UhdmType() == uhdmref_obj) {
//     if (any *tmp = getValue(name, component, compileDesign, Reduce::Yes, ...
//
// That resolves against the module DEFINITION, where the parameter still holds
// its default, and since the definition's cont_assigns are what every
// elaborated instance carries, the stale constant outlived the override.  The
// elaborated parameter itself was always right (work@dut.u.AxiSize = UINT:3),
// which is why the plain assignment below always agreed with read_slang.
//
// In the wild: PULP axi_lite_to_axi's
//   localparam AxiSize = axi_pkg::size_t'($unsigned($clog2(AxiDataWidth/8)));
//   assign mst_req_o = '{aw: '{size: AxiSize, ...}, ar: '{size: AxiSize, ...}};
// emitted aw.size/ar.size = 0 instead of 3, so axi_lite_to_axi and axi_from_mem
// (which instantiates it) both reported `differs` in the ext_ip sweep.

package pk;
  typedef logic [2:0] size_t;
  typedef struct packed {
    logic [7:0] addr;
    size_t      size;
    logic [1:0] burst;
  } chan_t;
endpackage

module child #(parameter int unsigned W = 32'd0) (
  input  logic [7:0]  addr_i,
  output logic [2:0]  plain_o,   // the localparam used directly  -> 3, correct
  output logic [12:0] pat_o      // the same one inside a pattern -> size 0, wrong
);
  localparam int unsigned AxiSize = pk::size_t'($unsigned($clog2(W/8)));
  pk::chan_t c;
  assign plain_o = AxiSize;
  assign c = '{ addr: addr_i, size: AxiSize, burst: 2'b00, default: '0 };
  assign pat_o = c;
endmodule

module dut (
  input  logic [7:0]  addr_i,
  output logic [2:0]  plain_o,
  output logic [12:0] pat_o
);
  child #(.W(64)) u (.*);
endmodule
