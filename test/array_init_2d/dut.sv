// Reproducer for chipsalliance/synlig#1116
// (UHDM-integration-tests/tests/ArrayInit/top.sv).  The DUT
// declares a 2D unpacked array `int n[1:2][1:3]` initialized with
// a nested assignment-pattern and then evaluates `n[1][2] == 1`
// inside an `initial` block.
//
// Per the upstream initializer:
//     n[1][1]=0  n[1][2]=1  n[1][3]=2
//     n[2][1]=4  n[2][2]=4  n[2][3]=4
// so `n[1][2] == 1` is true and `a == 1`.  The original report
// notes the UHDM-frontend AST for the if condition was wrong, so
// `a` came out as 0.
//
// Extra outputs `b`, `c`, `d` expose three other array elements so
// co-sim verifies the whole initializer, not just one cell.
module top(
    output reg a,
    output reg [31:0] b,
    output reg [31:0] c,
    output reg [31:0] d
);
   int n[1:2][1:3] = '{'{0,1,2},'{4, 4, 4}};

   initial begin
      if (n[1][2] == 1)
         a = 1;
      else
         a = 0;

      b = n[1][1];   // expect 0
      c = n[1][3];   // expect 2
      d = n[2][2];   // expect 4
   end
endmodule
