// MikePopoloski/slang#1249 (closed): [bug][slang] Looped port connection type elaboration
// https://github.com/MikePopoloski/slang/issues/1249
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module rv_plic import rv_plic_reg_pkg::*; (
    input  [63:0] c
);
endmodule

// ---- b1.sv
package rv_plic_reg_pkg;
    parameter int NumSrc = 64;
endpackage

module rv_plic_bind_fpv;
  bind rv_plic rv_plic_assert_fpv #(
    .P(rv_plic_reg_pkg::NumSrc)
  ) m(
    .intr_src_i(c)
  );
endmodule

// ---- b2.sv
module rv_plic_assert_fpv #(parameter int P = 1) (input [P-1:0] intr_src_i);
endmodule

