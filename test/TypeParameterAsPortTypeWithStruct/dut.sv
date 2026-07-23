// A `parameter type` port bound to a packed STRUCT, with struct-member access
// by NAME inside the child (the CVA6 perf_counters `bp_resolve_t
// resolved_branch_i` pattern).  A `parameter type` instance keeps the SAME
// VpiDefName as its generic definition (unlike value params, which Surelog
// specializes into `$paramod\...`), so the frontend must:
//   1. uniquify the type binding into its own module (else it collapses onto
//      the 1-bit generic `logic` default), and
//   2. recover the real struct width + member bit-offsets from the elaborated
//      instance so `in_i.valid` / `in_i.tag` resolve (the port's own typespec
//      is the generic default `logic`).

package bp_pkg;
  // 10-bit packed struct: valid (MSB) .. tag (LSB).
  typedef struct packed {
    logic       valid;
    logic [7:0] data;
    logic       tag;
  } bp_resolve_t;
endpackage

module tp_child #(
  parameter type field_t = logic
) (
  input  field_t in_i,
  output logic   valid_o,
  output logic   tag_o
);
  // Member access by name: resolves struct field offsets in the elaborated
  // (type-bound) instance, not the generic 1-bit `logic` default.
  assign valid_o = in_i.valid;
  assign tag_o   = in_i.tag;
endmodule

module TypeParameterAsPortTypeWithStruct (
  input  bp_pkg::bp_resolve_t a_i,
  output logic                valid_o,
  output logic                tag_o
);
  tp_child #(.field_t(bp_pkg::bp_resolve_t)) u_a (
    .in_i   (a_i),
    .valid_o(valid_o),
    .tag_o  (tag_o)
  );
endmodule
