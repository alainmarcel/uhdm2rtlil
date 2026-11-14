// MikePopoloski/slang#1652 (closed): latch inferred warning
// https://github.com/MikePopoloski/slang/issues/1652
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Test;
  logic test_a;
  logic test_b;

  always_comb begin
    case (test_a)
      1'b0: begin
        logic test_b;
        test_b = 1'b1;
        if (test_b) begin
          test_a = 1'b0;
        end
      end
      1'b1: ;
    endcase
  end
endmodule

