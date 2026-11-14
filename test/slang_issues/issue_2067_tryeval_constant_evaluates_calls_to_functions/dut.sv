// MikePopoloski/slang#2067 (closed): tryEval constant-evaluates calls to functions with static variables in procedural code, giving spurious index-oob errors and wrong cached constants
// https://github.com/MikePopoloski/slang/issues/2067
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(input logic clk, output logic q);
  function automatic int next_slot();
    static int slot = 5;
    slot = slot + 1;
    return slot;
  endfunction
  logic [15:0] pattern = 16'hB278;
  always_ff @(posedge clk) q <= pattern[next_slot()];
endmodule

