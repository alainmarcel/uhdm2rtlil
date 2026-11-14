// MikePopoloski/slang#553 (closed): Sampled value functions with explicitly specified clocking events 
// https://github.com/MikePopoloski/slang/issues/553
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_a);
    logic clk;
    logic a, b;
    always_comb begin
        a = $past(b,,,@(posedge clk));
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_a;
  assign __o_a = a;
endmodule

