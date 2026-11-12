// povik/sv-elab#132 (closed): `--ignore-timing` flag should ignore `clocking` statements/clauses
// https://github.com/povik/sv-elab/issues/132
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
/*
:name: rose_gclk_function
:description: $rose_gclk test
:tags: 20.13 16.9
:type: simulation elaboration parsing
*/
module top();
logic a, clk;
global clocking @(posedge clk); endclocking
assert property (@(posedge clk) $rose_gclk(a)) else $info;
endmodule

