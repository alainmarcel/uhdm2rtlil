// MikePopoloski/slang#1460 (closed): Unexpected error disallowing intra-assignment delay in always_comb block.
// https://github.com/MikePopoloski/slang/issues/1460
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M (__i_b, __o_a);
logic a,b;

always_comb
    a <= #1ns b;


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_b;
  output logic __o_a;
  assign b = __i_b;
  assign __o_a = a;
endmodule

