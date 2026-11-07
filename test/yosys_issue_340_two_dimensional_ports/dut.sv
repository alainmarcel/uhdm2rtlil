// YosysHQ/yosys#340: Feature suggestion - SV: support 2-dimensional IOs
// https://github.com/YosysHQ/yosys/issues/340
// A packed 2-D port and an unpacked-array port, read and written per element.

module dut(input logic [3:0][7:0] a, input logic [7:0] b [0:1], output logic [3:0][7:0] y, output logic [7:0] z [0:1]);
  always_comb begin
    for (int i = 0; i < 4; i++) y[i] = a[i] + 1;
    z[0] = b[1]; z[1] = b[0];
  end
endmodule
