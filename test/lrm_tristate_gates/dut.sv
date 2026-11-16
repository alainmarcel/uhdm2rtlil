// IEEE 1800-2023 28.6 / 28.10: bufif0/bufif1/notif0/notif1 three-state gates
// and a pullup on a shared net.  When neither driver is enabled the pullup
// gives 1.
module dut(input logic a, b, en_a, en_b, output wire y, output wire n1, n0);
  wire bus;
  bufif1 g1(bus, a, en_a);
  bufif1 g2(bus, b, en_b & ~en_a);
  pullup p(bus);
  assign y = bus;
  notif1 g3(n1, a, 1'b1);
  notif0 g4(n0, b, 1'b0);
endmodule
