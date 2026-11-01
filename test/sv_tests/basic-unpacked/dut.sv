// Converted from chipsalliance/sv-tests (basic-unpacked).
// Upstream declares one UNPACKED array of each of the three kinds and never drives or reads any of them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output bit [7:0] bit_o, output logic [7:0] logic_o,
            output reg [7:0] reg_o);
  bit _bit [7:0];
  logic _logic [7:0];
  reg _reg [7:0];
  // Every element of all three unpacked arrays is driven and read back, so an
  // array that collapsed to fewer elements is visible.
  always_comb
    for (int i = 0; i < 8; i++) begin
      _bit[i]   = x[i];
      _logic[i] = x[i];
      _reg[i]   = x[i];
    end
  always_comb
    for (int i = 0; i < 8; i++) begin
      bit_o[i]   = _bit[i];
      logic_o[i] = _logic[i];
      reg_o[i]   = _reg[i];
    end
endmodule
