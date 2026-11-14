// MikePopoloski/slang#1244 (closed): Some possible improvements for -Wint-bool-conv
// https://github.com/MikePopoloski/slang/issues/1244
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_a, __i_b);
    logic clk;
    logic [1:0] a, b;

    always_comb begin
        if (a) begin
       end 
       if (a & b) begin
       end
    end

    assert property (@(posedge clk) a |-> b);
    cover property (@(posedge clk) a);
    cover property (@(posedge clk) a & b);
    cover property (@(posedge clk) a && b);

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [1:0] __i_a;
  assign a = __i_a;
  input logic [1:0] __i_b;
  assign b = __i_b;
endmodule

