// povik/sv-elab#262 (closed): `assert` in `initial` block omitted
// https://github.com/povik/sv-elab/issues/262
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
//----------------------------------------------------------------
// Tests support of simple_immediate_assertions: assert()
//----------------------------------------------------------------
module simple_immediate_assert_statement(input dummy);

initial assert(0);

endmodule

