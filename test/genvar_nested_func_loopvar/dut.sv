// A genvar loop and two nested inlined-function for-loops ALL named `k` (as
// prim_prince's genvar rounds loop -> sbox4_64bit -> sbox4_8bit).  import_operation
// const-folded a function-body offset (`r[k*4+:4]`) via ExprEval against the
// instance context, where the GENVAR `k` is elaborated -> the inner base folded
// to genvar*4 (out of bounds) and the write dropped (ibex_top's PRINCE S-boxes
// read undriven).  Fixed by skipping the ExprEval fold when an operand
// references a loop-unrolled variable, so it resolves from loop_values instead.
package cp;
  function automatic logic [7:0] inner(logic [7:0] x);
    logic [7:0] r;
    for (int k = 0; k < 2; k++) r[k*4 +: 4] = x[k*4 +: 4] + 4'h1;
    return r;
  endfunction
  function automatic logic [63:0] outer(logic [63:0] x);
    logic [63:0] r;
    for (int k = 0; k < 8; k++) r[k*8 +: 8] = inner(x[k*8 +: 8]);
    return r;
  endfunction
endpackage
module genvar_nested_func_loopvar(input logic [4:0][63:0] di, output logic [4:0][63:0] dso);
  for (genvar k = 0; k < 5; k++) begin : gen
    assign dso[k] = cp::outer(di[k]);
  end
endmodule
