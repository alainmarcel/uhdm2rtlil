// Two nested functions whose for-loops BOTH use the same loop-var name `k`
// (as prim_cipher_pkg's sbox4_64bit calls sbox4_8bit, both looping over `k`).
// The function-inline for-loop unroll stored the loop value in a flat map keyed
// by bare name and ERASED it on loop exit, so the inner loop wiped the outer
// `k` -> the outer `r[k*8+:8]` indexed-part-select base went non-constant and
// the write was dropped (state_out read undriven).  Fixed by save/restoring the
// outer loop-var value across the (possibly nested) unrolled loop.
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
module nested_func_loopvar_collision(input logic [63:0] i, output logic [63:0] o);
  assign o = cp::outer(i);
endmodule
