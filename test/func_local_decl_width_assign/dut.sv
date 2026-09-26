// A block-local of declared width assigned a wider literal, then bit-written
// and concatenated:  reg [W-1:0] data_val;  data_val = 0;  data_val[i] = ...;
// f = {data_val, state_val};
// The compile-time evaluator took the literal's 64 bits as the local's new
// width, the bit writes landed in the low bits, and the concatenation grew
// to 128 bits — the function result kept only its low bits, so the upper
// half (data_val) vanished.  verilog-ethernet lfsr's REVERSE branch builds
// {data_val, state_val} exactly this way: the data half of every CRC mask
// was zero (axis_gmii_tx / eth_mac_1g co-sim divergences).  A whole-variable
// assignment is now sized to the local's declaration.
module func_local_decl_width_assign #(
  parameter W = 4
) (
  input  logic [7:0] x,
  output logic [7:0] y
);
  // f(1) = {data_val, state_val} = 8'b0100_0101
  function [2*W-1:0] f(input [31:0] index);
    reg [W-1:0] state_val;
    reg [W-1:0] data_val;
    integer i;
    begin
      state_val = 0;
      for (i = 0; i < W; i++) state_val[i] = (i + index) % 2;
      data_val = 0;
      for (i = 0; i < W; i++) data_val[i] = ((i + index) % 3) == 0;
      f = {data_val, state_val};
    end
  endfunction
  assign y = f(1) ^ x;
endmodule
