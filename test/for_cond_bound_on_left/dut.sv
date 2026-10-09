// A for loop whose condition puts the BOUND on the left (`0 <= j`, `4 > i`),
// RSD CommitStage's GetInsnPtr `for (int j = i - 1; 0 <= j; j--)`.  Unpatched
// read_uhdm read the operator literally as `j <= 0` / `i > 4` with the loop
// variable as the "bound": the loop could not be unrolled statically and its
// body ran with a dynamic index ("Reference to unknown signal: j").
module for_cond_bound_on_left(input logic [3:0] x, output logic [3:0] y, output logic [3:0] z);
  always_comb begin
    y = '0;
    for (int j = 3; 0 <= j; j--) y[j] = x[j] ^ x[3 - j];
    z = '0;
    for (int i = 0; 4 > i; i++) if (x[i]) z[i] = ~x[(i + 1) % 4];
  end
endmodule
