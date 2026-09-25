// `'{default: STRUCT_LOCALPARAM}` on an unpacked array of packed structs,
// inside a module that HAS A PARAMETER.
//
// Surelog represents the default tag differently in the two cases:
//   no parameters  -> vpiPattern is the folded `operation`, which carries the
//                     struct typespec;
//   parameterized  -> vpiPattern is a bare `ref_obj` naming the localparam,
//                     with NO typespec at all.
//
// The array-fill code decides element-wise vs bit-wise replication from that
// typespec.  With it missing the element width stayed 1, the struct constant
// was truncated to its bit 0 and replicated, and every element read 0 — so the
// one field whose default is 1'b1 silently disappeared.
//
// OTBN's otbn_mac_bignum_fsm is a parameterized module and lost
// `mul_op_a_tmp_sel` out of `'{default: PredecDynDefault}` on predec_vec,
// predec_mod and predec_mod_mul; that propagated to otbn_instruction_fetch
// and otbn_mac_bignum, which consume its predec_o.
//
// The `UnusedP` parameter is load-bearing: delete it and the bug vanishes.
package p;
  typedef enum logic [1:0] { MulOpB, MulOpMu, MulOpq } sel_e;
endpackage

module paramod_struct_default_array_fill
  #(parameter bit UnusedP = 1'b0)
  (input  logic [1:0] idx_i,
   input  logic [1:0] qw_i,
   output logic [8:0] o,
   output logic [8:0] d);

  typedef struct packed {
    logic [1:0] op_a_qw_sel;
    logic       mul_op_a_tmp_sel;   // the only field whose default is 1
    p::sel_e    mul_op_b_sel;
    logic       mul_add_en;
    logic       c_add_en;
    logic       add_mod_en;
    logic       acc_merger_en;
  } dyn_t;

  localparam dyn_t DynDefault = '{
    op_a_qw_sel:      2'b0,
    mul_op_a_tmp_sel: 1'b1,       // <-- must survive the array fill
    mul_op_b_sel:     p::MulOpB,
    mul_add_en:       1'b0,
    c_add_en:         1'b0,
    add_mod_en:       1'b0,
    acc_merger_en:    1'b0
  };

  // N must cover the whole 2-bit index: an out-of-range read of an unpacked
  // array is X in the behavioural RTL but the netlist's mux returns its last
  // arm, which is a TESTBENCH artefact, not a reader difference.
  localparam int N = 4;
  dyn_t arr [N];

  always_comb begin
    arr = '{default: DynDefault};   // whole-array fill with a STRUCT localparam

    // Elements 1 and 2 clear the field explicitly, so elements 0 and 3 are
    // what discriminate a working fill from a zero fill.
    arr[1].mul_op_a_tmp_sel = 1'b0;
    arr[1].mul_op_b_sel     = p::MulOpMu;
    arr[2].mul_op_a_tmp_sel = 1'b0;
    arr[2].mul_op_b_sel     = p::MulOpq;
    arr[2].mul_add_en       = 1'b1;
    for (int unsigned c = 0; c < N; c++)
      arr[c].op_a_qw_sel = qw_i;
  end

  assign o = arr[idx_i];
  // The SCALAR use of the same localparam was always correct — keep it in the
  // netlist so a regression that breaks it is caught too.
  assign d = DynDefault;
endmodule
