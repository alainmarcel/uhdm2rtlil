// IEEE 1800-2023 29.3: a combinational user-defined primitive (a mux whose
// table resolves a matching x on the data inputs).
primitive mux2_udp(output y, input s, input a, input b);
  table
  // s a b : y
     0 0 ? : 0;
     0 1 ? : 1;
     1 ? 0 : 0;
     1 ? 1 : 1;
     x 0 0 : 0;
     x 1 1 : 1;
  endtable
endprimitive

module dut(input logic s, input logic [3:0] a, b, output wire [3:0] y);
  mux2_udp m0(y[0], s, a[0], b[0]);
  mux2_udp m1(y[1], s, a[1], b[1]);
  mux2_udp m2(y[2], s, a[2], b[2]);
  mux2_udp m3(y[3], s, a[3], b[3]);
endmodule
