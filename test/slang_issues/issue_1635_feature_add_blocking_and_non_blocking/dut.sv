// MikePopoloski/slang#1635 (closed): [feature] add blocking and non-blocking diagnostic error
// https://github.com/MikePopoloski/slang/issues/1635
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module TestModule;
  struct {
    logic a;
    logic b;
  } test;

  always_comb begin
    test.a = 1'b0;
  end

  always_ff @(posedge clk or posedge reset) begin
    test.b <= 1'b1;
  end
endmodule

