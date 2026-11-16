// IEEE 1800-2023 29.6: an edge-sensitive sequential user-defined primitive (a
// rising-edge D flip-flop).
primitive dff_udp(output reg q, input d, input clk);
  table
  // d clk : q : q+
     0 (01) : ? : 0;
     1 (01) : ? : 1;
     ? (?0) : ? : -;
     * ?    : ? : -;
  endtable
endprimitive

module dut(input logic clk, input logic [1:0] d, output wire [1:0] q);
  dff_udp f0(q[0], d[0], clk);
  dff_udp f1(q[1], d[1], clk);
endmodule
