// MikePopoloski/slang#798 (closed): Wrong type printed for type-mismatch error on wildcard connection
// https://github.com/MikePopoloski/slang/issues/798
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface intf (
    input bit [4:0] a
);
endinterface

module top (__i_a, __i_intf_i_a);
    logic [4:0] a;

    intf intf_i(
        .*
    );

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [4:0] __i_a;
  input logic [4:0] __i_intf_i_a;
  assign a = __i_a;
  assign intf_i.a = __i_intf_i_a;
endmodule

