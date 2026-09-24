// A RELAYED type parameter whose default is DEPENDENT on another parameter is
// measured in the receiving instance instead of the declaring one.
//
//   module child #(parameter IdxWidth = pk::idx_width(NoIndices),   // 4 here
//                  parameter type idx_t = logic [IdxWidth-1:0]);
//     grandchild #(.idx_t(idx_t)) u (...);   // relays the TYPE, not NoIndices
//
// The binding is relayed CORRECTLY -- the grandchild's idx_t really does point
// at child's `logic [IdxWidth-1:0]` typespec.  The error was in measuring it:
// that typespec's IdxWidth must be read in CHILD's scope (4), but it was read
// in the grandchild's, where IdxWidth sits at its default 1.  So every idx_t
// port came out ONE BIT -- here grandchild's map_i was 66 bits instead of 72
// and idx_o 1 instead of 4, while dut's own ports were correct, leaving the
// netlist internally inconsistent (`Resizing cell port ... from 4 bits to 1`).
//
// In the wild: PULP axi_lite_mailbox_slave reaches common_cells'
// cc_addr_decode_dync through cc_addr_decode, which passes `.idx_t(idx_t)`
// without NoIndices, so the parent emitted `connect \idx_o \idx_o [0]` and
// tied idx_o[3:1] to zero.
//
// This is the same clone-measurement problem as the type-parameter struct
// width fix (#861), which measures such a typespec in the instance that
// DECLARED it -- but that search only scans each ancestor's TYPEDEF list, and
// a type parameter's own default is not a typedef, so it was never found.
// declaring_instance_of_typeparam_default() finds it by POINTER IDENTITY
// against the type-parameter defaults of every module definition.
//
// MATCHING BY SOURCE LOCATION DOES NOT WORK and was tried and reverted:
// several type parameters share a line, so file/line/column picked the wrong
// one and made map_i 4 bits instead of 66.
//
package pk;
  function automatic int unsigned idx_width (input int unsigned num_idx);
    if (num_idx > 32'd1) return unsigned'($clog2(num_idx));
    else                 return 32'd1;
  endfunction
endpackage

module grandchild #(
  parameter int unsigned NoIndices = 32'd0,
  parameter int unsigned NoRules   = 32'd1,
  parameter type         addr_t    = logic,
  parameter int unsigned IdxWidth  = pk::idx_width(NoIndices),
  parameter type         idx_t     = logic [IdxWidth-1:0],
  parameter type         rule_t    = struct packed {
    idx_t  idx;
    addr_t start_addr;
  }
) (
  input  rule_t [NoRules-1:0] map_i,
  output idx_t                idx_o
);
  assign idx_o = map_i[0].idx;
endmodule

module child #(
  parameter int unsigned NoIndices = 32'd0,
  parameter int unsigned NoRules   = 32'd1,
  parameter type         addr_t    = logic,
  parameter int unsigned IdxWidth  = pk::idx_width(NoIndices),
  parameter type         idx_t     = logic [IdxWidth-1:0],
  parameter type         rule_t    = struct packed {
    idx_t  idx;
    addr_t start_addr;
  }
) (
  input  rule_t [NoRules-1:0] map_i,
  output idx_t                idx_o
);
  grandchild #(.NoRules(NoRules), .addr_t(addr_t), .rule_t(rule_t), .idx_t(idx_t))
    u (.map_i(map_i), .idx_o(idx_o));      // relays types, NOT NoIndices
endmodule

module dut(input logic [71:0] map_i, output logic [3:0] idx_o);
  child #(.NoIndices(10), .NoRules(2), .addr_t(logic [31:0]))
    u (.map_i(map_i), .idx_o(idx_o));      // idx_width(10)=4, rule_t=36, x2=72
endmodule
