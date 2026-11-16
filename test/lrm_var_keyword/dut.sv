// IEEE 1800-2023 6.8: the var keyword declares a variable; with no type it is
// a 1-bit logic, and `output var` makes an output port a variable.
module dut(input logic [3:0] a, input logic b, output var logic [3:0] y, output var z);
  var logic [3:0] v;
  var w;
  always_comb begin
    v = a + 4'd2;
    w = b ^ a[0];
    y = v;
    z = w;
  end
endmodule
