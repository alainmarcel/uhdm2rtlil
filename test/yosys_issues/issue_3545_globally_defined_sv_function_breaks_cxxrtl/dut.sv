// YosysHQ/yosys#3545 (open): Globally defined SV function breaks CXXRTL export
// https://github.com/YosysHQ/yosys/issues/3545
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
//top.sv
function int f(input int p);
    f = p;
endfunction

module top(input int i, output int o);
mod m(
    .i(i),
    .o(o)
);
endmodule

(* cxxrtl_blackbox *)
module mod(input int i, output int o);
endmodule

