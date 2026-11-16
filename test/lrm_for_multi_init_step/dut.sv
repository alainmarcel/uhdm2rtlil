// IEEE 1800-2023 12.7.1: a for loop with two loop variables in the
// initialisation and two steps in the step list.
module dut(input  logic [7:0] a, output logic [7:0] rev, output logic [7:0] mix);
  always_comb begin
    rev = '0;
    for (int i = 0, j = 7; i < 8; i++, j--)
      rev[j] = a[i];
    mix = '0;
    for (int i = 0, j = 1; i < 4; i += 1, j += 2)
      mix[j] = a[i] ^ a[j];
  end
endmodule
