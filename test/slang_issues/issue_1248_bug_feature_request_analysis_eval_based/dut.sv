// MikePopoloski/slang#1248 (closed): [bug][feature-request][analysis] Eval-based analysis restrictions
// https://github.com/MikePopoloski/slang/issues/1248
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(__o_w);

reg w;

always_comb begin
    if (w == w) // Literally no latch - always equals to `true` but slang analysis engine reports this
        w = 1'b0;
end


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_w;
  assign __o_w = w;
endmodule

