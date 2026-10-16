// A MODULE parameter referenced from inside a constant function, as the
// bound of its loop.
//
// Surelog leaves that ref_obj UNBOUND (no vpiActual) inside the function
// body, and the folder answered an unbound, non-local reference with an
// empty value: `i < N` folded to 0 and the loop never ran.
// rggen_or_reducer's get_offset_list / get_next_n iterate `for (int i = 0;
// i < N; ++i)` over the module's own N.
//
// The loop is deliberately NOT the first statement after the declarations,
// so the loop-block shadowing defect (its own test:
// func_local_shadowed_by_loop_block) cannot mask this one.  The return type
// is a packed 2-D array because Surelog folds a SCALAR parameter RHS itself
// and leaves a multi-dim one as the func_call this folder evaluates.
module dut (
  output logic [15:0] o_val
);
  localparam int N = 5;

  function automatic bit [1:0][15:0] stepped(int base);
    bit [1:0][15:0] r;
    r = '0;                         // first statement: the loop below is NOT
    r[0] = 16'(base);               // the wrapped one (see the sibling test)
    for (int i = 0; i < N; ++i) r[0] = r[0] + 16'd2;
    return r;
  endfunction

  localparam bit [1:0][15:0] V = stepped(1);   // [0] = 1 + 5*2 = 11

  assign o_val = V[0];
endmodule
