// povik/sv-elab#157: comb loops whose exit depends on a RUNTIME value.
//  * k1: a `for` whose body writes its own loop variable under a runtime
//    condition (`i++; continue;`) -- the unroller bound `i` to compile-time
//    values and lost the body's increment.
//  * k2: a `while` with a runtime `break` -- the break was ignored.
// Both are 1 whatever x is.
module top(input x, output reg [2:0] k1, output reg [2:0] k2);
  always_comb begin
    k1 = 0;
    for (int i = 0; i < 2; i++) begin
      k1++;
      if (x) begin
        i++; continue;
      end
      break;
    end
  end
  always_comb begin
    int i;
    k2 = 0; i = 0;
    while (i < 2) begin
      k2++;
      if (x) break;
      i++;
    end
  end
endmodule
