// MikePopoloski/slang#464 (closed): Macro parsing issues if argument starts with a number
// https://github.com/MikePopoloski/slang/issues/464
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define MACRO(ARG) \
    if (PARAM == 0) begin: size``ARG \
        assign var_``ARG = 1'b1; \
    end
module top #(
    int unsigned PARAM = 0
) (__o_var_4K);
    logic var_4K;
    `MACRO(4K)

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_var_4K;
  assign __o_var_4K = var_4K;
endmodule

