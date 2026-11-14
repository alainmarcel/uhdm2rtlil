// MikePopoloski/slang#1608 (closed): width-expand warnings for string assignments using ternary-conditionals
// https://github.com/MikePopoloski/slang/issues/1608
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_a, __i_b, __i_clk, __o_s);

    string s;
    logic clk;
    logic a;
    logic [1:0] b;

    always_ff @(posedge clk) begin
        s = a         ? "1245678" :
            b == 2'h0 ? "12"      :
            b == 2'h1 ? "1234"    :
            b == 2'h1 ? "123456"  :
                        "0";

        s = a ? "1234" :
            b ? "12"   :
                "0";
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_a;
  assign a = __i_a;
  input logic [1:0] __i_b;
  assign b = __i_b;
  input logic __i_clk;
  assign clk = __i_clk;
  output logic __o_s;
  assign __o_s = s;
endmodule

