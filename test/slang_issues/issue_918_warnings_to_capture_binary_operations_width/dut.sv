// MikePopoloski/slang#918 (closed): Warnings to capture binary operations width mismatch
// https://github.com/MikePopoloski/slang/issues/918
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Test #(
  parameter int NumPipes = 4,
  parameter int Width = 32
 ) (
  input  logic [NumPipes-1:0][Width-1:0] a, b,
  output logic [NumPipes-1:0][Width-1:0] c
 );
  always_comb begin
    for (int pipe = 0; pipe < NumPipes; pipe++) begin
      // Should be b[pipe] but assume it's a typo
      c[pipe] = a[pipe] + b;
    end
  end
endmodule

