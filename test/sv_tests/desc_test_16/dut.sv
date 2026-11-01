// Converted from chipsalliance/sv-tests (desc_test_16).
// Upstream is an `ifdef skeleton with none of its names defined, so it resolves to an empty arm and declares no module at all -- nothing about which arm was taken is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`ifdef ASIC
module module_asic(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
`elsif FPGA  // ASIC
module module_fpga(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
`endif  // ASIC
module top(input logic [7:0] a, output logic [3:0] arm, output logic [8:0] y);
  // Neither arm is taken: `elsif FPGA is false too, so NO module is
  // declared and the top has to carry the logic itself.
  assign y   = a + 8'd3;
  assign arm = 4'd0;
endmodule
