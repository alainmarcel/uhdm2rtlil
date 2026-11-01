// Converted from chipsalliance/sv-tests (basic-packed).
// Upstream declares one packed variable of each of the three kinds and never drives or reads any of them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output bit [7:0] bit_o, output logic [7:0] logic_o,
            output reg [7:0] reg_o);
  bit [7:0] _bit;
  logic [7:0] _logic;
  reg [7:0] _reg;
  // Each of the three declarations is driven and read, so one that lost its width
  // or its driver is visible.
  always_comb begin
    _bit   = x;
    _logic = x;
    _reg   = x;
  end
  assign bit_o   = _bit;
  assign logic_o = _logic;
  assign reg_o   = _reg;
endmodule
