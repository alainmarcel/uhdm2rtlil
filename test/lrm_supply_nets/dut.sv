// IEEE 1800-2023 6.6.6: supply0 / supply1 nets are constant 0 / 1 drivers.
module dut(input logic [3:0] a, output logic [3:0] y, z);
  supply1 vdd;
  supply0 gnd;
  supply1 [3:0] ones;
  assign y = a & {4{vdd}} | {4{gnd}};
  assign z = a ^ ones;
endmodule
