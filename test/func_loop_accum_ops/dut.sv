// A function-local accumulator threaded through an UNROLLED for loop lost
// every iteration but the first.
//
// The unroll machinery threads the accumulator by temporarily remapping it to
// the value-so-far and emits ONE final action after the loop.  The loop body
// ALSO emitted a per-iteration `assign <lhs> <rhs>`, and because the
// accumulator was remapped, that action's target was the value, not the
// variable: `assign 8'00000000 <xor>` on iteration 0 (a write to a CONSTANT,
// which `check` reports as "Drivers conflicting with a constant") and
// `assign $xor$13 $xor$15` afterwards (a combinational self-loop).  `opt`
// collapsed the chain to the first iteration, so
//
//     acc = '0;  for (k) acc = acc ^ a[k];   returned a[0]
//
// The old guard only skipped an ADD into the RETURN variable, so every other
// operator and every function-LOCAL accumulator was silently wrong.  Nothing
// warned: the netlist simply computed the wrong function.
package p;
  // XOR into a local, no begin/end.
  function automatic reg [7:0] fx (input reg [3:0][7:0] a);
    reg [7:0] acc; acc = 8'h00;
    for (int k = 0; k < 4; k++) acc = acc ^ a[k];
    return acc;
  endfunction

  // Same, with begin/end.
  function automatic reg [7:0] fx_be (input reg [3:0][7:0] a);
    reg [7:0] acc; acc = 8'h00;
    for (int k = 0; k < 4; k++) begin acc = acc ^ a[k]; end
    return acc;
  endfunction

  // Initialised in the declaration instead of a statement.
  function automatic reg [7:0] fx_decl (input reg [3:0][7:0] a);
    reg [7:0] acc = 8'h00;
    for (int k = 0; k < 4; k++) acc = acc ^ a[k];
    return acc;
  endfunction

  // OR and AND, to show the operator was never the point.
  function automatic reg [7:0] fo (input reg [3:0][7:0] a);
    reg [7:0] acc; acc = 8'h00;
    for (int k = 0; k < 4; k++) acc = acc | a[k];
    return acc;
  endfunction
  function automatic reg [7:0] fn (input reg [3:0][7:0] a);
    reg [7:0] acc; acc = 8'hFF;
    for (int k = 0; k < 4; k++) acc = acc & a[k];
    return acc;
  endfunction

  // Accumulating straight into the return variable, non-ADD operator.
  function automatic reg [7:0] fr (input reg [3:0][7:0] a);
    fr = 8'h00;
    for (int k = 0; k < 4; k++) fr = fr ^ a[k];
  endfunction

  // ADD into the return variable — the one shape the old narrow guard
  // already covered.  Kept so a fix here cannot regress it.
  function automatic reg [7:0] fadd (input reg [3:0][7:0] a);
    fadd = 8'h00;
    for (int k = 0; k < 4; k++) fadd = fadd + a[k];
  endfunction

  // Leak guard.  `loop_accumulators` means "this variable is threaded by the
  // loop RIGHT NOW"; if an entry outlives its loop, every later write to a
  // same-named variable is skipped.  This function reuses the name `acc` for
  // a variable that is NOT an accumulator, and comes after the ones above.
  function automatic reg [7:0] freuse (input reg [3:0][7:0] a, input reg [1:0] m);
    reg [7:0] acc;
    acc = 8'h00;
    case (m)
      2'b00:   acc = a[0];
      2'b01:   for (int k = 0; k < 4; k++) acc[k] = a[k][0];
      2'b10:   acc = a[1] + a[2];
      default: acc = a[3];
    endcase
    return acc;
  endfunction

  // Control: accumulator seeded from a NON-constant.  This shape already
  // worked, because the remapped target was a real wire.
  function automatic reg [7:0] fseed (input reg [3:0][7:0] a, input reg [7:0] s);
    reg [7:0] acc; acc = s;
    for (int k = 0; k < 4; k++) acc = acc ^ a[k];
    return acc;
  endfunction
endpackage

module func_loop_accum_ops (
  input  reg [3:0][7:0] a,
  input  reg [7:0]      s,
  output logic [7:0]    o_xor,
  output logic [7:0]    o_xor_be,
  output logic [7:0]    o_xor_decl,
  output logic [7:0]    o_or,
  output logic [7:0]    o_and,
  output logic [7:0]    o_ret,
  output logic [7:0]    o_add,
  output logic [7:0]    o_seed,
  input  reg [1:0]      m,
  output logic [7:0]    o_reuse
);
  assign o_xor      = p::fx(a);
  assign o_xor_be   = p::fx_be(a);
  assign o_xor_decl = p::fx_decl(a);
  assign o_or       = p::fo(a);
  assign o_and      = p::fn(a);
  assign o_ret      = p::fr(a);
  assign o_add      = p::fadd(a);
  assign o_seed     = p::fseed(a, s);
  assign o_reuse    = p::freuse(a, m);
endmodule
