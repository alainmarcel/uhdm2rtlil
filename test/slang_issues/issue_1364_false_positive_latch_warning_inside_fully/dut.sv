// MikePopoloski/slang#1364 (closed): False positive latch warning inside fully-covered conditionals
// https://github.com/MikePopoloski/slang/issues/1364
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Test;
  logic [3:0][31:0] a;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      if (i == 0) begin
        a[i] = 0;
      end
      else if (i == 1) begin
        a[i] = 1;
      end
      else if (i == 2) begin
        a[i] = 2;
      end
      else if (i == 3) begin
        a[i] = 3;
      end
    end
  end
endmodule

