// A for-loop inside a function iterating over a PACKED-ARRAY MEMBER of a
// struct-typed constant function argument — CVA6 pmp_data_if's
// config_pkg::is_inside_execute_regions(CVA6Cfg, addr) shape:
//   - the loop bound is a hier_path member read (`k < C.n`), which in
//     function context imports as a slice of the arg WIRE, so the unroll
//     bound must be sliced from the call context's constant argument;
//   - each iteration reads `C.base[k]` / `C.len[k]`: the hier_path's member
//     element select carries the literal loop-var text `[k]`, which must be
//     substituted with the iteration value before string-driven member
//     resolution;
//   - when neither a module wire nor a parameter backs the base name, the
//     member (array-element select included) must be sliced out of the
//     constant bound to the function formal.
// Before the fixes the reads warned "Could not resolve struct member access
// 'C.base[k]'" and the whole call folded to a constant (pmp_data_if raised
// INSTR_ACCESS_FAULT for addresses inside an execute region).
package p;
  typedef struct packed {
    int unsigned n;
    logic [2:0][63:0] base;
    logic [2:0][63:0] len;
  } cfg_t;

  function automatic cfg_t build();
    cfg_t c;
    // NB: members are assigned WHOLE, matching CVA6's build_config().  Two
    // separate, known Surelog const-eval gaps are deliberately avoided: a
    // whole-struct clear (`c = '0;`) drops the member writes that follow it,
    // and per-element writes (`c.base[0] = ...`) are not captured in the
    // member value annotations at all.  This test targets the READ side: the
    // loop over `C.base[k]` inside inside_regions().
    c.n = 2;
    c.base = {64'h0, 64'h0000_8000, 64'h0000_1000};
    c.len  = {64'h0, 64'h0000_2000, 64'h0000_1000};
    return c;
  endfunction

  function automatic logic inside_regions(cfg_t C, logic [63:0] a);
    automatic logic [2:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < C.n; k++) begin
      pass[k] = (a >= C.base[k]) && (a < (C.base[k] + C.len[k]));
    end
    return |pass;
  endfunction
endpackage

module struct_param_func_loop (
    input  logic [63:0] a_i,
    output logic        o_fn,
    output logic [31:0] o_n
);
  localparam p::cfg_t CFG = p::build();

  // The loop-under-test: must become real address-compare logic, not a
  // constant.
  assign o_fn = p::inside_regions(CFG, a_i);

  // Control: a direct member read of the same parameter.
  assign o_n = CFG.n;
endmodule
