// MikePopoloski/slang#1705 (closed): Concatenation LHS assignment loses signedness flag in constant evaluation
// https://github.com/MikePopoloski/slang/issues/1705
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test;
  function [7:0] f(input [7:0] value);
    reg signed [2:0] tmp1, tmp2;
    begin
      {tmp1, tmp2} = {value[2:0], value[6:4]};
      f[7:4] = tmp1;
      f[3:0] = tmp2;
    end
  endfunction

  localparam [7:0] res = f(8'h5a);
  // Expected: 8'h2d (tmp2=3'sb101 sign-extends to 4'b1101)
  // Actual:   8'h25 (tmp2=3'b101 zero-extends to 4'b0101)

  initial begin
    $display("%h", res); // prints 25, should print 2d
  end
endmodule

