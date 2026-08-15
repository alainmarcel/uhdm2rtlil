// CVA6 cva6_ptw repro (adjudicated against the behavioural RTL under
// iverilog): a DYNAMIC index into a multi-dimensional PACKED array —
// `vaddr_lvl[0][ptw_lvl_q[0]]` on `logic [A:0][B:0][8:0] vaddr_lvl`.
// The packed multi-dim var_select path required ALL indices to be constant
// and bailed otherwise, so the read fell through to a plain 1-BIT
// bit_select: `ptw_pptr_n = {pte.ppn, vaddr_lvl[0][lvl], 3'b0}` lost 8 of
// the element's 9 bits and every page-table pointer was mis-formed.
// Fix: chained shiftx at Sigma (idx_k - low_k) * stride_k when any index is
// dynamic, mirroring the unpacked/struct-array dynamic read paths.
module dyn_packed_multidim (
  input  logic [17:0] flat,
  input  logic        lvl,
  input  logic [1:0]  sel2,
  output logic [8:0]  o_dyn,
  output logic [8:0]  o_const,
  output logic [8:0]  o_dyn_both
);
  logic [0:0][1:0][8:0] vaddr_lvl;
  assign vaddr_lvl  = flat;
  assign o_dyn      = vaddr_lvl[0][lvl];        // dynamic inner index
  assign o_const    = vaddr_lvl[0][1];          // constant control
  assign o_dyn_both = vaddr_lvl[sel2[1]][sel2[0]];  // both indices dynamic
endmodule
