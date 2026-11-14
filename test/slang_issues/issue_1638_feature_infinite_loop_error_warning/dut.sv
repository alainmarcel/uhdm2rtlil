// MikePopoloski/slang#1638 (closed): [feature] Infinite loop error/warning
// https://github.com/MikePopoloski/slang/issues/1638
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Test(input logic clk,
  output logic [7:0] __o_test_array);
  logic [7:0] test_array;

  always_ff @(posedge clk) begin
    for (logic [2:0] i = 0; i < 8; i++) begin
      test_array[i] <= 1'b0;
    end
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign __o_test_array = test_array;
endmodule

