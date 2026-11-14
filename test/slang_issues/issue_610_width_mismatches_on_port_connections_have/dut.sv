// MikePopoloski/slang#610 (closed): Width-mismatches on port-connections have no warning
// https://github.com/MikePopoloski/slang/issues/610
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(
    input logic       clk,
    input logic [7:0] data1,
    input logic [7:0] data2
);
endmodule

module top (__i_clk, __i_data, __i_data2);
    logic clk;
    logic [2:0] data2;

    m m(
        .clk   (clk),
        .data1 (data),
        .data2 (data2)
    );

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  input logic __i_data;
  assign data = __i_data;
  input logic [2:0] __i_data2;
  assign data2 = __i_data2;
endmodule

