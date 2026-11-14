// MikePopoloski/slang#1560 (closed): -Wbitwise-op-mismatch for operations between a vector and a packed array of the same bit width
// https://github.com/MikePopoloski/slang/issues/1560
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test;
  logic [15:0] vin, vout;
  logic [1:0][7:0] pa;
  
  initial begin
    vin = 16'h3333;
    pa[0] = 8'h11; 
    pa[1] = 8'h11; 
  end

  assign vout = vin ^ pa;
endmodule

