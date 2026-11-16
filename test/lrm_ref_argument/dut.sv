// IEEE 1800-2023 13.5.2: pass by reference.  A ref argument of an automatic
// task aliases the actual, so writes through it update the caller's variable.
module dut(input logic [7:0] a, b, output logic [7:0] x, y);
  task automatic swap_add(ref logic [7:0] p, ref logic [7:0] q, input logic [7:0] k);
    logic [7:0] t;
    t = p;
    p = q + k;
    q = t;
  endtask
  always_comb begin
    x = a;
    y = b;
    swap_add(x, y, 8'd3);
  end
endmodule
