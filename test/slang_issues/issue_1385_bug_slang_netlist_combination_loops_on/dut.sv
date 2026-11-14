// MikePopoloski/slang#1385 (closed): [bug][slang-netlist] Combination loops on different bits of the same variable
// https://github.com/MikePopoloski/slang/issues/1385
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(__o_w);

wire [10:0]w;

  assign w[0] = w[3];


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [10:0] __o_w;
  assign __o_w = w;
endmodule

