// IEEE 1800-2023 12.7.5: do ... while.  The body runs once before the
// condition is tested; with a constant trip count it unrolls like a for loop.
module dut(input logic [7:0] a, output logic [7:0] y, output logic [3:0] n);
  always_comb begin
    automatic int i = 0;
    y = a;
    do begin
      y = {y[6:0], y[7]} ^ 8'(i);
      i++;
    end while (i < 3);
    n = 4'(i);
  end
endmodule
