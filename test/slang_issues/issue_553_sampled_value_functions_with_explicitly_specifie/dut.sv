// MikePopoloski/slang#553 (closed): Sampled value functions with explicitly specified clocking events 
// https://github.com/MikePopoloski/slang/issues/553
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_b, __o_a);
    logic clk;
    logic a, b;
    always_comb begin
        a = $past(b,,,@(posedge clk));
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_b;
  output logic __o_a;
  assign b = __i_b;
  assign __o_a = a;
endmodule

