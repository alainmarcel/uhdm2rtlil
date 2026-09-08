// Struct signal declared in an OUTER generate scope, member-accessed from a
// NESTED generate scope.  Before the import_hier_path scoped-base fix, `q.<f>`
// referenced from the inner scope resolved the base `q` by flat name only (the
// wire is `\g_outer.q`), missed it, and returned X -- exactly the
// ibex_cs_registers `pmp_mseccfg_q.mml`/`.rlb` gap in the PMP generate, where
// the mseccfg struct is declared in `g_pmp_registers` and read from the nested
// `g_pmp_csrs[i]` for-generate.
module nested_gen_struct_member (
  input  logic [3:0] in,
  input  logic [3:0] sel,
  output logic [3:0] out,
  output logic [3:0] outb
);
  typedef struct packed { logic [1:0] hi; logic x; logic y; } s_t;
  if (1) begin : g_outer
    s_t q;
    assign q.hi = in[3:2];
    assign q.x  = in[0];
    assign q.y  = in[1];
    for (genvar i = 0; i < 4; i++) begin : g_inner
      // plain member access of a parent-scope struct from a nested gen scope
      assign out[i]  = sel[i] ? q.y : q.x;
      // constant (genvar) member bit-select of a parent-scope struct field
      assign outb[i] = q.hi[i[0]];
    end
  end
endmodule
